import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_post_model.dart';
import '../models/tutorial_model.dart';
import 'gallery_screen.dart';
import 'learn_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final List<Tutorial> tutorials;
  final List<GalleryPost> galleryPosts;
  final String currentUserName;
  final Future<void> Function() onAddTutorial;
  final Future<void> Function() onAddGalleryPost;

  const MainScreen({
    super.key,
    required this.tutorials,
    required this.galleryPosts,
    required this.currentUserName,
    required this.onAddTutorial,
    required this.onAddGalleryPost,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;
  String? _userProfileName;

  void _addTutorialDirectly(Tutorial tutorial) {
    // Add tutorial to local state immediately for instant UI update
    setState(() {
      widget.tutorials.insert(0, tutorial);
    });
  }

  void _addGalleryPostDirectly(GalleryPost post) {
    // Add gallery post to local state immediately for instant UI update
    setState(() {
      widget.galleryPosts.insert(0, post);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  List<Widget> _buildPages() {
    return [
      LearnScreen(
        tutorials: widget.tutorials,
        allPosts: widget.galleryPosts,
        onAdd: widget.onAddTutorial,
        onAddTutorial: _addTutorialDirectly,
        currentUserName: _userProfileName ?? widget.currentUserName,
      ),
      GalleryScreen(
        posts: widget.galleryPosts,
        onAdd: widget.onAddGalleryPost,
        onAddPost: _addGalleryPostDirectly,
        currentUserName: _userProfileName ?? widget.currentUserName,
      ),
      const MessagesScreen(),
      ProfileScreen(
        userName: _userProfileName ?? widget.currentUserName,
        allPosts: widget.galleryPosts,
      ),
    ];
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profileData = await _supabase
            .from('profiles')
            .select('name')
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            _userProfileName = profileData['name'] as String;
          });
        }
      }
    } catch (e) {
      // If profile fetch fails, use the default name
      print('Error loading profile: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            activeIcon: Icon(Icons.video_library),
            label: 'Tutorials',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined),
            activeIcon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
