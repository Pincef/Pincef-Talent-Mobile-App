import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import 'models/security_log_item_model.dart';

class SettingsRepository {
  SettingsRepository(this._dio);

  final Dio _dio;

  /// Same endpoint the profile screen's data ultimately comes from —
  /// firstName/lastName/bio/location/competencies/certifications all flow
  /// through updateMyAccountSchema on the backend.
  Future<UserModel> updateAccount({
    String? firstName,
    String? lastName,
    String? bio,
    String? location,
    String? phone,
    bool? remoteFriendly,
    bool? activeSeeking,
    List<String>? competencies,
    List<Map<String, dynamic>>? certifications,
  }) async {
    final response = await _dio.patch('/users/me', data: {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (bio != null) 'bio': bio,
      if (location != null) 'location': location,
      if (phone != null) 'phone': phone,
      if (remoteFriendly != null && activeSeeking != null)
        'workPreferences': {
          'remoteFriendly': remoteFriendly,
          'activeSeeking': activeSeeking,
        },
      if (competencies != null) 'competencies': competencies,
      if (certifications != null) 'certifications': certifications,
    });
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> removePhoto() async {
    await _dio.delete('/users/me/photo');
  }

  /// For refreshing the cached user after an action that changes it
  /// server-side without a natural response body to use directly (e.g.
  /// removePhoto's 204-ish "Photo removed" message, not the full user).
  Future<UserModel> getMyAccount() async {
    final response = await _dio.get('/users/me');
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Takes an `XFile` (from `image_picker`) rather than a `dart:io File` —
  /// `MultipartFile.fromFile` needs `dart:io`, which doesn't exist on
  /// Flutter Web, so this reads bytes instead, which works on every
  /// platform. `field: 'photo'` must match `upload.single('photo')` on the
  /// backend route.
  Future<ProfileImage> uploadPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    final response = await _dio.post('/users/me/photo', data: formData);
    return ProfileImage.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Backend re-auths with `currentPassword` and mails a confirm link to
  /// `newEmail` — the address doesn't actually change until that's clicked,
  /// so this doesn't return the updated user.
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    await _dio.post('/users/me/email-change', data: {
      'newEmail': newEmail,
      'currentPassword': currentPassword,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post('/users/me/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// Cursor-paginated, same pattern as the profile screen's activity feed —
  /// "View Full Activity History" calls this again with the last cursor.
  Future<SecurityLogPage> getSecurityLogs(
      {String? cursor, int limit = 10}) async {
    final response =
        await _dio.get('/users/me/security-logs', queryParameters: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    });
    final items = (response.data['data'] as List<dynamic>)
        .map((e) => SecurityLogItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final nextCursor = (response.data['meta']
        as Map<String, dynamic>?)?['nextCursor'] as String?;
    return SecurityLogPage(items: items, nextCursor: nextCursor);
  }
}
