import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String? otherUserId;
  final String? otherUserPhotoUrl;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.otherUserId,
    this.otherUserPhotoUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];
  String? userId;
  String? currentUserPhotoUrl;
  RealtimeChannel? _messagesChannel;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    userId = supabase.auth.currentUser?.id;
    _fetchCurrentUserPhoto();
    _fetchMessages();
    _setupRealtime();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchCurrentUserPhoto() async {
    if (userId == null) return;
    try {
      final response = await supabase
          .from('users')
          .select('photo_url')
          .eq('id', userId!)
          .single();

      setState(() {
        currentUserPhotoUrl = response['photo_url'];
      });
    } catch (e) {
      debugPrint('Error fetching current user photo: $e');
    }
  }

  Future<void> _fetchMessages() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true);

      setState(() {
        messages = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

      // Scroll to bottom after loading messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      setState(() => isLoading = false);
    }
  }

  void _setupRealtime() {
    // Unsubscribe from any existing channel first
    _messagesChannel?.unsubscribe();

    _messagesChannel = supabase
        .channel('messages:chat_${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) {
            debugPrint('New message received: ${payload.newRecord}');
            final newMessage = payload.newRecord;
            if (mounted) {
              setState(() {
                // Check if message already exists to avoid duplicates
                final exists = messages.any(
                  (msg) => msg['id'] == newMessage['id'],
                );
                if (!exists) {
                  messages.add(Map<String, dynamic>.from(newMessage));
                }
              });

              // Auto scroll to bottom when new message arrives
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('Successfully subscribed to messages channel');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('Channel error: $error');
          }
        });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || userId == null) return;

    // Store the message content
    final messageToSend = content;

    // Clear input immediately for better UX
    _messageController.clear();

    try {
      // Insert the message
      final response = await supabase
          .from('messages')
          .insert({
            'chat_id': widget.chatId,
            'sender_id': userId,
            'content': messageToSend,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('Message sent successfully: $response');

      // Also update the chat's last_message and updated_at
      await supabase
          .from('chats')
          .update({
            'last_message': messageToSend,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.chatId);

      // Manually add the message to the list for instant feedback
      // (in case realtime is slightly delayed)
      if (mounted) {
        setState(() {
          final exists = messages.any((msg) => msg['id'] == response['id']);
          if (!exists) {
            messages.add(Map<String, dynamic>.from(response));
          }
        });
      }

      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
        // Restore the message in the input field if it failed
        _messageController.text = messageToSend;
      }
    }
  }

  Future<void> _deleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this entire conversation? This action cannot be undone.',
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
        await supabase.from('messages').delete().eq('chat_id', widget.chatId);

        // Optionally delete the chat itself
        await supabase.from('chats').delete().eq('id', widget.chatId);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted successfully')),
          );
        }
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

  void _reportChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Report User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report ${widget.otherUserName} for inappropriate behavior?'),
            const SizedBox(height: 12),
            const Text(
              'Our team will review this conversation.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted successfully')),
              );
              // TODO: Implement actual report logic
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
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
            ListTile(
              leading: const Icon(LucideIcons.flag, color: Colors.orange),
              title: const Text('Report User'),
              onTap: () {
                Navigator.pop(context);
                _reportChat();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: const Text('Delete Chat'),
              onTap: () {
                Navigator.pop(context);
                _deleteChat();
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  (widget.otherUserPhotoUrl != null &&
                      widget.otherUserPhotoUrl!.isNotEmpty)
                  ? NetworkImage(widget.otherUserPhotoUrl!)
                  : null,
              child:
                  (widget.otherUserPhotoUrl == null ||
                      widget.otherUserPhotoUrl!.isEmpty)
                  ? Icon(
                      LucideIcons.user,
                      size: 18,
                      color: Colors.grey.shade600,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Active',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.moreVertical, color: Colors.black87),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF58C1D1)),
                  )
                : messages.isEmpty
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
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMine = msg['sender_id'] == userId;
                      final showAvatar =
                          index == 0 ||
                          messages[index - 1]['sender_id'] != msg['sender_id'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMine
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMine) ...[
                              showAvatar
                                  ? CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage:
                                          (widget.otherUserPhotoUrl != null &&
                                              widget
                                                  .otherUserPhotoUrl!
                                                  .isNotEmpty)
                                          ? NetworkImage(
                                              widget.otherUserPhotoUrl!,
                                            )
                                          : null,
                                      child:
                                          (widget.otherUserPhotoUrl == null ||
                                              widget.otherUserPhotoUrl!.isEmpty)
                                          ? Icon(
                                              LucideIcons.user,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            )
                                          : null,
                                    )
                                  : const SizedBox(width: 32),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isMine
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF58C1D1),
                                            Color(0xFF7DE0E6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isMine ? null : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(
                                      isMine ? 20 : 4,
                                    ),
                                    bottomRight: Radius.circular(
                                      isMine ? 4 : 20,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['content'] ?? '',
                                  style: TextStyle(
                                    color: isMine
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 8),
                              showAvatar
                                  ? CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage:
                                          (currentUserPhotoUrl != null &&
                                              currentUserPhotoUrl!.isNotEmpty)
                                          ? NetworkImage(currentUserPhotoUrl!)
                                          : null,
                                      child:
                                          (currentUserPhotoUrl == null ||
                                              currentUserPhotoUrl!.isEmpty)
                                          ? Icon(
                                              LucideIcons.user,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            )
                                          : null,
                                    )
                                  : const SizedBox(width: 32),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF58C1D1), Color(0xFF7DE0E6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(LucideIcons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
