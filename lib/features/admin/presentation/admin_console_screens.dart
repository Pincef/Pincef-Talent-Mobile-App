import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import '../application/admin_provider.dart';
import '../data/admin_repository.dart';
import '../data/models/admin_models.dart';

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) => _AdminPage(
        title: 'Admin overview',
        subtitle: 'Manage platform users and subscription accounts.',
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
              icon: Icons.support_agent_outlined,
              title: 'Tickets',
              description: 'Review user complaints, reply, and update status.',
              onTap: () => context.go('/admin/tickets'),
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
              for (final card in cards) SizedBox(width: cardWidth, child: card),
            ],
          );
        }),
      );
}

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    final currentUser = ref.watch(authProvider).user;
    return _AdminPage(
      title: 'Users',
      subtitle: 'Review user accounts and manage access.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
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
          data: (records) {
            final query = _search.text.trim().toLowerCase();
            final filtered = records.where((user) {
              return query.isEmpty ||
                  user.name.toLowerCase().contains(query) ||
                  user.email.toLowerCase().contains(query) ||
                  user.role.toLowerCase().contains(query);
            }).toList();
            if (filtered.isEmpty) {
              return _EmptyState(
                title: query.isEmpty ? 'No users found' : 'No matching users',
                message: query.isEmpty
                    ? 'User accounts will appear here when the admin API is connected.'
                    : 'Try a different name, email, or role.',
              );
            }
            return Column(children: [
              for (final user in filtered)
                _UserCard(
                  user: user,
                  isCurrentUser: user.id == currentUser?.id ||
                      user.email.toLowerCase() ==
                          currentUser?.email.toLowerCase(),
                  onStatusChanged: () => _changeStatus(user),
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
      ref.invalidate(adminUsersProvider);
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
    return _AdminPage(
      title: 'Subscriptions',
      subtitle: 'View account plans and subscription status.',
      child: subscriptions.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          message: _friendlyError(error),
          onRetry: () => ref.invalidate(adminSubscriptionsProvider),
        ),
        data: (records) => records.isEmpty
            ? const _EmptyState(
                title: 'No subscriptions found',
                message:
                    'Subscription records will appear here when the admin API is connected.',
              )
            : Column(children: [
                for (final record in records)
                  _SubscriptionCard(subscription: record),
              ]),
      ),
    );
  }
}

class AdminJobsScreen extends ConsumerStatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  ConsumerState<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends ConsumerState<AdminJobsScreen> {
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
    final jobs = ref.watch(adminJobsProvider(query));
    return _AdminPage(
      title: 'All jobs',
      subtitle: 'Review job postings across the platform.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  for (final job in result.items) _AdminJobCard(job: job),
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

class _AdminJobCard extends StatelessWidget {
  const _AdminJobCard({required this.job});

  final AdminJobRecord job;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: job.title,
        subtitle: '${job.companyName} · ${job.location}',
        leading: Icons.work_outline,
        trailing: _StatusPill(text: job.status),
        footer: Row(children: [
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.science_outlined,
                              size: 14, color: BrandColors.orange),
                          SizedBox(width: 6),
                          Text(
                              'DEMO DATA · changes reset when the app restarts',
                              style: TextStyle(
                                  color: BrandColors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
        subtitle:
            subscription.email.isEmpty ? subscription.plan : subscription.email,
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
            Text('Renews: ${_formatDate(subscription.renewsAt!)}',
                style: const TextStyle(fontSize: 12, color: BrandColors.muted)),
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
        color: color.withOpacity(.09),
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
