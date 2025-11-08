// lib/screens/admin_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tutorial_model.dart';
import '../models/gallery_post_model.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Tutorial> _tutorials = [];
  List<GalleryPost> _galleryPosts = [];
  List<Map<String, dynamic>> _adminActions = [];

  bool _isLoading = true;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Check if user is admin
      final profile = await _supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .single();

      final isAdmin = profile['is_admin'] == true;

      if (!isAdmin) {
        setState(() {
          _error = 'Access denied: Admin privileges required';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isAdmin = true);
      await _loadData();
    } catch (e) {
      setState(() {
        _error = 'Error checking admin status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadTutorials(),
        _loadGalleryPosts(),
        _loadAdminActions(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTutorials() async {
    try {
      final response = await _supabase
          .from('tutorials')
          .select('*')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        print('No tutorials found in database');
        setState(() => _tutorials = []);
        return;
      }

      print('Found ${response.length} tutorials');

      final tutorials = <Tutorial>[];
      for (final item in response) {
        try {
          // Fetch profile separately for better error handling
          String creatorName = 'Unknown User';
          String creatorAvatarUrl = 'assets/images/ourLogo.png';

          if (item['user_id'] != null) {
            try {
              final profileResponse = await _supabase
                  .from('profiles')
                  .select('name, avatar_url')
                  .eq('id', item['user_id'])
                  .maybeSingle();

              if (profileResponse != null) {
                creatorName = profileResponse['name'] ?? 'Unknown User';
                creatorAvatarUrl =
                    profileResponse['avatar_url'] ??
                    'assets/images/ourLogo.png';
              }
            } catch (profileError) {
              print(
                'Error fetching profile for tutorial ${item['id']}: $profileError',
              );
            }
          }

          final tutorial = Tutorial(
            id: item['id'],
            userId: item['user_id'],
            title: item['title'] ?? 'Untitled',
            description: item['description'] ?? '',
            eWasteType: item['e_waste_type'] ?? item['category'] ?? 'Other',
            videoUrl: item['video_url'] ?? '',
            imageUrl: item['thumbnail_url'] ?? item['image_url'] ?? '',
            creatorName: creatorName,
            creatorAvatarUrl: creatorAvatarUrl,
            likeCount: item['like_count'] ?? 0,
            comments: [],
            createdAt: item['created_at'] != null
                ? DateTime.parse(item['created_at'])
                : null,
          );

          tutorials.add(tutorial);
          print('Added tutorial: ${tutorial.title} by ${tutorial.creatorName}');
        } catch (itemError) {
          print('Error processing tutorial item: $itemError');
          print('Item data: $item');
        }
      }

      if (mounted) {
        setState(() => _tutorials = tutorials);
      }
      print('Successfully loaded ${tutorials.length} tutorials');
    } catch (e) {
      print('Error loading tutorials: $e');
      if (mounted) {
        setState(() => _tutorials = []);
      }
    }
  }

  Future<void> _loadGalleryPosts() async {
    try {
      final response = await _supabase
          .from('gallery_posts')
          .select('*')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        print('No gallery posts found in database');
        setState(() => _galleryPosts = []);
        return;
      }

      print('Found ${response.length} gallery posts');

      final posts = <GalleryPost>[];
      for (final item in response) {
        try {
          // Fetch profile separately for better error handling
          String userName = 'Unknown User';
          String? avatarUrl;

          if (item['user_id'] != null) {
            try {
              final profileResponse = await _supabase
                  .from('profiles')
                  .select('name, avatar_url')
                  .eq('id', item['user_id'])
                  .maybeSingle();

              if (profileResponse != null) {
                userName = profileResponse['name'] ?? 'Unknown User';
                avatarUrl = profileResponse['avatar_url'];
              }
            } catch (profileError) {
              print(
                'Error fetching profile for gallery post ${item['id']}: $profileError',
              );
            }
          }

          final post = GalleryPost(
            userId: item['user_id'],
            userName: userName,
            imageUrl: item['image_url'] ?? '',
            description: item['description'] ?? '',
            likeCount: item['like_count'] ?? 0,
            avatarUrl: avatarUrl,
            createdAt: item['created_at'] != null
                ? DateTime.parse(item['created_at'])
                : null,
          );

          posts.add(post);
          print('Added gallery post by $userName');
        } catch (itemError) {
          print('Error processing gallery post item: $itemError');
          print('Item data: $item');
        }
      }

      if (mounted) {
        setState(() => _galleryPosts = posts);
      }
      print('Successfully loaded ${posts.length} gallery posts');
    } catch (e) {
      print('Error loading gallery posts: $e');
      if (mounted) {
        setState(() => _galleryPosts = []);
      }
    }
  }

  Future<void> _loadAdminActions() async {
    try {
      final response = await _supabase
          .from('admin_actions')
          .select('*, profiles(name)')
          .order('created_at', ascending: false)
          .limit(50);

      setState(() => _adminActions = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      print('Error loading admin actions: $e');
    }
  }

  Future<void> _deleteTutorial(Tutorial tutorial) async {
    final confirmed = await _showDeleteConfirmation(
      'Delete Tutorial',
      'Are you sure you want to delete "${tutorial.title}" by ${tutorial.creatorName}?',
    );

    if (!confirmed) return;

    final reason = await _showReasonDialog();
    if (reason == null) return;

    try {
      // Log admin action BEFORE deleting (to capture details)
      await _supabase.from('admin_actions').insert({
        'admin_id': _supabase.auth.currentUser!.id,
        'action_type': 'delete_tutorial',
        'target_id': tutorial.id,
        'target_type': 'tutorial',
        'target_title': tutorial.title,
        'target_creator': tutorial.creatorName,
        'target_image_url': tutorial.imageUrl,
        'reason': reason,
      });

      // Delete tutorial from database
      await _supabase.from('tutorials').delete().eq('id', tutorial.id!);

      // Reload data
      await _loadTutorials();
      await _loadAdminActions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tutorial "${tutorial.title}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting tutorial: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteGalleryPost(GalleryPost post, int index) async {
    final confirmed = await _showDeleteConfirmation(
      'Delete Gallery Post',
      'Are you sure you want to delete this gallery post by ${post.userName}?',
    );

    if (!confirmed) return;

    final reason = await _showReasonDialog();
    if (reason == null) return;

    try {
      // Get the post ID from database by matching attributes
      final response = await _supabase
          .from('gallery_posts')
          .select('id')
          .eq('user_id', post.userId!)
          .eq('image_url', post.imageUrl)
          .maybeSingle();

      if (response == null) {
        throw Exception('Gallery post not found');
      }

      final postId = response['id'];

      // Log admin action BEFORE deleting (to capture details)
      await _supabase.from('admin_actions').insert({
        'admin_id': _supabase.auth.currentUser!.id,
        'action_type': 'delete_gallery_post',
        'target_id': postId,
        'target_type': 'gallery_post',
        'target_title': post.description.isNotEmpty
            ? (post.description.length > 50
                  ? '${post.description.substring(0, 50)}...'
                  : post.description)
            : 'Gallery post',
        'target_creator': post.userName,
        'target_image_url': post.imageUrl,
        'reason': reason,
      });

      // Delete gallery post from database
      await _supabase.from('gallery_posts').delete().eq('id', postId);

      // Reload data
      await _loadGalleryPosts();
      await _loadAdminActions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gallery post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting gallery post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _showReasonDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Deletion'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter reason (e.g., violates guidelines)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.isNotEmpty == true ? result : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin || _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Access Denied',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'You need admin privileges to access this page',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.video_library), text: 'Tutorials'),
            Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
            Tab(icon: Icon(Icons.history), text: 'Actions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTutorialsTab(),
          _buildGalleryTab(),
          _buildActionsTab(),
        ],
      ),
    );
  }

  Widget _buildTutorialsTab() {
    if (_tutorials.isEmpty) {
      return const Center(child: Text('No tutorials found'));
    }

    return RefreshIndicator(
      onRefresh: _loadTutorials,
      child: ListView.builder(
        itemCount: _tutorials.length,
        itemBuilder: (context, index) {
          final tutorial = _tutorials[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: tutorial.imageUrl.isNotEmpty
                    ? Image.network(
                        tutorial.imageUrl,
                        width: 100,
                        height: 70,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 70,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 70,
                          color: Colors.grey[300],
                          child: const Icon(Icons.video_library, size: 40),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 70,
                        color: Colors.grey[300],
                        child: const Icon(Icons.video_library, size: 40),
                      ),
              ),
              title: Text(
                tutorial.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tutorial.creatorName,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.category, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        tutorial.eWasteType,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  if (tutorial.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(tutorial.createdAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteTutorial(tutorial),
                tooltip: 'Delete tutorial',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildGalleryTab() {
    if (_galleryPosts.isEmpty) {
      return const Center(child: Text('No gallery posts found'));
    }

    return RefreshIndicator(
      onRefresh: _loadGalleryPosts,
      child: ListView.builder(
        itemCount: _galleryPosts.length,
        itemBuilder: (context, index) {
          final post = _galleryPosts[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 40),
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (post.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount} likes',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  if (post.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(post.createdAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteGalleryPost(post, index),
                tooltip: 'Delete gallery post',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionsTab() {
    if (_adminActions.isEmpty) {
      return const Center(child: Text('No admin actions recorded'));
    }

    return RefreshIndicator(
      onRefresh: _loadAdminActions,
      child: ListView.builder(
        itemCount: _adminActions.length,
        itemBuilder: (context, index) {
          final action = _adminActions[index];
          final profile = action['profiles'];
          final adminName = profile != null ? profile['name'] : 'Unknown Admin';
          final actionType = action['action_type'] as String;
          final reason = action['reason'] as String?;
          final targetTitle = action['target_title'] as String?;
          final targetCreator = action['target_creator'] as String?;
          final targetImageUrl = action['target_image_url'] as String?;
          final createdAt = DateTime.parse(action['created_at']);

          IconData icon;
          Color color;
          switch (actionType) {
            case 'delete_tutorial':
              icon = Icons.video_library;
              color = Colors.orange;
              break;
            case 'delete_gallery_post':
              icon = Icons.photo_library;
              color = Colors.purple;
              break;
            default:
              icon = Icons.admin_panel_settings;
              color = Colors.blue;
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: targetImageUrl != null && targetImageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        targetImageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            CircleAvatar(
                              backgroundColor: color.withOpacity(0.2),
                              child: Icon(icon, color: color),
                            ),
                      ),
                    )
                  : CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Icon(icon, color: color),
                    ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatActionType(actionType),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (targetTitle != null)
                    Text(
                      '"$targetTitle"',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (targetCreator != null) Text('Creator: $targetCreator'),
                  Text('Admin: $adminName'),
                  if (reason != null && reason.isNotEmpty)
                    Text(
                      'Reason: $reason',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  String _formatActionType(String actionType) {
    return actionType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
