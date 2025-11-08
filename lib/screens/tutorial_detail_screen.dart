// lib/screens/tutorial_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';
import '../services/likes_comments_service.dart';
import 'creator_profile_screen.dart';

class TutorialDetailScreen extends StatefulWidget {
  final Tutorial tutorial;
  final List<GalleryPost> allPosts;
  final String? currentUserName; // Add optional currentUserName

  const TutorialDetailScreen({
    super.key,
    required this.tutorial,
    required this.allPosts,
    this.currentUserName, // Make it optional for backward compatibility
  });

  @override
  State<TutorialDetailScreen> createState() => _TutorialDetailScreenState();
}

class _TutorialDetailScreenState extends State<TutorialDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _likesCommentsService = LikesCommentsService();
  late VideoPlayerController _videoController;
  late Future<void> _initializeVideoPlayerFuture;
  late int _tutorialLikeCount;
  late bool _isTutorialLiked;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  List<Comment> _comments = [];
  List<Map<String, dynamic>> _dbComments = [];
  Comment? _replyingToComment;
  bool _hasVideoError = false;
  String _videoErrorMessage = '';
  bool _isLoadingComments = true;
  bool _isLoadingLikeStatus = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _tutorialLikeCount = widget.tutorial.likeCount;
    _isTutorialLiked = false;
    _loadLikeStatus();
    _loadComments();
  }

  void _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset(widget.tutorial.videoUrl);
      _initializeVideoPlayerFuture = _videoController.initialize();

      // Wait for initialization to complete
      await _initializeVideoPlayerFuture;

      // Add listener to update UI when video position changes
      _videoController.addListener(_videoListener);

      // Check if video was successfully initialized
      if (_videoController.value.hasError) {
        setState(() {
          _hasVideoError = true;
          _videoErrorMessage =
              'Video failed to load: ${_videoController.value.errorDescription}';
        });
        print('Video error: ${_videoController.value.errorDescription}');
      } else {
        print(
          'Video initialized successfully - Duration: ${_videoController.value.duration}',
        );
        setState(() {
          _hasVideoError = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasVideoError = true;
        _videoErrorMessage = 'Video initialization failed: $e';
      });
      print('Video initialization error: $e');
    }
  }

  void _videoListener() {
    // Only update UI if the widget is still mounted and there are meaningful changes
    if (mounted && _videoController.value.isInitialized) {
      setState(() {
        // This will trigger a rebuild to update the progress slider and time displays
      });
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLikeStatus() async {
    if (widget.tutorial.id == null) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final isLiked = await _likesCommentsService.isTutorialLiked(
          widget.tutorial.id!,
          userId,
        );
        final likeCount = await _likesCommentsService.getTutorialLikeCount(
          widget.tutorial.id!,
        );

        if (mounted) {
          setState(() {
            _isTutorialLiked = isLiked;
            _tutorialLikeCount = likeCount;
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
    if (widget.tutorial.id == null) return;

    try {
      final comments = await _likesCommentsService.getTutorialComments(
        widget.tutorial.id!,
      );

      if (mounted) {
        // Convert database comments to Comment model
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
          _dbComments = comments;
          _comments = oldComments;
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

  Future<void> _toggleTutorialLike() async {
    if (widget.tutorial.id == null) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like tutorials')),
      );
      return;
    }

    try {
      // Optimistically update UI
      setState(() {
        if (_isTutorialLiked) {
          _tutorialLikeCount--;
          _isTutorialLiked = false;
        } else {
          _tutorialLikeCount++;
          _isTutorialLiked = true;
        }
      });

      // Update database
      await _likesCommentsService.toggleTutorialLike(
        widget.tutorial.id!,
        userId,
      );
    } catch (e) {
      print('Error toggling like: $e');
      // Revert on error
      setState(() {
        if (_isTutorialLiked) {
          _tutorialLikeCount--;
          _isTutorialLiked = false;
        } else {
          _tutorialLikeCount++;
          _isTutorialLiked = true;
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update like')));
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || widget.tutorial.id == null)
      return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in to comment')));
      return;
    }

    try {
      await _likesCommentsService.addTutorialComment(
        widget.tutorial.id!,
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

  void _addCommentOrReply() {
    _addComment();
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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tutorial'),
        content: const Text(
          'Are you sure you want to delete this tutorial? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _deleteTutorial();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTutorial() async {
    if (widget.tutorial.id == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Delete from database
      await _supabase.from('tutorials').delete().eq('id', widget.tutorial.id!);

      // Delete video from storage if it exists
      if (widget.tutorial.videoUrl.isNotEmpty &&
          widget.tutorial.videoUrl.contains('tutorial-videos')) {
        try {
          final videoPath = Uri.parse(
            widget.tutorial.videoUrl,
          ).path.split('/tutorial-videos/').last;
          await _supabase.storage.from('tutorial-videos').remove([videoPath]);
        } catch (e) {
          print('Error deleting video: $e');
        }
      }

      // Delete image from storage if it exists
      if (widget.tutorial.imageUrl.isNotEmpty &&
          widget.tutorial.imageUrl.contains('tutorial-images')) {
        try {
          final imagePath = Uri.parse(
            widget.tutorial.imageUrl,
          ).path.split('/tutorial-images/').last;
          await _supabase.storage.from('tutorial-images').remove([imagePath]);
        } catch (e) {
          print('Error deleting image: $e');
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
            content: Text('Tutorial deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting tutorial: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete tutorial: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _skipForward() {
    if (!_videoController.value.isInitialized) {
      print('Video controller not initialized yet');
      return;
    }

    final currentPosition = _videoController.value.position;
    final newPosition = currentPosition + const Duration(seconds: 10);
    final duration = _videoController.value.duration;

    if (newPosition < duration) {
      _videoController.seekTo(newPosition);
    } else {
      _videoController.seekTo(duration);
    }
  }

  void _skipBackward() {
    if (!_videoController.value.isInitialized) {
      print('Video controller not initialized yet');
      return;
    }

    final currentPosition = _videoController.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);

    if (newPosition > Duration.zero) {
      _videoController.seekTo(newPosition);
    } else {
      _videoController.seekTo(Duration.zero);
    }
  }

  void _togglePlayPause() async {
    print('_togglePlayPause called');

    if (!_videoController.value.isInitialized) {
      print('ERROR: Video controller not initialized yet');
      return;
    }

    if (_videoController.value.hasError) {
      print(
        'ERROR: Video controller has error: ${_videoController.value.errorDescription}',
      );
      return;
    }

    try {
      if (_videoController.value.isPlaying) {
        print('Attempting to pause video...');
        await _videoController.pause();
        print('Video paused successfully');
      } else {
        print('Attempting to play video...');
        await _videoController.play();
        print('Video play command sent successfully');
      }

      // Force a UI update
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('ERROR in _togglePlayPause: $e');
    }
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
                // Video player that scrolls with content (starts from top)
                SizedBox(
                  width: double.infinity,
                  height:
                      MediaQuery.of(context).size.width *
                      9 /
                      16, // 16:9 aspect ratio
                  child: _buildVideoPlayer(),
                ),

                // Content section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add some top spacing
                      const SizedBox(height: 8),
                      Text(
                        widget.tutorial.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () {
                          // Navigate to creator's profile (CreatorProfileScreen)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreatorProfileScreen(
                                userName: widget.tutorial.creatorName,
                                allPosts: widget.allPosts,
                                currentUserName:
                                    widget.currentUserName ?? 'Guest',
                                creatorUserId: widget.tutorial.userId,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _getAvatarColor(
                                widget.tutorial.creatorName,
                              ),
                              child: Text(
                                widget.tutorial.creatorName.isNotEmpty
                                    ? widget.tutorial.creatorName[0]
                                          .toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.tutorial.creatorName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Show delete menu only if current user is the creator
                            if (_supabase.auth.currentUser?.id ==
                                widget.tutorial.userId)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
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
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.tutorial.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                        maxLines: null, // Allow multiple lines
                      ),
                      const SizedBox(height: 16),
                      _buildActionBar(),
                      const Divider(height: 32),
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

  Widget _buildVideoPlayer() {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // Check for errors
          if (snapshot.hasError || _hasVideoError) {
            return Container(
              width: double.infinity,
              height: 250,
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load video',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _videoErrorMessage.isNotEmpty
                          ? _videoErrorMessage
                          : 'Video could not be loaded',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        print('Retrying video initialization...');
                        _initializeVideo();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Check if video controller is properly initialized
          if (!_videoController.value.isInitialized) {
            return Container(
              width: double.infinity,
              height: 250,
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Initializing video...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Stack(
              children: [
                // Video player
                Center(
                  child: FittedBox(
                    fit: BoxFit.contain, // Keep aspect ratio, no cropping
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                ),
                // Full screen tap area for play/pause
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      print(
                        'Video tapped - Current state: ${_videoController.value.isPlaying}',
                      );
                      _togglePlayPause();
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Central play button when paused
                if (!_videoController.value.isPlaying)
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Icon(
                          Icons.play_arrow,
                          size: 60.0,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                // Video controls at bottom
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        // Backward 10s button
                        GestureDetector(
                          onTap: () {
                            print('Backward button tapped');
                            _skipBackward();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.replay_10,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Current time
                        Text(
                          _formatDuration(_videoController.value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Progress slider
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              trackHeight: 3,
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value:
                                  _videoController.value.duration.inSeconds > 0
                                  ? _videoController.value.position.inSeconds
                                        .toDouble()
                                        .clamp(
                                          0.0,
                                          _videoController
                                              .value
                                              .duration
                                              .inSeconds
                                              .toDouble(),
                                        )
                                  : 0.0,
                              max: _videoController.value.duration.inSeconds > 0
                                  ? _videoController.value.duration.inSeconds
                                        .toDouble()
                                  : 1.0,
                              onChanged: (value) {
                                print('Slider changed to: $value');
                                _videoController.seekTo(
                                  Duration(seconds: value.toInt()),
                                );
                              },
                              activeColor: Colors.white,
                              inactiveColor: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Total duration
                        Text(
                          _formatDuration(_videoController.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Forward 10s button
                        GestureDetector(
                          onTap: () {
                            print('Forward button tapped');
                            _skipForward();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.forward_10,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container(
            width: double.infinity,
            height: 250,
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                _isTutorialLiked ? Icons.favorite : Icons.favorite_border,
                color: _isTutorialLiked ? Colors.redAccent : Colors.grey,
              ),
              onPressed: _toggleTutorialLike,
            ),
            Text('$_tutorialLikeCount likes'),
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

  Color _getAvatarColor(String name) {
    // Generate a consistent color based on the name
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];

    // Use the first character's code to pick a color
    final index = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[index];
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
}
