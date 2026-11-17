import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import '../application/admin_provider.dart';
import '../data/admin_repository.dart';
import '../data/models/admin_models.dart';

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(adminOverviewProvider);
    return _AdminPage(
      title: 'Admin overview',
      subtitle: 'Platform activity, account access, and billing health.',
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final cardWidth =
            wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        final cards = [
          _AdminActionCard(
            icon: Icons.people_outline,
            title: 'Users',
            description: 'Review accounts and suspend or reactivate users.',
            onTap: () => context.go('/admin/users'),
          ),
          _AdminActionCard(
            icon: Icons.work_outline,
            title: 'Jobs',
            description: 'Browse all platform job postings by page.',
            onTap: () => context.go('/admin/jobs'),
          ),
          _AdminActionCard(
            icon: Icons.payments_outlined,
            title: 'Subscriptions',
            description: 'Check plans, account status, and renewal dates.',
            onTap: () => context.go('/admin/subscriptions'),
          ),
        ];
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            if (overview.hasValue) ...[
              _AdminMetricCard(
                  label: 'Users',
                  value: '${overview.value!.users}',
                  detail:
                      '${overview.value!.recruiters} recruiters · ${overview.value!.candidates} candidates',
                  width: cardWidth),
              _AdminMetricCard(
                  label: 'Jobs',
                  value: '${overview.value!.jobs}',
                  detail: '${overview.value!.activeJobs} currently published',
                  width: cardWidth),
              _AdminMetricCard(
                  label: 'Applications',
                  value: '${overview.value!.applications}',
                  detail: '${overview.value!.companies} companies',
                  width: cardWidth),
              _AdminMetricCard(
                  label: 'Active subscriptions',
                  value: '${overview.value!.activeSubscriptions}',
                  detail:
                      '${overview.value!.upcomingRenewals} renewals in 30 days',
                  width: cardWidth),
              _AdminMetricCard(
                  label: 'Past due',
                  value: '${overview.value!.pastDueSubscriptions}',
                  detail:
                      '${overview.value!.plans} active plans · ${overview.value!.webhookEvents} webhook events processed',
                  width: cardWidth),
            ] else if (overview.hasError)
              SizedBox(
                  width: constraints.maxWidth,
                  child: _ErrorState(
                      message: _friendlyError(overview.error!),
                      onRetry: () => ref.invalidate(adminOverviewProvider))),
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      }),
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard(
      {required this.label,
      required this.value,
      required this.detail,
      required this.width});
  final String label, value, detail;
  final double width;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE4E9F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: BrandColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: BrandColors.navy,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(detail,
              style: const TextStyle(color: BrandColors.muted, fontSize: 11)),
        ]),
      );
}

class AdminAiUsageScreen extends ConsumerStatefulWidget {
  const AdminAiUsageScreen({super.key});
  @override
  ConsumerState<AdminAiUsageScreen> createState() => _AdminAiUsageScreenState();
}

class _AdminAiUsageScreenState extends ConsumerState<AdminAiUsageScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final usage = ref.watch(adminAiUsageProvider(_days));
    return _AdminPage(
      title: 'Automation usage',
      subtitle: 'See which automated workflows and models are consuming tokens.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: DropdownButton<int>(
            value: _days,
            onChanged: (value) =>
                value == null ? null : setState(() => _days = value),
            items: const [7, 30, 90]
                .map((days) => DropdownMenuItem(
                    value: days, child: Text('Last $days days')))
                .toList(),
          ),
        ),
        usage.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: _friendlyError(error),
            onRetry: () => ref.invalidate(adminAiUsageProvider(_days)),
          ),
          data: (summary) => _AiUsageContent(summary: summary),
        ),
      ]),
    );
  }
}

class _AiUsageContent extends StatelessWidget {
  const _AiUsageContent({required this.summary});
  final AdminAiUsageSummary summary;

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  String _count(Object? value) => _int(value)
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 540
                ? 2
                : 1;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final totals = summary.totals;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: gap, runSpacing: gap, children: [
            _AiUsageMetric(
                label: 'Total tokens',
                value: _count(totals['totalTokens']),
                detail: 'prompt + completion',
                width: tileWidth),
            _AiUsageMetric(
                label: 'Prompt tokens',
                value: _count(totals['promptTokens']),
                detail: 'input to Groq',
                width: tileWidth),
            _AiUsageMetric(
                label: 'Completion tokens',
                value: _count(totals['completionTokens']),
                detail: 'generated output',
                width: tileWidth),
            _AiUsageMetric(
                label: 'Requests / quota errors',
                value:
                    '${_count(totals['requests'])} / ${_count(totals['quotaErrors'])}',
                detail: '${_count(totals['errors'])} failed attempts total',
                width: tileWidth),
          ]),
          const SizedBox(height: 22),
          _usageSection(
              'Usage by workflow',
              summary.byOperation,
              (row) => '${row['operation'] ?? 'Unknown'}',
              (row) =>
                  '${_count(row['totalTokens'])} tokens · ${_count(row['requests'])} attempts · ${_count(row['errors'])} errors'),
          _usageSection(
              'Usage by model',
              summary.byModel,
              (row) => '${row['model'] ?? 'Unknown'}',
              (row) =>
                  '${_count(row['totalTokens'])} tokens · ${_count(row['requests'])} requests'),
          _usageSection(
              'Key rotation',
              summary.byKeySlot,
              (row) => (row['keySlot'] as num?)?.toInt() == 0
                  ? 'No configured key'
                  : 'Key slot ${row['keySlot']}',
              (row) =>
                  '${_count(row['totalTokens'])} tokens · ${_count(row['requests'])} attempts · ${_count(row['quotaErrors'])} quota errors'),
          _usageSection(
              'Daily usage (UTC)',
              summary.byDay.reversed.take(14).toList(),
              (row) => '${row['date'] ?? 'Unknown date'}',
              (row) =>
                  '${_count(row['totalTokens'])} tokens · ${_count(row['requests'])} attempts · ${_count(row['errors'])} errors'),
          _usageSection(
              'Recent requests',
              summary.recent,
              (row) =>
                  '${row['operation'] ?? 'Automation request'} · ${row['model'] ?? ''}',
              (row) =>
                  '${row['status']} · ${_count(row['totalTokens'])} tokens · key slot ${row['keySlot']} · ${row['errorType'] ?? 'no error'}'),
          if (summary.totals['requests'] == 0)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                    'No Groq usage has been recorded for this period yet. Records start appearing as automated requests run.',
                    style: TextStyle(color: BrandColors.muted))),
        ]);
      });

  Widget _usageSection(
          String title,
          List<Map<String, dynamic>> rows,
          String Function(Map<String, dynamic>) titleFor,
          String Function(Map<String, dynamic>) detailFor) =>
      Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: BrandColors.navy)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text('No data yet.',
                style: TextStyle(fontSize: 12, color: BrandColors.muted)),
          for (final row in rows)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE4E9F0))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleFor(row),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: BrandColors.navy)),
                    const SizedBox(height: 4),
                    Text(detailFor(row),
                        style: const TextStyle(
                            fontSize: 11, color: BrandColors.muted)),
                  ]),
            ),
        ]),
      );
}

class _AiUsageMetric extends StatelessWidget {
  const _AiUsageMetric(
      {required this.label,
      required this.value,
      required this.detail,
      required this.width});
  final String label, value, detail;
  final double width;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E9F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.muted)),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.navy)),
          const SizedBox(height: 3),
          Text(detail,
              style: const TextStyle(fontSize: 10, color: BrandColors.muted)),
        ]),
      );
}

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (page: _page, search: _search.text.trim());
    final users = ref.watch(adminUsersProvider(query));
    final currentUser = ref.watch(authProvider).user;
    return _AdminPage(
      title: 'Users',
      subtitle: 'Review user accounts and manage access.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() => _page = 1),
          decoration: InputDecoration(
            hintText: 'Search name, email, or role',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E9F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E9F0)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        users.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: _friendlyError(error),
            onRetry: () => ref.invalidate(adminUsersProvider),
          ),
          data: (result) {
            final query = _search.text.trim().toLowerCase();
            if (result.items.isEmpty) {
              return _EmptyState(
                title: query.isEmpty ? 'No users found' : 'No matching users',
                message: query.isEmpty
                    ? 'User accounts will appear here when the admin API is connected.'
                    : 'Try a different name, email, or role.',
              );
            }
            return Column(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${(result.page - 1) * result.limit + 1}–${(result.page * result.limit).clamp(0, result.total)} of ${result.total} users',
                  style:
                      const TextStyle(color: BrandColors.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 9),
              for (final user in result.items)
                _UserCard(
                  user: user,
                  isCurrentUser: user.id == currentUser?.id ||
                      user.email.toLowerCase() ==
                          currentUser?.email.toLowerCase(),
                  onStatusChanged: () => _changeStatus(user),
                ),
              _PageControls(
                page: result.page,
                totalPages: result.totalPages,
                onPrevious:
                    result.page > 1 ? () => setState(() => _page--) : null,
                onNext: result.page < result.totalPages
                    ? () => setState(() => _page++)
                    : null,
              ),
            ]);
          },
        ),
      ]),
    );
  }

  Future<void> _changeStatus(AdminUserRecord user) async {
    final suspend = !user.isSuspended;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(suspend ? 'Suspend this user?' : 'Reactivate this user?'),
        content: Text(suspend
            ? 'This will prevent ${user.name} from using their account.'
            : 'This will restore access for ${user.name}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  suspend ? const Color(0xFFB42318) : BrandColors.orange,
            ),
            child: Text(suspend ? 'Suspend user' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .setUserSuspended(user.id, suspend);
      ref.invalidate(
          adminUsersProvider((page: _page, search: _search.text.trim())));
      if (mounted) {
        AppToast.success(
          context,
          suspend ? 'User suspended.' : 'User reactivated.',
        );
      }
    } catch (error) {
      if (mounted) AppToast.error(context, _friendlyError(error));
    }
  }
}

class AdminSubscriptionsScreen extends ConsumerWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(adminSubscriptionsProvider);
    final billingHealth = ref.watch(adminBillingHealthProvider);
    return _AdminPage(
      title: 'Subscriptions',
      subtitle: 'View account plans and subscription status.',
      child: subscriptions.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          message: _friendlyError(error),
          onRetry: () => ref.invalidate(adminSubscriptionsProvider),
        ),
        data: (records) => Column(children: [
          if (billingHealth.hasValue)
            _BillingHealthStrip(summary: billingHealth.value!),
          if (records.isEmpty)
            const _EmptyState(
              title: 'No subscriptions found',
              message:
                  'Subscription records will appear here when a company or recruiter subscribes.',
            )
          else
            for (final record in records)
              _SubscriptionCard(subscription: record),
        ]),
      ),
    );
  }
}

class _BillingHealthStrip extends StatelessWidget {
  const _BillingHealthStrip({required this.summary});
  final AdminBillingHealth summary;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 760
              ? (constraints.maxWidth - 24) / 4
              : (constraints.maxWidth - 12) / 2;
          final cards = <(String, int, String)>[
            ('Active', summary.active, 'subscriptions'),
            ('Past due', summary.pastDue, 'need attention'),
            ('Upcoming', summary.renewalsNext30Days, 'renewals in 30 days'),
            (
              'Payment setup',
              summary.planCount,
              '${summary.processedWebhooks} webhook events processed'
            ),
          ];
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (label, value, detail) in cards)
              Container(
                  width: width,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE4E9F0)),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontSize: 11, color: BrandColors.muted)),
                        const SizedBox(height: 5),
                        Text('$value',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: BrandColors.navy)),
                        Text(detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: BrandColors.muted)),
                      ])),
          ]);
        }),
      );
}

class AdminJobsScreen extends ConsumerStatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  ConsumerState<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends ConsumerState<AdminJobsScreen> {
  final _search = TextEditingController();
  final Set<String> _publishingJobIds = {};
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (page: _page, search: _search.text.trim());
    final jobs = ref.watch(adminJobsProvider(query));
    final linkedIn = ref.watch(adminCompanyLinkedInStatusProvider);
    return _AdminPage(
      title: 'All jobs',
      subtitle: 'Review job postings across the platform.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _LinkedInConnectionCard(
          status: linkedIn,
          onConnect: _connectCompanyLinkedIn,
          onRefresh: () => ref.invalidate(adminCompanyLinkedInStatusProvider),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() => _page = 1),
          decoration:
              _adminSearchDecoration('Search title, company, or location'),
        ),
        const SizedBox(height: 14),
        jobs.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: _friendlyError(error),
            onRetry: () => ref.invalidate(adminJobsProvider(query)),
          ),
          data: (result) => result.items.isEmpty
              ? const _EmptyState(
                  title: 'No jobs found',
                  message: 'Try another search or check back later.',
                )
              : Column(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${result.total} jobs',
                        style: const TextStyle(
                            color: BrandColors.muted, fontSize: 12)),
                  ),
                  const SizedBox(height: 9),
                  for (final job in result.items)
                    _AdminJobCard(
                      job: job,
                      linkedInConnected:
                          linkedIn.valueOrNull?.connected == true,
                      isPublishing: _publishingJobIds.contains(job.id),
                      onPromote: () => _promoteJob(job),
                    ),
                  _PageControls(
                    page: result.page,
                    totalPages: result.totalPages,
                    onPrevious:
                        result.page > 1 ? () => setState(() => _page--) : null,
                    onNext: result.page < result.totalPages
                        ? () => setState(() => _page++)
                        : null,
                  ),
                ]),
        ),
      ]),
    );
  }

  Future<void> _connectCompanyLinkedIn() async {
    try {
      final uri = await ref
          .read(adminRepositoryProvider)
          .getCompanyLinkedInAuthorizationUrl();
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened && mounted) {
        AppToast.error(context, 'Could not open LinkedIn authorization.');
      }
    } catch (error) {
      if (mounted) AppToast.error(context, _friendlyError(error));
    }
  }

  Future<void> _promoteJob(AdminJobRecord job) async {
    if (_publishingJobIds.contains(job.id)) return;
    var confirmRetry = false;
    if (job.linkedInPromotionStatus == 'needs_review') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Check LinkedIn before retrying'),
          content: const Text(
              'LinkedIn did not confirm whether the first post was created. Check the company Page feed. Retrying without checking could publish a duplicate.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('I checked — retry'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      confirmRetry = true;
    }
    setState(() => _publishingJobIds.add(job.id));
    try {
      await ref
          .read(adminRepositoryProvider)
          .publishJobToCompanyLinkedIn(job.id, confirmRetry: confirmRetry);
      ref.invalidate(
          adminJobsProvider((page: _page, search: _search.text.trim())));
      if (mounted) AppToast.success(context, 'Job published to LinkedIn.');
    } catch (error) {
      ref.invalidate(
          adminJobsProvider((page: _page, search: _search.text.trim())));
      if (mounted) AppToast.error(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _publishingJobIds.remove(job.id));
    }
  }
}

class AdminTicketsScreen extends ConsumerStatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  ConsumerState<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends ConsumerState<AdminTicketsScreen> {
  static const _filters = <(String, String)>[
    ('All', 'all'),
    ('Open', 'open'),
    ('In progress', 'in_progress'),
    ('Resolved', 'resolved'),
  ];

  String _status = 'all';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final query = (page: _page, status: _status);
    final tickets = ref.watch(adminTicketsProvider(query));
    return _AdminPage(
      title: 'Tickets & complaints',
      subtitle: 'Review user reports, respond, and track resolution.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in _filters)
              ChoiceChip(
                label: Text(label),
                selected: _status == value,
                onSelected: (_) => setState(() {
                  _status = value;
                  _page = 1;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        tickets.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: _friendlyError(error),
            onRetry: () => ref.invalidate(adminTicketsProvider(query)),
          ),
          data: (result) => result.items.isEmpty
              ? const _EmptyState(
                  title: 'No tickets in this view',
                  message:
                      'User complaints and support requests will appear here.',
                )
              : Column(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${result.total} tickets',
                        style: const TextStyle(
                            color: BrandColors.muted, fontSize: 12)),
                  ),
                  const SizedBox(height: 9),
                  for (final ticket in result.items)
                    _AdminTicketCard(
                      ticket: ticket,
                      onStatusChanged: (status) =>
                          _changeTicketStatus(ticket, status),
                      onReply: () => _replyToTicket(ticket),
                    ),
                  _PageControls(
                    page: result.page,
                    totalPages: result.totalPages,
                    onPrevious:
                        result.page > 1 ? () => setState(() => _page--) : null,
                    onNext: result.page < result.totalPages
                        ? () => setState(() => _page++)
                        : null,
                  ),
                ]),
        ),
      ]),
    );
  }

  Future<void> _changeTicketStatus(
      AdminTicketRecord ticket, String status) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateTicketStatus(ticket.id, status);
      ref.invalidate(adminTicketsProvider);
      if (mounted) AppToast.success(context, 'Ticket status updated.');
    } catch (error) {
      if (mounted) AppToast.error(context, _friendlyError(error));
    }
  }

  Future<void> _replyToTicket(AdminTicketRecord ticket) async {
    final controller = TextEditingController();
    final reply = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ticket.subject),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ticket.requesterName} · ${ticket.requesterEmail}',
                    style: const TextStyle(
                        color: BrandColors.muted, fontSize: 12)),
                const SizedBox(height: 12),
                Text(ticket.message),
                if (ticket.replies.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Previous replies',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final item in ticket.replies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${item.author}: ${item.body}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Reply to user',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(dialogContext, text);
            },
            child: const Text('Send reply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reply == null || !mounted) return;
    try {
      await ref.read(adminRepositoryProvider).addTicketReply(ticket.id, reply);
      ref.invalidate(adminTicketsProvider);
      if (mounted) AppToast.success(context, 'Reply added to ticket.');
    } catch (error) {
      if (mounted) AppToast.error(context, _friendlyError(error));
    }
  }
}

class _LinkedInConnectionCard extends StatelessWidget {
  const _LinkedInConnectionCard({
    required this.status,
    required this.onConnect,
    required this.onRefresh,
  });

  final AsyncValue<AdminLinkedInStatus> status;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E9F0)),
        ),
        child: status.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, _) => Row(children: [
            const Icon(Icons.error_outline, color: Color(0xFFB42318)),
            const SizedBox(width: 8),
            Expanded(child: Text(_friendlyError(error))),
            IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          ]),
          data: (value) {
            final configured = value.readyToConnect;
            final connectionText = value.connected
                ? 'Connected to the Pincef company Page'
                : value.expired
                    ? 'LinkedIn access expired. Reconnect the company Page.'
                    : configured
                        ? 'Connect the company Page to publish approved job promotions.'
                        : 'Company Page publishing needs backend configuration.';
            final missing = <String>[
              if (!value.appConfigured) 'LinkedIn OAuth app and callback URL',
              if (!value.organizationConfigured)
                'company Page organization URN',
              if (!value.encryptionConfigured) 'token encryption key',
            ];
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business_outlined,
                          color: BrandColors.navy),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LinkedIn company Page',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: BrandColors.navy)),
                            const SizedBox(height: 3),
                            Text(connectionText,
                                style: const TextStyle(
                                    color: BrandColors.muted, fontSize: 12)),
                            if (missing.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text('Configure: ${missing.join(', ')}',
                                  style: const TextStyle(
                                      color: BrandColors.muted, fontSize: 11)),
                            ],
                            if (value.connected && value.expiresAt != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                  'Authorization expires ${_formatDate(value.expiresAt!.toLocal().toIso8601String())}',
                                  style: const TextStyle(
                                      color: BrandColors.muted, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(spacing: 8, children: [
                  IconButton(
                    tooltip: 'Refresh LinkedIn status',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  OutlinedButton.icon(
                    onPressed: configured ? onConnect : null,
                    icon: const Icon(Icons.link, size: 17),
                    label: Text(
                        value.connected ? 'Reconnect Page' : 'Connect Page'),
                  ),
                ]),
              ],
            );
          },
        ),
      );
}

class _AdminJobCard extends StatelessWidget {
  const _AdminJobCard({
    required this.job,
    required this.linkedInConnected,
    required this.isPublishing,
    required this.onPromote,
  });

  final AdminJobRecord job;
  final bool linkedInConnected;
  final bool isPublishing;
  final VoidCallback onPromote;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: job.title,
        subtitle: '${job.companyName} · ${job.location}',
        leading: Icons.work_outline,
        trailing: _StatusPill(text: job.status),
        footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                job.createdAt == null
                    ? 'Posted date unavailable'
                    : 'Posted ${_formatDate(job.createdAt!.toIso8601String())}',
                style: const TextStyle(fontSize: 12, color: BrandColors.muted),
              ),
            ),
            Text('${job.applicantCount} applicants',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.navy)),
          ]),
          if (job.promoteOnLinkedIn) ...[
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusPill(
                    text: job.linkedInPromotionStatus == 'published'
                        ? 'LinkedIn published'
                        : job.linkedInPromotionStatus == 'publishing'
                            ? 'Publishing to LinkedIn'
                            : job.linkedInPromotionStatus == 'failed'
                                ? 'LinkedIn failed'
                                : job.linkedInPromotionStatus == 'needs_review'
                                    ? 'Check Page before retry'
                                    : 'LinkedIn requested'),
                if (job.status.toLowerCase() == 'published' &&
                    job.linkedInPromotionStatus != 'published')
                  OutlinedButton.icon(
                    onPressed:
                        linkedInConnected && !isPublishing ? onPromote : null,
                    icon: isPublishing
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.campaign_outlined, size: 16),
                    label: Text(isPublishing
                        ? 'Publishing…'
                        : job.linkedInPromotionStatus == 'needs_review'
                            ? 'Retry after checking'
                            : job.linkedInPromotionStatus == 'failed'
                                ? 'Retry LinkedIn post'
                                : 'Publish on LinkedIn'),
                  ),
              ],
            ),
            if (job.linkedInPromotionError?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(job.linkedInPromotionError!,
                    style: const TextStyle(
                        color: Color(0xFFB42318), fontSize: 11)),
              ),
          ],
        ]),
      );
}

class _AdminTicketCard extends StatelessWidget {
  const _AdminTicketCard({
    required this.ticket,
    required this.onStatusChanged,
    required this.onReply,
  });

  final AdminTicketRecord ticket;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: ticket.subject,
        subtitle: '${ticket.requesterName} · ${ticket.requesterEmail}',
        leading: Icons.support_agent_outlined,
        trailing: _StatusPill(text: ticket.priority),
        footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(ticket.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: BrandColors.muted)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                  '${ticket.category} · ${ticket.status.replaceAll('_', ' ')}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: BrandColors.navy,
                      fontWeight: FontWeight.w600)),
            ),
            DropdownButton<String>(
              value: const ['open', 'in_progress', 'resolved']
                      .contains(ticket.status)
                  ? ticket.status
                  : 'open',
              underline: const SizedBox.shrink(),
              isDense: true,
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(
                    value: 'in_progress', child: Text('In progress')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              ],
              onChanged: (status) {
                if (status != null && status != ticket.status) {
                  onStatusChanged(status);
                }
              },
            ),
            TextButton.icon(
              onPressed: onReply,
              icon: const Icon(Icons.reply_outlined, size: 16),
              label: const Text('Reply'),
            ),
          ]),
        ]),
      );
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Page $page of $totalPages',
              style: const TextStyle(color: BrandColors.muted, fontSize: 12)),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Previous page',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
      );
}

InputDecoration _adminSearchDecoration(String hint) => InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E9F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E9F0)),
      ),
    );

class _AdminPage extends StatelessWidget {
  const _AdminPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF5F7FB),
        child: LayoutBuilder(builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 850 ? 30.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: BrandColors.navy,
                        )),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 14, color: BrandColors.muted)),
                    const SizedBox(height: 16),
                    child,
                  ],
                ),
              ),
            ),
          );
        }),
      );
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE4E9F0)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: BrandColors.orange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: const TextStyle(
                            color: BrandColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: BrandColors.muted),
            ]),
          ),
        ),
      );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.onStatusChanged,
  });

  final AdminUserRecord user;
  final bool isCurrentUser;
  final VoidCallback onStatusChanged;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: user.name,
        subtitle: user.email,
        leading: Icons.person_outline,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusPill(text: user.isSuspended ? 'Suspended' : 'Active'),
            const SizedBox(height: 6),
            Text(user.role, style: const TextStyle(fontSize: 11)),
          ],
        ),
        footer: Row(children: [
          if (user.company?.isNotEmpty == true)
            Expanded(
              child: Text('Company: ${user.company}',
                  style:
                      const TextStyle(fontSize: 12, color: BrandColors.muted)),
            )
          else
            const Spacer(),
          if (!isCurrentUser)
            TextButton.icon(
              onPressed: onStatusChanged,
              icon: Icon(
                user.isSuspended ? Icons.check_circle_outline : Icons.block,
                size: 16,
              ),
              label: Text(user.isSuspended ? 'Reactivate' : 'Suspend'),
              style: TextButton.styleFrom(
                foregroundColor: user.isSuspended
                    ? const Color(0xFF087F5B)
                    : const Color(0xFFB42318),
              ),
            ),
        ]),
      );
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final AdminSubscriptionRecord subscription;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: subscription.accountName,
        subtitle: [
          subscription.email,
          subscription.subscriberType,
          subscription.provider
        ].where((value) => value != null && value.isNotEmpty).join(' · '),
        leading: Icons.credit_card_outlined,
        trailing: _StatusPill(text: subscription.status),
        footer: Row(children: [
          Expanded(
            child: Text('Plan: ${subscription.plan}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.navy)),
          ),
          if (subscription.renewsAt != null)
            Flexible(
              child: Text(
                '${subscription.cancelAtPeriodEnd ? 'Ends' : 'Next billing'}: ${_formatDate(subscription.renewsAt!)}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, color: BrandColors.muted),
              ),
            ),
        ]),
      );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.trailing,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final IconData leading;
  final Widget trailing;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE4E9F0)),
        ),
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFF0E8),
              child: Icon(leading, color: BrandColors.orange, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: BrandColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ]),
          const Divider(height: 22),
          footer,
        ]),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final normalized = text.toLowerCase();
    final positive = normalized == 'active' || normalized == 'trialing';
    final color = positive
        ? const Color(0xFF087F5B)
        : normalized == 'suspended' || normalized == 'canceled'
            ? const Color(0xFFB42318)
            : const Color(0xFF8A5A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.isEmpty
            ? 'Unknown'
            : '${text[0].toUpperCase()}${text.substring(1)}',
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _MessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load admin data',
        message: message,
        action: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => _MessageCard(
        icon: Icons.inbox_outlined,
        title: title,
        message: message,
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E9F0)),
        ),
        child: Column(children: [
          Icon(icon, size: 30, color: BrandColors.muted),
          const SizedBox(height: 10),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BrandColors.muted, fontSize: 12)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

String _friendlyError(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();

String _formatDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
