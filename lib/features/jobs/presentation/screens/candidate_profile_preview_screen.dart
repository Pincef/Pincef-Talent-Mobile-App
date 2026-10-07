import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/features/jobs/presentation/widgets/download_cv_button.dart';

import '../../../../core/theme/brand_color.dart';
import '../../application/candidate_profile_provider.dart';
import '../../data/models/application_model.dart';
import '../../data/models/candidate_profile_model.dart';
import '../../data/models/candidate_analysis_model.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';

extension EducationEntryDisplay on EducationEntry {
  String get displayTitle {
    final degreeLabel = degree?.trim();
    final fieldLabel = fieldOfStudy?.trim();

    if (degreeLabel != null &&
        degreeLabel.isNotEmpty &&
        fieldLabel != null &&
        fieldLabel.isNotEmpty) {
      return '$degreeLabel in $fieldLabel';
    }
    if (degreeLabel != null && degreeLabel.isNotEmpty) return degreeLabel;
    if (fieldLabel != null && fieldLabel.isNotEmpty) return fieldLabel;
    return institution;
  }
}

/// Recruiter-facing candidate profile view. Pulls from three sources:
/// - GET /users/:candidateId — name, email, phone, photo
/// - GET /candidate-profile/:candidateId — bio/experience/education/skills/CVs
/// - GET (+POST fallback) .../jobs/:jobId/analysis — match score + insights
/// all bundled by candidateProfileViewProvider. Status + which CV was
/// actually submitted come from [applicant] instead (application data,
/// not candidate-profile data) — passed via go_router `extra` from
/// job_candidates_screen.dart, which already has it in memory.
class CandidateProfilePreviewScreen extends ConsumerWidget {
  const CandidateProfilePreviewScreen({
    super.key,
    required this.jobId,
    required this.candidateId,
    this.applicant,
  });

  final String jobId;
  final String candidateId;

  /// Null on a direct/deep link (no `extra` was passed) — in that case the
  /// status pill is hidden and the résumé card falls back to the
  /// candidate's most recent CV on file rather than the one actually
  /// submitted with this application.
  final JobApplicantSummary? applicant;

  static const _cardBorder = Color(0xFFF0D2C4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (candidateId: candidateId, jobId: jobId);
    final result = ref.watch(candidateProfileViewProvider(args));

    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: error.toString(),
        jobId: jobId,
        onRetry: () => ref.invalidate(candidateProfileViewProvider(args)),
      ),
      data: (data) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 940;
          final content = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/jobs/$jobId/candidates'),
                  icon: const Icon(Icons.arrow_back, size: 17),
                  label: const Text('Back to candidates'),
                ),
                const SizedBox(height: 6),
                _ProfileHeader(data: data, applicant: applicant),
                const SizedBox(height: 18),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _MainColumn(data: data)),
                      const SizedBox(width: 18),
                      SizedBox(
                          width: 290,
                          child: _SideColumn(data: data, applicant: applicant)),
                    ],
                  )
                else
                  Column(
                    children: [
                      _MainColumn(data: data),
                      const SizedBox(height: 18),
                      _SideColumn(data: data, applicant: applicant),
                    ],
                  ),
              ],
            ),
          );
          return SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 28 : 16),
            child: Align(alignment: Alignment.topCenter, child: content),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState(
      {required this.message, required this.jobId, required this.onRetry});
  final String message;
  final String jobId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load this candidate's profile."),
              const SizedBox(height: 8),
              Text(message,
                  style:
                      const TextStyle(color: BrandColors.muted, fontSize: 11)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.data, this.applicant});
  final CandidateProfileViewData data;
  final JobApplicantSummary? applicant;

  @override
  Widget build(BuildContext context) {
    final user = data.user;
    final profile = data.profile;
    // professionalTitle is manual-wizard-only — most candidates arrive via
    // CV upload and never set it, so fall back to their most recent role.
    final title = profile.professionalTitle ??
        (profile.experience.isNotEmpty ? profile.experience.first.title : null);
    final location = profile.location?.displayString;
    final cvUrl = applicant?.cvUrl ??
        (profile.cvFiles.isNotEmpty ? profile.cvFiles.last.url : null);

    return _Card(
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: const Color(0xFFE3EFF8),
            backgroundImage: user.profileImage != null
                ? NetworkImage(user.profileImage!.url)
                : null,
            child: user.profileImage == null
                ? const Icon(Icons.person, size: 39, color: Color(0xFF39769C))
                : null,
          ),
          SizedBox(
            width: 270,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(user.fullName, style: _titleStyle)),
                  if (applicant != null) ...[
                    const SizedBox(width: 7),
                    _StatusPill(status: applicant!.status),
                  ],
                ]),
                const SizedBox(height: 3),
                if (title != null) Text(title, style: _subTitleStyle),
                if (location != null && location.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: BrandColors.muted),
                    const SizedBox(width: 3),
                    Text(location, style: _smallMuted),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          DownloadCvButton(url: cvUrl, fileName: '${user.fullName}_CV'),
          ElevatedButton.icon(
            // No messaging feature/endpoint exists yet — left as a stub
            // rather than wiring it to something that doesn't exist.
            onPressed: () =>
                AppToast.info(context, 'Messaging isn\'t available yet.'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 15),
            label: const Text('Message'),
          ),
        ],
      ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({required this.data});
  final CandidateProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final summary = data.profile.displaySummary;
    return Column(
      children: [
        _MatchInsights(
            analysis: data.analysis, candidateName: data.user.firstName),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Professional Summary',
          child: Text(
            summary ?? 'No summary available yet.',
            style: _bodyStyle,
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Work Experience',
          child: data.profile.experience.isEmpty
              ? const Text('No work experience on file.', style: _smallMuted)
              : _WorkExperience(entries: data.profile.experience),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Education',
          child: data.profile.education.isEmpty
              ? const Text('No education on file.', style: _smallMuted)
              : _Education(entries: data.profile.education),
        ),
      ],
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.data, this.applicant});
  final CandidateProfileViewData data;
  final JobApplicantSummary? applicant;

  @override
  Widget build(BuildContext context) {
    final cv = applicant?.cvUrl != null
        ? data.profile.cvFiles
            .cast<CvFile?>()
            .firstWhere((f) => f?.url == applicant!.cvUrl, orElse: () => null)
        : (data.profile.cvFiles.isNotEmpty ? data.profile.cvFiles.last : null);

    return Column(
      children: [
        _SectionCard(
          title: 'Contact Information',
          child: _ContactInfo(
              user: data.user, portfolioLinks: data.profile.portfolioLinks),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Technical Skills',
          child: data.profile.skills.isEmpty
              ? const Text('No skills listed yet.', style: _smallMuted)
              : _Skills(skills: data.profile.skills),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Resume Document',
          child: cv == null
              ? const Text('No résumé on file.', style: _smallMuted)
              : _ResumeDocument(cv: cv, cvUrlOverride: applicant?.cvUrl),
        ),
      ],
    );
  }
}

class _MatchInsights extends StatelessWidget {
  const _MatchInsights({required this.analysis, required this.candidateName});
  final CandidateJobAnalysis? analysis;
  final String candidateName;

  @override
  Widget build(BuildContext context) {
    if (analysis == null) {
      return const _Card(
        child: Text("Couldn't load match insights for this candidate.",
            style: _bodyStyle),
      );
    }
    if (analysis!.status == CandidateJobAnalysisStatus.failed) {
      return _Card(
        child: Text(
          analysis!.error ?? 'Matching failed for this candidate.',
          style: _bodyStyle,
        ),
      );
    }
    if (analysis!.status != CandidateJobAnalysisStatus.completed ||
        analysis!.score == null) {
      return const _Card(
        child: Row(children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Analyzing fit for this role...', style: _bodyStyle),
        ]),
      );
    }

    return _Card(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 66,
          height: 54,
          decoration: BoxDecoration(
              color: const Color(0xFFF0F3FB),
              borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${analysis!.score}%',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.orange)),
            const Text('Match Score',
                style: TextStyle(fontSize: 8, color: BrandColors.navy)),
          ]),
        ),
        const SizedBox(width: 13),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.auto_awesome, size: 14, color: BrandColors.orange),
              SizedBox(width: 4),
              Text('Smart Match Insights', style: _sectionTitle),
            ]),
            const SizedBox(height: 5),
            Text(analysis!.summary ?? 'No summary available.',
                style: _bodyStyle),
          ]),
        ),
      ]),
    );
  }
}

class _WorkExperience extends StatelessWidget {
  const _WorkExperience({required this.entries});
  final List<ExperienceEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 17),
            _TimelineItem(entry: entries[i]),
          ],
        ],
      );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.entry});
  final ExperienceEntry entry;

  String get _dateRange {
    final start = entry.startDate?.year.toString() ?? '';
    final end =
        entry.isCurrent ? 'Present' : (entry.endDate?.year.toString() ?? '');
    if (start.isEmpty && end.isEmpty) return '';
    return '$start – $end';
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
                color: BrandColors.orange, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(entry.title, style: _sectionTitle)),
                  Text(_dateRange,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                ]),
                const SizedBox(height: 2),
                if (entry.company != null)
                  Text(entry.company!, style: _smallMuted),
                if (entry.description != null &&
                    entry.description!.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(entry.description!, style: _bodyStyle),
                ],
                if (entry.achievements.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...entry.achievements.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: _bodyStyle),
                            Expanded(child: Text(a, style: _bodyStyle)),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      );
}

class _Education extends StatelessWidget {
  const _Education({required this.entries});
  final List<EducationEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _EducationRow(entry: entries[i]),
          ],
        ],
      );
}

class _EducationRow extends StatelessWidget {
  const _EducationRow({required this.entry});
  final EducationEntry entry;

  @override
  Widget build(BuildContext context) {
    final end = entry.endDate?.year;
    return Row(children: [
      const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFE8F0FC),
          child:
              Icon(Icons.school_outlined, size: 19, color: BrandColors.navy)),
      const SizedBox(width: 11),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.displayTitle, style: _sectionTitle),
          const SizedBox(height: 2),
          Text(entry.institution, style: _smallMuted),
          if (end != null) ...[
            const SizedBox(height: 2),
            Text('Graduated $end',
                style: const TextStyle(fontSize: 9, color: BrandColors.navy)),
          ],
        ]),
      ),
    ]);
  }
}

class _ContactInfo extends StatelessWidget {
  const _ContactInfo({required this.user, required this.portfolioLinks});
  final UserModel user;
  final List<PortfolioLink> portfolioLinks;

  @override
  Widget build(BuildContext context) {
    final linkedIn = portfolioLinks.cast<PortfolioLink?>().firstWhere(
        (l) => l?.platform.toLowerCase().contains('linkedin') ?? false,
        orElse: () => null);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _InfoRow(Icons.email_outlined, user.email),
      if (user.phone != null) ...[
        const SizedBox(height: 10),
        _InfoRow(Icons.phone_outlined, user.phone!),
      ],
      if (linkedIn != null) ...[
        const SizedBox(height: 10),
        _InfoRow(Icons.link, linkedIn.displayTitle ?? linkedIn.url),
      ],
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: const Color(0xFF596989)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: _smallMuted, overflow: TextOverflow.ellipsis)),
      ]);
}

class _Skills extends StatelessWidget {
  const _Skills({required this.skills});
  final List<String> skills;
  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 6, runSpacing: 7, children: skills.map(_SkillChip.new).toList());
}

class _SkillChip extends StatelessWidget {
  const _SkillChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFEAF0FA),
          border: Border.all(color: const Color(0xFFC6D3E8)),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: const TextStyle(fontSize: 9, color: BrandColors.navy)));
}

class _ResumeDocument extends StatelessWidget {
  const _ResumeDocument({required this.cv, this.cvUrlOverride});
  final CvFile cv;

  /// The application's actual submitted cvUrl may differ from this CV's
  /// own `url` in edge cases (candidate replaced their CV after applying)
  /// — the download action always honors whichever URL was actually
  /// submitted with the application, falling back to this file's own URL.
  final String? cvUrlOverride;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFE),
          border: Border.all(color: const Color(0xFFD8E0EF)),
          borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        const Icon(Icons.picture_as_pdf_outlined,
            size: 20, color: Color(0xFFE54235)),
        const SizedBox(width: 7),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cv.originalName,
              style: const TextStyle(fontSize: 9, color: BrandColors.navy),
              overflow: TextOverflow.ellipsis),
          Text(cv.sizeLabel, style: _smallMuted),
        ])),
        DownloadCvButton(
          url: cvUrlOverride ?? cv.url,
          fileName: cv.originalName,
          compact: true,
        ),
      ]));
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => _Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: _sectionTitle),
        const SizedBox(height: 13),
        child,
      ]));
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CandidateProfilePreviewScreen._cardBorder),
          borderRadius: BorderRadius.circular(10)),
      child: child);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final ApplicationBackendStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ApplicationBackendStatus.interviewing => const Color(0xFF138B4A),
      ApplicationBackendStatus.offered ||
      ApplicationBackendStatus.hired =>
        const Color(0xFF138B4A),
      ApplicationBackendStatus.rejected => const Color(0xFFB91C1C),
      _ => BrandColors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12)),
      child: Text('● ${status.label}',
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

const _titleStyle = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w800, color: BrandColors.navy);
const _subTitleStyle = TextStyle(fontSize: 13, color: Color(0xFF596989));
const _sectionTitle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700, color: BrandColors.navy);
const _smallMuted = TextStyle(fontSize: 10, color: BrandColors.muted);
const _bodyStyle =
    TextStyle(fontSize: 11, height: 1.38, color: Color(0xFF59606E));
