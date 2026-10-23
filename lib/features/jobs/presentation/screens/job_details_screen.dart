import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brand_color.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/job_management_model.dart';
import 'post_job_screen.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../application/application_provider.dart';
import '../../data/models/application_model.dart';
import '../../../candidate_dashboard/presentation/widgets/cv_upload_modal.dart';

/// Shared Job Detail screen — GET /jobs/:jobId (job.service.ts's
/// getJobById, public/unauthenticated) is the same for every viewer; this
/// widget decides what to show/allow based on the logged-in user's role,
/// same pattern app_router.dart already uses to split /jobs itself between
/// JobManagementScreen and BrowseJobsScreen.
///
/// Stateful (not just a ConsumerWidget) specifically to hold `_isEditing` —
/// the recruiter's "Edit Posting" button swaps this same screen into
/// _EditJobForm rather than navigating anywhere else.
class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final isRecruiter =
        ref.watch(authProvider).user?.role == UserRole.recruiter;

    return jobAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(err.toString()),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(jobDetailProvider(widget.jobId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (job) {
        // Editing only ever applies to the recruiter view — if role
        // somehow flips mid-session, fall back to read-only rather than
        // trust stale local edit-mode state.
        if (_isEditing && isRecruiter) {
          return PostJobScreen(
            initialJob: job,
            onCancel: () => setState(() => _isEditing = false),
            onSaved: () {
              setState(() => _isEditing = false);
              ref.invalidate(jobDetailProvider(widget.jobId));
            },
          );
        }
        return _Body(
          job: job,
          isRecruiter: isRecruiter,
          jobId: widget.jobId,
          onEdit: () => setState(() => _isEditing = true),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(
      {required this.job,
      required this.isRecruiter,
      required this.jobId,
      required this.onEdit});

  final JobDetail job;
  final bool isRecruiter;
  final String jobId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: LayoutBuilder(builder: (context, content) {
                final columns = content.maxWidth >= 980
                    ? 3
                    : content.maxWidth >= 560
                        ? 2
                        : 1;
                final factWidth =
                    (content.maxWidth - (columns - 1) * 12) / columns;
                final factTiles = <Widget>[
                  _JobFactTile(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: job.location),
                  _JobFactTile(
                      icon: Icons.work_outline,
                      label: 'Employment',
                      value: job.employmentTypeLabel),
                  if (job.workplaceType?.isNotEmpty ?? false)
                    _JobFactTile(
                        icon: Icons.laptop_mac_outlined,
                        label: 'Work arrangement',
                        value: _workplaceLabel(job.workplaceType!)),
                  if (job.salaryRangeLabel != null)
                    _JobFactTile(
                        icon: Icons.payments_outlined,
                        label: 'Compensation',
                        value: job.salaryRangeLabel!),
                  if (job.minYearsOfExperience?.isNotEmpty ?? false)
                    _JobFactTile(
                        icon: Icons.timeline_outlined,
                        label: 'Experience',
                        value: job.minYearsOfExperience!),
                  if (job.educationLevelLabel != null)
                    _JobFactTile(
                        icon: Icons.school_outlined,
                        label: 'Education',
                        value: [
                          job.educationLevelLabel!,
                          if (job.fieldOfStudy?.isNotEmpty ?? false)
                            job.fieldOfStudy!,
                        ].join(' · ')),
                  if (job.industry?.isNotEmpty ?? false)
                    _JobFactTile(
                        icon: Icons.domain_outlined,
                        label: 'Industry',
                        value: job.industry!),
                  if (job.applicationDeadline != null)
                    _JobFactTile(
                      icon: Icons.event_outlined,
                      label: 'Apply by',
                      value:
                          _formatApplicationDeadline(job.applicationDeadline!),
                    ),
                ];
                final sections = <Widget>[];
                if (job.responsibilities.isNotEmpty) {
                  sections.add(SizedBox(
                    width: factWidth,
                    child: _SectionCard(
                      title: 'Responsibilities',
                      child: _DetailBulletList(items: job.responsibilities),
                    ),
                  ));
                }
                if (job.requiredSkills.isNotEmpty ||
                    (job.minYearsOfExperience?.isNotEmpty ?? false) ||
                    job.educationLevelLabel != null ||
                    job.requiresManagementExperience) {
                  sections.add(SizedBox(
                    width: factWidth,
                    child: _SectionCard(
                      title: 'Skills & qualifications',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (job.requiredSkills.isNotEmpty)
                            _SkillsGrid(skills: job.requiredSkills),
                          if (job.minYearsOfExperience?.isNotEmpty ??
                              false) ...[
                            if (job.requiredSkills.isNotEmpty)
                              const SizedBox(height: 14),
                            _DetailBulletList(items: [
                              '${job.minYearsOfExperience} experience',
                              if (job.educationLevelLabel != null)
                                'Education: ${job.educationLevelLabel}${job.fieldOfStudy?.isNotEmpty ?? false ? ' · ${job.fieldOfStudy}' : ''}',
                              if (job.requiresManagementExperience)
                                'Management experience required',
                            ]),
                          ] else if (job.educationLevelLabel != null ||
                              job.requiresManagementExperience) ...[
                            if (job.requiredSkills.isNotEmpty)
                              const SizedBox(height: 14),
                            _DetailBulletList(items: [
                              if (job.educationLevelLabel != null)
                                'Education: ${job.educationLevelLabel}${job.fieldOfStudy?.isNotEmpty ?? false ? ' · ${job.fieldOfStudy}' : ''}',
                              if (job.requiresManagementExperience)
                                'Management experience required',
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ));
                }
                if (job.benefits.isNotEmpty) {
                  sections.add(SizedBox(
                    width: factWidth,
                    child: _SectionCard(
                      title: 'Benefits',
                      child: _DetailBulletList(items: job.benefits),
                    ),
                  ));
                }
                if (job.companyOverview?.trim().isNotEmpty ?? false) {
                  sections.add(SizedBox(
                    width: factWidth,
                    child: _SectionCard(
                      title: 'About ${job.companyName}',
                      child: Text(job.companyOverview!.trim(),
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: BrandColors.muted,
                              height: 1.6)),
                    ),
                  ));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Breadcrumb(title: job.title, isRecruiter: isRecruiter),
                    const SizedBox(height: 12),
                    _Header(
                        job: job,
                        isRecruiter: isRecruiter,
                        jobId: jobId,
                        isWide: isWide,
                        onEdit: onEdit),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: factTiles
                          .map(
                              (tile) => SizedBox(width: factWidth, child: tile))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'About the role',
                      child: Text(
                        job.description.isEmpty
                            ? 'No description provided.'
                            : job.description,
                        style: const TextStyle(
                            fontSize: 13,
                            color: BrandColors.muted,
                            height: 1.7),
                      ),
                    ),
                    if (sections.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: sections,
                      ),
                    ],
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

String _workplaceLabel(String value) => switch (value) {
      'remote' => 'Remote',
      'hybrid' => 'Hybrid',
      'on_site' => 'On-site',
      _ => value,
    };

String _formatApplicationDeadline(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.title, required this.isRecruiter});
  final String title;
  final bool isRecruiter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/jobs'),
          child: Text(
            isRecruiter ? 'Jobs Management' : 'Browse Jobs',
            style: const TextStyle(
                fontSize: 11.5,
                color: BrandColors.muted,
                fontWeight: FontWeight.w600),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('/',
              style: TextStyle(fontSize: 11.5, color: BrandColors.muted)),
        ),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11.5,
                color: BrandColors.navy,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.job,
      required this.isRecruiter,
      required this.jobId,
      required this.isWide,
      required this.onEdit});
  final JobDetail job;
  final bool isRecruiter;
  final String jobId;
  final bool isWide;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final actions = isRecruiter
        ? _RecruiterActions(
            jobId: jobId,
            onEdit: onEdit,
            canShare: job.status == JobBackendStatus.published,
          )
        : _CandidateActions(job: job, jobId: jobId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRecruiter ? Colors.white : null,
        gradient: isRecruiter
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF233761), Color(0xFF142344)],
              ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isRecruiter ? BrandColors.border : const Color(0xFF334A75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(job.title,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color:
                                isRecruiter ? BrandColors.navy : Colors.white)),
                    _StatusPill(status: job.status),
                  ],
                ),
              ),
              if (isWide) actions,
            ],
          ),
          const SizedBox(height: 4),
          Text(job.companyName,
              style: TextStyle(
                  fontSize: 11.5,
                  color: isRecruiter ? BrandColors.muted : Colors.white70)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _MetaItem(
                  icon: Icons.location_on_outlined,
                  label: job.location,
                  color: isRecruiter ? BrandColors.muted : Colors.white70),
              _MetaItem(
                  icon: Icons.schedule_outlined,
                  label: job.employmentTypeLabel,
                  color: isRecruiter ? BrandColors.muted : Colors.white70),
              if (job.minYearsOfExperience != null)
                _MetaItem(
                    icon: Icons.timeline_outlined,
                    label: '${job.minYearsOfExperience} experience',
                    color: isRecruiter ? BrandColors.muted : Colors.white70),
              if (job.educationLevelLabel != null)
                _MetaItem(
                    icon: Icons.school_outlined,
                    label: [
                      job.educationLevelLabel!,
                      if (job.fieldOfStudy?.isNotEmpty ?? false)
                        job.fieldOfStudy!,
                    ].join(' • '),
                    color: isRecruiter ? BrandColors.muted : Colors.white70),
              if (job.salaryRangeLabel != null)
                _MetaItem(
                    icon: Icons.payments_outlined,
                    label: job.salaryRangeLabel!,
                    color: isRecruiter ? BrandColors.muted : Colors.white70),
            ],
          ),
          if (!isWide) ...[const SizedBox(height: 16), actions],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final JobBackendStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      JobBackendStatus.published => (
          const Color(0xFFE8F8EE),
          const Color(0xFF16A34A),
          'ACTIVE'
        ),
      JobBackendStatus.draft => (
          BrandColors.iconBg,
          BrandColors.muted,
          'DRAFT'
        ),
      JobBackendStatus.closed => (
          const Color(0xFFE7E9EF),
          BrandColors.muted,
          'CLOSED'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    this.color = BrandColors.muted,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, color: color)),
      ],
    );
  }
}

// ============================================================
// Recruiter actions
// ============================================================

class _RecruiterActions extends StatelessWidget {
  const _RecruiterActions(
      {required this.jobId, required this.onEdit, required this.canShare});
  final String jobId;
  final VoidCallback onEdit;
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        if (canShare)
          OutlinedButton.icon(
            onPressed: () async {
              final shareUrl = Uri.base
                  .replace(
                      path: '/shared/jobs/$jobId', query: null, fragment: null)
                  .toString();
              await Clipboard.setData(ClipboardData(text: shareUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Public job link copied')),
              );
            },
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Share job'),
          ),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit Posting'),
        ),
        ElevatedButton(
          onPressed: () => context.go('/jobs/$jobId/candidates'),
          style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.orange,
              foregroundColor: Colors.white,
              elevation: 0),
          child: const Text('View Candidates'),
        ),
      ],
    );
  }
}

// Candidate actions — apply + CV selection
// ============================================================

class _CandidateActions extends ConsumerWidget {
  const _CandidateActions({required this.job, required this.jobId});
  final JobDetail job;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (job.status != JobBackendStatus.published) {
      return const Text('Not accepting applications',
          style: TextStyle(fontSize: 11.5, color: BrandColors.muted));
    }

    final applicationsAsync = ref.watch(myApplicationsProvider);
    final applyState = ref.watch(applyProvider);

    return applicationsAsync.when(
      loading: () => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => _ApplyButton(
        isSubmitting: applyState.isSubmitting,
        onTap: () => _handleApply(context, ref),
      ),
      data: (applications) {
        final existing = applications.where((a) => a.jobId == jobId).toList();
        if (existing.isNotEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: BrandColors.iconBg,
                borderRadius: BorderRadius.circular(8)),
            child: Text('Applied • ${existing.first.status.label}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy)),
          );
        }
        return _ApplyButton(
          isSubmitting: applyState.isSubmitting,
          onTap: () => _handleApply(context, ref),
        );
      },
    );
  }

  Future<void> _handleApply(BuildContext context, WidgetRef ref) async {
    List<CvFileOption> cvFiles;
    try {
      cvFiles = await ref.read(myCvFilesProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, 'Could not load your CVs: $e');
      return;
    }
    if (!context.mounted) return;

    if (cvFiles.isEmpty) {
      final shouldUpload = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upload a CV first'),
          content: const Text(
              'You need at least one CV on your profile before applying.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Upload CV')),
          ],
        ),
      );
      if (shouldUpload == true && context.mounted) {
        showCandidateCvUploadModal(context, ref);
      }
      return;
    }

    String? cvPublicId;
    if (cvFiles.length > 1) {
      cvPublicId = await _showCvPicker(context, cvFiles);
      if (cvPublicId == null) return; // cancelled
    } else {
      cvPublicId = cvFiles.first.publicId;
    }

    final success = await ref
        .read(applyProvider.notifier)
        .submit(jobId, cvPublicId: cvPublicId);
    if (!context.mounted) return;

    if (success) {
      ref.invalidate(
          myApplicationsProvider); // so "Applied" reflects immediately
      final result = ref.read(applyProvider).result!;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ApplicationSubmittedDialog(
            application: result, jobTitle: job.title),
      );
      if (context.mounted) AppToast.success(context, 'Application submitted.');
    } else {
      final error =
          ref.read(applyProvider).error ?? 'Could not submit your application.';
      AppToast.error(context, error);
    }
  }

  Future<String?> _showCvPicker(
      BuildContext context, List<CvFileOption> cvFiles) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Which CV should we use?',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.navy)),
              const SizedBox(height: 4),
              const Text(
                  'You have more than one CV on file for this application.',
                  style: TextStyle(fontSize: 11.5, color: BrandColors.muted)),
              const SizedBox(height: 8),
              for (final cv in cvFiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined,
                      color: BrandColors.navy),
                  title: Text(cv.originalName,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('Uploaded ${_formatDate(cv.uploadedAt)}',
                      style: const TextStyle(
                          fontSize: 10.5, color: BrandColors.muted)),
                  onTap: () => Navigator.pop(sheetContext, cv.publicId),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.isSubmitting, required this.onTap});
  final bool isSubmitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isSubmitting ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: isSubmitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Text('Apply Now',
              style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ============================================================
// Post-apply confirmation
// ============================================================

class _ApplicationSubmittedDialog extends StatelessWidget {
  const _ApplicationSubmittedDialog(
      {required this.application, required this.jobTitle});
  final ApplicationSummary application;
  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: Color(0xFFE8F8EE), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Application Submitted',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.navy)),
              const SizedBox(height: 4),
              Text('Thank you for applying to $jobTitle.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: BrandColors.muted)),
              const SizedBox(height: 8),
              Text(
                application.receiptEmailSent
                    ? 'A confirmation email has been sent to your inbox.'
                    : 'Your application is saved. We could not send a confirmation email right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: BrandColors.muted, height: 1.45),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: BrandColors.iconBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('Reference: ${application.referenceNumber}',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.orange)),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: BrandColors.iconBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_outlined,
                            size: 14, color: BrandColors.navy),
                        SizedBox(width: 6),
                        Text('What to expect next',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: BrandColors.navy)),
                      ],
                    ),
                    SizedBox(height: 10),
                    _ExpectationStep(
                      title: 'Application Review',
                      description:
                          'Our recruiting team will review your application and profile.',
                      active: true,
                    ),
                    _ExpectationStep(
                      title: 'Initial Screening',
                      description:
                          'If selected, you may be invited to an introductory call.',
                      active: false,
                    ),
                    _ExpectationStep(
                      title: 'Interview',
                      description:
                          'A deeper conversation with the hiring team.',
                      active: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/jobs');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.work_outline, size: 16),
                  label: const Text('Return to Jobs'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpectationStep extends StatelessWidget {
  const _ExpectationStep(
      {required this.title, required this.description, required this.active});
  final String title;
  final String description;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? BrandColors.orange : BrandColors.border),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy)),
                Text(description,
                    style: const TextStyle(
                        fontSize: 10.5, color: BrandColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Technical requirements
// ============================================================

/// job.model.ts's requiredSkills is just string[] — there's no per-skill
/// description field, so unlike the mockup these cards show the skill name
/// only rather than fabricated blurbs under each one.
class _SkillsGrid extends StatelessWidget {
  const _SkillsGrid({required this.skills});
  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: skills
          .map((skill) => Container(
                constraints: const BoxConstraints(minWidth: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: BrandColors.iconBg.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: BrandColors.navy),
                    const SizedBox(width: 8),
                    Text(skill,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: BrandColors.navy)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _JobFactTile extends StatelessWidget {
  const _JobFactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: BrandColors.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: BrandColors.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: .5,
                          fontWeight: FontWeight.w800,
                          color: BrandColors.muted)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DetailBulletList extends StatelessWidget {
  const _DetailBulletList({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle_outline,
                        size: 15, color: BrandColors.orange),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: BrandColors.muted)),
                  ),
                ],
              ),
            ),
        ],
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.navy)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
