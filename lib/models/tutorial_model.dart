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
  final String? id; // UUID from database
  final String? userId; // Creator's user ID
  final String title;
  final String eWasteType;
  final String creatorName;
  final String creatorAvatarUrl;
  final String imageUrl;
  final String videoUrl;
  final String description;
  final int likeCount;
  final List<Comment> comments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tutorial({
    this.id,
    this.userId,
    required this.title,
    required this.eWasteType,
    required this.creatorName,
    required this.creatorAvatarUrl,
    required this.imageUrl,
    required this.videoUrl,
    required this.description,
    required this.likeCount,
    required this.comments,
    this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create Tutorial from Supabase data
  factory Tutorial.fromJson(Map<String, dynamic> json) {
    return Tutorial(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      title: json['title'] as String,
      eWasteType: json['e_waste_type'] as String,
      creatorName: json['creator_name'] as String? ?? 'Unknown',
      creatorAvatarUrl:
          json['creator_avatar_url'] as String? ??
          'https://i.pravatar.cc/150?u=default',
      imageUrl: json['image_url'] as String? ?? 'assets/images/placeholder.png',
      videoUrl: json['video_url'] as String? ?? '',
      description: json['description'] as String,
      likeCount: json['like_count'] as int? ?? 0,
      comments: [], // Comments will be loaded separately
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Convert Tutorial to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'e_waste_type': eWasteType,
      'description': description,
      'video_url': videoUrl,
      'image_url': imageUrl,
      'like_count': likeCount,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
