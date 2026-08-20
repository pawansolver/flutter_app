file_path = "c:/flutter/my_first_app/lib/modules/feed/feed_service.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add deletePost, reportPost, unfollowUser methods before the closing }
new_methods = """
  // 11. DELETE Post (author only)
  Future<FeedResult<bool>> deletePost(int postId) async {
    try {
      final resp = await _dio.delete(
        '$_base/post/$postId',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to delete post');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 12. Report Post
  Future<FeedResult<bool>> reportPost(int postId, {required String reason, String? details}) async {
    try {
      final resp = await _dio.post(
        '$_base/post/$postId/report',
        data: {'reason': reason, if (details != null) 'details': details},
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to report');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 13. Unfollow User
  Future<FeedResult<bool>> unfollowUser(int targetUserId) async {
    try {
      final resp = await _dio.delete(
        '$_base/users/unfollow/$targetUserId',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to unfollow');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }
"""

# Insert before the last closing }
last_brace = content.rfind("}")
content = content[:last_brace] + new_methods + "\n}"

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Added deletePost, reportPost, unfollowUser to feed_service.dart")
