import 'package:supabase_flutter/supabase_flutter.dart';

class LikesCommentsService {
  final _supabase = Supabase.instance.client;

  // ========================================
  // GALLERY LIKES
  // ========================================

  Future<bool> isGalleryPostLiked(String galleryPostId, String userId) async {
    try {
      final response = await _supabase
          .from('gallery_likes')
          .select('id')
          .eq('gallery_post_id', galleryPostId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking gallery like status: $e');
      return false;
    }
  }

  Future<void> toggleGalleryLike(String galleryPostId, String userId) async {
    try {
      final isLiked = await isGalleryPostLiked(galleryPostId, userId);

      if (isLiked) {
        // Unlike
        await _supabase
            .from('gallery_likes')
            .delete()
            .eq('gallery_post_id', galleryPostId)
            .eq('user_id', userId);
      } else {
        // Like
        await _supabase.from('gallery_likes').insert({
          'gallery_post_id': galleryPostId,
          'user_id': userId,
        });
      }
    } catch (e) {
      print('Error toggling gallery like: $e');
      rethrow;
    }
  }

  Future<int> getGalleryLikeCount(String galleryPostId) async {
    try {
      final response = await _supabase
          .from('gallery_posts')
          .select('like_count')
          .eq('id', galleryPostId)
          .single();

      return response['like_count'] ?? 0;
    } catch (e) {
      print('Error getting gallery like count: $e');
      return 0;
    }
  }

  // ========================================
  // TUTORIAL LIKES
  // ========================================

  Future<bool> isTutorialLiked(String tutorialId, String userId) async {
    try {
      final response = await _supabase
          .from('tutorial_likes')
          .select('id')
          .eq('tutorial_id', tutorialId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking tutorial like status: $e');
      return false;
    }
  }

  Future<void> toggleTutorialLike(String tutorialId, String userId) async {
    try {
      final isLiked = await isTutorialLiked(tutorialId, userId);

      if (isLiked) {
        // Unlike
        await _supabase
            .from('tutorial_likes')
            .delete()
            .eq('tutorial_id', tutorialId)
            .eq('user_id', userId);
      } else {
        // Like
        await _supabase.from('tutorial_likes').insert({
          'tutorial_id': tutorialId,
          'user_id': userId,
        });
      }
    } catch (e) {
      print('Error toggling tutorial like: $e');
      rethrow;
    }
  }

  Future<int> getTutorialLikeCount(String tutorialId) async {
    try {
      final response = await _supabase
          .from('tutorials')
          .select('like_count')
          .eq('id', tutorialId)
          .single();

      return response['like_count'] ?? 0;
    } catch (e) {
      print('Error getting tutorial like count: $e');
      return 0;
    }
  }

  // ========================================
  // GALLERY COMMENTS
  // ========================================

  Future<List<Map<String, dynamic>>> getGalleryComments(
    String galleryPostId,
  ) async {
    try {
      final response = await _supabase
          .from('gallery_comments')
          .select('''
            id,
            content,
            created_at,
            user_id,
            profiles!inner(name, avatar_url)
          ''')
          .eq('gallery_post_id', galleryPostId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting gallery comments: $e');
      return [];
    }
  }

  Future<void> addGalleryComment(
    String galleryPostId,
    String userId,
    String content,
  ) async {
    try {
      await _supabase.from('gallery_comments').insert({
        'gallery_post_id': galleryPostId,
        'user_id': userId,
        'content': content,
      });
    } catch (e) {
      print('Error adding gallery comment: $e');
      rethrow;
    }
  }

  Future<int> getGalleryCommentCount(String galleryPostId) async {
    try {
      final response = await _supabase
          .from('gallery_comments')
          .select('id')
          .eq('gallery_post_id', galleryPostId);

      return response.length;
    } catch (e) {
      print('Error getting gallery comment count: $e');
      return 0;
    }
  }

  Future<void> deleteGalleryComment(String commentId, String userId) async {
    try {
      await _supabase
          .from('gallery_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId);
    } catch (e) {
      print('Error deleting gallery comment: $e');
      rethrow;
    }
  }

  // ========================================
  // TUTORIAL COMMENTS
  // ========================================

  Future<List<Map<String, dynamic>>> getTutorialComments(
    String tutorialId,
  ) async {
    try {
      final response = await _supabase
          .from('tutorial_comments')
          .select('''
            id,
            content,
            created_at,
            user_id,
            profiles!inner(name, avatar_url)
          ''')
          .eq('tutorial_id', tutorialId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting tutorial comments: $e');
      return [];
    }
  }

  Future<void> addTutorialComment(
    String tutorialId,
    String userId,
    String content,
  ) async {
    try {
      await _supabase.from('tutorial_comments').insert({
        'tutorial_id': tutorialId,
        'user_id': userId,
        'content': content,
      });
    } catch (e) {
      print('Error adding tutorial comment: $e');
      rethrow;
    }
  }

  Future<int> getTutorialCommentCount(String tutorialId) async {
    try {
      final response = await _supabase
          .from('tutorial_comments')
          .select('id')
          .eq('tutorial_id', tutorialId);

      return response.length;
    } catch (e) {
      print('Error getting tutorial comment count: $e');
      return 0;
    }
  }

  Future<void> deleteTutorialComment(String commentId, String userId) async {
    try {
      await _supabase
          .from('tutorial_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId);
    } catch (e) {
      print('Error deleting tutorial comment: $e');
      rethrow;
    }
  }
}
