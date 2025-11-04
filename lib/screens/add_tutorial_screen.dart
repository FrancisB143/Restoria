import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/tutorial_model.dart';

class AddTutorialScreen extends StatefulWidget {
  final String currentUserName;

  const AddTutorialScreen({super.key, required this.currentUserName});

  @override
  State<AddTutorialScreen> createState() => _AddTutorialScreenState();
}

class _AddTutorialScreenState extends State<AddTutorialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  final List<String> _categories = [
    'Electronics',
    'Appliances',
    'Batteries',
    'Cables',
    'Lighting',
    'Clocks',
    'Furnitures',
    'Other',
  ];
  String? _selectedCategory;
  File? _selectedVideo;
  File? _selectedThumbnail; // Changed from _selectedImage to be clearer
  bool _isUploading = false;
  String? _videoFileName;
  String? _thumbnailFileName;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedThumbnail = File(image.path);
          _thumbnailFileName = image.name;
        });
      }
    } catch (e) {
      _showError('Failed to pick thumbnail: $e');
    }
  }

  Future<void> _pickAdditionalVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2), // Limit to 2 minutes
      );

      if (video != null) {
        final file = File(video.path);
        
        // Check file size (limit to 50MB)
        final fileSize = await file.length();
        const maxSizeInBytes = 50 * 1024 * 1024; // 50MB in bytes
        
        if (fileSize > maxSizeInBytes) {
          _showError('Video file size must be less than 50MB. Your video is ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB');
          return;
        }
        
        // Check video duration using video_player
        // Note: For more accurate duration check, you'd need video_player package
        // For now, we'll rely on the picker's maxDuration parameter
        
        setState(() {
          _selectedVideo = file;
          _videoFileName = video.name;
        });
        _showSuccess('Video selected successfully! (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB)');
      }
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
  }

  Future<String?> _uploadFile(File file, String bucket, String fileName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        return null;
      }

      // Create unique file path: {user_id}/{timestamp}_{filename}
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${user.id}/${timestamp}_$fileName';

      // Upload file to Supabase Storage
      await _supabase.storage
          .from(bucket)
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      _showError('Failed to upload file: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVideo == null) {
      _showError('Please select a tutorial video');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      // Upload video
      final videoUrl = await _uploadFile(
        _selectedVideo!,
        'tutorial-videos',
        _videoFileName ?? 'video.mp4',
      );

      if (videoUrl == null) return;

      // Upload thumbnail image (optional)
      String? imageUrl;
      if (_selectedThumbnail != null) {
        imageUrl = await _uploadFile(
          _selectedThumbnail!,
          'tutorial-images',
          _thumbnailFileName ?? 'thumbnail.jpg',
        );
      } else {
        // Use a default placeholder if no thumbnail provided
        imageUrl = 'https://via.placeholder.com/400x300?text=Video+Tutorial';
      }

      // Insert tutorial into database
      final tutorialData = {
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'e_waste_type': _selectedCategory!,
        'video_url': videoUrl,
        'image_url': imageUrl,
        'like_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('tutorials')
          .insert(tutorialData)
          .select()
          .single();

      if (!mounted) return;

      // Create Tutorial object from response
      final newTutorial = Tutorial(
        id: response['id'] as String,
        userId: user.id,
        title: _titleController.text.trim(),
        creatorName: widget.currentUserName,
        creatorAvatarUrl:
            'https://i.pravatar.cc/150?u=${widget.currentUserName.hashCode}',
        eWasteType: _selectedCategory!,
        videoUrl: videoUrl,
        imageUrl:
            imageUrl!, // Always has a value (either uploaded or placeholder)
        description: _descriptionController.text.trim(),
        likeCount: 0,
        comments: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _showSuccess('Tutorial uploaded successfully!');
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      Navigator.of(context).pop(newTutorial);
    } catch (e) {
      _showError('Failed to create tutorial: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Tutorial'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading tutorial...'),
                  Text('This may take a moment'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tutorial Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      hint: const Text('Select E-Waste Category'),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your tutorial step by step...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Video picker - Primary media
                    const Text(
                      'Tutorial Video (Required)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedVideo != null
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pickAdditionalVideo,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Icon(
                                  _selectedVideo != null
                                      ? Icons.video_file
                                      : Icons.video_call,
                                  size: 48,
                                  color: _selectedVideo != null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedVideo != null
                                      ? 'Video Selected'
                                      : 'Tap to Select Video from Gallery',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedVideo != null
                                        ? Colors.green
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                if (_selectedVideo != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _videoFileName ?? 'video.mp4',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 32,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Thumbnail picker - Optional
                    const Text(
                      'Thumbnail Image (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickThumbnail,
                      icon: Icon(
                        _selectedThumbnail != null
                            ? Icons.check_circle
                            : Icons.add_photo_alternate,
                        color: _selectedThumbnail != null ? Colors.green : null,
                      ),
                      label: Text(
                        _selectedThumbnail != null
                            ? 'Thumbnail: $_thumbnailFileName'
                            : 'Add Thumbnail (Optional)',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: _selectedThumbnail != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ),
                    if (_selectedThumbnail != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedThumbnail!,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    if (_selectedThumbnail == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'A default thumbnail will be used if not provided',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _submitForm,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload Tutorial'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Note: Large videos may take several minutes to upload',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your video will appear in the featured tutorials section',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
