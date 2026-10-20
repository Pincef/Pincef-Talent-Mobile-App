import 'package:dio/dio.dart';

class AssessmentRepository {
  AssessmentRepository(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  dynamic _data(dynamic response) => _map((response as Response).data)['data'];
  List<Map<String, dynamic>> _list(dynamic response) =>
      ((_data(response) as List?) ?? const [])
          .map((item) => _map(item))
          .toList();

  Future<List<Map<String, dynamic>>> listRecruiterAssessments() async =>
      _list(await _dio.get('/competency-tests'));

  Future<Map<String, dynamic>> getAssessment(String id) async =>
      _map(_data(await _dio.get('/competency-tests/$id')));

  Future<Map<String, dynamic>> createManual(
          Map<String, dynamic> payload) async =>
      _map(_data(await _dio.post('/competency-tests/manual', data: payload)));

  Future<Map<String, dynamic>> generate(Map<String, dynamic> payload) async =>
      _map(_data(await _dio.post('/competency-tests/generate', data: payload)));

  Future<Map<String, dynamic>> update(
          String id, Map<String, dynamic> payload) async =>
      _map(_data(await _dio.patch('/competency-tests/$id', data: payload)));

  Future<Map<String, dynamic>> publish(
    String id, {
    required List<String> applicationIds,
    required bool includeShortlisted,
    required String deliveryChannel,
  }) async =>
      _map(_data(await _dio.post('/competency-tests/$id/publish', data: {
        'applicationIds': applicationIds,
        'includeShortlisted': includeShortlisted,
        'deliveryChannel': deliveryChannel,
      })));

  Future<Map<String, dynamic>> invite(
    String id, {
    required List<String> applicationIds,
    required bool includeShortlisted,
    required String deliveryChannel,
  }) async =>
      _map(_data(await _dio.post('/competency-tests/$id/invite', data: {
        'applicationIds': applicationIds,
        'includeShortlisted': includeShortlisted,
        'deliveryChannel': deliveryChannel,
      })));

  Future<List<Map<String, dynamic>>> listMine() async =>
      _list(await _dio.get('/assessments/mine'));

  Future<Map<String, dynamic>> start(String assessmentId) async =>
      _map(_data(await _dio.post('/assessments/$assessmentId/start')));

  Future<void> saveAnswers(
      String assessmentId, List<Map<String, dynamic>> answers) async {
    await _dio
        .put('/assessments/$assessmentId/answers', data: {'answers': answers});
  }

  Future<Map<String, dynamic>> submit(
          String assessmentId, List<Map<String, dynamic>> answers) async =>
      _map(_data(await _dio.post('/assessments/$assessmentId/submit',
          data: {'answers': answers})));

  Future<Map<String, dynamic>> recordViolation(String assessmentId) async =>
      _map(_data(await _dio.post('/assessments/$assessmentId/violation')));

  Future<void> completeExternal(String assessmentId) async {
    await _dio.post('/assessments/$assessmentId/external-complete');
  }
}
