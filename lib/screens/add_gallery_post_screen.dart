// lib/screens/add_gallery_post_screen.dart

import 'dart:io'; // Add this line back
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';

class AddGalleryPostScreen extends StatefulWidget {
  final String userName;
  const AddGalleryPostScreen({super.key, required this.userName});

  @override
  State<AddGalleryPostScreen> createState() => _AddGalleryPostScreenState();
}

class _AddGalleryPostScreenState extends State<AddGalleryPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _supabase = Supabase.instance.client;

  XFile? _selectedImageXFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (pickedImage == null) return;
    setState(() {
      _selectedImageXFile = pickedImage;
    });
  }

  Future<void> _submitForm() async {
    if (_selectedImageXFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of your creation.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Upload image to Supabase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageBytes = await _selectedImageXFile!.readAsBytes();
      final imagePath = '${user.id}/${timestamp}_${_selectedImageXFile!.name}';

      debugPrint('Attempting to upload image to: $imagePath');
      debugPrint('Image size: ${imageBytes.length} bytes');

      try {
        await _supabase.storage
            .from('gallery-images')
            .uploadBinary(
              imagePath,
              imageBytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/*',
              ),
            );

        debugPrint('Image uploaded successfully');
      } catch (storageError) {
        debugPrint('Storage upload error: $storageError');
        throw Exception('Failed to upload image: $storageError');
      }

      final imageUrl = _supabase.storage
          .from('gallery-images')
          .getPublicUrl(imagePath);

      debugPrint('Image URL: $imageUrl');

      // Get user profile name
      String userName = widget.userName;
      String avatarUrl = 'assets/images/avatar1.png';

      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select('name, avatar_url')
            .eq('id', user.id)
            .single();

        userName = profileResponse['name'] as String? ?? widget.userName;
        if (profileResponse.containsKey('avatar_url')) {
          avatarUrl =
              profileResponse['avatar_url'] as String? ??
              'assets/images/avatar1.png';
        }
      } catch (profileError) {
        print('Error fetching profile: $profileError');

        // Profile doesn't exist, create it
        try {
          final userEmail = user.email ?? '';
          final userMetadata = user.userMetadata;
          userName = userMetadata?['name'] as String? ?? widget.userName;

          print('Creating profile for user ${user.id} with name: $userName');

          await _supabase.from('profiles').insert({
            'id': user.id,
            'name': userName,
            'email': userEmail,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          print('Profile created successfully');
        } catch (createError) {
          print('Error creating profile: $createError');
          userName = widget.userName;
        }
      }

      // Insert gallery post into database
      final postData = {
        'user_id': user.id,
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'like_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('gallery_posts').insert(postData);

      // Create new gallery post object
      final newPost = GalleryPost(
        userId: user.id,
        userName: userName,
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        likeCount: 0,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now(),
      );

      // Close loading dialog
      Navigator.pop(context);

      // Return to previous screen with new post
      Navigator.of(context).pop(newPost);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post shared successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      debugPrint('Error creating post: $e');

      String errorMessage = 'Failed to share post';

      if (e.toString().contains('StorageException') ||
          e.toString().contains('storage') ||
          e.toString().contains('bucket')) {
        errorMessage =
            'Storage error: Please ensure the gallery-images bucket exists in Supabase Storage with public access enabled.';
      } else if (e.toString().contains('authenticated')) {
        errorMessage = 'Authentication error: Please log in again.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error: Please check your internet connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Error Details'),
                  content: SingleChildScrollView(child: Text(e.toString())),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _selectedImageXFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(
                                  _selectedImageXFile!.path,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_selectedImageXFile!.path),
                                  fit: BoxFit.cover,
                                ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 50,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add Image',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedImageXFile != null)
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.edit),
                  label: const Text('Change Image'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Image'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description or Caption',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a short description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _submitForm,
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
