// lib/models/gallery_post_model.dart

class GalleryPost {
  final String? userId; // User ID of the creator
  final String userName;
  final String imageUrl;
  final String description; // Add a description for the post
  final int likeCount;
  final String? avatarUrl; // Optional avatar URL
  final DateTime? createdAt; // Timestamp of when the post was created

  GalleryPost({
    this.userId,
    required this.userName,
    required this.imageUrl,
    required this.description,
    required this.likeCount,
    this.avatarUrl,
    this.createdAt,
  });
}
