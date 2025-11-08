import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';
import '../services/likes_comments_service.dart';
import 'gallery_detail_screen.dart';
import 'tutorial_detail_screen.dart';

class CommunityContentScreen extends StatefulWidget {
  final String contentType; // 'tutorials' or 'gallery'
  final String? currentUserName;

  const CommunityContentScreen({
    super.key,
    required this.contentType,
    this.currentUserName,
  });

  @override
  State<CommunityContentScreen> createState() => _CommunityContentScreenState();
}

class _CommunityContentScreenState extends State<CommunityContentScreen> {
  final _supabase = Supabase.instance.client;
  final _likesCommentsService = LikesCommentsService();
  final _searchController = TextEditingController();

  List<Tutorial> _allTutorials = [];
  List<Tutorial> _filteredTutorials = [];
  List<GalleryPost> _allGalleryPosts = [];
  List<GalleryPost> _filteredGalleryPosts = [];

  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    if (widget.contentType == 'tutorials') {
      _loadTutorials();
    } else {
      _loadGalleryPosts();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTutorials() async {
    try {
      setState(() => _isLoading = true);

      final currentUserId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('tutorials')
          .select()
          .order('created_at', ascending: false);

      List<Tutorial> loadedTutorials = [];

      for (var json in response as List) {
        // Skip current user's posts
        if (json['user_id'] == currentUserId) {
          continue;
        }

        String creatorName = 'Unknown User';
        String creatorAvatarUrl = 'assets/images/avatar1.png';

        if (json['user_id'] != null) {
          try {
            final profileResponse = await _supabase
                .from('profiles')
                .select('name, avatar_url')
                .eq('id', json['user_id'])
                .maybeSingle();

            if (profileResponse != null) {
              creatorName = profileResponse['name'] ?? 'Unknown User';
              creatorAvatarUrl =
                  profileResponse['avatar_url'] ?? 'assets/images/avatar1.png';
            }
          } catch (e) {
            debugPrint('Error fetching profile: $e');
          }
        }

        loadedTutorials.add(
          Tutorial.fromJson({
            ...json,
            'creator_name': creatorName,
            'creator_avatar_url': creatorAvatarUrl,
          }),
        );
      }

      if (mounted) {
        setState(() {
          _allTutorials = loadedTutorials;
          _filteredTutorials = loadedTutorials;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tutorials: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadGalleryPosts() async {
    try {
      setState(() => _isLoading = true);

      final currentUserId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('gallery_posts')
          .select()
          .order('created_at', ascending: false);

      final posts = <GalleryPost>[];

      for (final post in response) {
        // Skip current user's posts
        if (post['user_id'] == currentUserId) {
          continue;
        }

        try {
          final profileResponse = await _supabase
              .from('profiles')
              .select('name, avatar_url')
              .eq('id', post['user_id'])
              .single();

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
        } catch (e) {
          debugPrint('Error fetching profile for post: $e');
        }
      }

      if (mounted) {
        setState(() {
          _allGalleryPosts = posts;
          _filteredGalleryPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading gallery posts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final searchQuery = _searchController.text.toLowerCase();

    if (widget.contentType == 'tutorials') {
      setState(() {
        _filteredTutorials = _allTutorials.where((tutorial) {
          final titleMatch = tutorial.title.toLowerCase().contains(searchQuery);
          final descriptionMatch = tutorial.description.toLowerCase().contains(
            searchQuery,
          );
          final creatorMatch = tutorial.creatorName.toLowerCase().contains(
            searchQuery,
          );
          final categoryMatch =
              _selectedCategory == 'All' ||
              tutorial.eWasteType == _selectedCategory;

          return (titleMatch || descriptionMatch || creatorMatch) &&
              categoryMatch;
        }).toList();
      });
    } else {
      setState(() {
        _filteredGalleryPosts = _allGalleryPosts.where((post) {
          final descriptionMatch = post.description.toLowerCase().contains(
            searchQuery,
          );
          final creatorMatch = post.userName.toLowerCase().contains(
            searchQuery,
          );

          return descriptionMatch || creatorMatch;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contentType == 'tutorials'
              ? 'All Tutorials'
              : 'Community Gallery',
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.contentType == 'tutorials'
                        ? 'Search tutorials, creators...'
                        : 'Search posts, creators...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                // Category filter for tutorials
                if (widget.contentType == 'tutorials') ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('All'),
                        _buildCategoryChip('Lighting'),
                        _buildCategoryChip('Clocks'),
                        _buildCategoryChip('Cables'),
                        _buildCategoryChip('Furnitures'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.contentType == 'tutorials'
                ? _buildTutorialsList()
                : _buildGalleryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
          _applyFilters();
        },
        selectedColor: Colors.green.shade100,
        checkmarkColor: Colors.green.shade700,
        labelStyle: TextStyle(
          color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTutorialsList() {
    if (_filteredTutorials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No tutorials found'
                  : 'No tutorials available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try a different search term'
                  : 'Check back later for new content',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTutorials.length,
      itemBuilder: (context, index) {
        final tutorial = _filteredTutorials[index];
        return _buildTutorialCard(tutorial);
      },
    );
  }

  Widget _buildGalleryList() {
    if (_filteredGalleryPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_search, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No posts found'
                  : 'No gallery posts available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try a different search term'
                  : 'Check back later for new content',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredGalleryPosts.length,
      itemBuilder: (context, index) {
        final post = _filteredGalleryPosts[index];
        return _buildGalleryCard(post);
      },
    );
  }

  Widget _buildTutorialCard(Tutorial tutorial) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TutorialDetailScreen(
                  tutorial: tutorial,
                  allPosts: _allGalleryPosts,
                  currentUserName: widget.currentUserName,
                ),
              ),
            );
            // Reload tutorials when returning from detail screen
            if (widget.contentType == 'tutorials') {
              _loadTutorials();
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tutorial Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: _buildTutorialImage(tutorial.imageUrl),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tutorial.eWasteType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      tutorial.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Description
                    Text(
                      tutorial.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Creator info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _getAvatarColor(
                            tutorial.creatorName,
                          ),
                          backgroundImage:
                              tutorial.creatorAvatarUrl.startsWith('http')
                              ? NetworkImage(tutorial.creatorAvatarUrl)
                              : null,
                          child: !tutorial.creatorAvatarUrl.startsWith('http')
                              ? Text(
                                  tutorial.creatorName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tutorial.creatorName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.favorite_border,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tutorial.likeCount}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryCard(GalleryPost post) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GalleryDetailScreen(
              post: post,
              allPosts: _allGalleryPosts,
              currentUserName: widget.currentUserName,
            ),
          ),
        );
        // Reload gallery posts when returning from detail screen
        if (widget.contentType == 'gallery') {
          _loadGalleryPosts();
        }
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
                        post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                        ? NetworkImage(post.avatarUrl!)
                        : null,
                    child: post.avatarUrl == null || post.avatarUrl!.isEmpty
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
                          _formatTimeAgo(post.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
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
                  ),
                  const SizedBox(height: 12),

                  // Interaction Row
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
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

  Widget _buildTutorialImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
            ),
          );
        },
      );
    } else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 40,
                color: Colors.grey,
              ),
            ),
          );
        },
      );
    } else {
      try {
        return Image.file(
          File(imageUrl),
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
              ),
            );
          },
        );
      } catch (e) {
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.image, size: 40, color: Colors.grey),
          ),
        );
      }
    }
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
