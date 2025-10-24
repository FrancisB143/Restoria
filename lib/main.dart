import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/tutorial_model.dart';
import 'models/gallery_post_model.dart';
import 'screens/main_screen.dart';
import 'screens/add_tutorial_screen.dart';
import 'screens/add_gallery_post_screen.dart';
import 'screens/login_screen.dart'; // Import the login screen
import 'screens/onboarding_screen.dart'; // Import the onboarding screen
import 'screens/register_screen.dart'; // Import the register screen
import 'screens/profile_setup_screen.dart'; // Import the profile setup screen
import 'config/supabase_config.dart'; // Import Supabase config

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with auth callback handling
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final String _currentUserName = 'Juana Dela Cruz';
  final _supabase = Supabase.instance.client;
  List<Tutorial> _tutorials = [];
  bool _isLoadingTutorials = true;

  @override
  void initState() {
    super.initState();
    _loadTutorials();
    _ensureUserProfileExists();
  }

  Future<void> _ensureUserProfileExists() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Check if profile exists
      final profileResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse == null) {
        // Profile doesn't exist, create it
        print('Profile not found for user ${user.id}, creating one...');

        final userEmail = user.email ?? '';
        final userMetadata = user.userMetadata;
        final userName = userMetadata?['name'] as String? ?? 'User';

        await _supabase.from('profiles').insert({
          'id': user.id,
          'name': userName,
          'email': userEmail,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        print('Profile created successfully for $userName');

        // Reload tutorials to show updated names
        _loadTutorials();
      }
    } catch (e) {
      print('Error ensuring user profile exists: $e');
    }
  }

  Future<void> _loadTutorials() async {
    try {
      final response = await _supabase
          .from('tutorials')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        List<Tutorial> loadedTutorials = [];

        for (var json in response as List) {
          // Fetch profile data separately for each tutorial
          String creatorName = 'Unknown User';
          String creatorAvatarUrl = 'assets/images/avatar1.png';

          print(
            'Loading tutorial: ${json['title']} by user_id: ${json['user_id']}',
          );

          try {
            final profileResponse = await _supabase
                .from('profiles')
                .select('name, avatar_url')
                .eq('id', json['user_id'])
                .maybeSingle();

            print('Profile response for ${json['user_id']}: $profileResponse');

            if (profileResponse != null) {
              creatorName =
                  profileResponse['name'] as String? ?? 'Unknown User';
              print('Creator name found: $creatorName');
              // Check if avatar_url exists in response
              if (profileResponse.containsKey('avatar_url')) {
                creatorAvatarUrl =
                    profileResponse['avatar_url'] as String? ??
                    'assets/images/avatar1.png';
                print('Avatar URL found: $creatorAvatarUrl');
              }
            } else {
              print('No profile found for user_id: ${json['user_id']}');
            }
          } catch (profileError) {
            print(
              'Error fetching profile for tutorial ${json['id']}: $profileError',
            );
            // Try fetching just name if avatar_url doesn't exist
            try {
              final nameOnlyResponse = await _supabase
                  .from('profiles')
                  .select('name')
                  .eq('id', json['user_id'])
                  .maybeSingle();

              if (nameOnlyResponse != null) {
                creatorName =
                    nameOnlyResponse['name'] as String? ?? 'Unknown User';
                print('Creator name found (name only): $creatorName');
              }
            } catch (nameError) {
              print(
                'Error fetching name for tutorial ${json['id']}: $nameError',
              );
            }
          }

          loadedTutorials.add(
            Tutorial.fromJson({
              ...json,
              'creator_name': creatorName,
              'creator_avatar_url': creatorAvatarUrl,
            }),
          );
        }

        setState(() {
          _tutorials = loadedTutorials;
          _isLoadingTutorials = false;
        });
      }
    } catch (e) {
      print('Error loading tutorials: $e');
      if (mounted) {
        setState(() {
          _isLoadingTutorials = false;
          // Only use sample tutorials if no tutorials exist in database
          _tutorials = [];
        });
      }
    }
  }

  List<Tutorial> _getSampleTutorials() {
    return [
      Tutorial(
        title: 'Plastic Bottle Flashlight',
        eWasteType: 'Lighting',
        creatorName: 'Admin',
        creatorAvatarUrl: 'https://i.pravatar.cc/150?u=admin',
        imageUrl: 'assets/images/flashlight.png',
        videoUrl: 'assets/videos/flashlight_plastic.mp4',
        description:
            'Learn how to safely cut up old motherboards and set them in clear resin to create stunning, geek-chic coasters for your home or office. This project is great for beginners.',
        likeCount: 134,
        comments: [
          Comment(
            userName: 'Pedro P.',
            avatarAsset: 'assets/images/avatar1.png',
            text: 'This looks amazing! I have to try this.',
            likeCount: 12,
            timestamp: '1w ago', // FIXED: Added timestamp
            replies: [
              Comment(
                userName: 'Maria K.',
                avatarAsset: 'assets/images/avatar2.png',
                text: 'I agree!',
                likeCount: 3,
                timestamp: '1w ago', // FIXED: Added timestamp
              ),
            ],
          ),
          Comment(
            userName: 'Maria K.',
            avatarAsset: 'assets/images/avatar2.png',
            text: 'Great tutorial, very clear instructions.',
            likeCount: 8,
            timestamp: '2w ago', // FIXED: Added timestamp
          ),
        ],
      ),
      Tutorial(
        title: 'Wire Organizer',
        eWasteType: 'Cables',
        creatorName: 'Juana Dela Cruz',
        creatorAvatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
        imageUrl: 'assets/images/carton_wire_organizer.jpg',
        videoUrl: 'assets/videos/wire_organizer.mp4',
        description:
            'DIY wire organizer made from carton – simple, cheap, and keeps my cables tangle-free!',
        likeCount: 78,
        comments: [],
      ),
      Tutorial(
        title: 'Disposable Cup Lamp',
        creatorName: "Maria K.",
        creatorAvatarUrl: 'https://i.pravatar.cc/150?u=maria',
        eWasteType: 'Lighting',
        imageUrl: 'assets/images/lamp.png',
        videoUrl: 'assets/videos/lamp_papercup.mp4',
        description:
            'Create a beautiful ambient lamp using disposable cups and a simple battery circuit.',
        likeCount: 201,
        comments: [],
      ),
      Tutorial(
        title: 'Hard Disk Clock',
        creatorName: "Tech Maker",
        creatorAvatarUrl: 'https://i.pravatar.cc/150?u=techmaker',
        eWasteType: 'Clocks',
        imageUrl: 'assets/images/harddisk_clock.png',
        videoUrl: 'assets/videos/harddisk_clock.mp4',
        description:
            'Give your old hard disk a second life as a unique wall clock! Instead of letting e-waste pile up, transform it into a functional piece of art that’s both eco-friendly and eye-catching. Every tick reminds you that recycling can be stylish and sustainable!',
        likeCount: 78,
        comments: [],
      ),
      Tutorial(
        title: 'Moon and Star Hanging CD',
        creatorName: "Admin",
        creatorAvatarUrl: 'https://i.pravatar.cc/150?u=admin',
        eWasteType: 'Furnitures',
        imageUrl: 'assets/images/hanging_cd.png',
        videoUrl: 'assets/videos/hanging_cd.mp4',
        description:
            'Turn your old CDs into a dreamy Moon and Star hanging decor! 🌙⭐ With just a little creativity, you can upcycle waste into something magical that brightens up your space. Easy to make, eco-friendly, and perfect for adding sparkle to your room—why throw away when you can create?',
        likeCount: 155,
        comments: [],
      ),
      Tutorial(
        title: 'Toaster Bookends',
        creatorName: "Pedro P.",
        creatorAvatarUrl: 'https://i.pravatar.cc/150?u=pedro',
        eWasteType: 'Furnitures',
        imageUrl: 'assets/images/toaster_bookends.jpg',
        videoUrl: 'assets/videos/lamp_papercup.mp4',
        description:
            'Give an old toaster a new purpose as a quirky set of bookends for your shelf.',
        likeCount: 92,
        comments: [],
      ),
    ];
  }

  final List<GalleryPost> _galleryPosts = [
    GalleryPost(
      userName: 'Juana Dela Cruz',
      imageUrl: 'assets/images/project1.jpg',
      likeCount: 28,
      description: 'My new circuit board coasters came out great!',
    ),
    GalleryPost(
      userName: 'Juana Dela Cruz',
      imageUrl: 'assets/images/project2.jpg',
      likeCount: 45,
      description: 'Upcycled some old CDs into this beautiful wall art.',
    ),
    GalleryPost(
      userName: 'Juana Dela Cruz',
      imageUrl: 'assets/images/project3.jpg',
      likeCount: 18,
      description: 'Gave this old phone a new life as a mini planter.',
    ),
    GalleryPost(
      userName: 'Pedro P.',
      imageUrl: 'assets/images/project1.jpg',
      likeCount: 32,
      description: 'Turned a broken hard drive into a working clock!',
    ),
    GalleryPost(
      userName: 'Maria K.',
      imageUrl: 'assets/images/project4.jpg',
      likeCount: 51,
      description: 'My latest creation from old computer fans!',
    ),
  ];

  void _addTutorial(Tutorial tutorial) {
    setState(() {
      _tutorials.insert(0, tutorial);
    });
  }

  Future<void> _refreshTutorials() async {
    await _loadTutorials();
  }

  void _addGalleryPost(GalleryPost post) {
    setState(() {
      _galleryPosts.insert(0, post);
    });
  }

  Future<void> _navigateAndAddTutorial(BuildContext context) async {
    final result = await Navigator.push<Tutorial>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTutorialScreen(currentUserName: _currentUserName),
      ),
    );
    if (result != null) {
      _addTutorial(result);
    }
  }

  Future<void> _navigateAndAddGalleryPost(BuildContext context) async {
    final result = await Navigator.push<GalleryPost>(
      context,
      MaterialPageRoute(
        builder: (context) => AddGalleryPostScreen(userName: _currentUserName),
      ),
    );
    if (result != null) {
      _addGalleryPost(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restoria Creations',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const OnboardingScreen(), // Updated: Start with OnboardingScreen
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/main': (context) => MainScreen(
          tutorials: _tutorials,
          galleryPosts: _galleryPosts,
          currentUserName: _currentUserName,
          onAddTutorial: () => _navigateAndAddTutorial(context),
          onAddGalleryPost: () => _navigateAndAddGalleryPost(context),
        ),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile-setup': (context) => const ProfileSetupScreen(),
      },
    );
  }
}
