import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Validate inputs
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError('Please enter a password');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sign up the user without email confirmation
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'name': _nameController.text.trim()},
        emailRedirectTo: null, // Disable email confirmation redirect
      );

      if (!mounted) return;

      if (response.user != null) {
        print('User created: ${response.user!.id}');

        // Check if profile already exists first
        try {
          final existingProfile = await _supabase
              .from('profiles')
              .select('id')
              .eq('id', response.user!.id)
              .maybeSingle();

          if (existingProfile != null) {
            print('Profile already exists for this user');
            // Profile already exists, just sign out and redirect to login
            await _supabase.auth.signOut();

            // Wait for sign out to complete
            await Future.delayed(const Duration(milliseconds: 500));

            if (!mounted) return;
            _showSuccess('Account already exists. Please login to continue.');

            // Wait for message to show
            await Future.delayed(const Duration(seconds: 2));

            if (!mounted) return;

            // Use Navigator.pushNamedAndRemoveUntil to clear the entire stack
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false, // Remove all previous routes
            );
            return;
          }
        } catch (e) {
          print('Error checking existing profile: $e');
        }

        // Create profile in database immediately with empty bio
        try {
          await _supabase.from('profiles').insert({
            'id': response.user!.id,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'bio': '', // Empty bio - user will fill it later
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          print('Profile created successfully with empty bio');

          if (!mounted) return;

          // Sign out the user so they need to login
          await _supabase.auth.signOut();

          // Add a small delay to ensure sign-out completes
          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) return;

          // Registration successful - navigate to login screen
          _showSuccess('Registration successful! Please login to continue.');

          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;

          // Use Navigator.pushNamedAndRemoveUntil to clear the entire stack
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false, // Remove all previous routes
          );
        } catch (profileError) {
          print('Error creating profile: $profileError');

          // Profile creation failed - delete the auth user and show error
          try {
            await _supabase.auth.signOut();
          } catch (e) {
            print('Error signing out: $e');
          }

          if (!mounted) return;
          _showError(
            'Profile creation failed. Please try again with a different email.',
          );
          return; // Stop here
        }
      } else {
        _showError('Registration failed. Please try again.');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 375; // iPhone SE width

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 20.0 : 28.0,
          vertical: isSmallScreen ? 16.0 : 20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: isSmallScreen ? 8 : 12),
            // Name Field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 14 : 16),
            // Email Field
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 14 : 16),

            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 14 : 16),

            // Confirm Password Field
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),

            // Register Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 14 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _handleRegister,
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
                      'Register',
                      style: TextStyle(fontSize: isSmallScreen ? 15 : 16),
                    ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),

            // Already have an account? Sign in
            GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text(
                'Already have an account? Sign in',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: isSmallScreen ? 13 : 15,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Spacer(),

            // Footer Text
            Padding(
              padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 20),
              child: Text(
                'By registering, you agree to our Terms of Service\nand Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  height: 1.4,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
