/// lib/features/jobs/presentation/widgets/send_interview_invite_dialog.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Confirmed against your real application_provider.dart — exports
// `applicationsRepositoryProvider` (plural "Applications"), not the
// singular name I'd guessed originally.
import '../../application/application_provider.dart';
import '../../data/models/application_model.dart';

/// One-off compose surface, not a saved template library — per the call
/// on this: "Template Type"/"Template Name" below are for the recruiter's
/// own context while writing this specific email, not something read
/// back later. Only `inviteType` (from Template Type) is actually sent to
/// the backend, and only as a free-text label for history/reporting.
///
/// Shows a plain multi-line body field with token insertion rather than a
/// full rich-text editor (the mockup's B/I/U/H1-3/link/image toolbar) —
/// that would need a package like flutter_quill and a decision on
/// storing/sending HTML, which hasn't been made. Ask if that's wanted.
Future<bool?> showSendInterviewInviteDialog(
  BuildContext context, {
  required JobApplicantSummary applicant,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => SendInterviewInviteDialog(applicant: applicant),
  );
}

const List<String> _templateTypes = [
  'Interview Invitation',
  'Technical Interview',
  'Final Round',
  'Custom',
];

class SendInterviewInviteDialog extends ConsumerStatefulWidget {
  const SendInterviewInviteDialog({super.key, required this.applicant});

  final JobApplicantSummary applicant;

  @override
  ConsumerState<SendInterviewInviteDialog> createState() =>
      _SendInterviewInviteDialogState();
}

class _SendInterviewInviteDialogState
    extends ConsumerState<SendInterviewInviteDialog> {
  String? _templateType;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  final _subjectFocus = FocusNode();
  final _bodyFocus = FocusNode();

  List<String>? _availableTokens;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectController =
        TextEditingController(text: 'Interview Invitation for {jobTitle}');
    _bodyController = TextEditingController(
      text: 'Hi {candidateFirstName},\n\n'
          'Thank you for applying to the {jobTitle} position at {CompanyName}. '
          "We'd love to invite you to the next step of the process, an interview with our team.\n\n"
          'To make scheduling easy, please use the link below to choose a time that works best for you:\n\n'
          '{InterviewBookingLink}\n\n'
          'We look forward to speaking with you!',
    );
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    try {
      final tokens =
          await ref.read(applicationsRepositoryProvider).getInviteTokens();
      if (mounted) setState(() => _availableTokens = tokens);
    } catch (_) {
      // Non-fatal — the token menu just won't offer suggestions, but the
      // recruiter can still type {tokenName} manually and the backend
      // will still render whichever ones it recognizes.
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _subjectFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _insertToken(String token) {
    final controller =
        _bodyFocus.hasFocus ? _bodyController : _subjectController;
    final selection = controller.selection;
    final text = controller.text;
    final insertion = '{$token}';
    final cursor = selection.start >= 0 ? selection.start : text.length;

    controller.value = TextEditingValue(
      text: text.replaceRange(
          cursor, selection.end >= 0 ? selection.end : cursor, insertion),
      selection: TextSelection.collapsed(offset: cursor + insertion.length),
    );
  }

  Future<void> _send() async {
    if (_subjectController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      setState(() => _error = 'Subject and body are both required');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await ref.read(applicationsRepositoryProvider).sendInterviewInvite(
            widget.applicant.id,
            subject: _subjectController.text.trim(),
            body: _bodyController.text.trim(),
            inviteType: _templateType,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Couldn\'t send invite: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Send Interview Invite',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              Text(
                'To ${widget.applicant.candidate.fullName} · ${widget.applicant.candidate.email}',
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TEMPLATE TYPE',
                          style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.black54,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _templateType,
                        hint: const Text('Template Type'),
                        items: _templateTypes
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setState(() => _templateType = v),
                      ),
                      const SizedBox(height: 14),
                      const Text('EMAIL SUBJECT',
                          style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.black54,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _subjectController,
                        focusNode: _subjectFocus,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('EMAIL BODY TEXT',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.black54,
                                  letterSpacing: 0.4)),
                          if (_availableTokens != null)
                            PopupMenuButton<String>(
                              tooltip: 'Insert token',
                              onSelected: _insertToken,
                              itemBuilder: (_) => _availableTokens!
                                  .map((t) => PopupMenuItem(
                                      value: t, child: Text('{$t}')))
                                  .toList(),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Token', style: TextStyle(fontSize: 11)),
                                  Icon(Icons.arrow_drop_down, size: 16),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _bodyController,
                        focusNode: _bodyFocus,
                        maxLines: 10,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 11.5)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSending
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSending ? null : _send,
                    child: Text(_isSending ? 'Sending...' : 'Send Invite'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
