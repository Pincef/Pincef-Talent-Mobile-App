import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:talentbridge/features/assessment/application/assessment_provider.dart';
import '../widgets/job_management_widget.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/job_management_model.dart';

class JobManagementScreen extends ConsumerStatefulWidget {
  const JobManagementScreen({super.key});

  @override
  ConsumerState<JobManagementScreen> createState() =>
      _JobManagementScreenState();
}

class _JobManagementScreenState extends ConsumerState<JobManagementScreen> {
  // UI-only for now — matches the stubbed search/sort pattern elsewhere.
  // Wire these to actually refetch once the real endpoint supports
  // filtering/pagination server-side.
  JobPostingTab _tab = JobPostingTab.active;
  int _postingPage = 1;
  String? _lastRouteStatus;
  bool _creatingDemo = false;

  Future<void> _createAutomationDemo() async {
    setState(() => _creatingDemo = true);
    String? jobId;
    String? assessmentId;
    const jobTitle = 'TalentBridge Demo: AI Operations Analyst';
    const purpose =
        'Assess workflow automation, data handling, and practical AI operations skills. Use objective questions with clear correct answers for automatic scoring.';
    final deadline = DateTime.now().add(const Duration(days: 14));
    final assessmentClose = deadline.add(const Duration(days: 7));

    try {
      final job = JobDraft(
        title: jobTitle,
        description:
            'This demonstration role is designed to exercise TalentBridge’s automated hiring workflow. The analyst will evaluate AI-assisted business processes, build reliable workflow automations, and measure quality using clear operational metrics.',
        employmentType: 'full_time',
        workplaceType: 'remote',
        industry: 'Technology',
        companyOverview:
            'TalentBridge automation demonstration job. This draft is for product evaluation.',
        location: 'Remote, Nigeria',
        currency: 'NGN',
        requiredSkills: const [
          'Workflow automation',
          'Data analysis',
          'Python',
          'AI operations',
        ],
        minYearsOfExperience: '3',
        educationLevel: 'bachelors',
        applicationDeadline: deadline,
        aiRanking: true,
        aiSummary: true,
        pipelineTier: 'Premium',
        rankingPlanTier: 'Premium',
        rankingLimit: 20,
        assessmentEmailCount: 15,
        interviewEmailCount: 10,
        responsibilities: const [
          'Design and maintain reliable workflow automations.',
          'Analyze operational data and communicate measurable improvements.',
          'Evaluate AI-assisted processes for accuracy and quality.',
        ],
        benefits: const ['Remote work', 'Professional development'],
      );
      jobId =
          await ref.read(jobManagementRepositoryProvider).createJobDraft(job);

      final assessmentRepository = ref.read(assessmentRepositoryProvider);
      final generated = await assessmentRepository.generate({
        'title': '$jobTitle assessment',
        'purpose': purpose,
        'generationMode': 'full_ai',
        'assessmentKind': 'internal',
        'deliveryChannel': 'email',
        'durationMinutes': 45,
        'passingScore': 75,
        'questions': <Map<String, dynamic>>[],
        'autoInviteShortlisted': true,
        'autoGenerateAfterDeadline': false,
        'jobId': jobId,
        'pipelineStageName': 'Assessment',
        'questionsPerSkill': 2,
      });
      final rawAssessmentId = generated['_id'] ?? generated['id'];
      if (rawAssessmentId == null) {
        throw StateError('The generated assessment did not include an ID.');
      }
      assessmentId = rawAssessmentId.toString();

      final questions = (generated['questions'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_serializeGeneratedQuestion)
          .toList();
      if (questions.isEmpty) {
        throw StateError('AI generation returned no assessment questions.');
      }

      await assessmentRepository.update(assessmentId, {
        'title': '$jobTitle assessment',
        'purpose': purpose,
        'generationMode': 'full_ai',
        'assessmentKind': 'internal',
        'deliveryChannel': 'email',
        'durationMinutes': 45,
        'passingScore': 75,
        'questions': questions,
        'autoInviteShortlisted': true,
        'autoGenerateAfterDeadline': true,
        'pipelineStageName': 'Assessment',
        'availableUntil': assessmentClose.toUtc().toIso8601String(),
      });

      ref.invalidate(jobManagementProvider);
      ref.invalidate(recruiterAssessmentsProvider);
      if (!mounted) return;
      AppToast.success(context,
          'Draft demo job and automated assessment created. Publish the job to start collecting applications.');
      context.go('/competency-assessments/$assessmentId');
    } catch (error) {
      if (!mounted) return;
      final message = jobId == null
          ? 'Could not create the demo job: $error'
          : assessmentId == null
              ? 'The demo job was created, but its AI assessment could not be generated: $error'
              : 'The demo job and assessment were created, but scheduling could not be saved: $error';
      AppToast.error(context, message);
      if (assessmentId != null) {
        context.go('/competency-assessments/$assessmentId');
      } else if (jobId != null) {
        context.go('/jobs/$jobId');
      }
    } finally {
      if (mounted) setState(() => _creatingDemo = false);
    }
  }

  Map<String, dynamic> _serializeGeneratedQuestion(
      Map<String, dynamic> question) {
    final type = question['type']?.toString() ?? 'multiple_choice';
    return {
      'questionId':
          question['questionId']?.toString() ?? UniqueKey().toString(),
      'text': question['text']?.toString() ?? '',
      'type': type,
      'skillCategory': question['skillCategory']?.toString() ?? 'General',
      'points': (question['points'] as num?)?.toInt() ?? 10,
      if (type != 'multiple_choice') ...{
        'referenceAnswer': question['referenceAnswer']?.toString().trim() ?? '',
        'gradingRubric': question['gradingRubric']?.toString().trim() ?? '',
      },
      if (type == 'multiple_choice') ...{
        'options': (question['options'] as List? ?? const [])
            .map((option) => option.toString().trim())
            .where((option) => option.isNotEmpty)
            .toList(),
        if (question['correctAnswer'] != null)
          'correctAnswer': question['correctAnswer'].toString().trim(),
      },
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeStatus =
        GoRouterState.of(context).uri.queryParameters['status'] ?? 'active';
    if (routeStatus == _lastRouteStatus) return;
    _lastRouteStatus = routeStatus;
    final nextTab = switch (routeStatus) {
      'closed' => JobPostingTab.closed,
      'pending' => JobPostingTab.pending,
      _ => JobPostingTab.active,
    };
    if (nextTab != _tab) {
      _tab = nextTab;
      _postingPage = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(jobManagementProvider.notifier)
            .load(tab: _toPipelineStatus(nextTab));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobManagementProvider);

    return _Body(
      state: state,
      tab: _tab,
      currentPage: _postingPage,
      onPageChanged: (page) => setState(() => _postingPage = page),
      onTabChanged: (tab) {
        final status = switch (tab) {
          JobPostingTab.active => 'active',
          JobPostingTab.pending => 'pending',
          JobPostingTab.closed => 'closed',
        };
        setState(() {
          _tab = tab;
          _postingPage = 1;
          _lastRouteStatus = status;
        });
        ref
            .read(jobManagementProvider.notifier)
            .load(tab: _toPipelineStatus(tab));
        context.go('/jobs?status=$status');
      },
      onRetry: () => ref.read(jobManagementProvider.notifier).load(),
      onPostJob: () => context.go('/jobs/new'),
      onCreateDemo: _createAutomationDemo,
      creatingDemo: _creatingDemo,
    );
  }

  JobPipelineStatus _toPipelineStatus(JobPostingTab tab) => switch (tab) {
        JobPostingTab.active => JobPipelineStatus.active,
        JobPostingTab.pending => JobPipelineStatus.drafting,
        JobPostingTab.closed => JobPipelineStatus.closed,
      };
}

class _Body extends StatelessWidget {
  const _Body(
      {required this.state,
      required this.tab,
      required this.currentPage,
      required this.onPageChanged,
      required this.onTabChanged,
      required this.onRetry,
      required this.onPostJob,
      required this.onCreateDemo,
      required this.creatingDemo});

  final JobManagementState state;
  final JobPostingTab tab;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<JobPostingTab> onTabChanged;
  final VoidCallback onRetry;
  final VoidCallback onPostJob;
  final VoidCallback onCreateDemo;
  final bool creatingDemo;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final summary = state.summary;
    if (summary == null) return const SizedBox.shrink();
    const pageSize = 6;
    final totalPages =
        (summary.postings.length / pageSize).ceil().clamp(1, 1 << 30).toInt();
    final page = currentPage.clamp(1, totalPages).toInt();
    final start = (page - 1) * pageSize;
    final postings = summary.postings.skip(start).take(pageSize);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final columns = constraints.maxWidth >= 1100
            ? 3
            : (constraints.maxWidth >= 760 ? 2 : 1);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isWide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: ActivePipelinesCard(
                                summary: summary.pipeline,
                                onPostJob: onPostJob),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: HiringEfficiencyCard(
                                efficiency: summary.efficiency),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        ActivePipelinesCard(
                            summary: summary.pipeline, onPostJob: onPostJob),
                        const SizedBox(height: 16),
                        HiringEfficiencyCard(efficiency: summary.efficiency),
                      ],
                    ),
              const SizedBox(height: 24),
              _AutomationDemoCard(
                onCreate: onCreateDemo,
                isCreating: creatingDemo,
              ),
              const SizedBox(height: 24),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                    child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                      const Text('Job Postings',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2A4E))),
                      JobPostingsHeader(
                          activeTab: tab,
                          activeCount: summary.activeTabCount,
                          pendingCount: summary.pendingTabCount,
                          closedCount: summary.closedTabCount,
                          onTabChanged: onTabChanged),
                    ])),
                if (isWide)
                  TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      label: const Text('Sort by: Recently Added'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          textStyle: const TextStyle(fontSize: 11))),
              ]),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
                children: [
                  ...postings.map((job) => JobPostingCard(job: job)),
                  PostNewJobCard(onTap: onPostJob),
                ],
              ),
              const SizedBox(height: 20),
              JobPostingsFooter(
                shownCount: postings.length,
                totalCount: summary.postings.length,
                currentPage: page,
                totalPages: totalPages,
                onPageChanged: onPageChanged,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _AutomationDemoCard extends StatelessWidget {
  const _AutomationDemoCard({
    required this.onCreate,
    required this.isCreating,
  });

  final VoidCallback onCreate;
  final bool isCreating;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F1),
          border: Border.all(color: const Color(0xFFFFD9B8)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          const content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Try the full automation flow',
                  style: TextStyle(
                      color: Color(0xFF1B2A4E),
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text(
                  'Creates a draft Premium job with AI ranking and a generated assessment. After you publish, shortlisted candidates are invited automatically at the deadline and their objective answers are scored automatically. Nothing is published or sent yet.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
            ],
          );
          final action = FilledButton.icon(
            onPressed: isCreating ? null : onCreate,
            icon: isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(isCreating ? 'Creating demo…' : 'Create demo job'),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [content, const SizedBox(height: 12), action],
                )
              : Row(
                  children: [
                    const Expanded(child: content),
                    const SizedBox(width: 16),
                    action,
                  ],
                );
        }),
      );
}
