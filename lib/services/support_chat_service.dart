import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_conversation.dart';
import '../models/support_message.dart';

/// Support Chat Service
/// Manages persistent customer-support conversations and messages in Supabase PostgreSQL
/// with Row-Level Security, Supabase Realtime subscriptions, and local offline/test fallbacks.
class SupportChatService {
  SharedPreferences? _prefs;
  static int _idCounter = 0;

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get hasSupabase {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  // Local fallback storage keys partitioned per user
  String _userConvKey(String userId) => 'shophub.support.conversations.$userId';
  String _convMsgKey(String convId) => 'shophub.support.messages.$convId';

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Retrieves or creates an active support conversation for [customerId].
  /// If [orderId] is specified, associates the conversation with that order.
  Future<SupportConversation> getOrCreateConversation({
    required String customerId,
    String? customerName,
    String? customerEmail,
    String? orderId,
    String? subject,
  }) async {
    await _ensurePrefs();
    final cleanOrderId = orderId?.replaceAll('#', '').trim();
    final cleanSubject = subject?.trim();

    if (!hasSupabase) {
      return _localGetOrCreateConversation(
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        orderId: cleanOrderId,
        subject: cleanSubject,
      );
    }

    try {
      // 1. Check if an open conversation already exists for this customer (and order if specified)
      var query = _supabase
          .from('support_conversations')
          .select()
          .eq('customer_id', customerId)
          .eq('status', 'open');

      if (cleanOrderId != null && cleanOrderId.isNotEmpty) {
        query = query.eq('order_id', cleanOrderId);
      }

      final existing =
          await query.order('updated_at', ascending: false).limit(1);

      if (existing.isNotEmpty) {
        var conv = SupportConversation.fromJson(existing.first);
        conv = conv.copyWith(
          customerName: customerName ?? conv.customerName,
          customerEmail: customerEmail ?? conv.customerEmail,
          subject: cleanSubject ?? conv.subject,
        );

        // Update customer details on remote if they were previously null
        final existingName = existing.first['customer_name'] as String?;
        final existingEmail = existing.first['customer_email'] as String?;
        if ((existingName == null && customerName != null) ||
            (existingEmail == null && customerEmail != null)) {
          try {
            final updateDetails = <String, dynamic>{};
            if (customerName != null) {
              updateDetails['customer_name'] = customerName;
            }
            if (customerEmail != null) {
              updateDetails['customer_email'] = customerEmail;
            }
            await _supabase
                .from('support_conversations')
                .update(updateDetails)
                .eq('id', conv.id);
          } catch (_) {}
        }

        _cacheLocalConversation(conv);
        return conv;
      }

      // 2. If orderId was specified, also check general open conversation and link orderId
      if (cleanOrderId != null && cleanOrderId.isNotEmpty) {
        final generalOpen = await _supabase
            .from('support_conversations')
            .select()
            .eq('customer_id', customerId)
            .eq('status', 'open')
            .isFilter('order_id', null)
            .order('updated_at', ascending: false)
            .limit(1);

        if (generalOpen.isNotEmpty) {
          final convId = generalOpen.first['id'] as String;
          final updateData = <String, dynamic>{
            'order_id': cleanOrderId,
            'updated_at': DateTime.now().toIso8601String(),
          };
          if (customerName != null) {
            updateData['customer_name'] = customerName;
          }
          if (customerEmail != null) {
            updateData['customer_email'] = customerEmail;
          }
          if (cleanSubject != null && cleanSubject.isNotEmpty) {
            updateData['subject'] = cleanSubject;
          }

          await _supabase
              .from('support_conversations')
              .update(updateData)
              .eq('id', convId);

          final conv = SupportConversation.fromJson(generalOpen.first).copyWith(
            orderId: cleanOrderId,
            customerName: customerName,
            customerEmail: customerEmail,
            subject: cleanSubject,
          );
          _cacheLocalConversation(conv);
          return conv;
        }
      }

      // 3. Otherwise, create a new conversation in Supabase
      final now = DateTime.now();
      final insertData = <String, dynamic>{
        'customer_id': customerId,
        'status': 'open',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      if (customerName != null && customerName.isNotEmpty) {
        insertData['customer_name'] = customerName;
      }
      if (customerEmail != null && customerEmail.isNotEmpty) {
        insertData['customer_email'] = customerEmail;
      }
      if (cleanOrderId != null && cleanOrderId.isNotEmpty) {
        insertData['order_id'] = cleanOrderId;
      }
      if (cleanSubject != null && cleanSubject.isNotEmpty) {
        insertData['subject'] = cleanSubject;
      }

      final created = await _supabase
          .from('support_conversations')
          .insert(insertData)
          .select()
          .single();

      final conv = SupportConversation.fromJson(created).copyWith(
        customerName: customerName,
        customerEmail: customerEmail,
        subject: cleanSubject,
      );

      _cacheLocalConversation(conv);
      return conv;
    } catch (e) {
      debugPrint('Supabase getOrCreateConversation error: $e');
      return _localGetOrCreateConversation(
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        orderId: cleanOrderId,
        subject: cleanSubject,
      );
    }
  }

  /// Explicitly creates a brand new support ticket for [customerId] without reusing existing conversations.
  /// Allows the customer to specify subject/topic and send an optional initial message.
  Future<SupportConversation> createTicket({
    required String customerId,
    String? customerName,
    String? customerEmail,
    String? orderId,
    String? subject,
    String? initialMessage,
  }) async {
    await _ensurePrefs();
    final cleanOrderId = orderId?.replaceAll('#', '').trim();
    final cleanSubject = subject?.trim();
    final now = DateTime.now();

    if (!hasSupabase) {
      final newConv = SupportConversation(
        id: 'conv_${customerId}_${now.microsecondsSinceEpoch}_${++_idCounter}',
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        orderId: cleanOrderId,
        subject: cleanSubject,
        status: 'open',
        createdAt: now,
        updatedAt: now,
      );
      _cacheLocalConversation(newConv);
      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        await sendMessage(
          conversationId: newConv.id,
          senderId: customerId,
          senderRole: 'customer',
          text: initialMessage.trim(),
        );
      }
      return newConv;
    }

    try {
      final insertData = <String, dynamic>{
        'customer_id': customerId,
        'status': 'open',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      if (customerName != null && customerName.isNotEmpty) {
        insertData['customer_name'] = customerName;
      }
      if (customerEmail != null && customerEmail.isNotEmpty) {
        insertData['customer_email'] = customerEmail;
      }
      if (cleanOrderId != null && cleanOrderId.isNotEmpty) {
        insertData['order_id'] = cleanOrderId;
      }
      if (cleanSubject != null && cleanSubject.isNotEmpty) {
        insertData['subject'] = cleanSubject;
      }

      final created = await _supabase
          .from('support_conversations')
          .insert(insertData)
          .select()
          .single();

      final conv = SupportConversation.fromJson(created).copyWith(
        customerName: customerName,
        customerEmail: customerEmail,
        subject: cleanSubject,
      );

      _cacheLocalConversation(conv);

      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        await sendMessage(
          conversationId: conv.id,
          senderId: customerId,
          senderRole: 'customer',
          text: initialMessage.trim(),
        );
      }

      return conv;
    } catch (e) {
      debugPrint('Supabase createTicket error: $e');
      final fallbackConv = SupportConversation(
        id: 'conv_${customerId}_${now.microsecondsSinceEpoch}_${++_idCounter}',
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        orderId: cleanOrderId,
        subject: cleanSubject,
        status: 'open',
        createdAt: now,
        updatedAt: now,
      );
      _cacheLocalConversation(fallbackConv);
      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        await sendMessage(
          conversationId: fallbackConv.id,
          senderId: customerId,
          senderRole: 'customer',
          text: initialMessage.trim(),
        );
      }
      return fallbackConv;
    }
  }

  /// Fetches all conversations belonging strictly to [customerId].
  Future<List<SupportConversation>> fetchConversationsForCustomer(
    String customerId,
  ) async {
    await _ensurePrefs();
    final localList = _loadLocalConversations(customerId);

    if (!hasSupabase) {
      return localList;
    }

    try {
      final res = await _supabase
          .from('support_conversations')
          .select()
          .eq('customer_id', customerId)
          .order('updated_at', ascending: false);

      final Map<String, SupportConversation> mergedMap = {};
      for (final conv in localList) {
        mergedMap[conv.id] = conv;
      }

      for (final item in res as List) {
        final conv =
            SupportConversation.fromJson(item as Map<String, dynamic>);
        mergedMap[conv.id] = conv;
        _cacheLocalConversation(conv);
      }

      final result = mergedMap.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } catch (e) {
      debugPrint('Supabase fetch user conversations error: $e');
      return localList;
    }
  }

  /// Admin: Fetches all support conversations across customers, sorted by latest activity.
  /// Combines remote Supabase conversations with any locally cached records for complete resilience.
  Future<List<SupportConversation>> fetchAllConversationsForAdmin() async {
    await _ensurePrefs();
    final localList = _loadAllLocalConversations();

    if (!hasSupabase) {
      return localList;
    }

    try {
      final res = await _supabase
          .from('support_conversations')
          .select()
          .order('updated_at', ascending: false);

      final Map<String, SupportConversation> mergedMap = {};

      // Seed with local conversations
      for (final conv in localList) {
        mergedMap[conv.id] = conv;
      }

      // Single batch query for unread customer messages across all conversations
      final Map<String, int> unreadCounts = {};
      try {
        final unreadRes = await _supabase
            .from('support_messages')
            .select('conversation_id')
            .eq('sender_role', 'customer')
            .eq('is_read', false);
        for (final row in unreadRes as List) {
          final cId = row['conversation_id'] as String?;
          if (cId != null) {
            unreadCounts[cId] = (unreadCounts[cId] ?? 0) + 1;
          }
        }
      } catch (_) {}

      for (final item in res as List) {
        var conv = SupportConversation.fromJson(item as Map<String, dynamic>);
        final unread = unreadCounts[conv.id] ?? 0;
        conv = conv.copyWith(unreadCount: unread);

        // Merge with local state to preserve newest data
        if (mergedMap.containsKey(conv.id)) {
          final localConv = mergedMap[conv.id]!;
          final newestUpdated = localConv.updatedAt.isAfter(conv.updatedAt)
              ? localConv.updatedAt
              : conv.updatedAt;
          final lastMsg = (conv.lastMessage != null && conv.lastMessage!.isNotEmpty)
              ? conv.lastMessage
              : localConv.lastMessage;
          conv = conv.copyWith(
            customerName: conv.customerName ?? localConv.customerName,
            customerEmail: conv.customerEmail ?? localConv.customerEmail,
            lastMessage: lastMsg,
            updatedAt: newestUpdated,
          );
        }

        mergedMap[conv.id] = conv;
        _cacheLocalConversation(conv);
      }

      final result = mergedMap.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } catch (e) {
      debugPrint('Supabase fetch admin conversations error: $e');
      return localList;
    }
  }

  /// Fetches complete message history for a [conversationId].
  /// Merges remote Supabase messages with local messages.
  Future<List<SupportMessage>> fetchMessages(String conversationId) async {
    await _ensurePrefs();
    final localMsgs = _loadLocalMessages(conversationId);

    if (!hasSupabase) {
      return localMsgs;
    }

    try {
      final res = await _supabase
          .from('support_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final remoteList = (res as List)
          .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
          .toList();

      final Map<String, SupportMessage> mergedMap = {};
      for (final m in localMsgs) {
        mergedMap[m.id] = m;
      }
      for (final m in remoteList) {
        mergedMap[m.id] = m;
      }

      final merged = mergedMap.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _saveLocalMessages(conversationId, merged);
      return merged;
    } catch (e) {
      debugPrint('Supabase fetch messages error: $e');
      return localMsgs;
    }
  }

  /// Sends a new message and permanently inserts it into Supabase PostgreSQL.
  Future<SupportMessage?> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    await _ensurePrefs();
    final cleanText = text.trim();
    if (cleanText.isEmpty) return null;

    final now = DateTime.now();

    if (!hasSupabase) {
      final localMsg = SupportMessage(
        id: 'msg_${now.microsecondsSinceEpoch}_${++_idCounter}',
        conversationId: conversationId,
        senderId: senderId,
        senderRole: senderRole,
        message: cleanText,
        isRead: false,
        createdAt: now,
      );
      final current = _loadLocalMessages(conversationId);
      current.add(localMsg);
      _saveLocalMessages(conversationId, current);
      _updateLocalConversationActivity(conversationId, cleanText, now);
      return localMsg;
    }

    try {
      // 1. Insert message
      final insertData = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'message': cleanText,
        'is_read': false,
        'created_at': now.toIso8601String(),
      };

      final res = await _supabase
          .from('support_messages')
          .insert(insertData)
          .select()
          .single();

      final message = SupportMessage.fromJson(res);

      // 2. Update conversation's updated_at and last_message
      try {
        await _supabase
            .from('support_conversations')
            .update({
              'updated_at': now.toIso8601String(),
              'last_message': cleanText,
            })
            .eq('id', conversationId);
      } catch (_) {}

      // Cache locally
      final current = _loadLocalMessages(conversationId);
      if (!current.any((m) => m.id == message.id)) {
        current.add(message);
      }
      _saveLocalMessages(conversationId, current);
      _updateLocalConversationActivity(conversationId, cleanText, now);

      return message;
    } catch (e) {
      debugPrint('Supabase sendMessage error: $e');
      // Local fallback on network failure
      final fallbackMsg = SupportMessage(
        id: 'msg_${now.microsecondsSinceEpoch}_${++_idCounter}',
        conversationId: conversationId,
        senderId: senderId,
        senderRole: senderRole,
        message: cleanText,
        isRead: false,
        createdAt: now,
      );
      final current = _loadLocalMessages(conversationId);
      current.add(fallbackMsg);
      _saveLocalMessages(conversationId, current);
      _updateLocalConversationActivity(conversationId, cleanText, now);
      return fallbackMsg;
    }
  }

  /// Marks unread messages in [conversationId] as read for the given [readerRole].
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String readerRole,
  }) async {
    await _ensurePrefs();
    final targetRole = readerRole == 'admin' ? 'customer' : 'admin';

    // Update locally
    final msgs = _loadLocalMessages(conversationId);
    var changed = false;
    final updated = msgs.map((m) {
      if (m.senderRole == targetRole && !m.isRead) {
        changed = true;
        return m.copyWith(isRead: true);
      }
      return m;
    }).toList();

    if (changed) {
      _saveLocalMessages(conversationId, updated);
    }

    if (!hasSupabase) return;

    try {
      await _supabase
          .from('support_messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('sender_role', targetRole)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Supabase markMessagesAsRead error: $e');
    }
  }

  /// Closes a conversation in Supabase and records closed_at timestamp.
  /// Never deletes messages or the conversation.
  Future<void> closeConversation(String conversationId) async {
    await _ensurePrefs();
    final now = DateTime.now();
    _updateLocalConversationStatus(conversationId, 'closed', closedAt: now);
    if (!hasSupabase) return;

    try {
      await _supabase
          .from('support_conversations')
          .update({
            'status': 'closed',
            'closed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Supabase closeConversation error: $e');
    }
  }

  /// Reopens a closed conversation in Supabase so customer and admin can resume communication.
  Future<void> reopenConversation(String conversationId) async {
    await _ensurePrefs();
    final now = DateTime.now();
    _updateLocalConversationStatus(conversationId, 'open', closedAt: null);
    if (!hasSupabase) return;

    try {
      await _supabase
          .from('support_conversations')
          .update({
            'status': 'open',
            'closed_at': null,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Supabase reopenConversation error: $e');
    }
  }

  /// Explicitly deletes a conversation and all its messages permanently from Supabase and local storage.
  /// Must only be triggered upon explicit user confirmation.
  Future<bool> deleteConversation(String conversationId) async {
    await _ensurePrefs();
    _deleteLocalConversation(conversationId);

    if (!hasSupabase) return true;

    try {
      // 1. Delete all messages for this conversation
      await _supabase
          .from('support_messages')
          .delete()
          .eq('conversation_id', conversationId);

      // 2. Delete the conversation record
      await _supabase
          .from('support_conversations')
          .delete()
          .eq('id', conversationId);

      return true;
    } catch (e) {
      debugPrint('Supabase deleteConversation error: $e');
      return true;
    }
  }

  /// Listens to real-time incoming messages for [conversationId].
  RealtimeChannel? subscribeToConversationMessages(
    String conversationId,
    void Function(SupportMessage) onNewMessage,
  ) {
    if (!hasSupabase) return null;
    try {
      final channel = _supabase
          .channel('public:support_messages_$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'support_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final msg = SupportMessage.fromJson(newRecord);
                onNewMessage(msg);
              }
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      debugPrint('Supabase Realtime messages subscription error: $e');
      return null;
    }
  }

  /// Admin: Listens to all incoming messages across the entire platform in real time.
  RealtimeChannel? subscribeToAllMessages(
    void Function(SupportMessage) onNewMessage,
  ) {
    if (!hasSupabase) return null;
    try {
      final channel = _supabase
          .channel('public:admin_support_all_messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'support_messages',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final msg = SupportMessage.fromJson(newRecord);
                onNewMessage(msg);
              }
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      debugPrint('Supabase Realtime all messages error: $e');
      return null;
    }
  }

  /// Admin: Listens to any conversation table changes (new conversation, status closed, etc.).
  RealtimeChannel? subscribeToConversationChanges(
    void Function() onConversationChanged,
  ) {
    if (!hasSupabase) return null;
    try {
      final channel = _supabase
          .channel('public:admin_support_all_conversations')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'support_conversations',
            callback: (_) {
              onConversationChanged();
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      debugPrint('Supabase Realtime conversations subscription error: $e');
      return null;
    }
  }

  // ===========================================================================
  // Local Fallback Storage Helpers
  // ===========================================================================

  SupportConversation _localGetOrCreateConversation({
    required String customerId,
    String? customerName,
    String? customerEmail,
    String? orderId,
    String? subject,
  }) {
    final list = _loadLocalConversations(customerId);

    // Look for existing open conversation
    final match = list.firstWhere(
      (c) =>
          c.isOpen &&
          (orderId == null || orderId.isEmpty || c.orderId == orderId),
      orElse: () {
        final now = DateTime.now();
        final newConv = SupportConversation(
          id: 'conv_${customerId}_${now.microsecondsSinceEpoch}_${++_idCounter}',
          customerId: customerId,
          customerName: customerName,
          customerEmail: customerEmail,
          orderId: orderId,
          subject: subject,
          status: 'open',
          createdAt: now,
          updatedAt: now,
        );
        list.insert(0, newConv);
        _saveLocalConversations(customerId, list);
        return newConv;
      },
    );

    return match.copyWith(
      customerName: customerName ?? match.customerName,
      customerEmail: customerEmail ?? match.customerEmail,
      orderId: (orderId != null && orderId.isNotEmpty) ? orderId : match.orderId,
      subject: subject ?? match.subject,
    );
  }

  List<SupportConversation> _loadLocalConversations(String customerId) {
    final prefs = _prefs;
    if (prefs == null || customerId.isEmpty) return [];
    final jsonStr = prefs.getString(_userConvKey(customerId));
    if (jsonStr == null) return [];
    try {
      final decoded = jsonDecode(jsonStr) as List;
      final list = decoded
          .map((e) => SupportConversation.fromJson(e as Map<String, dynamic>))
          .toList();
      for (var i = 0; i < list.length; i++) {
        final c = list[i];
        final unread = _loadLocalMessages(c.id)
            .where((m) => m.senderRole == 'customer' && !m.isRead)
            .length;
        list[i] = c.copyWith(unreadCount: unread);
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  void _saveLocalConversations(
    String customerId,
    List<SupportConversation> list,
  ) {
    final prefs = _prefs;
    if (prefs == null || customerId.isEmpty) return;
    try {
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      prefs.setString(_userConvKey(customerId), jsonStr);
    } catch (_) {}
  }

  void _cacheLocalConversation(SupportConversation conv) {
    final list = _loadLocalConversations(conv.customerId);
    final idx = list.indexWhere((c) => c.id == conv.id);
    if (idx >= 0) {
      list[idx] = conv;
    } else {
      list.insert(0, conv);
    }
    _saveLocalConversations(conv.customerId, list);
  }

  List<SupportConversation> _loadAllLocalConversations() {
    final prefs = _prefs;
    if (prefs == null) return [];
    final allKeys =
        prefs.getKeys().where((k) => k.startsWith('shophub.support.conversations.'));
    final allList = <SupportConversation>[];
    for (final key in allKeys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          final decoded = jsonDecode(jsonStr) as List;
          allList.addAll(
            decoded.map(
                (e) => SupportConversation.fromJson(e as Map<String, dynamic>)),
          );
        } catch (_) {}
      }
    }
    for (var i = 0; i < allList.length; i++) {
      final c = allList[i];
      final unread = _loadLocalMessages(c.id)
          .where((m) => m.senderRole == 'customer' && !m.isRead)
          .length;
      allList[i] = c.copyWith(unreadCount: unread);
    }
    allList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return allList;
  }

  List<SupportMessage> _loadLocalMessages(String convId) {
    final prefs = _prefs;
    if (prefs == null || convId.isEmpty) return [];
    final jsonStr = prefs.getString(_convMsgKey(convId));
    if (jsonStr == null) return [];
    try {
      final decoded = jsonDecode(jsonStr) as List;
      return decoded
          .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _saveLocalMessages(String convId, List<SupportMessage> list) {
    final prefs = _prefs;
    if (prefs == null || convId.isEmpty) return;
    try {
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      prefs.setString(_convMsgKey(convId), jsonStr);
    } catch (_) {}
  }

  void _updateLocalConversationActivity(
    String convId,
    String lastMsg,
    DateTime now,
  ) {
    final prefs = _prefs;
    if (prefs == null) return;
    final allKeys =
        prefs.getKeys().where((k) => k.startsWith('shophub.support.conversations.'));
    for (final key in allKeys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) continue;
      try {
        final decoded = (jsonDecode(jsonStr) as List)
            .map((e) => SupportConversation.fromJson(e as Map<String, dynamic>))
            .toList();
        final idx = decoded.indexWhere((c) => c.id == convId);
        if (idx >= 0) {
          decoded[idx] = decoded[idx].copyWith(
            lastMessage: lastMsg,
            updatedAt: now,
          );
          prefs.setString(
              key, jsonEncode(decoded.map((e) => e.toJson()).toList()));
          break;
        }
      } catch (_) {}
    }
  }

  void _updateLocalConversationStatus(
    String convId,
    String newStatus, {
    DateTime? closedAt,
  }) {
    final prefs = _prefs;
    if (prefs == null) return;
    final allKeys =
        prefs.getKeys().where((k) => k.startsWith('shophub.support.conversations.'));
    for (final key in allKeys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) continue;
      try {
        final decoded = (jsonDecode(jsonStr) as List)
            .map((e) => SupportConversation.fromJson(e as Map<String, dynamic>))
            .toList();
        final idx = decoded.indexWhere((c) => c.id == convId);
        if (idx >= 0) {
          decoded[idx] = decoded[idx].copyWith(
            status: newStatus,
            closedAt: newStatus == 'open' ? null : (closedAt ?? DateTime.now()),
            clearClosedAt: newStatus == 'open',
            updatedAt: DateTime.now(),
          );
          prefs.setString(
              key, jsonEncode(decoded.map((e) => e.toJson()).toList()));
          break;
        }
      } catch (_) {}
    }
  }

  void _deleteLocalConversation(String convId) {
    final prefs = _prefs;
    if (prefs == null || convId.isEmpty) return;

    // Remove messages key
    prefs.remove(_convMsgKey(convId));

    // Remove conversation from all user conversation caches
    final allKeys =
        prefs.getKeys().where((k) => k.startsWith('shophub.support.conversations.'));
    for (final key in allKeys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) continue;
      try {
        final decoded = (jsonDecode(jsonStr) as List)
            .map((e) => SupportConversation.fromJson(e as Map<String, dynamic>))
            .toList();
        final beforeCount = decoded.length;
        decoded.removeWhere((c) => c.id == convId);
        if (decoded.length != beforeCount) {
          prefs.setString(
              key, jsonEncode(decoded.map((e) => e.toJson()).toList()));
        }
      } catch (_) {}
    }
  }
}
