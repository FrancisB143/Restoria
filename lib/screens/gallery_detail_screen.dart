import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';
import '../services/likes_comments_service.dart';
import 'creator_profile_screen.dart';

class GalleryDetailScreen extends StatefulWidget {
  final GalleryPost post;
  final List<GalleryPost>? allPosts;
  final String? currentUserName; // Add optional currentUserName

  const GalleryDetailScreen({
    super.key,
    required this.post,
    this.allPosts,
    this.currentUserName, // Make it optional for backward compatibility
  });

  @override
  State<GalleryDetailScreen> createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends State<GalleryDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _likesCommentsService = LikesCommentsService();
  late int _currentLikeCount;
  late bool _isLiked;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  List<Map<String, dynamic>> _comments = [];
  List<Comment> _oldComments = []; // For the old Comment model display
  Comment? _replyingToComment;
  bool _isLoadingComments = true;
  bool _isLoadingLikeStatus = true;

  @override
  void initState() {
    super.initState();
    _currentLikeCount = widget.post.likeCount;
    _isLiked = false;
    _loadLikeStatus();
    _loadComments();
  }

  Future<void> _loadLikeStatus() async {
    if (widget.post.id == null) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final isLiked = await _likesCommentsService.isGalleryPostLiked(
          widget.post.id!,
          userId,
        );
        final likeCount = await _likesCommentsService.getGalleryLikeCount(
          widget.post.id!,
        );

        if (mounted) {
          setState(() {
            _isLiked = isLiked;
            _currentLikeCount = likeCount;
            _isLoadingLikeStatus = false;
          });
        }
      }
    } catch (e) {
      print('Error loading like status: $e');
      if (mounted) {
        setState(() => _isLoadingLikeStatus = false);
      }
    }
  }

  Future<void> _loadComments() async {
    if (widget.post.id == null) return;

    try {
      final comments = await _likesCommentsService.getGalleryComments(
        widget.post.id!,
      );

      if (mounted) {
        // Convert database comments to old Comment model format
        final oldComments = comments.map((comment) {
          final profile = comment['profiles'] as Map<String, dynamic>?;
          final userName = profile?['name'] ?? 'Anonymous';
          final avatarUrl = profile?['avatar_url'];
          final createdAt = DateTime.parse(comment['created_at']);
          final timeAgo = _formatTimeAgo(createdAt);

          return Comment(
            userName: userName,
            avatarAsset: avatarUrl ?? 'assets/images/ourLogo.png',
            text: comment['content'],
            timestamp: timeAgo,
          );
        }).toList();

        setState(() {
          _comments = comments;
          _oldComments = oldComments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (widget.post.id == null) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like posts')),
      );
      return;
    }

    try {
      // Optimistically update UI
      setState(() {
        if (_isLiked) {
          _currentLikeCount--;
          _isLiked = false;
        } else {
          _currentLikeCount++;
          _isLiked = true;
        }
      });

      // Update database
      await _likesCommentsService.toggleGalleryLike(widget.post.id!, userId);
    } catch (e) {
      print('Error toggling like: $e');
      // Revert on error
      setState(() {
        if (_isLiked) {
          _currentLikeCount--;
          _isLiked = false;
        } else {
          _currentLikeCount++;
          _isLiked = true;
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update like')));
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || widget.post.id == null)
      return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in to comment')));
      return;
    }

    try {
      await _likesCommentsService.addGalleryComment(
        widget.post.id!,
        userId,
        _commentController.text.trim(),
      );

      _commentController.clear();
      _commentFocusNode.unfocus();

      // Reload comments
      await _loadComments();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comment added!')));
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to add comment')));
    }
  }

  // Alias for compatibility with old code
  void _addCommentOrReply() {
    _addComment();
  }

  // RESTORED: Functions to handle the reply state
  void _startReply(Comment comment) {
    setState(() {
      _replyingToComment = comment;
      _commentFocusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToComment = null;
      _commentFocusNode.unfocus();
    });
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _deletePost();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    print('=== DELETE POST DEBUG ===');
    print('Post ID: ${widget.post.id}');
    print('Post imageUrl: ${widget.post.imageUrl}');
    print('Current user ID: ${_supabase.auth.currentUser?.id}');
    print('Post user ID: ${widget.post.userId}');

    if (widget.post.id == null) {
      print('ERROR: Post ID is null, cannot delete');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: Post ID is missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      print('Attempting to delete from database...');
      // Delete from database
      await _supabase.from('gallery_posts').delete().eq('id', widget.post.id!);

      print('Database deletion successful');

      // Delete image from storage if it exists
      if (widget.post.imageUrl.isNotEmpty) {
        print('Image URL: ${widget.post.imageUrl}');

        // Check if it's a Supabase storage URL
        if (widget.post.imageUrl.contains('gallery-images') ||
            widget.post.imageUrl.contains('supabase.co')) {
          try {
            // Try to extract the path
            String imagePath;
            if (widget.post.imageUrl.contains(
              '/storage/v1/object/public/gallery-images/',
            )) {
              imagePath = widget.post.imageUrl
                  .split('/storage/v1/object/public/gallery-images/')
                  .last;
            } else if (widget.post.imageUrl.contains('gallery-images/')) {
              imagePath = widget.post.imageUrl.split('gallery-images/').last;
            } else {
              // Try to extract from URL
              final uri = Uri.parse(widget.post.imageUrl);
              final pathSegments = uri.pathSegments;
              final galleryIndex = pathSegments.indexOf('gallery-images');
              if (galleryIndex >= 0 && galleryIndex < pathSegments.length - 1) {
                imagePath = pathSegments.sublist(galleryIndex + 1).join('/');
              } else {
                throw Exception('Could not parse image path from URL');
              }
            }

            print('Attempting to delete image from storage: $imagePath');
            final result = await _supabase.storage
                .from('gallery-images')
                .remove([imagePath]);
            print('Storage deletion result: $result');
          } catch (e) {
            print('Error deleting image from storage: $e');
            // Don't fail the whole operation if storage deletion fails
          }
        } else {
          print(
            'Image URL does not appear to be in Supabase storage, skipping storage deletion',
          );
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(
          context,
          true,
        ); // Go back to previous screen with success flag
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('ERROR deleting post: $e');
      print('Error type: ${e.runtimeType}');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildPostImage(String imageUrl) {
    const double imageHeight = 300.0;
    Widget image;

    if (imageUrl.startsWith('assets/')) {
      image = Image.asset(imageUrl, fit: BoxFit.contain);
    } else if (kIsWeb) {
      image = Image.network(imageUrl, fit: BoxFit.contain);
    } else {
      image = Image.file(File(imageUrl), fit: BoxFit.contain);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          height: imageHeight,
          width: double.infinity,
          color: Colors.grey.shade200,
          child: image,
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggleLike,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.redAccent : Colors.black54,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentLikeCount.toString(),
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.black54,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _oldComments.length.toString(),
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // This function now recursively builds comment trees
  Widget _buildCommentTree(List<Comment> comments, {int depth = 0}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Column(
          children: [
            _buildCommentWidget(comment, depth),
            if (comment.replies.isNotEmpty)
              _buildCommentTree(comment.replies, depth: depth + 1),
          ],
        );
      },
    );
  }

  // RESTORED: Like and Reply buttons are back
  Widget _buildCommentWidget(Comment comment, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: 24.0 * depth, top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundImage: AssetImage(comment.avatarAsset),
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          comment.timestamp,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment.text),
                  ],
                ),
              ),
            ],
          ),
          // Like and Reply buttons row
          Row(
            children: [
              SizedBox(width: 52.0 * (depth > 0 ? 0.8 : 1)), // Indent buttons
              InkWell(
                onTap: () {
                  setState(() {
                    comment.isLiked = !comment.isLiked;
                    comment.isLiked ? comment.likeCount++ : comment.likeCount--;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: comment.isLiked ? Colors.redAccent : Colors.grey,
                      size: 18,
                    ),
                    if (comment.likeCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          comment.likeCount.toString(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _startReply(comment),
                child: const Text(
                  'Reply',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 8.0,
        top: 8.0,
        bottom: MediaQuery.of(context).padding.bottom + 8.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      // Column to show the "Replying to..." text
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToComment != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 8.0,
                right: 8.0,
                bottom: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Replying to ${_replyingToComment!.userName}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _cancelReply,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  decoration: InputDecoration(
                    hintText: _replyingToComment == null
                        ? 'Add a comment...'
                        : 'Add a reply...',
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _addCommentOrReply,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [],
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      bottomNavigationBar: _buildCommentInputArea(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostImage(widget.post.imageUrl),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      if (widget.allPosts == null) return;

                      // Navigate to creator's profile (CreatorProfileScreen)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatorProfileScreen(
                            userName: widget.post.userName,
                            allPosts: widget.allPosts!,
                            currentUserName: widget.currentUserName ?? 'Guest',
                            creatorUserId: widget.post.userId,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.teal.shade100,
                          backgroundImage:
                              widget.post.avatarUrl != null &&
                                  widget.post.avatarUrl!.isNotEmpty
                              ? NetworkImage(widget.post.avatarUrl!)
                              : null,
                          child:
                              widget.post.avatarUrl == null ||
                                  widget.post.avatarUrl!.isEmpty
                              ? Text(
                                  widget.post.userName.isNotEmpty
                                      ? widget.post.userName[0]
                                      : 'U',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade800,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.post.userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Show delete menu only if current user is the creator
                        Builder(
                          builder: (context) {
                            final currentUserId =
                                _supabase.auth.currentUser?.id;
                            final postUserId = widget.post.userId;
                            final isOwner = currentUserId == postUserId;

                            print('=== DELETE MENU DEBUG ===');
                            print('Current user ID: $currentUserId');
                            print('Post user ID: $postUserId');
                            print('Is owner: $isOwner');
                            print('Post has ID: ${widget.post.id != null}');
                            print('Post ID: ${widget.post.id}');

                            if (!isOwner) {
                              return const SizedBox.shrink();
                            }

                            return PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                print('Menu item selected: $value');
                                if (value == 'delete') {
                                  _showDeleteConfirmation();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.post.description,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
            _buildActionBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // This now handles nested comments
                  _buildCommentTree(_oldComments),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
