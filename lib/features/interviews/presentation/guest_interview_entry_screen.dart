import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/interview_repository.dart';
import '../data/models/interview_model.dart';
import 'interview_room_screen.dart';

class GuestInterviewEntryScreen extends ConsumerStatefulWidget {
  const GuestInterviewEntryScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<GuestInterviewEntryScreen> createState() =>
      _GuestInterviewEntryScreenState();
}

class _GuestInterviewEntryScreenState
    extends ConsumerState<GuestInterviewEntryScreen> {
  final _nameController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final token = widget.token?.trim() ?? '';
    final name = _nameController.text.trim();
    if (token.isEmpty) {
      setState(
          () => _error = 'This invitation link is missing its access code.');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Enter your name to join.');
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final info = await ref
          .read(interviewRepositoryProvider)
          .guestJoinToken(token, name);
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => InterviewRoomScreen(
            interview: Interview.guestPlaceholder(),
            guestToken: token,
            guestDisplayName: name,
            initialGuestJoinInfo: info,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is InterviewException
            ? error.message
            : 'This invitation could not be validated.');
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1030),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                color: const Color(0xFF171E4A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.video_call_outlined,
                          color: Color(0xFFFFC58E), size: 42),
                      const SizedBox(height: 16),
                      const Text(
                        'Join an interview',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your name to continue. This invitation only grants access to the interview room.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _nameController,
                        enabled: !_joining,
                        autofocus: true,
                        maxLength: 48,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _join(),
                        decoration: InputDecoration(
                          labelText: 'Your name',
                          filled: true,
                          fillColor: Colors.white,
                          errorText: _error,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _joining ? null : _join,
                        icon: _joining
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login),
                        label: Text(_joining ? 'Checking invitation…' : 'Join'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDB6B32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No account sign-in is required. The invitation expires when the interview join window closes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
