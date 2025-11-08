import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';
import '../services/likes_comments_service.dart';
import 'gallery_detail_screen.dart';

class LikedProjectsScreen extends StatefulWidget {
  final String? currentUserName;

  const LikedProjectsScreen({super.key, this.currentUserName});

  @override
  State<LikedProjectsScreen> createState() => _LikedProjectsScreenState();
}

class _LikedProjectsScreenState extends State<LikedProjectsScreen> {
  final _supabase = Supabase.instance.client;
  final _likesCommentsService = LikesCommentsService();
  List<GalleryPost> _likedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  Future<void> _loadLikedPosts() async {
    try {
      setState(() => _isLoading = true);

      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get liked gallery posts
      final likesResponse = await _supabase
          .from('gallery_likes')
          .select('gallery_post_id')
          .eq('user_id', currentUserId);

      if (likesResponse.isEmpty) {
        setState(() {
          _likedPosts = [];
          _isLoading = false;
        });
        return;
      }

      final likedPostIds = likesResponse
          .map((like) => like['gallery_post_id'] as String)
          .toList();

      // Fetch the actual posts
      final postsResponse = await _supabase
          .from('gallery_posts')
          .select()
          .inFilter('id', likedPostIds)
          .order('created_at', ascending: false);

      final List<GalleryPost> posts = [];

      for (final post in postsResponse) {
        try {
          // Fetch user profile for each post
          final profileResponse = await _supabase
              .from('profiles')
              .select('name, avatar_url')
              .eq('id', post['user_id'])
              .maybeSingle();

          if (profileResponse != null) {
            posts.add(
              GalleryPost(
                id: post['id'] as String?,
                userId: post['user_id'] as String?,
                userName: profileResponse['name'] ?? 'Anonymous',
                imageUrl: post['image_url'] ?? '',
                description: post['description'] ?? '',
                likeCount: post['like_count'] ?? 0,
                avatarUrl: profileResponse['avatar_url'],
                createdAt: post['created_at'] != null
                    ? DateTime.parse(post['created_at'])
                    : null,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error loading post profile: $e');
        }
      }

      if (mounted) {
        setState(() {
          _likedPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading liked posts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Liked Projects',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _likedPosts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Liked Projects Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start liking projects to see them here',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _likedPosts.length,
              itemBuilder: (context, index) {
                final post = _likedPosts[index];
                return _buildGalleryCard(post);
              },
            ),
    );
  }

  Widget _buildGalleryCard(GalleryPost post) {
    final timeAgo = _formatTimeAgo(post.createdAt);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GalleryDetailScreen(
              post: post,
              allPosts: _likedPosts,
              currentUserName: widget.currentUserName,
            ),
          ),
        );
        // Reload after returning in case user unliked
        _loadLikedPosts();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getAvatarColor(post.userName),
                    backgroundImage:
                        post.avatarUrl != null &&
                            post.avatarUrl!.isNotEmpty &&
                            post.avatarUrl!.startsWith('http')
                        ? NetworkImage(post.avatarUrl!)
                        : null,
                    child:
                        post.avatarUrl == null ||
                            post.avatarUrl!.isEmpty ||
                            !post.avatarUrl!.startsWith('http')
                        ? Text(
                            post.userName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Post Image
            _buildGalleryImage(post.imageUrl),

            // Post Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.description,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Interaction Row
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 20, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Icon(
                        Icons.comment_outlined,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      FutureBuilder<int>(
                        future: post.id != null
                            ? _likesCommentsService.getGalleryCommentCount(
                                post.id!,
                              )
                            : Future.value(0),
                        builder: (context, snapshot) {
                          return Text(
                            '${snapshot.data ?? 0}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryImage(String imageUrl) {
    Widget imageWidget;
    if (imageUrl.startsWith('assets/')) {
      imageWidget = Image.asset(
        imageUrl,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      );
    } else if (imageUrl.startsWith('http')) {
      imageWidget = Image.network(
        imageUrl,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade300,
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.grey[600],
              ),
            ),
          );
        },
      );
    } else if (!kIsWeb && imageUrl != 'placeholder.png') {
      imageWidget = Image.file(
        File(imageUrl),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.image, size: 50, color: Colors.grey[600]),
        ),
      );
    }
    return imageWidget;
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
}
