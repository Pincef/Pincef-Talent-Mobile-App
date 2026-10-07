import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';

/// Talks to the company-profile backend (`POST /companies`).
///
/// company.service.ts's CompanyInput only has `name` / `industry` /
/// `website` — no `companySize`, no logo field, and the route has no
/// multer middleware, so this can only be a JSON request, not
/// multipart. Two things collected by the setup screen currently have
/// nowhere to go on the backend:
///   - companySize: no field on CompanyInput at all
///   - logoBytes: no upload handling anywhere on the company routes
/// Both are silently dropped here (not sent) rather than sent to an
/// endpoint that can't use them. Once the backend adds support for
/// either, wire it back in — logo will likely need its own
/// multipart/multer route the same way CV upload does, since mixing
/// binary + JSON on one endpoint would require adding multer here too.
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
      await _dio.post('/companies', data: {
        'name': companyName,
        if (industry != null) 'industry': industry,
        if (companyWebsite != null && companyWebsite.isNotEmpty)
          'website': companyWebsite,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
