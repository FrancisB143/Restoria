import 'package:flutter/material.dart';
import '../models/gallery_post_model.dart';
import 'gallery_detail_screen.dart'; // Import the detail screen

class ProfileScreen extends StatelessWidget {
  final String userName;
  final List<GalleryPost> allPosts;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.allPosts,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final myPosts = allPosts
        .where((post) => post.userName == userName)
        .toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            CircleAvatar(
              radius: 54,
              backgroundColor: colorScheme.primary,
              child: const CircleAvatar(
                radius: 50,
                // MODIFIED: Changed to a local asset image
                backgroundImage: AssetImage('assets/images/avatar1.png'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 16, color: colorScheme.secondary),
                const SizedBox(width: 4),
                Text(
                  'Davao City, Philippines',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Turning e-waste into e-wonderful! ♻️✨ Creator and seller of unique upcycled art.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('12', 'Creations', textTheme),
                _buildStatItem('5', 'Following', textTheme),
                _buildStatItem('128', 'Followers', textTheme),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildSectionTitle('My Projects', textTheme),
            const SizedBox(height: 12),
            myPosts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Text("You haven't posted any projects yet."),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: myPosts.length,
                    itemBuilder: (context, index) {
                      final post = myPosts[index];
                      // MODIFIED: Wrapped with GestureDetector to make it clickable
                      return GestureDetector(
                        onTap: () {
                          // Navigate to the detail screen for the tapped post
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GalleryDetailScreen(post: post),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.asset(post.imageUrl, fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, TextTheme textTheme) {
    return Column(
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }

  Widget _buildSectionTitle(String title, TextTheme textTheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
