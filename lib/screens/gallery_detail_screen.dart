// lib/screens/gallery_detail_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';

class GalleryDetailScreen extends StatefulWidget {
  final GalleryPost post;

  const GalleryDetailScreen({super.key, required this.post});

  @override
  State<GalleryDetailScreen> createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends State<GalleryDetailScreen> {
  // Local state to manage likes for this specific post
  late int _currentLikeCount;
  late bool _isLiked;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  late List<Comment> _comments;
  Comment? _replyingToComment;

  @override
  void initState() {
    super.initState();
    // Initialize the local state from the post data passed to the screen
    _currentLikeCount = widget.post.likeCount;
    _isLiked =
        false; // In a real app, you'd check if the user has already liked this

    // Initialize some sample comments
    _comments = [
      Comment(
        userName: 'Emma Thompson',
        avatarAsset: 'assets/images/project1.jpg',
        text: 'This is amazing! How long did it take you to make?',
      ),
      Comment(
        userName: 'David Kim',
        avatarAsset: 'assets/images/project2.jpg',
        text: 'Great use of e-waste! Very creative approach 👏',
      ),
      Comment(
        userName: 'Maria Garcia',
        avatarAsset: 'assets/images/project3.jpg',
        text: 'I want to try making something similar. Do you have a tutorial?',
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

  void _addCommentOrReply() {
    if (_commentController.text.isEmpty) return;
    final newComment = Comment(
      userName: 'You',
      avatarAsset: 'assets/images/ourLogo.png',
      text: _commentController.text,
    );
    setState(() {
      if (_replyingToComment == null) {
        _comments.insert(0, newComment);
      } else {
        _replyingToComment!.replies.insert(0, newComment);
        _replyingToComment = null;
      }
      _commentController.clear();
      _commentFocusNode.unfocus();
    });
  }

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

  Widget _buildImage(String imageUrl) {
    // Check if it's an asset image
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 300,
            color: Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: 100,
                color: Colors.grey[600],
              ),
            ),
          );
        },
      );
    } else {
      // Handle network or file images
      return kIsWeb
          ? Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover)
          : Image.file(
              File(imageUrl),
              width: double.infinity,
              fit: BoxFit.cover,
            );
    }
  }

  ImageProvider? _getCreatorAvatar() {
    // Try to match creator with sample data for profile pictures
    final creatorAvatars = {
      'Sarah Chen': 'assets/images/project1.jpg',
      'Mike Rodriguez': 'assets/images/project2.jpg',
      'Emma Wilson': 'assets/images/project3.jpg',
      'Alex Kim': 'assets/images/harddriveclock.jpg',
      'Lisa Zhang': 'assets/images/ourLogo.png',
    };

    final avatarPath = creatorAvatars[widget.post.userName];
    if (avatarPath != null) {
      return AssetImage(avatarPath);
    }
    return null;
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.redAccent : Colors.grey,
              ),
              onPressed: _toggleLike,
            ),
            Text('$_currentLikeCount likes'),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.comment_outlined, color: Colors.grey),
            const SizedBox(width: 8),
            Text('${_comments.length} comments'),
          ],
        ),
      ],
    );
  }

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

  Widget _buildCommentWidget(Comment comment, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * depth, top: 8, bottom: 8),
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
                    Text(
                      comment.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(comment.text),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 52),
              IconButton(
                icon: Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: comment.isLiked ? Colors.redAccent : Colors.grey,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    comment.isLiked = !comment.isLiked;
                    comment.isLiked ? comment.likeCount++ : comment.likeCount--;
                  });
                },
              ),
              if (comment.likeCount > 0)
                Text(
                  comment.likeCount.toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              TextButton(
                child: const Text(
                  'Reply',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _startReply(comment),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToComment != null)
            Row(
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
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _addCommentOrReply,
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
      body: Stack(
        children: [
          // Single ScrollView containing everything
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status bar spacing
                SizedBox(height: MediaQuery.of(context).padding.top),
                // Image that scrolls with content (starts from top)
                SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(
                    context,
                  ).size.width, // Square aspect ratio
                  child: _buildImage(widget.post.imageUrl),
                ),

                // Content section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Creator profile section (clickable)
                      InkWell(
                        onTap: () {
                          // Navigate to creator profile
                          // You can implement this navigation later
                          print('Navigate to ${widget.post.userName} profile');
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue,
                              backgroundImage: _getCreatorAvatar(),
                              child: _getCreatorAvatar() == null
                                  ? Text(
                                      widget.post.userName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.post.userName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        widget.post.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                        maxLines: null, // Allow multiple lines
                      ),

                      const SizedBox(height: 16),

                      // Action bar with like and comment
                      _buildActionBar(),

                      const Divider(height: 32),

                      // Comments section
                      Text(
                        'Comments (${_comments.length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildCommentTree(_comments),

                      // Add bottom padding for comment input area
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Fixed positioned back button
          Positioned(
            top:
                MediaQuery.of(context).padding.top +
                8, // Account for status bar
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Fixed positioned comment input area at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCommentInputArea(),
          ),
        ],
      ),
    );
  }
}
