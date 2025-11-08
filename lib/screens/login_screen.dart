import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // Don't auto-login on init - user should manually login
    // _checkCurrentSession(); // Commented out to prevent auto-login

    // Listen for OAuth callbacks - but only handle them if we initiated the login
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      print('Auth state changed: $event');

      // Only handle signedIn events if we're still mounted and on the login screen
      // This prevents interfering with the registration flow
      if (event == AuthChangeEvent.signedIn && mounted && _isLoading) {
        print('User signed in during login attempt, handling auth success...');
        _handleAuthSuccess();
      } else if (event == AuthChangeEvent.signedIn) {
        print('User signed in but not from this login screen, ignoring...');
      }
    });
  }

  Future<void> _checkCurrentSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null && mounted) {
        print('Found existing session, navigating...');
        _handleAuthSuccess();
      }
    } catch (e) {
      print('Error checking session: $e');
    }
  }

  Future<void> _handleAuthSuccess() async {
    print('handleAuthSuccess called');
    final user = _supabase.auth.currentUser;
    print('Current user: ${user?.id}');

    if (user != null && mounted) {
      setState(() => _isLoading = false);

      // Check if profile exists
      try {
        print('Checking if profile exists for user: ${user.id}');
        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        print('Profile data: $profileData');

        if (!mounted) return;

        if (profileData == null) {
          // No profile exists, navigate to profile setup
          print('No profile found, navigating to profile setup');
          Navigator.pushReplacementNamed(context, '/profile-setup');
        } else {
          // Profile exists, navigate to main
          print('Profile exists, navigating to main screen');
          Navigator.pushReplacementNamed(context, '/main');
        }
      } catch (e) {
        print('Error checking profile: $e');
        if (mounted) {
          _showError('Error checking profile: $e');
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.user != null) {
        // Check if profile exists
        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (!mounted) return;

        if (profileData == null) {
          // No profile exists, navigate to profile setup
          Navigator.pushReplacementNamed(context, '/profile-setup');
        } else {
          // Profile exists, login successful, navigate to main screen
          Navigator.pushReplacementNamed(context, '/main');
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('An unexpected error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 375; // iPhone SE width

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A), Color(0xFF81C784)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // Top Section with Logo and Branding
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16.0 : 32.0,
                        vertical: isSmallScreen ? 8.0 : 16.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: isSmallScreen ? 8 : 16),
                          // Logo Container
                          Container(
                            width: isSmallScreen ? 64 : 100,
                            height: isSmallScreen ? 64 : 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                isSmallScreen ? 16 : 24,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  spreadRadius: 0,
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(
                                isSmallScreen ? 8.0 : 16.0,
                              ),
                              child: Image.asset(
                                'assets/images/ourLogo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 18),
                          // App Name
                          Text(
                            'Restoria',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: isSmallScreen ? 20 : 26,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 2 : 6),
                          Text(
                            'Sustainable Innovation Hub',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w300,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 14),
                        ],
                      ),
                    ),

                    // Bottom Section with Login Options - Extended to bottom
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12.0 : 24.0,
                          vertical: isSmallScreen ? 10.0 : 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: isSmallScreen ? 6 : 10),
                            // Welcome Text
                            Text(
                              'Welcome Back!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                fontSize: isSmallScreen ? 16 : 20,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 2 : 4),
                            Text(
                              'Sign in to continue your sustainable journey',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                height: 1.3,
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),

                            // Email Field
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 10 : 14,
                                  horizontal: 12,
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 10 : 14),

                            // Password Field
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 10 : 14,
                                  horizontal: 12,
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),

                            // Login Button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 12 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14 : 16,
                                      ),
                                    ),
                            ),

                            SizedBox(height: isSmallScreen ? 14 : 20),

                            // Register Button
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: Text(
                                'Don\'t have an account? Register',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF4CAF50),
                                  fontSize: isSmallScreen ? 13 : 15,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 10 : 14),

                            // Footer Text
                            Text(
                              'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                                height: 1.3,
                                fontSize: isSmallScreen ? 10 : 12,
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 12 : 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
