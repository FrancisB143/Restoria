import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversation_screen.dart';
import '../models/chat_model.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _supabase = Supabase.instance.client;
  List<Chat> _allChats = [];
  late List<Chat> _filteredChats;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filteredChats = [];
    _searchController.addListener(_filterChats);
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Query conversations where current user is a participant
      final conversationsResponse = await _supabase
          .from('conversations')
          .select('*, messages(content, created_at, sender_id, is_read)')
          .or(
            'participant1_id.eq.$currentUserId,participant2_id.eq.$currentUserId',
          )
          .order('updated_at', ascending: false);

      final List<Chat> chats = [];

      for (final convo in conversationsResponse) {
        // Determine the other user's ID
        final participant1Id = convo['participant1_id'] as String;
        final participant2Id = convo['participant2_id'] as String;
        final otherUserId = participant1Id == currentUserId
            ? participant2Id
            : participant1Id;

        // Fetch the other user's profile
        final profileResponse = await _supabase
            .from('profiles')
            .select('name, avatar_url')
            .eq('id', otherUserId)
            .maybeSingle();

        if (profileResponse == null) continue;

        // Get the last message
        final messages = convo['messages'] as List?;
        String lastMessage = 'No messages yet';
        String time = '';
        bool hasUnreadMessages = false;
        int unreadCount = 0;

        if (messages != null && messages.isNotEmpty) {
          // Sort messages by created_at to get the latest
          messages.sort((a, b) {
            final aTime = DateTime.parse(a['created_at']);
            final bTime = DateTime.parse(b['created_at']);
            return bTime.compareTo(aTime);
          });

          final lastMsg = messages.first;
          lastMessage = lastMsg['content'] as String;
          final lastMsgTime = DateTime.parse(lastMsg['created_at']);
          time = _formatTime(lastMsgTime);

          // Check if there are unread messages (messages from other user that are not read)
          unreadCount = messages.where((msg) {
            return msg['sender_id'] != currentUserId && msg['is_read'] == false;
          }).length;

          hasUnreadMessages = unreadCount > 0;
        }

        chats.add(
          Chat(
            name: profileResponse['name'] as String? ?? 'Unknown User',
            time: time,
            avatarAsset:
                profileResponse['avatar_url'] as String? ??
                'assets/images/ourLogo.png',
            lastMessage: lastMessage,
            isGroup: false,
            isOnline: false, // You can add online status later with presence
            hasUnreadMessages: hasUnreadMessages,
            unreadCount: unreadCount,
            otherUserId: otherUserId, // Store this for navigation
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allChats = chats;
          _filteredChats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      final hour = timestamp.hour;
      final minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _allChats;
      } else {
        _filteredChats = _allChats.where((chat) {
          final nameLower = chat.name.toLowerCase();
          return nameLower.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadConversations,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredChats.isEmpty && _searchController.text.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Results Found',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching for a different name.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _filteredChats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Conversations Yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start messaging other users!',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = _filteredChats[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage:
                                  chat.avatarAsset.startsWith('http')
                                  ? NetworkImage(chat.avatarAsset)
                                        as ImageProvider
                                  : AssetImage(chat.avatarAsset),
                              child:
                                  chat.avatarAsset.isEmpty ||
                                      (!chat.avatarAsset.startsWith('http') &&
                                          !chat.avatarAsset.startsWith(
                                            'assets/',
                                          ))
                                  ? Text(
                                      chat.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            // Online status indicator for individual users
                            if (!chat.isGroup && chat.isOnline)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            // Group chat icon
                            if (chat.isGroup)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.group,
                                    size: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      chat.name,
                                      style: TextStyle(
                                        fontWeight: chat.hasUnreadMessages
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!chat.isGroup && chat.isOnline) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (chat.hasUnreadMessages) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '●',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${chat.lastMessage} • ${chat.time}',
                          style: TextStyle(
                            fontWeight: chat.hasUnreadMessages
                                ? FontWeight.w500
                                : FontWeight.normal,
                            color: chat.hasUnreadMessages
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (chat.hasUnreadMessages && chat.unreadCount > 0)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    chat.unreadCount > 9
                                        ? '9+'
                                        : '${chat.unreadCount}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                          ],
                        ),
                        onTap: () async {
                          // Navigate to conversation and reload when returning
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConversationScreen(
                                otherUserName: chat.name,
                                otherUserAvatarUrl: chat.avatarAsset,
                                otherUserId: chat.otherUserId ?? '',
                              ),
                            ),
                          );
                          // Reload conversations to update read status
                          _loadConversations();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
