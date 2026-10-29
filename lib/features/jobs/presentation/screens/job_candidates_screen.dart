import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brand_color.dart';
import '../../application/job_management_provider.dart';
// NOTE: adjust this path if the applications feature folder is named
// differently in your project — this assumes
// features/applications/application/application_provider.dart, a sibling
// of features/jobs, based on the relative imports inside
// application_provider.dart itself (same depth as job_management_provider.dart).
import '../../application/application_provider.dart';
import '../../data/models/application_model.dart';
import '../../data/models/job_management_model.dart';
import 'package:talentbridge/features/jobs/presentation/widgets/download_cv_button.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:talentbridge/features/jobs/presentation/widgets/candidate_email_dialog.dart';
import 'package:talentbridge/features/jobs/presentation/widgets/send_invite_widget.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
// "Message" button — reuses the same socket-backed messaging repository/
// providers as the Messages screens, so a thread started here shows up
// there (and in the candidate's inbox) with no separate code path.
import 'package:talentbridge/features/messages/application/messages_provider.dart'
    show
        messagesRepositoryProvider,
        selectedMessageThreadProvider,
        messageThreadsProvider;

/// Recruiter-only applications view. Backed by live data from
/// GET /applications/job/:jobId via [jobApplicantsProvider] — no more local
/// placeholder candidates.
class JobCandidatesScreen extends ConsumerStatefulWidget {
  const JobCandidatesScreen({
    super.key,
    required this.jobId,
    this.keepCandidatesVisible = false,
  });

  final String jobId;
  final bool keepCandidatesVisible;

  @override
  ConsumerState<JobCandidatesScreen> createState() =>
      _JobCandidatesScreenState();
}

class _JobCandidatesScreenState extends ConsumerState<JobCandidatesScreen> {
  String _search = '';
  ApplicationBackendStatus? _statusFilter; // null = all statuses
  bool _newestFirst = true;
  final _scrollController = ScrollController();
  bool _deadlineRedirectQueued = false;

  /// Get-or-create a conversation for this applicant, then hand off to the
  /// Messages screen with that thread already selected — the candidate
  /// sees the same thread appear in their own inbox the moment it exists,
  /// no separate "send a message" flow needed here.
  Future<void> _startMessage(JobApplicantSummary applicant) async {
    try {
      final conversationId = await ref
          .read(messagesRepositoryProvider)
          .startConversationForApplication(applicant.id);
      if (!mounted) return;
      // Force a fresh fetch rather than relying on messageThreadsProvider's
      // autoDispose timing — that's a safety net for the general case, not
      // a guarantee at this exact instant. Invalidating here means the
      // conversation we just created is definitely in the list by the time
      // MessagesScreen reads it, not "probably, if it happened to dispose."
      ref.invalidate(messageThreadsProvider);
      ref.read(selectedMessageThreadProvider.notifier).state = conversationId;
      context.go('/messages');
    } catch (e) {
      if (mounted) AppToast.error(context, "Couldn't start a conversation: $e");
    }
  }

  Future<void> _setCandidateDecision(
    JobApplicantSummary applicant,
    ApplicationBackendStatus status,
  ) async {
    final isReject = status == ApplicationBackendStatus.rejected;
    if (isReject) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject candidate?'),
          content: Text(
              'This will mark ${applicant.candidate.fullName} as not selected and send them an application update email.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reject candidate')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      final emailSent = await ref
          .read(applicationsRepositoryProvider)
          .updateApplicationStatus(applicant.id, status);
      if (!mounted) return;
      await ref.read(jobApplicantsProvider(widget.jobId).notifier).refresh();
      if (!mounted) return;
      if (status != ApplicationBackendStatus.submitted && !emailSent) {
        AppToast.info(context,
            'Status updated. The email could not be delivered; try again later.');
      } else {
        AppToast.success(
            context,
            isReject
                ? 'Candidate rejected and notified.'
                : 'Candidate shortlisted.');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, "Couldn't update candidate: $e");
    }
  }

  static const _avatarPalette = [
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFFF97316),
    Color(0xFF10B981),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
  ];

  Color _colorForName(String name) =>
      _avatarPalette[name.hashCode.abs() % _avatarPalette.length];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll-triggered pagination: fires loadMore once the user is within
  /// ~400px of the bottom, instead of showing a "Load more" button. Guards
  /// inside JobApplicantsNotifier.loadMore already no-op while a page is
  /// in flight or there's nothing left, so this can fire on every scroll
  /// tick without extra bookkeeping here.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(jobApplicantsProvider(widget.jobId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final jobTitle = jobAsync.maybeWhen(
      data: (job) => job.title,
      orElse: () => 'this role',
    );
    final user = ref.watch(authProvider).user;
    jobAsync.whenData((job) {
      final jobClosed = job.status == JobBackendStatus.closed;
      final deadlinePassed = job.status != JobBackendStatus.draft &&
          job.applicationDeadline != null &&
          !job.applicationDeadline!.isAfter(DateTime.now());
      final shouldShowAiReview = job.aiRanking || job.aiSummary;
      if ((jobClosed || deadlinePassed) &&
          shouldShowAiReview &&
          !widget.keepCandidatesVisible &&
          !_deadlineRedirectQueued) {
        _deadlineRedirectQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.replace(
              '/jobs/${widget.jobId}/candidate-ranking',
              extra: {
                'originRoute': '/jobs/${widget.jobId}/candidates',
                'originLabel': 'Candidates',
              },
            );
          }
        });
      }
    });
    final applicantsState = ref.watch(jobApplicantsProvider(widget.jobId));
    final canMessageCandidates =
        user?.capabilities['allowsCandidateMessaging'] == true ||
            user?.hasModule('hiring.candidate.messaging') == true;
    final notifier = ref.read(jobApplicantsProvider(widget.jobId).notifier);

    final query = _search.trim().toLowerCase();
    final visible = applicantsState.applications.where((applicant) {
      final matchesSearch = query.isEmpty ||
          applicant.candidate.fullName.toLowerCase().contains(query) ||
          applicant.candidate.email.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == null || applicant.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList()
      ..sort((a, b) => _newestFirst
          ? b.appliedAt.compareTo(a.appliedAt)
          : a.appliedAt.compareTo(b.appliedAt));

    final newCount = applicantsState.applications
        .where((a) => a.status == ApplicationBackendStatus.submitted)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final columns = constraints.maxWidth >= 1100
            ? 3
            : (constraints.maxWidth >= 760 ? 2 : 1);
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _breadcrumb(jobTitle),
                const SizedBox(height: 14),
                _header(isWide, jobTitle, applicantsState.total, newCount),
                const SizedBox(height: 12),
                _interviewAutomationBanner(
                  ref.watch(pendingInterviewAutomationProvider(widget.jobId)),
                ),
                const SizedBox(height: 20),
                _insightsRow(jobAsync, applicantsState),
                const SizedBox(height: 18),
                _filters(isWide, notifier),
                const SizedBox(height: 14),
                _body(applicantsState, visible, columns, notifier,
                    canMessageCandidates),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Breadcrumb: lets the recruiter step back to Jobs / this job ----------

  Widget _breadcrumb(String jobTitle) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _crumbLink('Jobs', () => context.go('/jobs')),
          _crumbDivider(),
          _crumbLink('Job details', () => context.go('/jobs/${widget.jobId}')),
          _crumbDivider(),
          Flexible(
            child: Text(
              jobTitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: BrandColors.navy,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

  Widget _crumbLink(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Text(label,
            style: const TextStyle(
                fontSize: 11.5,
                color: BrandColors.muted,
                fontWeight: FontWeight.w600)),
      );

  Widget _crumbDivider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('/',
            style: TextStyle(fontSize: 11.5, color: BrandColors.muted)),
      );

  // --- Main content switch: loading / error / empty / grid -----------------

  Widget _body(
    JobApplicantsState state,
    List<JobApplicantSummary> visible,
    int columns,
    JobApplicantsNotifier notifier,
    bool canMessageCandidates,
  ) {
    if (state.isLoading && state.applications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null && state.applications.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: notifier.refresh);
    }
    if (visible.isEmpty) {
      return const _EmptyCandidates();
    }
    // +1 slot for the trailing "Add Candidate" placeholder card from the
    // mockup — it isn't a real applicant, so it's appended after the real
    // items rather than folded into JobApplicantSummary.
    final itemCount = visible.length + 1;
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 250,
          ),
          itemBuilder: (context, index) {
            if (index == visible.length) {
              return _AddCandidateCard(onTap: () {
                AppToast.info(
                    context, 'Manually adding a candidate is coming soon.');
              });
            }
            return _CandidateCard(
              applicant: visible[index],
              avatarColor: _colorForName(visible[index].candidate.fullName),
              onViewProfile: () => context.push(
                // NOTE: the old placeholder comment here suggested
                // visible[index].id (the *application* id) — the route
                // param is candidateId, which is visible[index].candidate.id.
                '/jobs/${widget.jobId}/candidates/${visible[index].candidate.id}',
                extra: visible[index],
              ),
              onSendEmail: () async {
                final sent = await showCandidateEmailDialog(
                  context,
                  applicant: visible[index],
                );
                if (sent == true && context.mounted) {
                  AppToast.success(context,
                      'Email sent to ${visible[index].candidate.fullName}.');
                }
              },
              onInvite: () async {
                final sent = await showSendInterviewInviteDialog(
                  context,
                  applicant: visible[index],
                );
                if (sent == true && context.mounted) {
                  await ref
                      .read(jobApplicantsProvider(widget.jobId).notifier)
                      .refresh();
                  if (context.mounted) {
                    AppToast.success(context,
                        'Interview invitation sent to ${visible[index].candidate.fullName}.');
                  }
                }
              },
              onMessage: () => _startMessage(visible[index]),
              onDecision: (status) =>
                  _setCandidateDecision(visible[index], status),
              canMessage: canMessageCandidates,
            );
          },
        ),
        // Scroll-triggered pagination (see _onScroll) replaces the old
        // "Load more" button, which never appeared in the mockup. The
        // spinner still surfaces while the next page is in flight so the
        // recruiter gets feedback near the bottom of the grid.
        if (state.isLoadingMore) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 16),
        // The mockup shows numbered page buttons ("1 2 3 >") — that needs
        // a goToPage() on JobApplicantsNotifier, which isn't confirmed to
        // exist alongside loadMore()/refresh(). This keeps the real count
        // without inventing page-jump controls that might not do anything.
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Showing ${visible.length} of ${state.total} candidates',
              style: const TextStyle(fontSize: 11.5, color: BrandColors.muted)),
        ),
      ],
    );
  }

  Widget _interviewAutomationBanner(
    AsyncValue<Map<String, dynamic>?> pending,
  ) {
    return pending.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (action) {
        if (action == null) return const SizedBox.shrink();
        final count = action['candidateCount'] ?? 0;
        final stage = action['stageName'] ?? 'Interview';
        final due = DateTime.tryParse('${action['dueAt']}')?.toLocal();
        final dueText = due == null
            ? 'soon'
            : '${due.day}/${due.month} at ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            border: Border.all(color: const Color(0xFFFED7AA)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: BrandColors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI plans to invite $count top-ranked candidates to $stage at $dueText. If you take no action, it will proceed automatically.',
                style: const TextStyle(
                    fontSize: 12, color: BrandColors.navy, height: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => _takeOverInterviewAutomation(),
              child: const Text('Take over'),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _takeOverInterviewAutomation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take over interview invitations?'),
        content: const Text(
            'This stops the pending automatic invitations. You can then send invitations manually from each candidate card.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep automation')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Take over')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(jobManagementRepositoryProvider)
          .takeOverInterviewAutomation(widget.jobId);
      ref.invalidate(pendingInterviewAutomationProvider(widget.jobId));
      if (mounted) {
        AppToast.success(
            context, 'Automatic invitations stopped. You are in control.');
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, "Couldn't take over automation: $error");
      }
    }
  }

  // --- Header: title/subtitle + stat chips ----------------------------------

  Widget _header(bool isWide, String jobTitle, int total, int newCount) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.start,
        spacing: 16,
        runSpacing: 12,
        children: [
          SizedBox(
            width: isWide ? 460 : double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Candidates Directory',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.navy)),
                const SizedBox(height: 4),
                Text('Applications for $jobTitle',
                    style: const TextStyle(
                        fontSize: 12.5, color: BrandColors.muted)),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(
                value: '$total',
                label: 'TOTAL APPLICANTS',
                icon: Icons.groups_outlined,
                color: const Color(0xFF16A34A),
              ),
              _StatChip(
                value: '$newCount',
                label: 'NEW',
                icon: Icons.person_add_alt_1_outlined,
                color: BrandColors.orange,
              ),
            ],
          ),
        ],
      );

  // --- Smart Match Insights + Advanced Search cards -------------------------

  Widget _insightsRow(AsyncValue jobAsync, JobApplicantsState state) {
    final job = jobAsync.maybeWhen(data: (j) => j, orElse: () => null);
    // Advanced Search removed — it was a "coming soon" placeholder with no
    // backend behind it. Smart Match Insights now takes the full row
    // instead of sharing it with an empty-feeling second column.
    return _SmartMatchCard(job: job, state: state);
  }

  // --- Filter bar -------------------------------------------------------------

  Widget _filters(bool isWide, JobApplicantsNotifier notifier) {
    final searchField = _labeledField(
      label: 'SEARCH',
      child: TextField(
        onChanged: (value) => setState(() => _search = value),
        style: const TextStyle(fontSize: 12.5),
        decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: 'Name or email',
            hintStyle: TextStyle(fontSize: 12.5),
            prefixIcon: Icon(Icons.search, size: 18, color: BrandColors.muted),
            contentPadding: EdgeInsets.symmetric(vertical: 12)),
      ),
    );
    final refreshButton = SizedBox(
      height: 42,
      width: 42,
      child: ElevatedButton(
        onPressed: notifier.refresh,
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Icon(Icons.refresh, size: 18),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.orange.withValues(alpha: .25))),
      // On wide screens each field gets an equal Expanded share so the row
      // fills edge-to-edge like the mockup, instead of the old fixed
      // 220/160/150px widths that left a dead gap before the button. Narrow
      // screens keep the wrapping wrap-and-stack layout since Expanded
      // inside a Row can't wrap.
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                Expanded(child: _statusDropdown()),
                const SizedBox(width: 12),
                Expanded(child: _sortDropdown()),
                const SizedBox(width: 12),
                refreshButton,
              ],
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(width: double.infinity, child: searchField),
                SizedBox(width: double.infinity, child: _statusDropdown()),
                SizedBox(width: double.infinity, child: _sortDropdown()),
                refreshButton,
              ],
            ),
    );
  }

  /// Light-gray-filled field with a small orange uppercase label above it —
  /// the mockup's SKILLS/LOCATION/EXPERIENCE styling, reused here for the
  /// real filters (search/status/sort) this screen actually has data for.
  /// No fixed width here anymore — the caller controls sizing (Expanded on
  /// wide screens, a SizedBox(width: double.infinity) on narrow ones).
  Widget _labeledField({required String label, required Widget child}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: BrandColors.orange)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8)),
            child: child,
          ),
        ],
      );

  Widget _statusDropdown() => _labeledField(
        label: 'STATUS',
        child: DropdownButtonFormField<ApplicationBackendStatus?>(
          initialValue: _statusFilter,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(fontSize: 12.5, color: BrandColors.navy),
          decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
          onChanged: (value) => setState(() => _statusFilter = value),
          items: [
            const DropdownMenuItem(
                value: null,
                child: Text('All statuses', style: TextStyle(fontSize: 12))),
            ...ApplicationBackendStatus.values.map((status) => DropdownMenuItem(
                  value: status,
                  child:
                      Text(status.label, style: const TextStyle(fontSize: 12)),
                )),
          ],
        ),
      );

  Widget _sortDropdown() => _labeledField(
        label: 'SORT',
        child: DropdownButtonFormField<bool>(
          initialValue: _newestFirst,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(fontSize: 12.5, color: BrandColors.navy),
          decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
          onChanged: (value) => setState(() => _newestFirst = value ?? true),
          items: const [
            DropdownMenuItem(
                value: true,
                child: Text('Newest first', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(
                value: false,
                child: Text('Oldest first', style: TextStyle(fontSize: 12))),
          ],
        ),
      );
}

// --- Header stat chip ---------------------------------------------------------

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: .8))),
          ]),
        ]),
      );
}

// --- Smart Match Insights card (now driven by real aiScore data) -------------

class _SmartMatchCard extends StatelessWidget {
  const _SmartMatchCard({required this.job, required this.state});
  final dynamic
      job; // JobDetail? — kept dynamic to avoid a model import cycle here
  final JobApplicantsState state;

  /// The mockup's copy ("...identified 12 high-priority candidates...")
  /// reads as a count of strong matches, not the total applicant count —
  /// so this counts real aiScore values above a "high-priority" bar
  /// instead of hardcoding a number that has nothing to do with the job
  /// actually loaded.
  static const _highPriorityThreshold = 80;

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];
    if (job != null) {
      if ((job.location as String).isNotEmpty &&
          job.location != 'Not specified') {
        tags.add(_Tag(
            label: (job.location as String).toUpperCase(),
            color: const Color(0xFF6366F1)));
      }
      final employmentLabel = job.employmentTypeLabel as String;
      if (employmentLabel != '—') {
        tags.add(_Tag(
            label: employmentLabel.toUpperCase(), color: BrandColors.orange));
      }
      final skills = job.requiredSkills as List<String>;
      if (skills.isNotEmpty) {
        tags.add(_Tag(
            label: skills.first.toUpperCase(), color: const Color(0xFF16A34A)));
      }
    }

    final highPriorityCount = state.applications
        .where((a) => (a.aiScore ?? 0) >= _highPriorityThreshold)
        .length;
    final jobTitle = job != null ? "'${job.title}'" : 'this';
    final locationPhrase = job != null && (job.location as String).isNotEmpty
        ? ' in ${job.location}'
        : '';
    final copy = highPriorityCount > 0
        ? 'Our AI-driven matching engine has identified $highPriorityCount '
            'high-priority candidate${highPriorityCount == 1 ? '' : 's'} for '
            'the $jobTitle role$locationPhrase based on recent profile '
            'updates.'
        : "Automated candidate matching isn't wired up yet — for now, "
            "review each applicant's CV and status below as they come in.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Smart Match Insights',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.navy)),
          const SizedBox(height: 8),
          Text(
            copy,
            style: const TextStyle(
                fontSize: 12, height: 1.5, color: BrandColors.muted),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: tags),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

// --- Match score bar (aiScore) ------------------------------------------------

class _MatchScoreBar extends StatelessWidget {
  const _MatchScoreBar({required this.score});
  final int score;

  Color get _color {
    if (score >= 85) return const Color(0xFF16A34A);
    if (score >= 60) return BrandColors.orange;
    return BrandColors.muted;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('MATCH SCORE',
                  style: TextStyle(
                      fontSize: 8.5,
                      color: BrandColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
              Text('$score%',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 5,
              backgroundColor: BrandColors.iconBg,
              color: _color,
            ),
          ),
        ],
      );
}

// --- Candidate avatar: photo when available, initials otherwise ----------

/// Shows [imageUrl] when there is one; falls back to the initials bubble
/// when there isn't, or if the image fails to load (broken/expired
/// Cloudinary URL, offline, etc.) — `CircleAvatar.backgroundImage` doesn't
/// fall back to `child` automatically on error, so that's tracked here
/// with a small bit of state instead.
class _CandidateAvatar extends StatefulWidget {
  const _CandidateAvatar({
    required this.imageUrl,
    required this.initials,
    required this.color,
  }) : radius = 20;

  final String? imageUrl;
  final String initials;
  final Color color;
  final double radius;

  @override
  State<_CandidateAvatar> createState() => _CandidateAvatarState();
}

class _CandidateAvatarState extends State<_CandidateAvatar> {
  bool _failedToLoad = false;

  @override
  void didUpdateWidget(covariant _CandidateAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled card (e.g. list re-sort) could get handed a different
    // candidate's URL — don't keep showing initials from a previous,
    // unrelated failure.
    if (oldWidget.imageUrl != widget.imageUrl) _failedToLoad = false;
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    final hasImage = url != null && url.isNotEmpty && !_failedToLoad;

    if (!hasImage) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.color.withValues(alpha: .18),
        child: Text(
          widget.initials,
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13, color: widget.color),
        ),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.color.withValues(alpha: .18),
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {
        if (mounted) setState(() => _failedToLoad = true);
      },
    );
  }
}

// --- Candidate card (live data) --------------------------------------------------

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.applicant,
    required this.avatarColor,
    required this.onViewProfile,
    required this.onSendEmail,
    required this.onInvite,
    required this.onMessage,
    required this.onDecision,
    required this.canMessage,
  });
  final JobApplicantSummary applicant;
  final Color avatarColor;
  final VoidCallback onViewProfile;
  final VoidCallback onSendEmail;
  final VoidCallback onInvite;
  final VoidCallback onMessage;
  final ValueChanged<ApplicationBackendStatus> onDecision;
  final bool canMessage;

  Color get _stageColor => switch (applicant.status) {
        ApplicationBackendStatus.submitted => const Color(0xFF2F6FED),
        ApplicationBackendStatus.shortlisted => const Color(0xFF7C3AED),
        ApplicationBackendStatus.interviewing => const Color(0xFF16A34A),
        ApplicationBackendStatus.offered => BrandColors.orange,
        ApplicationBackendStatus.rejected => const Color(0xFFDC2626),
        ApplicationBackendStatus.hired => BrandColors.navy,
      };

  @override
  Widget build(BuildContext context) {
    final candidate = applicant.candidate;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CandidateAvatar(
              imageUrl: candidate.profileImageUrl,
              initials: candidate.initials,
              color: avatarColor),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(candidate.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.navy)),
                const SizedBox(height: 2),
                Text(candidate.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: BrandColors.muted)),
              ])),
          SizedBox(
            width: 34,
            height: 34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: BrandColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: PopupMenuButton<ApplicationBackendStatus>(
                tooltip: 'Candidate decision',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz, size: 18),
                onSelected: onDecision,
                itemBuilder: (context) => [
                  if (applicant.status != ApplicationBackendStatus.shortlisted)
                    const PopupMenuItem(
                      value: ApplicationBackendStatus.shortlisted,
                      child: Text('Shortlist candidate'),
                    ),
                  if (applicant.status != ApplicationBackendStatus.rejected)
                    const PopupMenuItem(
                      value: ApplicationBackendStatus.rejected,
                      child: Text('Reject and email candidate'),
                    ),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Only the backend actually returns aiScore per application — when
        // it's null (older applications scored before this field existed)
        // the bar is skipped entirely rather than faking a number.
        if (applicant.aiScore != null) ...[
          _MatchScoreBar(score: applicant.aiScore!),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              color: _stageColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(applicant.status.label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _stageColor)),
        ),
        const SizedBox(height: 8),
        // Per-candidate skills aren't in GET /applications/job/:jobId
        // today (only aiScore/cvUrl/status/appliedAt) — this renders
        // whatever JobApplicantSummary.skills carries so it lights up the
        // moment the backend adds it, without showing fabricated tags in
        // the meantime.
        if (candidate.skills.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: candidate.skills
                .take(3)
                .map((skill) => _Tag(label: skill, color: avatarColor))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        Text('Applied ${applicant.appliedRelativeLabel}',
            style: const TextStyle(fontSize: 10.5, color: BrandColors.muted)),
        const Spacer(),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 34,
              child: ElevatedButton(
                // Open the full profile; a separate control downloads the
                // CV directly from this applicant card.
                onPressed: onViewProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View Profile',
                    style:
                        TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            height: 34,
            child: DownloadCvButton(
              url: applicant.cvUrl,
              fileName: '${candidate.fullName}_CV',
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            height: 34,
            child: Tooltip(
              message: 'Send interview invitation',
              child: OutlinedButton(
                onPressed: onInvite,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: BrandColors.orange,
                  side: const BorderSide(color: BrandColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.event_available_outlined, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            height: 34,
            child: Tooltip(
              message: 'Email candidate',
              child: OutlinedButton(
                // Opens a template-based email composer. Sending email is
                // separate from messaging and does not change pipeline stage.
                onPressed: onSendEmail,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: BrandColors.navy,
                  side: const BorderSide(color: BrandColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.mail_outline, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            height: 34,
            child: OutlinedButton(
              // Opens/reopens a direct conversation with this candidate —
              // distinct from the email-template composer above.
              onPressed: canMessage
                  ? onMessage
                  : () => AppToast.info(context,
                      'Candidate messaging is available on Pro and Business plans.'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: BrandColors.navy,
                side: const BorderSide(color: BrandColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Icon(
                  canMessage ? Icons.chat_bubble_outline : Icons.lock_outline,
                  size: 15),
            ),
          ),
        ]),
      ]),
    );
  }
}

// --- "Add Candidate" placeholder card, matches the dashed card in the mockup --

class _AddCandidateCard extends StatelessWidget {
  const _AddCandidateCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BrandColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: BrandColors.muted.withValues(alpha: .4),
                width: 1.4,
                strokeAlign: BorderSide.strokeAlignInside),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_add_alt_1_outlined,
                    size: 22, color: BrandColors.muted),
                SizedBox(height: 10),
                Text('Add Candidate',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy)),
                SizedBox(height: 4),
                Text(
                  'Upload CV or manually enter candidate details into the pipeline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: BrandColors.muted),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BrandColors.border)),
        child: Column(children: [
          const Icon(Icons.error_outline, size: 32, color: Color(0xFFDC2626)),
          const SizedBox(height: 10),
          const Text("Couldn't load candidates",
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: BrandColors.navy)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: BrandColors.muted)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.navy,
                foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ]),
      );
}

class _EmptyCandidates extends StatelessWidget {
  const _EmptyCandidates();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BrandColors.border)),
        child: const Column(children: [
          Icon(Icons.person_search_outlined,
              size: 34, color: BrandColors.muted),
          SizedBox(height: 10),
          Text('No candidates found',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: BrandColors.navy)),
          SizedBox(height: 4),
          Text('No one matches your current search or filters yet.',
              style: TextStyle(fontSize: 12, color: BrandColors.muted)),
        ]),
      );
}
