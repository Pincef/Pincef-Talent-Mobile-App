import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'models/location_models.dart';

/// Wraps /api/locations/countries → .../states → .../cities. App-wide and
/// feature-agnostic on purpose — anywhere the app needs a location picker
/// (candidate profile setup today; a recruiter company-address field or
/// anything else later) can reuse this instead of each feature rolling
/// its own.
///
/// ⚠️ ASSUMPTION: calls go through the same Dio instance (and therefore
/// the same kApiBaseUrl / port) as the rest of the app. The Swagger docs
/// you linked were on localhost:4000, while kApiBaseUrl defaults to
/// localhost:3000/api — if locations genuinely live on a different
/// host/port than the rest of the API, this needs a second Dio instance
/// with that base URL instead. Confirm before relying on this as-is.
class LocationsRepository {
  LocationsRepository(this._dio);
  final Dio _dio;

  Future<List<CountryEntry>> fetchCountries() async {
    try {
      final response = await _dio.get('/locations/countries');
      final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
      return list.map(CountryEntry.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<StateEntry>> fetchStates(String countryCode) async {
    try {
      final response = await _dio.get('/locations/countries/$countryCode/states');
      final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
      return list.map(StateEntry.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<CityEntry>> fetchCities(String countryCode, String stateCode) async {
    try {
      final response = await _dio.get('/locations/countries/$countryCode/states/$stateCode/cities');
      final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
      return list.map(CityEntry.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}