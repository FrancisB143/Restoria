import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';
import 'tutorial_detail_screen.dart';

class LearnScreen extends StatefulWidget {
  final List<Tutorial> tutorials;
  final List<GalleryPost> allPosts;
  final Future<void> Function() onAdd;
  final Function(Tutorial) onAddTutorial;
  final String? currentUserName; // Add currentUserName

  const LearnScreen({
    super.key,
    required this.tutorials,
    required this.allPosts,
    required this.onAdd,
    required this.onAddTutorial,
    this.currentUserName, // Make it optional
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  late List<Tutorial> _filteredTutorials;
  List<Tutorial> _allTutorials = []; // Store all tutorials from database
  bool _isLoadingTutorials = true;
  String _selectedCategory = 'All';
  String _selectedCategoryDisplay = 'All';

  @override
  void initState() {
    super.initState();
    _filteredTutorials = widget.tutorials;
    _searchController.addListener(_applyFilters);
    _loadAllTutorials(); // Load from database on init
  }

  Future<void> _loadAllTutorials() async {
    try {
      setState(() => _isLoadingTutorials = true);

      final response = await _supabase
          .from('tutorials')
          .select('*')
          .order('created_at', ascending: false);

      List<Tutorial> loadedTutorials = [];

      for (var json in response as List) {
        String creatorName = 'Unknown User';
        String creatorAvatarUrl = 'assets/images/avatar1.png';

        print(
          'Loading tutorial: ${json['title']} by user_id: ${json['user_id']}',
        );

        if (json['user_id'] != null) {
          try {
            // First try to get just the name
            final profileResponse = await _supabase
                .from('profiles')
                .select('name')
                .eq('id', json['user_id'])
                .maybeSingle(); // Changed to maybeSingle to handle missing profiles

            print('Profile response for ${json['user_id']}: $profileResponse');

            if (profileResponse != null && profileResponse['name'] != null) {
              creatorName = profileResponse['name'] as String;
              print('Creator name found: $creatorName');

              // Try to get avatar_url separately if it exists
              try {
                final avatarResponse = await _supabase
                    .from('profiles')
                    .select('avatar_url')
                    .eq('id', json['user_id'])
                    .maybeSingle();

                if (avatarResponse != null &&
                    avatarResponse['avatar_url'] != null) {
                  creatorAvatarUrl = avatarResponse['avatar_url'] as String;
                }
              } catch (avatarError) {
                print('Avatar URL fetch error: $avatarError');
                // Keep default avatar
              }
            } else {
              print('Profile not found for user ${json['user_id']}');
            }
          } catch (e) {
            print('Error fetching profile for user ${json['user_id']}: $e');
          }
        } else {
          print('Tutorial has null user_id');
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
          _isLoadingTutorials = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('Error loading tutorials: $e');
      if (mounted) {
        setState(() {
          _isLoadingTutorials = false;
          _allTutorials = widget.tutorials; // Fallback to passed tutorials
        });
        _applyFilters();
      }
    }
  }

  @override
  void didUpdateWidget(LearnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tutorials.length != oldWidget.tutorials.length) {
      _applyFilters();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final searchQuery = _searchController.text.toLowerCase();
    setState(() {
      _filteredTutorials = _allTutorials.where((tutorial) {
        final titleMatch = tutorial.title.toLowerCase().contains(searchQuery);
        final categoryMatch =
            _selectedCategory == 'All' ||
            tutorial.eWasteType == _selectedCategory;
        return titleMatch && categoryMatch;
      }).toList();
    });
  }

  void _showUploadTutorialBottomSheet(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'Lighting';
    XFile? selectedVideoXFile; // Changed to XFile for cross-platform support
    String? videoFileName;
    XFile? selectedThumbnailXFile; // Store XFile instead of File
    String? thumbnailFileName;

    final imagePicker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
                        'Upload Tutorial',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _saveTutorialWithVideo(
                          context,
                          titleController.text,
                          descriptionController.text,
                          selectedCategory,
                          selectedVideoXFile,
                          selectedThumbnailXFile,
                        );
                      },
                      child: const Text('Save'),
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
                      // Video selection
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedVideoXFile != null
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: selectedVideoXFile != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.video_file,
                                      size: 64,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Video Selected',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      videoFileName ?? 'video.mp4',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.video_call,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No Video Selected',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final XFile? video = await imagePicker.pickVideo(
                              source: ImageSource.gallery,
                              maxDuration: const Duration(minutes: 15),
                            );
                            if (video != null) {
                              setModalState(() {
                                selectedVideoXFile = video;
                                videoFileName = video.name;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick video: $e'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.video_library),
                        label: Text(
                          selectedVideoXFile != null
                              ? 'Change Video'
                              : 'Select Video from Gallery',
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Optional thumbnail picker
                      const Text(
                        'Thumbnail Image (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (selectedThumbnailXFile != null)
                        Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FutureBuilder<Uint8List>(
                              future: selectedThumbnailXFile!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final XFile? image = await imagePicker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1920,
                              maxHeight: 1080,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              setModalState(() {
                                selectedThumbnailXFile = image;
                                thumbnailFileName = image.name;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick image: $e'),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          selectedThumbnailXFile != null
                              ? Icons.check_circle
                              : Icons.add_photo_alternate,
                          color: selectedThumbnailXFile != null
                              ? Colors.green
                              : null,
                        ),
                        label: Text(
                          selectedThumbnailXFile != null
                              ? 'Change Thumbnail'
                              : 'Add Thumbnail (Optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title field
                      const Text(
                        'Tutorial Title',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'Enter tutorial title...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Category selection
                      const Text(
                        'Category',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: ['Lighting', 'Clocks', 'Cables', 'Furnitures']
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedCategory = value!;
                          });
                        },
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
                          hintText: 'Describe your tutorial...',
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

  void _saveTutorialWithVideo(
    BuildContext context,
    String title,
    String description,
    String category,
    XFile? videoFile,
    XFile? thumbnailFile,
  ) async {
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Upload video to Supabase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoBytes = await videoFile.readAsBytes();
      final videoPath = '${user.id}/${timestamp}_${videoFile.name}';

      await supabase.storage
          .from('tutorial-videos')
          .uploadBinary(
            videoPath,
            videoBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final videoUrl = supabase.storage
          .from('tutorial-videos')
          .getPublicUrl(videoPath);

      // Upload thumbnail to Supabase Storage (if provided)
      String imageUrl;
      if (thumbnailFile != null) {
        final imageBytes = await thumbnailFile.readAsBytes();
        final imagePath = '${user.id}/${timestamp}_${thumbnailFile.name}';

        await supabase.storage
            .from('tutorial-images')
            .uploadBinary(
              imagePath,
              imageBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        imageUrl = supabase.storage
            .from('tutorial-images')
            .getPublicUrl(imagePath);
      } else {
        imageUrl = 'https://via.placeholder.com/400x300?text=Video+Tutorial';
      }

      // Insert tutorial into database
      final tutorialData = {
        'user_id': user.id,
        'title': title,
        'description': description,
        'e_waste_type': category,
        'video_url': videoUrl,
        'image_url': imageUrl,
        'like_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('tutorials').insert(tutorialData);

      // Get user profile name and avatar
      String userName = 'You';
      String avatarUrl = 'assets/images/avatar1.png';

      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('name, avatar_url')
            .eq('id', user.id)
            .single();

        userName = profileResponse['name'] as String? ?? 'You';
        // Check if avatar_url exists in response
        if (profileResponse.containsKey('avatar_url')) {
          avatarUrl =
              profileResponse['avatar_url'] as String? ??
              'assets/images/avatar1.png';
        }
      } catch (profileError) {
        print('Error fetching profile: $profileError');

        // Profile doesn't exist, create it
        try {
          // Get user email
          final userEmail = user.email ?? '';

          // Try to get name from user metadata
          final userMetadata = user.userMetadata;
          userName = userMetadata?['name'] as String? ?? 'User';

          print('Creating profile for user ${user.id} with name: $userName');

          // Insert profile into database
          await supabase.from('profiles').insert({
            'id': user.id,
            'name': userName,
            'email': userEmail,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          print('Profile created successfully');
        } catch (createError) {
          print('Error creating profile: $createError');
          // If still fails, try fetching just name as fallback
          try {
            final nameResponse = await supabase
                .from('profiles')
                .select('name')
                .eq('id', user.id)
                .single();

            userName = nameResponse['name'] as String? ?? 'You';
          } catch (nameError) {
            print('Error fetching profile name: $nameError');
            userName = 'You';
          }
        }
      }

      // Create new tutorial object
      final newTutorial = Tutorial(
        userId: user.id,
        title: title,
        eWasteType: category,
        creatorName: userName,
        creatorAvatarUrl: avatarUrl,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        description: description,
        likeCount: 0,
        comments: [],
      );

      // Close loading dialog if mounted
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Close the upload modal if mounted
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Add to parent (this will refresh the main list)
      widget.onAddTutorial(newTutorial);

      // Reload tutorials from database to show the new one
      await _loadAllTutorials();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tutorial "$title" uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if mounted
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload tutorial: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildTutorialImage(String imageUrl) {
    bool isNetworkImage = imageUrl.startsWith('http');
    bool isAssetImage = imageUrl.startsWith('assets/');
    bool isBlobUrl = imageUrl.startsWith('blob:');

    if (isNetworkImage || isBlobUrl) {
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
    } else if (isAssetImage) {
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
      // For local file paths (mobile/desktop)
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
        // Fallback for any errors
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.image, size: 40, color: Colors.grey),
          ),
        );
      }
    }
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String title,
    String categoryType,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
    int tutorialCount,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = categoryType;
          _selectedCategoryDisplay = title;
        });
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getTutorialCountByCategory(String category) {
    if (category == 'All') return _allTutorials.length;
    return _allTutorials
        .where((tutorial) => tutorial.eWasteType == category)
        .length;
  }

  Widget _buildFeaturedTutorialCard(BuildContext context, Tutorial tutorial) {
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TutorialDetailScreen(
                  tutorial: tutorial,
                  allPosts: widget.allPosts,
                  currentUserName: widget.currentUserName,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tutorial Image - Full width at top
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: _buildTutorialImage(tutorial.imageUrl),
                ),
              ),
              // Content section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category and Time row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tutorial.eWasteType,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${_formatTimeAgo(tutorial.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Tutorial Title
                    Text(
                      tutorial.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Description
                    Text(
                      tutorial.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Creator and Rating row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: _getAvatarColor(
                            tutorial.creatorName,
                          ),
                          child: Text(
                            tutorial.creatorName.isNotEmpty
                                ? tutorial.creatorName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tutorial.creatorName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Rating
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '4.8',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
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

          // Hero Section
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
                    'Turn E-Waste Into Art',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn to create amazing projects from electronic waste',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Scroll to tutorials section or trigger search
                    },
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
                      'Start Learning',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tutorials',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Indicator
          if (_selectedCategory != 'All')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Category: $_selectedCategoryDisplay',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = 'All';
                              _selectedCategoryDisplay = 'All';
                            });
                            _applyFilters();
                          },
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedCategory != 'All') const SizedBox(height: 16),

          // Popular Categories Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Popular Categories',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'See All',
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryCard(
                        context,
                        'Lighting',
                        'Lighting',
                        Icons.lightbulb_outline,
                        Colors.blue.shade100,
                        Colors.blue.shade600,
                        _getTutorialCountByCategory('Lighting'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCategoryCard(
                        context,
                        'Clocks',
                        'Clocks',
                        Icons.access_time,
                        Colors.purple.shade100,
                        Colors.purple.shade600,
                        _getTutorialCountByCategory('Clocks'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryCard(
                        context,
                        'Cables',
                        'Cables',
                        Icons.cable,
                        Colors.pink.shade100,
                        Colors.pink.shade600,
                        _getTutorialCountByCategory('Cables'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCategoryCard(
                        context,
                        'Furniture',
                        'Furnitures',
                        Icons.chair_outlined,
                        Colors.orange.shade100,
                        Colors.orange.shade600,
                        _getTutorialCountByCategory('Furnitures'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Upload Tutorials Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.upload_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share Your Tutorial',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Help others learn by sharing your e-waste projects',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.blue.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showUploadTutorialBottomSheet(context);
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Upload Tutorial'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Featured Tutorials Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Featured Tutorials',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'See All',
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoadingTutorials)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filteredTutorials.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text(
                        'No tutorials found. Be the first to upload!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredTutorials.take(5).length,
                    itemBuilder: (context, index) {
                      final tutorial = _filteredTutorials[index];
                      return _buildFeaturedTutorialCard(context, tutorial);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    // Generate consistent color based on name
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.pink.shade600,
    ];

    // Use hashCode to get consistent color for same name
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '--';

    final now = DateTime.now().toUtc();
    final created = dateTime.toUtc();
    final diff = now.difference(created);

    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds} seconds ago';

    if (diff.inMinutes < 2) return '1 minute ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';

    if (diff.inHours < 2) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';

    if (diff.inDays < 2) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    final weeks = (diff.inDays / 7).floor();
    if (weeks < 2) return '1 week ago';
    if (weeks < 52) return '$weeks weeks ago';

    final years = (diff.inDays / 365).floor();
    if (years < 2) return '1 year ago';
    return '$years years ago';
  }
}
