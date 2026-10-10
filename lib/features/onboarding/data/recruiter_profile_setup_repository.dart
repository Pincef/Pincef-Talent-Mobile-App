import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';

/// Talks to the company-profile backend (`POST /companies`).
///
/// Sends the company profile as multipart when a logo is selected, so the
/// image is uploaded in the same request as the company fields.
class RecruiterProfileSetupRepository {
  RecruiterProfileSetupRepository(this._dio);
  final Dio _dio;

  Future<void> saveCompanyProfile({
    required String companyName,
    String? industry,
    String? companySize,
    String? companyWebsite,
    Uint8List? logoBytes,
    String? logoFilename,
  }) async {
    try {
      final fields = <String, dynamic>{
        'name': companyName,
        if (industry != null) 'industry': industry,
        if (companyWebsite != null && companyWebsite.isNotEmpty)
          'website': companyWebsite,
      };
      if (logoBytes != null) {
        fields['logo'] = MultipartFile.fromBytes(
          logoBytes,
          filename: logoFilename ?? 'company-logo.png',
        );
      }
      await _dio.post(
        '/companies',
        data: logoBytes == null ? fields : FormData.fromMap(fields),
        options: logoBytes == null
            ? null
            : Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
