class AdminPaginatedResult<T> {
  const AdminPaginatedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  factory AdminPaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
    String listKey,
  ) {
    final rows = (json[listKey] as List? ?? const [])
        .whereType<Map>()
        .map((row) => fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    final total = (json['total'] as num?)?.toInt() ?? rows.length;
    final page = (json['page'] as num?)?.toInt() ?? 1;
    final limit = (json['limit'] as num?)?.toInt() ?? rows.length;
    return AdminPaginatedResult<T>(
      items: rows,
      total: total,
      page: page,
      limit: limit,
      totalPages: (json['totalPages'] as num?)?.toInt() ??
          (limit == 0 ? 1 : (total / limit).ceil().clamp(1, 1 << 31).toInt()),
    );
  }
}

class AdminJobRecord {
  const AdminJobRecord({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.status,
    required this.createdAt,
    this.applicantCount = 0,
  });

  final String id;
  final String title;
  final String companyName;
  final String location;
  final String status;
  final DateTime? createdAt;
  final int applicantCount;

  factory AdminJobRecord.fromJson(Map<String, dynamic> json) {
    final company = json['companyId'] ?? json['company'];
    final companyName = company is Map
        ? (company['name'] ?? 'Unknown company').toString()
        : (json['companyName'] ?? 'Unknown company').toString();
    return AdminJobRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled job').toString(),
      companyName: companyName,
      location: (json['location'] ?? 'Not specified').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      createdAt: DateTime.tryParse(
        (json['createdAt'] ?? json['publishedAt'] ?? '').toString(),
      ),
      applicantCount: (json['applicantCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminTicketReply {
  const AdminTicketReply({
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final String author;
  final String body;
  final DateTime? createdAt;

  factory AdminTicketReply.fromJson(Map<String, dynamic> json) =>
      AdminTicketReply(
        author: (json['authorName'] ?? json['author'] ?? 'Support').toString(),
        body: (json['body'] ?? json['message'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      );
}

class AdminTicketRecord {
  const AdminTicketRecord({
    required this.id,
    required this.subject,
    required this.message,
    required this.requesterName,
    required this.requesterEmail,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.replies = const [],
  });

  final String id;
  final String subject;
  final String message;
  final String requesterName;
  final String requesterEmail;
  final String category;
  final String status;
  final String priority;
  final DateTime? createdAt;
  final List<AdminTicketReply> replies;

  AdminTicketRecord copyWith(
          {String? status, List<AdminTicketReply>? replies}) =>
      AdminTicketRecord(
        id: id,
        subject: subject,
        message: message,
        requesterName: requesterName,
        requesterEmail: requesterEmail,
        category: category,
        status: status ?? this.status,
        priority: priority,
        createdAt: createdAt,
        replies: replies ?? this.replies,
      );

  factory AdminTicketRecord.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] ?? json['user'];
    final requesterMap = requester is Map
        ? Map<String, dynamic>.from(requester)
        : <String, dynamic>{};
    return AdminTicketRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      subject:
          (json['subject'] ?? json['title'] ?? 'Support request').toString(),
      message: (json['message'] ?? json['description'] ?? '').toString(),
      requesterName: (requesterMap['name'] ??
              '${requesterMap['firstName'] ?? ''} ${requesterMap['lastName'] ?? ''}')
          .toString()
          .trim(),
      requesterEmail:
          (requesterMap['email'] ?? json['requesterEmail'] ?? '').toString(),
      category: (json['category'] ?? 'General').toString(),
      status: (json['status'] ?? 'open').toString(),
      priority: (json['priority'] ?? 'normal').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      replies: (json['replies'] as List? ?? const [])
          .whereType<Map>()
          .map((reply) => AdminTicketReply.fromJson(
                Map<String, dynamic>.from(reply),
              ))
          .toList(growable: false),
    );
  }
}
