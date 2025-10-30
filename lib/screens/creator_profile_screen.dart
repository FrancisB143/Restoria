// lib/screens/creator_profile_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';
import 'conversation_screen.dart';
import 'tutorial_detail_screen.dart';
import 'gallery_detail_screen.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String userName;
  final List<GalleryPost> allPosts;
  final String currentUserName;
  final String? creatorUserId; // Add to identify the creator

  const CreatorProfileScreen({
    super.key,
    required this.userName,
    required this.allPosts,
    required this.currentUserName,
    this.creatorUserId,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  int _currentUserFollowingCount = 0;
  bool _isLoading = true;
  List<dynamic> _userProjects = [];
  String? _creatorUserId;
  String _creatorAvatarUrl = '';
  String _creatorBio =
      'Turning e-waste into e-wonderful! ♻️✨ Creator and seller of unique upcycled art.';

  @override
  void initState() {
    super.initState();
    _creatorUserId = widget.creatorUserId;
    _loadCreatorData();
  }

  Future<void> _loadCreatorData() async {
    try {
      setState(() => _isLoading = true);

      // Load creator profile from database
      await _loadCreatorProfile();

      // Load follow status
      await _loadFollowStatus();

      // Load creator's projects (tutorials and gallery posts)
      await _loadCreatorProjects();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading creator data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCreatorProfile() async {
    try {
      // If we don't have the user ID, try to find it by name
      if (_creatorUserId == null) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, name, avatar_url, bio')
            .eq('name', widget.userName)
            .maybeSingle();

        if (profileResponse != null) {
          _creatorUserId = profileResponse['id'] as String;
          _creatorAvatarUrl = profileResponse['avatar_url'] as String? ?? '';
          _creatorBio =
              profileResponse['bio'] as String? ??
              'Turning e-waste into e-wonderful! ♻️✨ Creator and seller of unique upcycled art.';
        }
      } else {
        // Load profile with the provided user ID
        final profileResponse = await _supabase
            .from('profiles')
            .select('name, avatar_url, bio')
            .eq('id', _creatorUserId!)
            .single();

        _creatorAvatarUrl = profileResponse['avatar_url'] as String? ?? '';
        _creatorBio =
            profileResponse['bio'] as String? ??
            'Turning e-waste into e-wonderful! ♻️✨ Creator and seller of unique upcycled art.';
      }

      // Load followers and following counts from database
      if (_creatorUserId != null) {
        // Count followers (people who follow this creator)
        final followersResponse = await _supabase
            .from('user_follows')
            .select('follower_id')
            .eq('following_id', _creatorUserId!);
        _followersCount = (followersResponse as List).length;

        // Count following (people this creator follows)
        final followingResponse = await _supabase
            .from('user_follows')
            .select('following_id')
            .eq('follower_id', _creatorUserId!);
        _followingCount = (followingResponse as List).length;
      }
    } catch (e) {
      debugPrint('Error loading creator profile: $e');
      // If tables don't exist, use SharedPreferences fallback
      await _loadFollowStatusFromPrefs();
    }
  }

  Future<void> _loadFollowStatus() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || _creatorUserId == null) {
        await _loadFollowStatusFromPrefs();
        return;
      }

      // Check if current user follows this creator in database
      final followResponse = await _supabase
          .from('user_follows')
          .select('id')
          .eq('follower_id', currentUser.id)
          .eq('following_id', _creatorUserId!)
          .maybeSingle();

      setState(() {
        _isFollowing = followResponse != null;
      });

      // Get current user's following count
      final currentUserFollowingResponse = await _supabase
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', currentUser.id);
      _currentUserFollowingCount =
          (currentUserFollowingResponse as List).length;
    } catch (e) {
      debugPrint('Error loading follow status from database: $e');
      // Fallback to SharedPreferences
      await _loadFollowStatusFromPrefs();
    }
  }

  Future<void> _loadFollowStatusFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final followingKey =
          'following_${widget.currentUserName}_${widget.userName}';
      final followersKey = 'followers_${widget.userName}';
      final currentUserFollowingKey =
          'following_count_${widget.currentUserName}';

      setState(() {
        _isFollowing = prefs.getBool(followingKey) ?? false;
        if (_followersCount == 0) {
          _followersCount = prefs.getInt(followersKey) ?? 128;
        }
        _currentUserFollowingCount = prefs.getInt(currentUserFollowingKey) ?? 5;
      });
    } catch (e) {
      debugPrint('Error loading follow status from prefs: $e');
    }
  }

  Future<void> _loadCreatorProjects() async {
    try {
      if (_creatorUserId == null) return;

      final projects = <Map<String, dynamic>>[];

      // Fetch creator's tutorials
      final tutorialsResponse = await _supabase
          .from('tutorials')
          .select()
          .eq('user_id', _creatorUserId!)
          .order('created_at', ascending: false);

      for (var tutorial in tutorialsResponse) {
        projects.add({
          'type': 'tutorial',
          'data': Tutorial.fromJson({
            ...tutorial,
            'creator_name': widget.userName,
            'creator_avatar_url': _creatorAvatarUrl,
          }),
          'created_at': tutorial['created_at'],
        });
      }

      // Fetch creator's gallery posts
      final galleryResponse = await _supabase
          .from('gallery_posts')
          .select()
          .eq('user_id', _creatorUserId!)
          .order('created_at', ascending: false);

      for (var post in galleryResponse) {
        projects.add({
          'type': 'gallery',
          'data': GalleryPost(
            userId: post['user_id'],
            userName: widget.userName,
            imageUrl: post['image_url'] ?? '',
            description: post['description'] ?? '',
            likeCount: post['like_count'] ?? 0,
            avatarUrl: _creatorAvatarUrl,
          ),
          'created_at': post['created_at'],
        });
      }

      // Sort by created_at descending
      projects.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] ?? '2000-01-01');
        final bTime = DateTime.parse(b['created_at'] ?? '2000-01-01');
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _userProjects = projects;
        });
      }
    } catch (e) {
      debugPrint('Error loading creator projects: $e');
      // Fallback to widget.allPosts if database fails
      setState(() {
        _userProjects = widget.allPosts
            .where((post) => post.userName == widget.userName)
            .map(
              (post) => {
                'type': 'gallery',
                'data': post,
                'created_at': DateTime.now().toIso8601String(),
              },
            )
            .toList();
      });
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || _creatorUserId == null) {
        // Fallback to SharedPreferences if not authenticated
        await _toggleFollowWithPrefs();
        return;
      }

      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount = _isFollowing
            ? _followersCount + 1
            : _followersCount - 1;
        _currentUserFollowingCount = _isFollowing
            ? _currentUserFollowingCount + 1
            : _currentUserFollowingCount - 1;
      });

      if (_isFollowing) {
        // Add follow relationship to database
        await _supabase.from('user_follows').insert({
          'follower_id': currentUser.id,
          'following_id': _creatorUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Remove follow relationship from database
        await _supabase
            .from('user_follows')
            .delete()
            .eq('follower_id', currentUser.id)
            .eq('following_id', _creatorUserId!);
      }

      // Also save to SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      final followingKey =
          'following_${widget.currentUserName}_${widget.userName}';
      final followersKey = 'followers_${widget.userName}';
      final currentUserFollowingKey =
          'following_count_${widget.currentUserName}';

      await prefs.setBool(followingKey, _isFollowing);
      await prefs.setInt(followersKey, _followersCount);
      await prefs.setInt(currentUserFollowingKey, _currentUserFollowingCount);

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowing
                  ? 'You are now following ${widget.userName}'
                  : 'You unfollowed ${widget.userName}',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      // Revert the state if error occurs
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount = _isFollowing
            ? _followersCount + 1
            : _followersCount - 1;
        _currentUserFollowingCount = _isFollowing
            ? _currentUserFollowingCount + 1
            : _currentUserFollowingCount - 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFollowWithPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final followingKey =
          'following_${widget.currentUserName}_${widget.userName}';
      final followersKey = 'followers_${widget.userName}';
      final currentUserFollowingKey =
          'following_count_${widget.currentUserName}';

      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount = _isFollowing
            ? _followersCount + 1
            : _followersCount - 1;
        _currentUserFollowingCount = _isFollowing
            ? _currentUserFollowingCount + 1
            : _currentUserFollowingCount - 1;
      });

      // Save to SharedPreferences
      await prefs.setBool(followingKey, _isFollowing);
      await prefs.setInt(followersKey, _followersCount);
      await prefs.setInt(currentUserFollowingKey, _currentUserFollowingCount);

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowing
                  ? 'You are now following ${widget.userName}'
                  : 'You unfollowed ${widget.userName}',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      // Revert the state if error occurs
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount = _isFollowing
            ? _followersCount + 1
            : _followersCount - 1;
        _currentUserFollowingCount = _isFollowing
            ? _currentUserFollowingCount + 1
            : _currentUserFollowingCount - 1;
      });
    }
  }

  Widget _buildProjectImage(String imageUrl) {
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, fit: BoxFit.cover);
    } else if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.image),
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.image),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).padding.top + 40,
                  ), // Space for back button
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: colorScheme.primary,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _creatorAvatarUrl.isNotEmpty
                          ? NetworkImage(_creatorAvatarUrl)
                          : NetworkImage(
                              'https://i.pravatar.cc/150?u=${widget.userName.hashCode}',
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userName,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Davao City, Philippines',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _creatorBio,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        _userProjects.length.toString(),
                        'Creations',
                        textTheme,
                      ),
                      _buildStatItem(
                        _followingCount.toString(),
                        'Following',
                        textTheme,
                      ),
                      _buildStatItem(
                        _followersCount.toString(),
                        'Followers',
                        textTheme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Message and Follow Buttons Row
                  Row(
                    children: [
                      // Message Button (takes more space)
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConversationScreen(
                                  otherUserName: widget.userName,
                                  otherUserAvatarUrl:
                                      'https://i.pravatar.cc/150?u=${widget.userName.hashCode}',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Follow/Unfollow Button
                      Expanded(
                        flex: 2,
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: _toggleFollow,
                                icon: Icon(
                                  _isFollowing
                                      ? Icons.person_remove
                                      : Icons.person_add,
                                  size: 20,
                                ),
                                label: Text(
                                  _isFollowing ? 'Unfollow' : 'Follow',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _isFollowing
                                      ? colorScheme.error
                                      : colorScheme.primary,
                                  side: BorderSide(
                                    color: _isFollowing
                                        ? colorScheme.error
                                        : colorScheme.primary,
                                  ),
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Projects', textTheme),
                  const SizedBox(height: 12),
                  _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _userProjects.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.0),
                            child: Text(
                              "This user hasn't posted any projects yet.",
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: _userProjects.length,
                          itemBuilder: (context, index) {
                            final project = _userProjects[index];
                            final type = project['type'] as String;

                            return GestureDetector(
                              onTap: () {
                                if (type == 'tutorial') {
                                  final tutorial = project['data'] as Tutorial;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TutorialDetailScreen(
                                            tutorial: tutorial,
                                            allPosts: widget.allPosts,
                                            currentUserName:
                                                widget.currentUserName,
                                          ),
                                    ),
                                  );
                                } else {
                                  final post = project['data'] as GalleryPost;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GalleryDetailScreen(
                                        post: post,
                                        allPosts: widget.allPosts,
                                        currentUserName: widget.currentUserName,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Display image based on type
                                    type == 'tutorial'
                                        ? Image.network(
                                            (project['data'] as Tutorial)
                                                .imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      color:
                                                          Colors.grey.shade300,
                                                      child: const Icon(
                                                        Icons.video_library,
                                                      ),
                                                    ),
                                          )
                                        : _buildProjectImage(
                                            (project['data'] as GalleryPost)
                                                .imageUrl,
                                          ),
                                    // Video icon overlay for tutorials
                                    if (type == 'tutorial')
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          // Back button positioned at top left
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
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
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, TextTheme textTheme) {
    return Column(
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }

  Widget _buildSectionTitle(String title, TextTheme textTheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
