import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/features/jobs/application/application_provider.dart';
import 'package:talentbridge/features/jobs/data/models/application_model.dart';

Future<bool?> showCandidateEmailDialog(
  BuildContext context, {
  required JobApplicantSummary applicant,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => CandidateEmailDialog(applicant: applicant),
  );
}

class CandidateEmailDialog extends ConsumerStatefulWidget {
  const CandidateEmailDialog({super.key, required this.applicant});

  final JobApplicantSummary applicant;

  @override
  ConsumerState<CandidateEmailDialog> createState() =>
      _CandidateEmailDialogState();
}

class _CandidateEmailDialogState extends ConsumerState<CandidateEmailDialog> {
  static const _templates = <_CandidateEmailTemplate>[
    _CandidateEmailTemplate(
      name: 'Shortlist update',
      subject: 'Good news about your {{jobTitle}} application',
      body: 'Hi {{candidateFirstName}},\n\n'
          'We are pleased to let you know that your application for '
          '{{jobTitle}} at {{companyName}} has progressed to the next stage. '
          'Our team will be in touch shortly with more information.\n\n'
          'Thank you,\n{{recruiterName}}',
    ),
    _CandidateEmailTemplate(
      name: 'Interview invitation',
      subject: 'Interview invitation: {{jobTitle}} at {{companyName}}',
      body: 'Hi {{candidateFirstName}},\n\n'
          'We would like to invite you to interview for the {{jobTitle}} role '
          'at {{companyName}}. Please reply to this email with a few times '
          'that work for you, and we will coordinate the details.\n\n'
          'Best,\n{{recruiterName}}',
    ),
    _CandidateEmailTemplate(
      name: 'Application update',
      subject: 'An update on your {{jobTitle}} application',
      body: 'Hi {{candidateFirstName}},\n\n'
          'Thank you for your interest in the {{jobTitle}} position at '
          '{{companyName}}. We wanted to share an update about your '
          'application.\n\n{{recruiterName}}',
    ),
    _CandidateEmailTemplate(
      name: 'Application received',
      subject: 'We received your {{jobTitle}} application',
      body: 'Hi {{candidateFirstName}},\n\n'
          'Thank you for applying for {{jobTitle}} at {{companyName}}. '
          'Your application has been received by our hiring team. We will '
          'be in touch when we have an update.\n\n'
          'Best regards,\n{{recruiterName}}',
    ),
  ];

  static const _knownTokens = {
    'candidateName',
    'candidateFirstName',
    'candidateLastName',
    'jobTitle',
    'companyName',
    'recruiterName',
  };

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  late _CandidateEmailTemplate _selectedTemplate;
  bool _isSending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = _templates.first;
    _applyTemplate(_selectedTemplate);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _applyTemplate(_CandidateEmailTemplate template) {
    _subjectController.text = template.subject;
    _bodyController.text = template.body;
    _sendError = null;
  }

  String? _validateMessage(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required.';
    if (text.length > 12000) return 'Keep the email under 12,000 characters.';

    final tokens = RegExp(r'\{\{([^{}]+)\}\}')
        .allMatches(text)
        .map((match) => match.group(1)!)
        .toList();
    if (tokens.any((token) => !_knownTokens.contains(token))) {
      return 'This email contains an unsupported dynamic field.';
    }
    final withoutTokens = text.replaceAll(RegExp(r'\{\{[^{}]+\}\}'), '');
    if (withoutTokens.contains('{{') || withoutTokens.contains('}}')) {
      return 'Dynamic fields must use the complete {{fieldName}} format.';
    }
    return null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSending = true;
      _sendError = null;
    });

    try {
      await ref.read(applicationsRepositoryProvider).sendCandidateEmail(
            widget.applicant.id,
            templateName: _selectedTemplate.name,
            subject: _subjectController.text.trim(),
            body: _bodyController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _sendError = 'Could not send email: $error');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.applicant.candidate;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FA),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.mark_email_read_outlined,
                          color: BrandColors.navy),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email candidate',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          SizedBox(height: 3),
                          Text('Choose a template and personalize the message.',
                              style: TextStyle(
                                  fontSize: 12, color: BrandColors.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _isSending
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BrandColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 17, color: BrandColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${candidate.fullName} · ${candidate.email}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<_CandidateEmailTemplate>(
                  initialValue: _selectedTemplate,
                  decoration: const InputDecoration(
                    labelText: 'Email template',
                    prefixIcon: Icon(Icons.article_outlined),
                  ),
                  items: _templates
                      .map((template) => DropdownMenuItem(
                            value: template,
                            child: Text(template.name),
                          ))
                      .toList(),
                  onChanged: _isSending
                      ? null
                      : (template) {
                          if (template == null) return;
                          setState(() {
                            _selectedTemplate = template;
                            _applyTemplate(template);
                          });
                        },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _subjectController,
                          enabled: !_isSending,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            counterText: '',
                          ),
                          inputFormatters: [
                            _ProtectMergeFieldsFormatter(),
                            LengthLimitingTextInputFormatter(200),
                          ],
                          validator: (value) {
                            final error = _validateMessage(value);
                            if (error != null) return error;
                            if ((value ?? '').contains(RegExp(r'[\r\n]'))) {
                              return 'Subject must be a single line.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bodyController,
                          enabled: !_isSending,
                          minLines: 8,
                          maxLines: 12,
                          maxLength: 12000,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          decoration: const InputDecoration(
                            labelText: 'Email message',
                            alignLabelWithHint: true,
                            helperText:
                                'Dynamic fields are filled from the candidate, job, and company profile.',
                          ),
                          inputFormatters: [
                            _ProtectMergeFieldsFormatter(),
                            LengthLimitingTextInputFormatter(12000),
                          ],
                          validator: _validateMessage,
                        ),
                        if (_sendError != null) ...[
                          const SizedBox(height: 8),
                          Text(_sendError!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 15, color: BrandColors.muted),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '{{candidateName}} and other merge fields are locked.',
                        style:
                            TextStyle(color: BrandColors.muted, fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: _isSending
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: _isSending ? null : _send,
                      icon: _isSending
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 16),
                      label: Text(_isSending ? 'Sending…' : 'Send email'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateEmailTemplate {
  const _CandidateEmailTemplate({
    required this.name,
    required this.subject,
    required this.body,
  });

  final String name;
  final String subject;
  final String body;
}

class _ProtectMergeFieldsFormatter extends TextInputFormatter {
  const _ProtectMergeFieldsFormatter();

  static final _tokenPattern = RegExp(r'\{\{[^{}]+\}\}');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldTokens =
        _tokenPattern.allMatches(oldValue.text).map((m) => m.group(0)).toList();
    final newTokens =
        _tokenPattern.allMatches(newValue.text).map((m) => m.group(0)).toList();
    return listEquals(oldTokens, newTokens) ? newValue : oldValue;
  }
}
