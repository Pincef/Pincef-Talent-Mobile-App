import 'package:dio/dio.dart';
import 'models/admin_models.dart';

class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.company,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final String? company;

  bool get isSuspended =>
      status.toLowerCase() == 'suspended' || status.toLowerCase() == 'inactive';

  AdminUserRecord copyWith({String? status}) => AdminUserRecord(
        id: id,
        name: name,
        email: email,
        role: role,
        status: status ?? this.status,
        company: company,
      );

  factory AdminUserRecord.fromJson(Map<String, dynamic> json) {
    final first = (json['firstName'] ?? '').toString().trim();
    final last = (json['lastName'] ?? '').toString().trim();
    final name = (json['name'] ?? '$first $last').toString().trim();
    return AdminUserRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: name.isEmpty ? 'Unnamed user' : name,
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'User').toString(),
      status: (json['status'] ??
              (json['isSuspended'] == true ? 'suspended' : 'active'))
          .toString(),
      company: (json['companyName'] ??
              (json['company'] is Map ? json['company']['name'] : null))
          ?.toString(),
    );
  }
}

class AdminSubscriptionRecord {
  const AdminSubscriptionRecord({
    required this.id,
    required this.accountName,
    required this.email,
    required this.plan,
    required this.status,
    this.renewsAt,
  });

  final String id;
  final String accountName;
  final String email;
  final String plan;
  final String status;
  final String? renewsAt;

  factory AdminSubscriptionRecord.fromJson(Map<String, dynamic> json) {
    final account =
        json['user'] ?? json['company'] ?? const <String, dynamic>{};
    final accountMap = account is Map
        ? Map<String, dynamic>.from(account)
        : <String, dynamic>{};
    final first = (accountMap['firstName'] ?? '').toString();
    final last = (accountMap['lastName'] ?? '').toString();
    return AdminSubscriptionRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      accountName:
          (accountMap['name'] ?? '$first $last').toString().trim().isEmpty
              ? 'Account'
              : (accountMap['name'] ?? '$first $last').toString().trim(),
      email: (accountMap['email'] ?? json['email'] ?? '').toString(),
      plan: (json['planName'] ??
              (json['plan'] is Map ? json['plan']['name'] : json['plan']) ??
              'Unknown plan')
          .toString(),
      status: (json['status'] ?? 'unknown').toString(),
      renewsAt:
          (json['currentPeriodEnd'] ?? json['renewsAt'] ?? json['renewalDate'])
              ?.toString(),
    );
  }
}

/// Admin endpoints are isolated here so their paths and response mappings
/// can be aligned quickly once the backend contract is available.
class AdminRepository {
  AdminRepository(this._dio, {this.useDemoData = true});

  final Dio _dio;
  final bool useDemoData;

  final List<AdminUserRecord> _demoUsers = _seedUsers();
  final List<AdminSubscriptionRecord> _demoSubscriptions = _seedSubscriptions();
  final List<AdminJobRecord> _demoJobs = _seedJobs();
  final List<AdminTicketRecord> _demoTickets = _seedTickets();

  Future<List<AdminUserRecord>> listUsers() async {
    if (useDemoData) return List.unmodifiable(_demoUsers);
    final data = await _request(() => _dio.get('/admin/users'));
    final rows = _listFrom(data, const ['users', 'items']);
    return rows.map(AdminUserRecord.fromJson).toList(growable: false);
  }

  Future<void> setUserSuspended(String userId, bool suspended) async {
    if (useDemoData) {
      final index = _demoUsers.indexWhere((user) => user.id == userId);
      if (index >= 0) {
        _demoUsers[index] = _demoUsers[index].copyWith(
          status: suspended ? 'suspended' : 'active',
        );
      }
      return;
    }
    await _request(() => _dio.patch('/admin/users/$userId/status', data: {
          'status': suspended ? 'suspended' : 'active',
        }));
  }

  Future<List<AdminSubscriptionRecord>> listSubscriptions() async {
    if (useDemoData) return List.unmodifiable(_demoSubscriptions);
    final data = await _request(() => _dio.get('/admin/subscriptions'));
    final rows = _listFrom(data, const ['subscriptions', 'items']);
    return rows.map(AdminSubscriptionRecord.fromJson).toList(growable: false);
  }

  /// Paginated platform job listing. Demo data is enabled until the admin
  /// endpoint is available; set [useDemoData] to false to call the API.
  Future<AdminPaginatedResult<AdminJobRecord>> listJobs({
    int page = 1,
    int limit = 8,
    String search = '',
  }) async {
    if (useDemoData) {
      final query = search.trim().toLowerCase();
      final filtered = _demoJobs.where((job) {
        return query.isEmpty ||
            job.title.toLowerCase().contains(query) ||
            job.companyName.toLowerCase().contains(query) ||
            job.location.toLowerCase().contains(query);
      }).toList();
      return _paginate(filtered, page, limit);
    }
    final data = await _request(() => _dio.get('/admin/jobs', queryParameters: {
          'page': page,
          'limit': limit,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        }));
    return AdminPaginatedResult.fromJson(
      Map<String, dynamic>.from(data as Map),
      AdminJobRecord.fromJson,
      'jobs',
    );
  }

  Future<AdminPaginatedResult<AdminTicketRecord>> listTickets({
    int page = 1,
    int limit = 8,
    String status = 'all',
  }) async {
    if (useDemoData) {
      final filtered = status == 'all'
          ? _demoTickets
          : _demoTickets.where((ticket) => ticket.status == status).toList();
      return _paginate(filtered, page, limit);
    }
    final data =
        await _request(() => _dio.get('/admin/tickets', queryParameters: {
              'page': page,
              'limit': limit,
              if (status != 'all') 'status': status,
            }));
    return AdminPaginatedResult.fromJson(
      Map<String, dynamic>.from(data as Map),
      AdminTicketRecord.fromJson,
      'tickets',
    );
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    if (useDemoData) {
      final index = _demoTickets.indexWhere((ticket) => ticket.id == ticketId);
      if (index >= 0) {
        _demoTickets[index] = _demoTickets[index].copyWith(status: status);
      }
      return;
    }
    await _request(() => _dio
        .patch('/admin/tickets/$ticketId/status', data: {'status': status}));
  }

  Future<void> addTicketReply(String ticketId, String body) async {
    if (useDemoData) {
      final index = _demoTickets.indexWhere((ticket) => ticket.id == ticketId);
      if (index >= 0) {
        final ticket = _demoTickets[index];
        _demoTickets[index] = ticket.copyWith(
          replies: [
            ...ticket.replies,
            AdminTicketReply(
              author: 'TalentBridge Support',
              body: body,
              createdAt: DateTime.now(),
            ),
          ],
        );
      }
      return;
    }
    await _request(() =>
        _dio.post('/admin/tickets/$ticketId/replies', data: {'body': body}));
  }

  AdminPaginatedResult<T> _paginate<T>(
      List<T> source, int requestedPage, int limit) {
    final safeLimit = limit < 1 ? 1 : limit;
    final totalPages = source.isEmpty ? 1 : (source.length / safeLimit).ceil();
    final page = requestedPage.clamp(1, totalPages).toInt();
    final start = (page - 1) * safeLimit;
    final end = (start + safeLimit).clamp(0, source.length).toInt();
    return AdminPaginatedResult<T>(
      items: source.sublist(start, end),
      total: source.length,
      page: page,
      limit: safeLimit,
      totalPages: totalPages,
    );
  }

  static List<AdminUserRecord> _seedUsers() => const [
        AdminUserRecord(
            id: 'u-3001',
            name: 'Dare Omotayo',
            email: 'dare@example.com',
            role: 'Recruiter',
            status: 'active',
            company: 'Northstar Labs'),
        AdminUserRecord(
            id: 'u-3002',
            name: 'Mariam Bello',
            email: 'mariam@example.com',
            role: 'Recruiter',
            status: 'active',
            company: 'Mosaic Health'),
        AdminUserRecord(
            id: 'u-3003',
            name: 'Chidi Eze',
            email: 'chidi@example.com',
            role: 'Candidate',
            status: 'active'),
        AdminUserRecord(
            id: 'u-3004',
            name: 'Tola Akin',
            email: 'tola@example.com',
            role: 'Candidate',
            status: 'suspended'),
        AdminUserRecord(
            id: 'u-3005',
            name: 'Samuel Okafor',
            email: 'samuel@example.com',
            role: 'Recruiter',
            status: 'active',
            company: 'Tandem Works'),
        AdminUserRecord(
            id: 'u-3006',
            name: 'Aisha Yusuf',
            email: 'aisha@example.com',
            role: 'Candidate',
            status: 'active'),
        AdminUserRecord(
            id: 'u-3007',
            name: 'Emeka Nwosu',
            email: 'emeka@example.com',
            role: 'Recruiter',
            status: 'active',
            company: 'Coastline'),
        AdminUserRecord(
            id: 'u-3008',
            name: 'Grace Obi',
            email: 'grace@example.com',
            role: 'Candidate',
            status: 'active'),
      ];

  static List<AdminSubscriptionRecord> _seedSubscriptions() {
    final now = DateTime.now();
    return [
      AdminSubscriptionRecord(
          id: 's-4101',
          accountName: 'Northstar Labs',
          email: 'dare@example.com',
          plan: 'Growth',
          status: 'active',
          renewsAt: now.add(const Duration(days: 19)).toIso8601String()),
      AdminSubscriptionRecord(
          id: 's-4102',
          accountName: 'Mosaic Health',
          email: 'mariam@example.com',
          plan: 'Scale',
          status: 'active',
          renewsAt: now.add(const Duration(days: 6)).toIso8601String()),
      AdminSubscriptionRecord(
          id: 's-4103',
          accountName: 'BrightPath',
          email: 'admin@brightpath.example',
          plan: 'Starter',
          status: 'past_due',
          renewsAt: now.subtract(const Duration(days: 2)).toIso8601String()),
      AdminSubscriptionRecord(
          id: 's-4104',
          accountName: 'Tandem Works',
          email: 'samuel@example.com',
          plan: 'Growth',
          status: 'trialing',
          renewsAt: now.add(const Duration(days: 13)).toIso8601String()),
      AdminSubscriptionRecord(
          id: 's-4105',
          accountName: 'Coastline',
          email: 'emeka@example.com',
          plan: 'Starter',
          status: 'canceled',
          renewsAt: now.subtract(const Duration(days: 17)).toIso8601String()),
    ];
  }

  static List<AdminJobRecord> _seedJobs() {
    final now = DateTime.now();
    return [
      _job('j-1001', 'Senior Product Designer', 'Northstar Labs', 'Lagos',
          'published', 18, now.subtract(const Duration(days: 2))),
      _job('j-1002', 'Backend Engineer', 'Mosaic Health', 'Remote', 'published',
          31, now.subtract(const Duration(days: 3))),
      _job('j-1003', 'Customer Success Lead', 'BrightPath', 'Abuja',
          'published', 12, now.subtract(const Duration(days: 5))),
      _job('j-1004', 'Growth Marketing Manager', 'KoraPay', 'Lagos',
          'published', 24, now.subtract(const Duration(days: 6))),
      _job('j-1005', 'Data Analyst', 'Northstar Labs', 'Remote', 'draft', 0,
          now.subtract(const Duration(days: 8))),
      _job('j-1006', 'People Operations Partner', 'Tandem Works', 'Ibadan',
          'published', 9, now.subtract(const Duration(days: 10))),
      _job('j-1007', 'Mobile Engineer', 'Mosaic Health', 'Remote', 'closed', 43,
          now.subtract(const Duration(days: 13))),
      _job('j-1008', 'Finance Associate', 'Coastline', 'Lagos', 'published', 15,
          now.subtract(const Duration(days: 15))),
      _job('j-1009', 'UX Researcher', 'BrightPath', 'Remote', 'published', 21,
          now.subtract(const Duration(days: 18))),
      _job('j-1010', 'Operations Coordinator', 'Tandem Works', 'Abuja', 'draft',
          0, now.subtract(const Duration(days: 21))),
      _job('j-1011', 'Platform Engineer', 'KoraPay', 'Lagos', 'published', 37,
          now.subtract(const Duration(days: 25))),
      _job('j-1012', 'Recruitment Specialist', 'Coastline', 'Remote', 'closed',
          28, now.subtract(const Duration(days: 31))),
      _job('j-1013', 'Sales Executive', 'Northstar Labs', 'Port Harcourt',
          'published', 11, now.subtract(const Duration(days: 35))),
      _job('j-1014', 'QA Automation Engineer', 'Mosaic Health', 'Remote',
          'published', 16, now.subtract(const Duration(days: 41))),
      _job('j-1015', 'Content Strategist', 'BrightPath', 'Lagos', 'draft', 0,
          now.subtract(const Duration(days: 46))),
    ];
  }

  static AdminJobRecord _job(String id, String title, String company,
          String location, String status, int applicants, DateTime createdAt) =>
      AdminJobRecord(
        id: id,
        title: title,
        companyName: company,
        location: location,
        status: status,
        applicantCount: applicants,
        createdAt: createdAt,
      );

  static List<AdminTicketRecord> _seedTickets() {
    final now = DateTime.now();
    return [
      AdminTicketRecord(
          id: 't-2041',
          subject: 'Unable to publish a job',
          message:
              'The publish button returns an error even though the form is complete.',
          requesterName: 'Dare Omotayo',
          requesterEmail: 'dare@example.com',
          category: 'Jobs',
          status: 'open',
          priority: 'high',
          createdAt: now.subtract(const Duration(hours: 2))),
      AdminTicketRecord(
          id: 't-2042',
          subject: 'Subscription payment not reflected',
          message: 'My card was charged but the plan still shows as pending.',
          requesterName: 'Mariam Bello',
          requesterEmail: 'mariam@example.com',
          category: 'Billing',
          status: 'in_progress',
          priority: 'high',
          createdAt: now.subtract(const Duration(hours: 7))),
      AdminTicketRecord(
          id: 't-2043',
          subject: 'Cannot invite a teammate',
          message: 'The invite link expires immediately after it is created.',
          requesterName: 'Chidi Eze',
          requesterEmail: 'chidi@example.com',
          category: 'Account access',
          status: 'open',
          priority: 'normal',
          createdAt: now.subtract(const Duration(days: 1))),
      AdminTicketRecord(
          id: 't-2044',
          subject: 'Candidate profile details are missing',
          message:
              'Several candidate profiles do not show their portfolio links.',
          requesterName: 'Tola Akin',
          requesterEmail: 'tola@example.com',
          category: 'Candidates',
          status: 'open',
          priority: 'normal',
          createdAt: now.subtract(const Duration(days: 2))),
      AdminTicketRecord(
          id: 't-2045',
          subject: 'Request to update company name',
          message: 'Please help update our company profile after a rebrand.',
          requesterName: 'Samuel Okafor',
          requesterEmail: 'samuel@example.com',
          category: 'Company profile',
          status: 'resolved',
          priority: 'low',
          createdAt: now.subtract(const Duration(days: 3))),
      AdminTicketRecord(
          id: 't-2046',
          subject: 'Interview email was not sent',
          message:
              'The candidate did not receive the interview invitation email.',
          requesterName: 'Aisha Yusuf',
          requesterEmail: 'aisha@example.com',
          category: 'Interviews',
          status: 'in_progress',
          priority: 'normal',
          createdAt: now.subtract(const Duration(days: 4))),
      AdminTicketRecord(
          id: 't-2047',
          subject: 'CV upload is stuck',
          message: 'The upload progress remains at 90% for every PDF.',
          requesterName: 'Emeka Nwosu',
          requesterEmail: 'emeka@example.com',
          category: 'CV upload',
          status: 'resolved',
          priority: 'normal',
          createdAt: now.subtract(const Duration(days: 6))),
      AdminTicketRecord(
          id: 't-2048',
          subject: 'Need an invoice for last month',
          message:
              'Could you send the invoice for our previous billing period?',
          requesterName: 'Zainab Musa',
          requesterEmail: 'zainab@example.com',
          category: 'Billing',
          status: 'open',
          priority: 'low',
          createdAt: now.subtract(const Duration(days: 8))),
      AdminTicketRecord(
          id: 't-2049',
          subject: 'Hiring pipeline stage disappeared',
          message:
              'Our assessment stage is no longer visible in a saved workflow.',
          requesterName: 'Femi James',
          requesterEmail: 'femi@example.com',
          category: 'Hiring pipelines',
          status: 'in_progress',
          priority: 'high',
          createdAt: now.subtract(const Duration(days: 9))),
      AdminTicketRecord(
          id: 't-2050',
          subject: 'Profile verification question',
          message: 'What document should I upload to complete verification?',
          requesterName: 'Grace Obi',
          requesterEmail: 'grace@example.com',
          category: 'Verification',
          status: 'resolved',
          priority: 'low',
          createdAt: now.subtract(const Duration(days: 11))),
    ];
  }

  List<Map<String, dynamic>> _listFrom(dynamic data, List<String> keys) {
    if (data is List)
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (data is Map) {
      for (final key in keys) {
        final value = data[key];
        if (value is List) {
          return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
        }
      }
    }
    return const [];
  }

  Future<dynamic> _request(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      final body = response.data;
      return body is Map && body.containsKey('data') ? body['data'] : body;
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map ? body['message'] ?? body['error'] : null;
      throw Exception(message?.toString() ??
          'Admin data could not be loaded. Check that the admin API is connected.');
    }
  }
}
