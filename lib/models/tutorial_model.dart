// lib/models/tutorial_model.dart

class Comment {
  final String userName;
  final String avatarAsset;
  final String text;
  final String timestamp; // Added for the new detail screen design
  int likeCount;
  bool isLiked;
  final List<Comment> replies;

  Comment({
    required this.userName,
    required this.avatarAsset,
    required this.text,
    required this.timestamp, // Added to constructor
    this.likeCount = 0,
    this.isLiked = false,
    List<Comment>? replies,
  }) : replies = replies ?? [];
}

class Tutorial {
  final String title;
  final String eWasteType;
  final String creatorName;
  final String creatorAvatarUrl;
  final String imageUrl;
  final String videoUrl;
  final String description;
  final int likeCount;
  final List<Comment> comments;

  Tutorial({
    required this.title,
    required this.eWasteType,
    required this.creatorName,
    required this.creatorAvatarUrl,
    required this.imageUrl,
    required this.videoUrl,
    required this.description,
    required this.likeCount,
    required this.comments,
  });
}
