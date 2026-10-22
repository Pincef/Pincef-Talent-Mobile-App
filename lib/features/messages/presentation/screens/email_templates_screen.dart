import 'package:flutter/material.dart';

import '../../../../core/theme/brand_color.dart';

class EmailTemplatesScreen extends StatefulWidget {
  const EmailTemplatesScreen({super.key});

  @override
  State<EmailTemplatesScreen> createState() => _EmailTemplatesScreenState();
}

class _EmailTemplatesScreenState extends State<EmailTemplatesScreen> {
  final _searchController = TextEditingController();
  String _category = 'All templates';
  String _query = '';

  static const _categories = [
    'All templates',
    'Applications',
    'Assessments',
    'Interviews',
    'Offers',
  ];

  static const _templates = <_EmailTemplateInfo>[
    _EmailTemplateInfo(
      title: 'Application received',
      category: 'Applications',
      stage: 'Application stage',
      timing: 'Sent when a candidate applies',
      description:
          'Confirm their application arrived and set a thoughtful expectation for what happens next.',
      subject: 'We received your application for {jobTitle}',
      body: 'Hi {candidateName},\n\n'
          'Thank you for applying for the {jobTitle} position at {companyName}. '
          'Your application is now with our hiring team. We will review your experience '
          'and get back to you as soon as we can.\n\n'
          'Best regards,\n{companyName} Recruiting Team',
      variables: ['{candidateName}', '{jobTitle}', '{companyName}'],
      icon: Icons.mark_email_read_outlined,
      accent: Color(0xFF16856B),
      tint: Color(0xFFE6F6F1),
    ),
    _EmailTemplateInfo(
      title: 'Standard Rejection - Engineering',
      category: 'Applications',
      stage: 'Application stage',
      timing: 'Sent after a hiring decision',
      description:
          'Share a considerate decision with candidates and leave them with a positive impression.',
      subject: 'Update on Your Application for {jobTitle}',
      body: 'Dear {candidateName},\n\n'
          'Thank you for taking the time to apply for the {jobTitle} position at {companyName}. '
          'We appreciate your interest in joining our team and the effort you put into your application.\n\n'
          'After careful consideration of your qualifications and experience, we have decided to move forward with other candidates who more closely align with our current needs for this specific role.\n\n'
          'The caliber of applicants was exceptionally high, and this was a difficult decision. We were impressed by your background and encourage you to apply for future openings at {companyName} that match your skills.\n\n'
          'We wish you the best in your job search and your future professional endeavors.\n\n'
          'Best regards,\n\nThe {companyName} Recruiting Team',
      variables: ['{candidateName}', '{jobTitle}', '{companyName}'],
      icon: Icons.mark_email_unread_outlined,
      accent: Color(0xFF67748A),
      tint: Color(0xFFEEF1F6),
    ),
    _EmailTemplateInfo(
      title: 'Competency Assessment Invitation - Engineering',
      category: 'Assessments',
      stage: 'Assessment stage',
      timing: 'Sent when an assessment is assigned',
      description:
          'Invite shortlisted candidates to demonstrate their skills with clear instructions and a secure link.',
      subject:
          'Take Your Technical Competency Assessment for {jobTitle} at {companyName}',
      body: 'Dear {candidateName},\n\n'
          'Thank you for taking the time to apply for the {jobTitle} position at {companyName}.\n\n'
          'As part of our evaluation process, we invite you to complete a standardized technical competency assessment: {assessmentTitle}.\n\n'
          '• Duration: {durationLimit} (timed session)\n'
          '• Passing Benchmark: {passingScore}\n\n'
          'Please access your personalized assessment portal using the secure link below:\n'
          '{assessmentLink}',
      variables: [
        '{candidateName}',
        '{jobTitle}',
        '{companyName}',
        '{assessmentTitle}',
        '{assessmentLink}',
        '{durationLimit}',
        '{passingScore}',
      ],
      icon: Icons.assignment_outlined,
      accent: Color(0xFF7B61B8),
      tint: Color(0xFFF0EBFA),
    ),
    _EmailTemplateInfo(
      title: 'Technical Interview Invitation - Stage 3',
      category: 'Interviews',
      stage: 'Interview stage',
      timing: 'Sent when a candidate advances',
      description:
          'Invite candidates to a conversation, with the schedule and meeting details easy to find.',
      subject: 'Interview Invitation: {jobTitle} at {companyName}',
      body: 'Dear {candidateName},\n\n'
          'We were very impressed by your background and assessment performance for the {jobTitle} role at {companyName}!\n\n'
          'We would love to invite you for a 45-minute technical discussion with {interviewerName}. During this session, you’ll dive into real-world architecture questions and review key components of our design workflow.\n\n'
          'To choose a time slot that works best for your schedule, please select an available time via the link below:\n'
          '{meetingLink}\n\n'
          'If none of the available slots work, or if you need adjustments, you can request an alternate time here: {rescheduleLink}\n\n'
          'We look forward to speaking with you!\n\n'
          'Best regards,\nThe {companyName} Recruiting Team',
      variables: [
        '{candidateName}',
        '{jobTitle}',
        '{companyName}',
        '{interviewerName}',
        '{interviewDate}',
        '{interviewTime}',
        '{meetingLink}',
        '{rescheduleLink}',
      ],
      icon: Icons.calendar_month_outlined,
      accent: Color(0xFF2877BD),
      tint: Color(0xFFE9F2FC),
    ),
    _EmailTemplateInfo(
      title: 'Shortlist update',
      category: 'Applications',
      stage: 'Application stage',
      timing: 'Sent when a candidate is shortlisted',
      description:
          'Let candidates know they are moving forward and keep the momentum going.',
      subject: 'Good news about your {jobTitle} application',
      body: 'Hi {candidateName},\n\n'
          'We are pleased to let you know that your application for {jobTitle} at {companyName} has progressed to the next stage. '
          'Our team will be in touch shortly with more information.\n\n'
          'Thank you,\n{companyName} Recruiting Team',
      variables: ['{candidateName}', '{jobTitle}', '{companyName}'],
      icon: Icons.trending_up_rounded,
      accent: Color(0xFF16856B),
      tint: Color(0xFFE6F6F1),
    ),
    _EmailTemplateInfo(
      title: 'Standard Offer - Tech Roles',
      category: 'Offers',
      stage: 'Offer stage',
      timing: 'Sent when a candidate is selected',
      description:
          'Celebrate the decision and share the next steps for joining the team.',
      subject: 'Congratulations! You’ve Been Selected for {jobTitle}',
      body: 'Hi {candidateName},\n\n'
          'We are absolutely thrilled to offer you the position of {jobTitle} at {companyName}! Throughout the interview process, our team was incredibly impressed by your skills, experience, and unique perspective you bring. We believe you will be a fantastic addition to our team and play a key role in our upcoming projects.\n\n'
          'Your anticipated start date will be {startDate}. You can review the full details of your offer package by clicking the button below.\n\n'
          'Please let us know if you have any questions. We can’t wait to welcome you aboard!\n'
          '{offerLink}\n'
          'Best regards,\nThe {companyName} Recruiting Team',
      variables: [
        '{candidateName}',
        '{jobTitle}',
        '{companyName}',
        '{startDate}',
        '{offerLink}',
      ],
      icon: Icons.celebration_outlined,
      accent: Color(0xFFD17A18),
      tint: Color(0xFFFFF2DF),
    ),
  ];

  List<_EmailTemplateInfo> get _visibleTemplates {
    final query = _query.trim().toLowerCase();
    return _templates.where((template) {
      final categoryMatches =
          _category == 'All templates' || template.category == _category;
      final queryMatches = query.isEmpty ||
          template.title.toLowerCase().contains(query) ||
          template.description.toLowerCase().contains(query) ||
          template.category.toLowerCase().contains(query);
      return categoryMatches && queryMatches;
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = _visibleTemplates;
    return Container(
      color: BrandColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final columns = constraints.maxWidth >= 1160
              ? 3
              : constraints.maxWidth >= 760
                  ? 2
                  : 1;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                compact ? 16 : 28, 24, compact ? 16 : 28, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LibraryHero(compact: compact),
                    const SizedBox(height: 22),
                    _LibraryHighlights(compact: compact),
                    const SizedBox(height: 24),
                    _LibraryToolbar(
                      controller: _searchController,
                      query: _query,
                      category: _category,
                      categories: _categories,
                      onQueryChanged: (value) => setState(() => _query = value),
                      onCategoryChanged: (value) =>
                          setState(() => _category = value),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Templates for every milestone',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: BrandColors.navy,
                            ),
                          ),
                        ),
                        Text(
                          '${templates.length} ${templates.length == 1 ? 'template' : 'templates'}',
                          style: const TextStyle(
                              color: BrandColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (templates.isEmpty)
                      const _EmptyTemplates()
                    else
                      LayoutBuilder(
                        builder: (context, gridConstraints) {
                          final spacing = compact ? 12.0 : 16.0;
                          final itemWidth = (gridConstraints.maxWidth -
                                  spacing * (columns - 1)) /
                              columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final template in templates)
                                SizedBox(
                                  width: itemWidth,
                                  child: _TemplateCard(
                                    template: template,
                                    onPreview: () => _showPreview(template),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                    _LibraryFooter(compact: compact),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPreview(_EmailTemplateInfo template) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _TemplatePreviewDialog(template: template),
    );
  }
}

class _EmailTemplateInfo {
  const _EmailTemplateInfo({
    required this.title,
    required this.category,
    required this.stage,
    required this.timing,
    required this.description,
    required this.subject,
    required this.body,
    required this.variables,
    required this.icon,
    required this.accent,
    required this.tint,
  });

  final String title;
  final String category;
  final String stage;
  final String timing;
  final String description;
  final String subject;
  final String body;
  final List<String> variables;
  final IconData icon;
  final Color accent;
  final Color tint;
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome, color: Color(0xFFFFC48A), size: 14),
            SizedBox(width: 6),
            Text('TALENTBRIDGE COMMUNICATIONS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .9)),
          ]),
        ),
        const SizedBox(height: 13),
        Text(
          'Every candidate touchpoint,\nthoughtfully worded.',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 26 : 32,
            height: 1.13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Explore ready-to-use emails for each stage of your hiring journey.',
          style: TextStyle(color: Color(0xFFD9E0EF), fontSize: 13, height: 1.5),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2A4E), Color(0xFF30436D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1B2A4E),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: intro),
          if (!compact) ...[
            const SizedBox(width: 24),
            const _HeroArtwork(),
          ],
        ],
      ),
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 184,
        height: 142,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .06),
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: _floatingIcon(Icons.mark_email_read_outlined,
                  const Color(0xFFFFF0E3), BrandColors.orange),
            ),
            Positioned(
              left: 12,
              bottom: 16,
              child: _floatingIcon(Icons.calendar_month_outlined,
                  const Color(0xFFE8F2FF), const Color(0xFF2877BD)),
            ),
            Container(
              width: 78,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, color: BrandColors.orange, size: 28),
                  SizedBox(height: 8),
                  _ArtworkLine(width: 42),
                  SizedBox(height: 5),
                  _ArtworkLine(width: 32),
                  SizedBox(height: 5),
                  _ArtworkLine(width: 38),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _floatingIcon(IconData icon, Color background, Color foreground) =>
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: foreground, size: 21),
      );
}

class _ArtworkLine extends StatelessWidget {
  const _ArtworkLine({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E9F0),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

class _LibraryHighlights extends StatelessWidget {
  const _LibraryHighlights({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      const _Highlight(
        icon: Icons.route_outlined,
        title: 'A message for every stage',
        description: 'From first application to final offer',
        accent: Color(0xFF2877BD),
        tint: Color(0xFFE9F2FC),
      ),
      const _Highlight(
        icon: Icons.tune_rounded,
        title: 'Personalize in seconds',
        description: 'Dynamic fields keep each note personal',
        accent: Color(0xFF7B61B8),
        tint: Color(0xFFF0EBFA),
      ),
      const _Highlight(
        icon: Icons.favorite_border_rounded,
        title: 'A consistent candidate experience',
        description: 'Warm, clear, and ready for your team',
        accent: Color(0xFF16856B),
        tint: Color(0xFFE6F6F1),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final stack = compact || constraints.maxWidth < 900;
      if (stack) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: constraints.maxWidth > 520
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth,
                child: item,
              ),
          ],
        );
      }
      return Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: items[i]),
          if (i < items.length - 1) const SizedBox(width: 12),
        ],
      ]);
    });
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.border),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: tint, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: BrandColors.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: BrandColors.muted, fontSize: 10.5)),
              ],
            ),
          ),
        ]),
      );
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({
    required this.controller,
    required this.query,
    required this.category,
    required this.categories,
    required this.onQueryChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController controller;
  final String query;
  final String category;
  final List<String> categories;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search templates by name or stage...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: BrandColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: BrandColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: BrandColors.orange)),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  ChoiceChip(
                    label: Text(categories[i]),
                    selected: category == categories[i],
                    onSelected: (_) => onCategoryChanged(categories[i]),
                    selectedColor: BrandColors.navy,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: category == categories[i]
                          ? Colors.white
                          : BrandColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: category == categories[i]
                          ? BrandColors.navy
                          : BrandColors.border,
                    ),
                    showCheckmark: false,
                  ),
                  if (i < categories.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onPreview});

  final _EmailTemplateInfo template;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPreview,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 274),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BrandColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: template.tint,
                        borderRadius: BorderRadius.circular(13)),
                    child:
                        Icon(template.icon, color: template.accent, size: 22),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: template.tint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      template.category,
                      style: TextStyle(
                          color: template.accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(template.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.navy)),
                const SizedBox(height: 7),
                Text(template.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, height: 1.5, color: BrandColors.muted)),
                const SizedBox(height: 13),
                Row(children: [
                  Icon(Icons.schedule_outlined,
                      size: 14, color: template.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(template.timing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: BrandColors.navy,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 12),
                const Divider(height: 24, color: BrandColors.border),
                Row(children: [
                  const Icon(Icons.data_object,
                      size: 14, color: BrandColors.muted),
                  const SizedBox(width: 6),
                  Text('${template.variables.length} dynamic fields',
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: BrandColors.muted,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Preview'),
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.orange,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}

class _TemplatePreviewDialog extends StatelessWidget {
  const _TemplatePreviewDialog({required this.template});
  final _EmailTemplateInfo template;

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660, maxHeight: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: template.tint,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(template.icon, color: template.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: BrandColors.navy)),
                        Text(template.stage,
                            style: const TextStyle(
                                fontSize: 11.5, color: BrandColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewLabel(
                          label: 'WHEN IT IS USED', value: template.timing),
                      const SizedBox(height: 18),
                      const Text('Subject',
                          style: TextStyle(
                              fontSize: 11,
                              color: BrandColors.muted,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: BrandColors.border),
                        ),
                        child: Text(template.subject,
                            style: const TextStyle(
                                color: BrandColors.navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        const Expanded(
                          child: Text('Email preview',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: BrandColors.muted,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Icon(Icons.desktop_windows_outlined,
                            size: 14, color: template.accent),
                        const SizedBox(width: 5),
                        Text('Desktop preview',
                            style: TextStyle(
                                fontSize: 10, color: template.accent)),
                      ]),
                      const SizedBox(height: 7),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BrandColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A1B2A4E),
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(template.subject,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: BrandColors.navy)),
                            const SizedBox(height: 12),
                            const Row(children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: BrandColors.orange,
                                child: Text('T',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text('TalentBridge Recruiting',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: BrandColors.navy,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Text('Just now',
                                  style: TextStyle(
                                      fontSize: 10, color: BrandColors.muted)),
                            ]),
                            const Divider(height: 24),
                            Text(template.body,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.75,
                                    color: Color(0xFF475467))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Available dynamic fields',
                          style: TextStyle(
                              fontSize: 11,
                              color: BrandColors.muted,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final variable in template.variables)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 6),
                              decoration: BoxDecoration(
                                color: template.tint,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(variable,
                                  style: TextStyle(
                                      color: template.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                        backgroundColor: BrandColors.orange,
                        foregroundColor: Colors.white),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: BrandColors.muted,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    color: BrandColors.navy,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      );
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.border),
        ),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 34, color: BrandColors.muted),
          SizedBox(height: 10),
          Text('No templates match your search',
              style: TextStyle(
                  color: BrandColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 5),
          Text('Try another keyword or choose a different category.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BrandColors.muted, fontSize: 12)),
        ]),
      );
}

class _LibraryFooter extends StatelessWidget {
  const _LibraryFooter({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(compact ? 15 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE3CC)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: BrandColors.orange, size: 19),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Keep it personal',
              style: TextStyle(
                  color: BrandColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
          ),
          if (!compact)
            const Expanded(
              flex: 3,
              child: Text(
                'Dynamic fields such as {candidateName} and {jobTitle} help make every message feel like it was written for one person.',
                style: TextStyle(
                    color: BrandColors.muted, fontSize: 11, height: 1.45),
              ),
            )
          else
            const Expanded(
              flex: 3,
              child: Text(
                'Use dynamic fields to make every message feel personal.',
                style: TextStyle(
                    color: BrandColors.muted, fontSize: 11, height: 1.45),
              ),
            ),
        ]),
      );
}
