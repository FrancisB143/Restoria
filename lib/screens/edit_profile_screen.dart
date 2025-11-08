// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String? currentAvatarUrl;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    this.currentAvatarUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  File? _imageFile;
  Uint8List? _webImage;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
    _bioController.text = widget.currentBio;
    _avatarUrl = widget.currentAvatarUrl;

    // Listen for changes
    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _hasChanges = true;
          });
        } else {
          setState(() {
            _imageFile = File(image.path);
            _hasChanges = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadAvatar() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No user authenticated');
        return null;
      }

      debugPrint('Starting avatar upload for user: ${user.id}');

      final fileExt = 'jpg';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_avatar.$fileExt';
      // IMPORTANT: Path must be {user_id}/filename for RLS policies to work
      final filePath = '${user.id}/$fileName';

      debugPrint('Upload path: $filePath');
      debugPrint('Attempting direct upload to profile-avatars bucket...');

      if (kIsWeb && _webImage != null) {
        // Upload for web
        debugPrint('Uploading for web, size: ${_webImage!.length} bytes');
        await _supabase.storage
            .from('profile-avatars')
            .uploadBinary(
              filePath,
              _webImage!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        debugPrint('Web upload successful');
      } else if (_imageFile != null) {
        // Upload for mobile
        debugPrint('Uploading for mobile from: ${_imageFile!.path}');
        await _supabase.storage
            .from('profile-avatars')
            .upload(
              filePath,
              _imageFile!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        debugPrint('Mobile upload successful');
      } else {
        debugPrint('No image file to upload');
        return null;
      }

      // Get public URL
      final publicUrl = _supabase.storage
          .from('profile-avatars')
          .getPublicUrl(filePath);

      debugPrint('Avatar uploaded successfully. Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      debugPrint('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String? newAvatarUrl = _avatarUrl;

      // Upload new avatar if selected
      if (_imageFile != null || _webImage != null) {
        try {
          newAvatarUrl = await _uploadAvatar();
        } catch (storageError) {
          debugPrint('Storage error: $storageError');

          // Show specific error for storage issues
          if (mounted) {
            String errorMessage;
            String errorDetails = storageError.toString();

            if (errorDetails.contains('not configured')) {
              errorMessage =
                  'Avatar upload is not available yet. Please set up storage bucket first.\n\nYour name and bio will still be saved.';
            } else if (errorDetails.contains('permission') ||
                errorDetails.contains('policy') ||
                errorDetails.contains('authorized')) {
              errorMessage =
                  'Permission denied: Please check storage bucket policies.\n\nError: $errorDetails\n\nYour name and bio will still be saved.';
            } else if (errorDetails.contains('bucket')) {
              errorMessage =
                  'Storage bucket error: $errorDetails\n\nYour name and bio will still be saved.';
            } else {
              errorMessage =
                  'Failed to upload avatar.\n\nError: $errorDetails\n\nYour name and bio will still be saved.';
            }

            final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Upload Issue'),
                content: Text(errorMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Continue Anyway'),
                  ),
                ],
              ),
            );

            if (shouldContinue != true) {
              setState(() => _isLoading = false);
              return;
            }
          }
          // Keep the old avatar URL if upload failed
          newAvatarUrl = _avatarUrl;
        }
      }

      // Update profile in database
      final updateData = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Always update avatar_url if we have a new one
      if (newAvatarUrl != null) {
        updateData['avatar_url'] = newAvatarUrl;
      }

      debugPrint('Updating profile with data: $updateData');
      await _supabase.from('profiles').update(updateData).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Return updated data - always include avatar_url even if unchanged
        Navigator.pop(context, {
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'avatar_url': newAvatarUrl ?? _avatarUrl,
        });
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        String errorMessage = 'Error updating profile: ';

        if (e.toString().contains('column') && e.toString().contains('bio')) {
          errorMessage +=
              'Bio field not found in database. Please run the database setup.';
        } else {
          errorMessage += e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAvatarSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 64,
              backgroundColor: colorScheme.primary.withOpacity(0.2),
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _getAvatarImage(),
                child: _getAvatarImage() == null
                    ? Icon(Icons.person, size: 60, color: colorScheme.primary)
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: _isLoading ? null : _pickImage,
                  iconSize: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isLoading ? null : _pickImage,
          icon: const Icon(Icons.photo_library, size: 18),
          label: const Text('Change Profile Picture'),
        ),
      ],
    );
  }

  ImageProvider? _getAvatarImage() {
    if (_webImage != null) {
      return MemoryImage(_webImage!);
    } else if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('assets/')) {
        return AssetImage(_avatarUrl!);
      } else {
        return NetworkImage(_avatarUrl!);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_hasChanges) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Discard Changes?'),
                  content: const Text(
                    'You have unsaved changes. Are you sure you want to discard them?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close edit screen
                      },
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAvatarSection(),
                const SizedBox(height: 32),
                Text(
                  'Name',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(
                      0.3,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 24),
                Text(
                  'Bio',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  enabled: !_isLoading,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'Tell us about yourself...',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 60),
                      child: Icon(Icons.info_outline),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(
                      0.3,
                    ),
                    counterText: '${_bioController.text.length}/200',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bio is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Bio must be at least 10 characters';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading || !_hasChanges ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
