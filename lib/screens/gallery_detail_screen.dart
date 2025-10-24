import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';
import 'creator_profile_screen.dart';

class GalleryDetailScreen extends StatefulWidget {
  final GalleryPost post;
  final List<GalleryPost>? allPosts;

  const GalleryDetailScreen({super.key, required this.post, this.allPosts});

  @override
  State<GalleryDetailScreen> createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends State<GalleryDetailScreen> {
  late int _currentLikeCount;
  late bool _isLiked;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  late List<Comment> _comments;
  Comment? _replyingToComment;

  @override
  void initState() {
    super.initState();
    _currentLikeCount = widget.post.likeCount;
    _isLiked = false;

    _comments = [
      Comment(
        userName: 'Liam',
        avatarAsset: 'assets/images/avatar1.png',
        text: 'This is so creative! I love the use of recycled materials.',
        timestamp: '2d',
      ),
      Comment(
        userName: 'Sophia',
        avatarAsset: 'assets/images/avatar2.png',
        text:
            'Amazing work! It\'s inspiring to see how e-waste can be transformed into something beautiful.',
        timestamp: '1d',
        replies: [
          Comment(
            userName: widget.post.userName,
            avatarAsset: 'assets/images/ourLogo.png',
            text: 'Thank you! Glad you liked it.',
            timestamp: '1d',
          ),
        ],
      ),
      Comment(
        userName: 'Ethan',
        avatarAsset: 'assets/images/avatar1.png',
        text:
            'I\'m impressed by the craftsmanship. This piece really stands out.',
        timestamp: '1d',
      ),
    ];
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _currentLikeCount--;
        _isLiked = false;
      } else {
        _currentLikeCount++;
        _isLiked = true;
      }
    });
  }

  // MODIFIED: This now handles both comments and replies
  void _addCommentOrReply() {
    if (_commentController.text.isEmpty) return;
    final newComment = Comment(
      userName: 'You',
      avatarAsset: 'assets/images/ourLogo.png',
      text: _commentController.text,
      timestamp: 'Just now',
    );
    setState(() {
      if (_replyingToComment == null) {
        // Add a new top-level comment
        _comments.add(newComment);
      } else {
        // Add a reply to an existing comment
        _replyingToComment!.replies.add(newComment);
        _replyingToComment = null;
      }
      _commentController.clear();
      _commentFocusNode.unfocus();
    });
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
                  _comments.length.toString(),
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share action triggered!')),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.share_outlined,
                color: Colors.black54,
                size: 24,
              ),
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

                      final currentUserId =
                          Supabase.instance.client.auth.currentUser?.id;

                      // Check if the current user is the post creator
                      if (currentUserId == widget.post.userId) {
                        // Navigate back to main screen (Profile tab)
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      } else {
                        // Navigate to creator's profile (CreatorProfileScreen)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreatorProfileScreen(
                              userName: widget.post.userName,
                              allPosts: widget.allPosts!,
                            ),
                          ),
                        );
                      }
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
                        Text(
                          widget.post.userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                  _buildCommentTree(_comments),
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
