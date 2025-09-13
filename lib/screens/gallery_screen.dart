import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/gallery_post_model.dart';
import 'gallery_detail_screen.dart';

class GalleryScreen extends StatelessWidget {
  final List<GalleryPost> posts;
  final Future<void> Function() onAdd;
  final Function(GalleryPost)? onAddPost;

  const GalleryScreen({
    super.key,
    required this.posts,
    required this.onAdd,
    this.onAddPost,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section (same as learn screen)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              child: Row(
                children: [
                  // Logo and App Name
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/ourLogo.png',
                        height: 32,
                        width: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Restoria',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Notification Icon
                  IconButton(
                    onPressed: () {
                      // Handle notification tap
                    },
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.black54,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hero Section (same structure as learn screen, but with gallery text)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Turn E-Waste into Art',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create upcycling projects from electronic\nwaste and share with the community.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _showNewProjectDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Start Creating',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Action Buttons Section
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.add,
                    label: 'New Project',
                    subtitle: 'Start a new\ncreation',
                    onTap: () => _showNewProjectDialog(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    subtitle: 'Browse community\ncreations',
                    onTap: () => _showGalleryOptions(context),
                  ),
                ),
              ],
            ),
          ),

          // Community Gallery Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Community Gallery',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Posts List
          posts.isEmpty
              ? _buildSampleCommunityPosts(
                  context,
                ) // Show sample posts when empty
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _buildCommunityPost(context, post, index);
                  },
                ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPost(
    BuildContext context,
    GalleryPost post,
    int index,
  ) {
    // Generate mock time ago data
    final timeAgo = _getTimeAgo(index);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GalleryDetailScreen(post: post),
          ),
        );
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
                    backgroundColor: _getAvatarColor(index),
                    child: Text(
                      post.userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: post.imageUrl != 'placeholder.png'
                  ? (kIsWeb
                        ? Image.network(
                            post.imageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(post.imageUrl),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ))
                  : Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
            ),

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
                      _buildInteractionButton(
                        icon: Icons.favorite_border,
                        count: post.likeCount,
                        onTap: () {},
                      ),
                      const SizedBox(width: 20),
                      _buildInteractionButton(
                        icon: Icons.chat_bubble_outline,
                        count: _getCommentCount(index),
                        onTap: () {},
                      ),
                      const Spacer(),
                      Icon(
                        Icons.share_outlined,
                        size: 20,
                        color: Colors.grey[600],
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

  Widget _buildInteractionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(int index) {
    final timeOptions = [
      '2 hours ago',
      '5 hours ago',
      '1 day ago',
      '3 days ago',
      '1 week ago',
    ];
    return timeOptions[index % timeOptions.length];
  }

  Color _getAvatarColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  int _getCommentCount(int index) {
    final counts = [5, 12, 8, 3, 15, 7];
    return counts[index % counts.length];
  }

  Widget _buildSampleCommunityPosts(BuildContext context) {
    // Sample posts using only existing asset images
    final samplePosts = [
      {
        'userName': 'Sarah Chen',
        'profilePicture': null, // Use avatar color instead
        'imageUrl': 'assets/images/lamp.png',
        'description':
            'LED Art Display from old motherboards! Took me 3 days but totally worth it 💡',
        'likeCount': 24,
        'timeAgo': '2 hours ago',
        'avatarColor': Colors.blue,
      },
      {
        'userName': 'Mike Rodriguez',
        'profilePicture': null, // Use avatar color instead
        'imageUrl': 'assets/images/flashlight.png',
        'description':
            'Robot buddy made from old phones and cables! Kids love it 🤖',
        'likeCount': 18,
        'timeAgo': '5 hours ago',
        'avatarColor': Colors.green,
      },
      {
        'userName': 'Emma Wilson',
        'profilePicture': null, // Use avatar color instead
        'imageUrl': 'assets/images/toaster_bookends.jpg',
        'description':
            'Vintage toaster transformed into unique bookends for my study room',
        'likeCount': 32,
        'timeAgo': '1 day ago',
        'avatarColor': Colors.purple,
      },
      {
        'userName': 'Alex Kim',
        'profilePicture': null, // Use avatar color instead
        'imageUrl': 'assets/images/cable_organize.jpg',
        'description':
            'Cable management organizer made from old hard drive parts',
        'likeCount': 15,
        'timeAgo': '2 days ago',
        'avatarColor': Colors.orange,
      },
      {
        'userName': 'Lisa Zhang',
        'profilePicture': null, // Use avatar color instead
        'imageUrl': 'assets/images/mouse_planter.jpg',
        'description':
            'Mini succulent planter from recycled computer mouse - so cute! 🌱',
        'likeCount': 28,
        'timeAgo': '3 days ago',
        'avatarColor': Colors.teal,
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: samplePosts.length,
      itemBuilder: (context, index) {
        final samplePost = samplePosts[index];
        return _buildSampleCommunityPost(context, samplePost, index);
      },
    );
  }

  Widget _buildSampleCommunityPost(
    BuildContext context,
    Map<String, dynamic> sampleData,
    int index,
  ) {
    return GestureDetector(
      onTap: () {
        // Create a temporary GalleryPost for navigation
        final tempPost = GalleryPost(
          userName: sampleData['userName'],
          imageUrl: sampleData['imageUrl'],
          description: sampleData['description'],
          likeCount: sampleData['likeCount'],
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GalleryDetailScreen(post: tempPost),
          ),
        );
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
                    backgroundColor: sampleData['avatarColor'],
                    backgroundImage: sampleData['profilePicture'] != null
                        ? AssetImage(sampleData['profilePicture'])
                        : null,
                    child: sampleData['profilePicture'] == null
                        ? Text(
                            sampleData['userName'][0].toUpperCase(),
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
                          sampleData['userName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          sampleData['timeAgo'],
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: Image.asset(
                sampleData['imageUrl'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Post Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sampleData['description'],
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  // Interaction Row
                  Row(
                    children: [
                      _buildInteractionButton(
                        icon: Icons.favorite_border,
                        count: sampleData['likeCount'],
                        onTap: () {},
                      ),
                      const SizedBox(width: 20),
                      _buildInteractionButton(
                        icon: Icons.chat_bubble_outline,
                        count: _getCommentCount(index),
                        onTap: () {},
                      ),
                      const Spacer(),
                      Icon(
                        Icons.share_outlined,
                        size: 20,
                        color: Colors.grey[600],
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

  void _showNewProjectDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedImagePath = 'assets/images/lamp.png';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    const Expanded(
                      child: Text(
                        'New Project',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _saveNewProject(
                          context,
                          titleController.text,
                          descriptionController.text,
                          selectedImagePath,
                        );
                      },
                      child: const Text('Share'),
                    ),
                  ],
                ),
              ),
              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image selection
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            selectedImagePath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          _showProjectImageSelector(context, (imagePath) {
                            setModalState(() {
                              selectedImagePath = imagePath;
                            });
                          });
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Change Image'),
                      ),
                      const SizedBox(height: 16),
                      // Title field
                      const Text(
                        'Project Title',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'What did you create?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description field
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tell us about your creation process...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProjectImageSelector(
    BuildContext context,
    Function(String) onImageSelected,
  ) {
    final availableImages = [
      'assets/images/lamp.png',
      'assets/images/flashlight.png',
      'assets/images/toaster_bookends.jpg',
      'assets/images/cable_organize.jpg',
      'assets/images/mouse_planter.jpg',
      'assets/images/harddriveclock.jpg',
      'assets/images/ourLogo.png',
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Project Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: availableImages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    onImageSelected(availableImages[index]);
                    Navigator.pop(context);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      availableImages[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveNewProject(
    BuildContext context,
    String title,
    String description,
    String imagePath,
  ) {
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create new gallery post
    final newPost = GalleryPost(
      userName: 'You',
      imageUrl: imagePath,
      description: description,
      likeCount: 0,
    );

    // Add to posts list if callback is available
    if (onAddPost != null) {
      onAddPost!(newPost);
    }

    // Close the modal
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Project "$title" shared successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showGalleryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gallery Options',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.grid_view, color: Colors.green),
              title: const Text('View All Projects'),
              subtitle: const Text('Browse all community creations'),
              onTap: () {
                Navigator.pop(context);
                // Scroll to community gallery section
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scrolled to Community Gallery!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.red),
              title: const Text('Liked Projects'),
              subtitle: const Text('View your liked creations'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Liked Projects feature coming soon!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.purple),
              title: const Text('My Projects'),
              subtitle: const Text('View your own creations'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('My Projects feature coming soon!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
