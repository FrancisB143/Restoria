// lib/models/gallery_post_model.dart

class GalleryPost {
  final String userName;
  final String imageUrl;
  final String description; // Add a description for the post
  final int likeCount;

  GalleryPost({
    required this.userName,
    required this.imageUrl,
    required this.description,
    required this.likeCount,
  });
}