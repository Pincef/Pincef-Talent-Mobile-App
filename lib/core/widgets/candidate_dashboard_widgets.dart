import 'package:flutter/material.dart';
import '../theme/brand_color.dart';
// TODO: fix this relative path to wherever dashboard_models.dart actually
// lives in your tree — I don't have confirmed evidence of its location
// relative to core/widgets/, only that dashboard_repository.dart imports
// it via 'model/dashboard_models.dart' from one level up.
import '../../features/candidate_dashboard/data/model/dashboard_models.dart';

// ============================================================
// Shared building blocks
// ============================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.color = Colors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: color == Colors.white
            ? Border.all(color: BrandColors.border)
            : null,
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label,
      required this.background,
      required this.foreground,
      this.icon});

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: foreground,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10.5, color: BrandColors.navy)),
    );
  }
}

const _kSectionLabelStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  color: BrandColors.muted,
  letterSpacing: 0.5,
);

// ============================================================
// Professional Profile Summary
// ============================================================

class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({
    super.key,
    required this.highlights,
    required this.strengths,
    required this.stacked,
  });

  final List<String> highlights;
  final List<String> strengths;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final highlightsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CAREER HIGHLIGHTS', style: _kSectionLabelStyle),
        const SizedBox(height: 10),
        ...highlights.map(
          (h) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle,
                    size: 15, color: BrandColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(h,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: BrandColors.navy,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final strengthsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CORE STRENGTHS', style: _kSectionLabelStyle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: strengths
              .map(
                (s) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s,
                      style: const TextStyle(
                          fontSize: 11.5, color: BrandColors.navy)),
                ),
              )
              .toList(),
        ),
      ],
    );

    return _SectionCard(
      color: const Color(
          0xFFFCE8DB), // light peach — distinct from the white cards below it
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROFESSIONAL PROFILE SUMMARY',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: BrandColors.navy,
                letterSpacing: 0.4),
          ),
          const SizedBox(height: 16),
          stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    highlightsContent,
                    const SizedBox(height: 16),
                    strengthsContent,
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: highlightsContent),
                      const SizedBox(width: 24),
                      Expanded(child: strengthsContent),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

// ============================================================
// Work Experience Summary
// ============================================================

class WorkExperienceCard extends StatelessWidget {
  const WorkExperienceCard({super.key, required this.summary});
  final WorkExperienceSummary summary;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WORK EXPERIENCE SUMMARY', style: _kSectionLabelStyle),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: BrandColors.navy,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      summary.yearsOfExperience % 1 == 0
                          ? summary.yearsOfExperience.toStringAsFixed(0)
                          : summary.yearsOfExperience.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'YEARS EXP',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.company} • ${summary.period}',
                      style: const TextStyle(
                          fontSize: 12, color: BrandColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summary.description,
                      style: const TextStyle(
                          fontSize: 12.5, color: BrandColors.navy, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Active Application Status
// ============================================================

class ActiveApplicationsCard extends StatelessWidget {
  const ActiveApplicationsCard(
      {super.key, required this.applications, required this.onViewAll});

  final List<CandidateDashboardApplication> applications;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Application Status',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text(
                  'View All Applications',
                  style: TextStyle(
                      fontSize: 12,
                      color: BrandColors.orange,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < applications.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 16),
              const Divider(color: BrandColors.border),
              const SizedBox(height: 16)
            ],
            _ApplicationRow(application: applications[i]),
          ],
        ],
      ),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({required this.application});
  final CandidateDashboardApplication application;

  @override
  Widget build(BuildContext context) {
    // Derives stage progress from enum declaration order + .name for labels,
    // rather than hardcoding member names I'm not certain of. Assumes
    // ApplicationStage's values are declared in the same left-to-right
    // order shown in the design (e.g. applied -> screening -> technical
    // -> whatever your 4th/final stage is actually called).
    const stages = ApplicationStage.values;
    final currentIndex = stages.indexOf(application.currentStage);

    final isSent = application.statusLabel.toUpperCase().contains('SENT');
    final statusColor = isSent ? const Color(0xFF2563EB) : BrandColors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.jobTitle,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${application.company} • ${application.appliedLabel}',
                    style:
                        const TextStyle(fontSize: 12, color: BrandColors.muted),
                  ),
                ],
              ),
            ),
            _Pill(
                label: application.statusLabel,
                background: statusColor,
                foreground: Colors.white),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 6,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: List.generate(stages.length, (i) {
                final reached = i <= currentIndex;
                return Text(
                  stages[i].name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color:
                        reached ? const Color(0xFF16A34A) : BrandColors.muted,
                  ),
                );
              }),
            ),
            Text(
              '${(application.progressPercent * 100).round()}% Complete',
              style: const TextStyle(fontSize: 11, color: BrandColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: application.progressPercent,
            minHeight: 6,
            backgroundColor: BrandColors.border,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Recent Uploads
// ============================================================

class RecentUploadsCard extends StatelessWidget {
  const RecentUploadsCard(
      {super.key, required this.uploads, required this.onAdd});

  final List<RecentUpload> uploads;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Uploads',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy),
              ),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: BrandColors.iconBg,
                      borderRadius: BorderRadius.circular(20)),
                  child:
                      const Icon(Icons.add, size: 16, color: BrandColors.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < uploads.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _UploadRow(upload: uploads[i]),
          ],
        ],
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.upload});
  final RecentUpload upload;

  @override
  Widget build(BuildContext context) {
    // .parsing / .ready are confirmed exact member names (seen in your
    // repository's mock data); anything else falls back to a neutral pill
    // rather than throwing, in case the enum has more values than that.
    final Color color;
    final IconData icon;
    final String label;
    if (upload.status == UploadStatus.parsing) {
      color = BrandColors.orange;
      icon = Icons.autorenew;
      label = 'Parsing';
    } else if (upload.status == UploadStatus.ready) {
      color = const Color(0xFF16A34A);
      icon = Icons.check_circle;
      label = 'Ready';
    } else {
      color = BrandColors.muted;
      icon = Icons.info_outline;
      label = upload.status.name;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: BrandColors.iconBg,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.description_outlined,
              size: 16, color: BrandColors.navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                upload.fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.navy),
              ),
              const SizedBox(height: 2),
              Text(upload.uploadedLabel,
                  style: const TextStyle(
                      fontSize: 10.5, color: BrandColors.muted)),
              const SizedBox(height: 4),
              _Pill(
                  label: label,
                  background: color,
                  foreground: Colors.white,
                  icon: icon),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Top Job Matches
// ============================================================

class TopJobMatchesCard extends StatelessWidget {
  const TopJobMatchesCard(
      {super.key, required this.matches, required this.onDiscoverMore});

  final List<JobMatch> matches;
  final VoidCallback onDiscoverMore;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Jobs Matches',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: BrandColors.navy),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < matches.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _JobMatchRow(match: matches[i]),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDiscoverMore,
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandColors.orange,
                side: const BorderSide(color: BrandColors.orange),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Discover More Jobs',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobMatchRow extends StatelessWidget {
  const _JobMatchRow({required this.match});
  final JobMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: BrandColors.border),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  match.title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.navy),
                ),
              ),
              _Pill(
                label: '${match.matchPercent}% Match',
                background: const Color(0xFF16A34A),
                foreground: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${match.company} • ${match.workMode} • ${match.salaryRange}',
            style: const TextStyle(fontSize: 11.5, color: BrandColors.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: match.tags.map(_TagChip.new).toList()),
        ],
      ),
    );
  }
}

// ============================================================
// Workspace Tip
// ============================================================

class WorkspaceTipCard extends StatelessWidget {
  const WorkspaceTipCard({super.key, required this.tip});
  final String tip;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(color: BrandColors.navy),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WORKSPACE TIP',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Text(tip,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12.5, height: 1.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
