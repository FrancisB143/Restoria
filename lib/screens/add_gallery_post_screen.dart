// lib/screens/add_gallery_post_screen.dart

import 'dart:io'; // Add this line back
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  XFile? _selectedImageXFile;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedImage == null) return;
    setState(() {
      _selectedImageXFile = pickedImage;
    });
  }

  void _submitForm() {
    if (_selectedImageXFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of your creation.')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final newPost = GalleryPost(
        userName: widget.userName,
        description: _descriptionController.text,
        imageUrl: _selectedImageXFile!.path,
        likeCount: 0,
      );
      Navigator.of(context).pop(newPost);
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
                            Text('Tap to add a photo'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
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
                onPressed: _submitForm,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share to Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
