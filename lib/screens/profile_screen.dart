import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';
import 'gallery_detail_screen.dart';
import 'tutorial_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  final List<GalleryPost> allPosts;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.allPosts,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _userProjects = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _userName = '';
  String _userBio =
      'Turning e-waste into e-wonderful! ♻️✨ Creator and seller of unique upcycled art.';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _loadUserProjects();
  }

  Future<void> _loadUserProjects() async {
    try {
      setState(() => _isLoading = true);

      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch user profile data
      String userName = widget.userName;
      String avatarUrl = 'assets/images/avatar1.png';
      String bio =
          'Turning e-waste into e-wonderful! ♻️✨ Creator and seller of unique upcycled art.';

      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select('name, avatar_url, bio, is_admin')
            .eq('id', user.id)
            .single();

        userName = profileResponse['name'] as String? ?? widget.userName;
        bio = profileResponse['bio'] as String? ?? bio;
        _isAdmin = profileResponse['is_admin'] == true;
        if (profileResponse.containsKey('avatar_url') &&
            profileResponse['avatar_url'] != null) {
          avatarUrl = profileResponse['avatar_url'] as String;
        }
      } catch (profileError) {
        debugPrint('Error fetching profile: $profileError');
        // Try fetching without bio field if it doesn't exist
        try {
          final nameResponse = await _supabase
              .from('profiles')
              .select('name, avatar_url')
              .eq('id', user.id)
              .single();

          userName = nameResponse['name'] as String? ?? widget.userName;
          if (nameResponse.containsKey('avatar_url') &&
              nameResponse['avatar_url'] != null) {
            avatarUrl = nameResponse['avatar_url'] as String;
          }
        } catch (nameError) {
          debugPrint('Error fetching name: $nameError');
        }
      }

      // Fetch user's tutorials
      final tutorialsResponse = await _supabase
          .from('tutorials')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Fetch user's gallery posts
      final galleryResponse = await _supabase
          .from('gallery_posts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final projects = <Map<String, dynamic>>[];

      // Add tutorials with type marker and updated creator info
      for (var tutorial in tutorialsResponse) {
        final tutorialData = {
          ...tutorial,
          'creator_name': userName,
          'creator_avatar_url': avatarUrl,
        };

        projects.add({
          'type': 'tutorial',
          'data': Tutorial.fromJson(tutorialData),
          'created_at': tutorial['created_at'],
        });
      }

      // Add gallery posts with type marker and updated user info
      for (var post in galleryResponse) {
        projects.add({
          'type': 'gallery',
          'data': GalleryPost(
            id: post['id'] as String?,
            userId: post['user_id'],
            userName: userName,
            imageUrl: post['image_url'] ?? '',
            description: post['description'] ?? '',
            likeCount: post['like_count'] ?? 0,
            avatarUrl: avatarUrl,
            createdAt: post['created_at'] != null
                ? DateTime.parse(post['created_at'])
                : null,
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
          _userName = userName;
          _userBio = bio;
          _avatarUrl = avatarUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user projects: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                CircleAvatar(
                  radius: 54,
                  backgroundColor: colorScheme.primary,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? (_avatarUrl!.startsWith('assets/')
                              ? AssetImage(_avatarUrl!) as ImageProvider
                              : NetworkImage(_avatarUrl!))
                        : const AssetImage('assets/images/avatar1.png'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _userName,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _userBio,
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
                    _buildStatItem('5', 'Following', textTheme),
                    _buildStatItem('128', 'Followers', textTheme),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(
                          currentName: _userName,
                          currentBio: _userBio,
                          currentAvatarUrl: _avatarUrl,
                        ),
                      ),
                    );

                    // If profile was updated, reload data
                    if (result != null && mounted) {
                      setState(() {
                        if (result['name'] != null) {
                          _userName = result['name'];
                        }
                        if (result['bio'] != null) {
                          _userBio = result['bio'];
                        }
                        if (result.containsKey('avatar_url')) {
                          _avatarUrl = result['avatar_url'];
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildSectionTitle('My Projects', textTheme),
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
                          child: Text("You haven't posted any projects yet."),
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
                            onTap: () async {
                              if (type == 'tutorial') {
                                final tutorial = project['data'] as Tutorial;
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TutorialDetailScreen(
                                      tutorial: tutorial,
                                      allPosts: widget.allPosts,
                                      currentUserName: widget.userName,
                                    ),
                                  ),
                                );
                                // Reload if item was deleted
                                if (result == true) {
                                  _loadUserProjects();
                                }
                              } else {
                                final post = project['data'] as GalleryPost;
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GalleryDetailScreen(
                                      post: post,
                                      allPosts: widget.allPosts,
                                      currentUserName: widget.userName,
                                    ),
                                  ),
                                );
                                // Reload if item was deleted
                                if (result == true) {
                                  _loadUserProjects();
                                }
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
                                                    color: Colors.grey.shade300,
                                                    child: const Icon(
                                                      Icons.video_library,
                                                    ),
                                                  ),
                                        )
                                      : Image.network(
                                          (project['data'] as GalleryPost)
                                              .imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: Colors.grey.shade300,
                                                    child: const Icon(
                                                      Icons.image,
                                                    ),
                                                  ),
                                        ),
                                  // Video icon overlay for tutorials
                                  if (type == 'tutorial')
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
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
        // Admin button (if user is admin)
        if (_isAdmin)
          Positioned(
            top: 8,
            right: 60,
            child: SafeArea(
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings),
                color: Colors.orange,
                tooltip: 'Admin Panel',
                iconSize: 28,
              ),
            ),
          ),
        // Logout button in upper right corner
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton(
              onPressed: () async {
                // Show confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true && mounted) {
                  try {
                    // Sign out from Supabase
                    await _supabase.auth.signOut();

                    // Navigate to login screen and remove all previous routes
                    if (mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error logging out: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.logout),
              color: Colors.red,
              tooltip: 'Logout',
              iconSize: 28,
            ),
          ),
        ),
      ],
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
