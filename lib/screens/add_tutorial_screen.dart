import 'package:flutter/material.dart';
import '../models/tutorial_model.dart';

class AddTutorialScreen extends StatefulWidget {
  // 1. Add this to accept the user's name
  final String currentUserName;

  // 2. Update the constructor to require it
  const AddTutorialScreen({super.key, required this.currentUserName});

  @override
  State<AddTutorialScreen> createState() => _AddTutorialScreenState();
}

class _AddTutorialScreenState extends State<AddTutorialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  // 3. The manual creator name controller is no longer needed
  // final _creatorNameController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _categories = [
    'Electronics',
    'Appliances',
    'Batteries',
    'Cables',
    'Other',
  ];
  String? _selectedCategory;

  @override
  void dispose() {
    _titleController.dispose();
    // No need to dispose the creator controller anymore
    _videoUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final newTutorial = Tutorial(
        title: _titleController.text,
        // 4. Use the name passed into the widget
        creatorName: widget.currentUserName,
        creatorAvatarUrl:
            'https://i.pravatar.cc/150?u=${widget.currentUserName.hashCode}',
        eWasteType: _selectedCategory!,
        // NOTE: For simplicity, this still assumes the video URL is a valid asset path.
        // If you input a youtube link here, it will not play in the detail screen
        // without a package like `Youtubeer_flutter`.
        videoUrl: _videoUrlController.text,
        description: _descriptionController.text,
        imageUrl: 'assets/images/placeholder.png',
        likeCount: 0,
        comments: [],
      );
      Navigator.of(context).pop(newTutorial);
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tutorial Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // 5. The TextFormField for creator's name is removed
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                hint: const Text('Select a Category'),
                decoration: const InputDecoration(labelText: 'Category'),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _videoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Video Asset Path (e.g., assets/videos/video.mp4)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a video asset path';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Tutorial'),
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
