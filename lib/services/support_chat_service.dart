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
  }) async {
    await _ensurePrefs();
    final cleanOrderId = orderId?.replaceAll('#', '').trim();

    if (!hasSupabase) {
      return _localGetOrCreateConversation(
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        orderId: cleanOrderId,
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

          await _supabase
              .from('support_conversations')
              .update(updateData)
              .eq('id', convId);

          final conv = SupportConversation.fromJson(generalOpen.first).copyWith(
            orderId: cleanOrderId,
            customerName: customerName,
            customerEmail: customerEmail,
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

      final created = await _supabase
          .from('support_conversations')
          .insert(insertData)
          .select()
          .single();

      final conv = SupportConversation.fromJson(created).copyWith(
        customerName: customerName,
        customerEmail: customerEmail,
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
      );
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

      for (final item in res as List) {
        var conv = SupportConversation.fromJson(item as Map<String, dynamic>);

        // Enrich customerName & customerEmail from profiles if missing
        if (conv.customerName == null ||
            conv.customerName!.isEmpty ||
            conv.customerEmail == null ||
            conv.customerEmail!.isEmpty) {
          try {
            final profile = await _supabase
                .from('profiles')
                .select('name, email')
                .eq('id', conv.customerId)
                .maybeSingle();

            if (profile != null) {
              conv = conv.copyWith(
                customerName: conv.customerName ?? profile['name'] as String?,
                customerEmail:
                    conv.customerEmail ?? profile['email'] as String?,
              );
            }
          } catch (_) {}
        }

        // Enrich with order status if linked to an order
        if (conv.orderId != null && conv.orderId!.isNotEmpty) {
          try {
            final orderRes = await _supabase
                .from('orders')
                .select('status')
                .eq('id', conv.orderId!)
                .maybeSingle();
            if (orderRes != null) {
              conv = conv.copyWith(orderStatus: orderRes['status'] as String?);
            }
          } catch (_) {}
        }

        // Count unread customer messages
        try {
          final unreadRes = await _supabase
              .from('support_messages')
              .select('id')
              .eq('conversation_id', conv.id)
              .eq('sender_role', 'customer')
              .eq('is_read', false);
          final remoteUnread = (unreadRes as List).length;
          final localUnread = _loadLocalMessages(conv.id)
              .where((m) => m.senderRole == 'customer' && !m.isRead)
              .length;
          conv = conv.copyWith(
            unreadCount:
                remoteUnread > localUnread ? remoteUnread : localUnread,
          );
        } catch (_) {
          final localUnread = _loadLocalMessages(conv.id)
              .where((m) => m.senderRole == 'customer' && !m.isRead)
              .length;
          conv = conv.copyWith(unreadCount: localUnread);
        }

        // Fetch last message snippet if null or empty
        if (conv.lastMessage == null || conv.lastMessage!.isEmpty) {
          try {
            final lastMsgRes = await _supabase
                .from('support_messages')
                .select('message')
                .eq('conversation_id', conv.id)
                .order('created_at', ascending: false)
                .limit(1);
            if ((lastMsgRes as List).isNotEmpty) {
              conv = conv.copyWith(
                lastMessage: lastMsgRes.first['message'] as String?,
              );
            }
          } catch (_) {}
        }

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
        id: 'msg_${now.millisecondsSinceEpoch}',
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
        id: 'msg_${now.millisecondsSinceEpoch}',
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

  /// Closes a conversation in Supabase.
  Future<void> closeConversation(String conversationId) async {
    await _ensurePrefs();
    _updateLocalConversationStatus(conversationId, 'closed');
    if (!hasSupabase) return;

    try {
      await _supabase
          .from('support_conversations')
          .update({
            'status': 'closed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Supabase closeConversation error: $e');
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
          id: 'conv_${customerId}_${now.millisecondsSinceEpoch}',
          customerId: customerId,
          customerName: customerName,
          customerEmail: customerEmail,
          orderId: orderId,
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

  void _updateLocalConversationStatus(String convId, String newStatus) {
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
            updatedAt: DateTime.now(),
          );
          prefs.setString(
              key, jsonEncode(decoded.map((e) => e.toJson()).toList()));
          break;
        }
      } catch (_) {}
    }
  }
}
