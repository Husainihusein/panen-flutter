import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'chat_detail.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> chats = [];
  List<Map<String, dynamic>> filteredChats = [];
  String? userId;
  RealtimeChannel? _chatsChannel;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      _fetchChats();
      _subscribeToChats();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchChats() async {
    if (userId == null) return;

    try {
      final data = await supabase
          .from('chats')
          .select('''
            *,
            user1:users!chats_user1_fk(id, name, username, photo_url),
            user2:users!chats_user2_fk(id, name, username, photo_url)
            ''')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('updated_at', ascending: false);

      // Filter out chats where user is talking to themselves
      final validChats = (data as List<dynamic>)
          .map((chat) => chat as Map<String, dynamic>)
          .where((chat) {
            return chat['user1_id'] != chat['user2_id'];
          })
          .toList();

      setState(() {
        chats = validChats;
        _applySearchFilter();
      });
    } catch (e) {
      debugPrint('Error fetching chats: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load chats: $e')));
      }
    }
  }

  void _subscribeToChats() {
    _chatsChannel = supabase
        .channel('chats_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            final newChat = payload.newRecord;
            if (newChat['user1_id'] == userId ||
                newChat['user2_id'] == userId) {
              _fetchChats();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            _fetchChats();
          },
        )
        .subscribe();
  }

  void _applySearchFilter() {
    if (searchQuery.isEmpty) {
      filteredChats = chats;
    } else {
      filteredChats = chats.where((chat) {
        final otherUser = _getOtherUser(chat);
        final name = (otherUser['name'] ?? '').toString().toLowerCase();
        final username = (otherUser['username'] ?? '').toString().toLowerCase();
        final query = searchQuery.toLowerCase();
        return name.contains(query) || username.contains(query);
      }).toList();
    }
  }

  Map<String, dynamic> _getOtherUser(Map<String, dynamic> chat) {
    if (chat['user1_id'] == userId) {
      return chat['user2'] ?? {};
    } else {
      return chat['user1'] ?? {};
    }
  }

  String _getOtherUserId(Map<String, dynamic> chat) {
    if (chat['user1_id'] == userId) {
      return chat['user2_id'] ?? '';
    } else {
      return chat['user1_id'] ?? '';
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(dateTime);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE').format(dateTime);
      } else {
        return DateFormat('dd/MM/yy').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _deleteChat(String chatId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete all messages in this chat
        await supabase.from('messages').delete().eq('chat_id', chatId);

        // Delete the chat
        await supabase.from('chats').delete().eq('id', chatId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted successfully')),
          );
        }
        _fetchChats();
      } catch (e) {
        debugPrint('Error deleting chat: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete chat: $e')));
        }
      }
    }
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    final otherUser = _getOtherUser(chat);
    final otherName = otherUser['name'] ?? 'User';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: (otherUser['photo_url'] != null)
                        ? NetworkImage(otherUser['photo_url'])
                        : null,
                    child: (otherUser['photo_url'] == null)
                        ? Icon(
                            LucideIcons.user,
                            size: 24,
                            color: Colors.grey.shade600,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    otherName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: const Text('Delete Chat'),
              onTap: () {
                Navigator.pop(context);
                _deleteChat(chat['id']);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF58C1D1), Color(0xFF7DE0E6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Icon(
                          LucideIcons.search,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  LucideIcons.x,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    searchQuery = '';
                                    _applySearchFilter();
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                          _applySearchFilter();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Chat List
            Expanded(
              child: filteredChats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.messageCircle,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchQuery.isEmpty
                                ? 'No conversations yet'
                                : 'No results found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isEmpty
                                ? 'Start chatting with creators'
                                : 'Try a different search',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF58C1D1),
                      onRefresh: _fetchChats,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          final otherUser = _getOtherUser(chat);
                          final otherUserId = _getOtherUserId(chat);
                          final otherName = otherUser['name'] ?? 'User';
                          final otherUsername = otherUser['username'] ?? '';
                          final photoUrl = otherUser['photo_url'];
                          final lastMessage = chat['last_message'] ?? '';
                          final unreadCount = chat['unread_count'] ?? 0;
                          final timestamp = chat['updated_at'];

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    chatId: chat['id'],
                                    otherUserName: otherName,
                                    otherUserId: otherUserId,
                                    otherUserPhotoUrl: photoUrl,
                                  ),
                                ),
                              ).then((_) => _fetchChats());
                            },
                            onLongPress: () => _showChatOptions(chat),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Avatar with online indicator
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: Colors.grey.shade200,
                                          backgroundImage: (photoUrl != null)
                                              ? NetworkImage(photoUrl)
                                              : null,
                                          child: (photoUrl == null)
                                              ? Icon(
                                                  LucideIcons.user,
                                                  size: 28,
                                                  color: Colors.grey.shade600,
                                                )
                                              : null,
                                        ),
                                        // Online indicator (optional)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),

                                    // Chat info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  otherName,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatTimestamp(timestamp),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: unreadCount > 0
                                                      ? const Color(0xFF58C1D1)
                                                      : Colors.grey.shade500,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  lastMessage.isEmpty
                                                      ? 'Start a conversation'
                                                      : lastMessage,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: lastMessage.isEmpty
                                                        ? Colors.grey.shade400
                                                        : Colors.grey.shade600,
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.w500
                                                        : FontWeight.normal,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (unreadCount > 0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFF58C1D1),
                                                            Color(0xFF7DE0E6),
                                                          ],
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    unreadCount > 99
                                                        ? '99+'
                                                        : unreadCount
                                                              .toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // More options
                                    IconButton(
                                      icon: Icon(
                                        LucideIcons.moreVertical,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                                      onPressed: () => _showChatOptions(chat),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
