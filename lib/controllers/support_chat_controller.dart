import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_conversation.dart';
import '../models/support_message.dart';
import '../models/user.dart';
import '../services/support_chat_service.dart';

/// Support Chat Controller
/// Reactive GetX controller for Customer Support Chat and Admin Support Management.
/// Features dual-mode real-time sync (Supabase Realtime WebSocket + background polling fallback).
class SupportChatController extends GetxController {
  final SupportChatService _service;

  SupportChatController({SupportChatService? service})
      : _service = service ?? SupportChatService();

  static SupportChatController get to => Get.find<SupportChatController>();

  final Rx<SupportConversation?> _activeConversation =
      Rx<SupportConversation?>(null);
  final RxList<SupportMessage> _messages = <SupportMessage>[].obs;
  final RxList<SupportConversation> _adminConversations =
      <SupportConversation>[].obs;

  final RxBool _isLoading = false.obs;
  final RxBool _isSending = false.obs;
  final RxString _activeUserId = ''.obs;
  final RxString _activeRole = 'customer'.obs; // 'customer' or 'admin'

  RealtimeChannel? _conversationChannel;
  RealtimeChannel? _adminMessagesChannel;
  RealtimeChannel? _adminConversationsChannel;

  SupportConversation? get activeConversation => _activeConversation.value;
  List<SupportMessage> get messages => List.unmodifiable(_messages);
  List<SupportConversation> get adminConversations =>
      List.unmodifiable(_adminConversations);

  bool get isLoading => _isLoading.value;
  bool get isSending => _isSending.value;
  String get activeUserId => _activeUserId.value;
  String get activeRole => _activeRole.value;

  int get totalAdminUnreadCount =>
      _adminConversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  int get unreadCustomerCount => _messages
      .where((m) => m.senderRole == 'admin' && !m.isRead)
      .length;

  Future<void> init() async {
    await _service.init();
  }

  /// Initializes the chat session for a customer, loading or creating their conversation.
  Future<void> initCustomerChat({
    required String customerId,
    String? customerName,
    String? customerEmail,
    String? orderId,
  }) async {
    _activeUserId.value = customerId;
    _activeRole.value = 'customer';
    _isLoading.value = true;
    update();

    try {
      final conv = await _service.getOrCreateConversation(
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        orderId: orderId,
      );

      _activeConversation.value = conv;
      await _loadConversationMessages(conv.id, 'customer');
      _subscribeToRealtime(conv.id);
    } catch (e) {
      debugPrint('Error initializing customer chat: $e');
    } finally {
      _isLoading.value = false;
      update();
    }
  }

  /// Admin: Fetches all customer conversations for the Admin Portal and starts global listeners.
  Future<void> loadAdminConversations() async {
    _activeRole.value = 'admin';
    _isLoading.value = true;
    update();

    try {
      final list = await _service.fetchAllConversationsForAdmin();
      _adminConversations.assignAll(list);
      _subscribeToAdminChannels();
    } catch (e) {
      debugPrint('Error loading admin conversations: $e');
    } finally {
      _isLoading.value = false;
      update();
    }
  }

  /// Admin: Selects and opens a customer conversation.
  Future<void> openAdminConversation(SupportConversation conv) async {
    _activeRole.value = 'admin';
    _activeConversation.value = conv;
    _isLoading.value = true;
    update();

    try {
      await _loadConversationMessages(conv.id, 'admin');
      _subscribeToRealtime(conv.id);

      // Reset unread count locally for instant UI responsiveness
      final idx = _adminConversations.indexWhere((c) => c.id == conv.id);
      if (idx >= 0) {
        _adminConversations[idx] =
            _adminConversations[idx].copyWith(unreadCount: 0);
      }
    } catch (e) {
      debugPrint('Error opening admin conversation: $e');
    } finally {
      _isLoading.value = false;
      update();
    }
  }

  /// Internal: Loads messages and marks opposite role's messages as read.
  Future<void> _loadConversationMessages(
    String convId,
    String readerRole,
  ) async {
    final list = await _service.fetchMessages(convId);
    _messages.assignAll(list);
    await _service.markMessagesAsRead(
      conversationId: convId,
      readerRole: readerRole,
    );
    update();
  }

  /// Sends a message into the active conversation.
  Future<bool> sendMessage(String text, {ShopUser? sender}) async {
    final conv = _activeConversation.value;
    if (conv == null || text.trim().isEmpty) return false;

    _isSending.value = true;
    update();

    final role = _activeRole.value;
    final senderId = sender?.id ?? _activeUserId.value;

    try {
      final msg = await _service.sendMessage(
        conversationId: conv.id,
        senderId: senderId,
        senderRole: role,
        text: text.trim(),
      );

      if (msg != null) {
        // Optimistically add if not already present
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages.add(msg);
        }

        // Update active conversation updatedAt and lastMessage
        _activeConversation.value = conv.copyWith(
          lastMessage: msg.message,
          updatedAt: msg.createdAt,
        );

        // Update admin conversation list if admin is active
        final idx = _adminConversations.indexWhere((c) => c.id == conv.id);
        if (idx >= 0) {
          final updated = _adminConversations[idx].copyWith(
            lastMessage: msg.message,
            updatedAt: msg.createdAt,
          );
          _adminConversations.removeAt(idx);
          _adminConversations.insert(0, updated);
        }
        update();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      return false;
    } finally {
      _isSending.value = false;
      update();
    }
  }

  /// Closes the active conversation.
  Future<void> closeActiveConversation() async {
    final conv = _activeConversation.value;
    if (conv == null) return;

    await _service.closeConversation(conv.id);
    _activeConversation.value = conv.copyWith(status: 'closed');

    final idx = _adminConversations.indexWhere((c) => c.id == conv.id);
    if (idx >= 0) {
      _adminConversations[idx] =
          _adminConversations[idx].copyWith(status: 'closed');
    }
    update();
  }

  /// Silent message refresh for active conversation (used by polling timer).
  Future<void> refreshActiveMessages() async {
    final conv = _activeConversation.value;
    if (conv == null) return;

    try {
      final list = await _service.fetchMessages(conv.id);
      final hasChanged = list.length != _messages.length ||
          (list.isNotEmpty && _messages.isNotEmpty && list.last.id != _messages.last.id);

      if (hasChanged) {
        _messages.assignAll(list);
        await _service.markMessagesAsRead(
          conversationId: conv.id,
          readerRole: _activeRole.value,
        );
        update();
      }
    } catch (_) {}
  }

  /// Silent data refresh for Admin Portal (used by polling timer).
  Future<void> refreshAdminData() async {
    try {
      final list = await _service.fetchAllConversationsForAdmin();
      _adminConversations.assignAll(list);

      if (_activeConversation.value != null) {
        await refreshActiveMessages();
      } else {
        update();
      }
    } catch (_) {}
  }

  /// Subscribes to Supabase Realtime channel for live message streaming in active conversation.
  void _subscribeToRealtime(String conversationId) {
    _unsubscribeRealtime();
    _conversationChannel = _service.subscribeToConversationMessages(
      conversationId,
      (newMsg) {
        if (!_messages.any((m) => m.id == newMsg.id)) {
          _messages.add(newMsg);
          // If we are viewing this conversation, mark as read
          _service.markMessagesAsRead(
            conversationId: conversationId,
            readerRole: _activeRole.value,
          );
          update();
        }
      },
    );
  }

  void _unsubscribeRealtime() {
    try {
      _conversationChannel?.unsubscribe();
      _conversationChannel = null;
    } catch (_) {}
  }

  /// Subscribes Admin to all incoming messages and conversation updates across the platform.
  void _subscribeToAdminChannels() {
    _unsubscribeAdminChannels();

    _adminMessagesChannel = _service.subscribeToAllMessages((newMsg) {
      _handleIncomingAdminMessage(newMsg);
    });

    _adminConversationsChannel = _service.subscribeToConversationChanges(() {
      refreshAdminData();
    });
  }

  void _handleIncomingAdminMessage(SupportMessage newMsg) {
    final activeId = _activeConversation.value?.id;

    // If Admin is currently looking at this conversation, append message
    if (activeId == newMsg.conversationId) {
      if (!_messages.any((m) => m.id == newMsg.id)) {
        _messages.add(newMsg);
        _service.markMessagesAsRead(
          conversationId: newMsg.conversationId,
          readerRole: 'admin',
        );
      }
    }

    // Update conversation item in Admin list
    final idx =
        _adminConversations.indexWhere((c) => c.id == newMsg.conversationId);
    if (idx >= 0) {
      final existing = _adminConversations[idx];
      final isViewing = activeId == newMsg.conversationId;
      final newUnread = (isViewing || newMsg.senderRole == 'admin')
          ? existing.unreadCount
          : existing.unreadCount + 1;

      final updated = existing.copyWith(
        lastMessage: newMsg.message,
        updatedAt: newMsg.createdAt,
        unreadCount: newUnread,
      );

      _adminConversations.removeAt(idx);
      _adminConversations.insert(0, updated);
      update();
    } else {
      // New conversation from a customer
      refreshAdminData();
    }
  }

  void _unsubscribeAdminChannels() {
    try {
      _adminMessagesChannel?.unsubscribe();
      _adminMessagesChannel = null;
      _adminConversationsChannel?.unsubscribe();
      _adminConversationsChannel = null;
    } catch (_) {}
  }

  /// Event hook called on user login, logout, or session switch.
  /// Wipes all in-memory support chat data so User A's messages never leak to User B.
  void onUserChanged(String? newUserId) {
    _unsubscribeRealtime();
    _unsubscribeAdminChannels();
    _activeConversation.value = null;
    _messages.clear();
    _adminConversations.clear();
    _activeUserId.value = newUserId ?? '';
    _isLoading.value = false;
    _isSending.value = false;
    update();
  }

  @override
  void onClose() {
    _unsubscribeRealtime();
    _unsubscribeAdminChannels();
    super.onClose();
  }
}
