import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// Prefixed: LiveKit also exports a `ConnectionState` that clashes with Flutter's.
import 'package:livekit_client/livekit_client.dart' as lk;

import '../data/models/interview_model.dart';
import '../application/interview_provider.dart';
import '../data/interview_repository.dart';
import './widgets/interview_theme.dart';

const _bg = Color(0xFF0B1030);
const _panel = Color(0xFF171E4A);

/// Full-screen call. Works for recruiters and candidates: the backend decides
/// who may join and tells us which role we have.
Future<void> openInterviewRoom(BuildContext context, Interview interview) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => InterviewRoomScreen(interview: interview),
    ));

enum _Phase { connecting, waiting, live, failed }

class InterviewRoomScreen extends ConsumerStatefulWidget {
  const InterviewRoomScreen({super.key, required this.interview});
  final Interview interview;

  @override
  ConsumerState<InterviewRoomScreen> createState() => _RoomState();
}

class _RoomState extends ConsumerState<InterviewRoomScreen> {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _events;
  JoinInfo? _info;
  _Phase _phase = _Phase.connecting;
  String? _error;
  String? _mediaWarning;
  DateTime? _connectedAt;
  Timer? _ticker;
  Timer? _waitingPoll;
  Timer? _hostPoll;
  InterviewWaitingCandidate? _waitingCandidate;
  bool _waitingPollBusy = false;
  bool _hostPollBusy = false;
  bool _admitting = false;
  bool _leaving = false;

  // Screen sharing on phones needs extra native setup (Android foreground
  // service / iOS broadcast extension), so it's offered on web & desktop only.
  bool get _canShareScreen =>
      kIsWeb ||
      const {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux}
          .contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    _join();
  }

  @override
  void dispose() {
    _leaving = true;
    _waitingPoll?.cancel();
    _hostPoll?.cancel();
    unawaited(_cleanup());
    super.dispose();
  }

  // ---------------------------------------------------------- connection --

  Future<void> _join() async {
    await _cleanup();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.connecting;
      _error = null;
      _mediaWarning = null;
      _leaving = false;
    });

    try {
      final info = await ref
          .read(interviewRepositoryProvider)
          .joinToken(widget.interview.id);
      if (!mounted) return;

      if (info.waiting) {
        setState(() {
          _info = info;
          _phase = _Phase.waiting;
        });
        _waitingPoll?.cancel();
        _waitingPoll = Timer.periodic(const Duration(seconds: 3), (_) {
          unawaited(_checkWaitingAdmission());
        });
        return;
      }

      await _connectWithInfo(info);
    } catch (e) {
      await _cleanup();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e is InterviewException
            ? e.message
            : 'Couldn\'t connect to the call. Check your connection and try again.';
      });
    }
  }

  Future<void> _connectWithInfo(JoinInfo info) async {
    if (info.token == null || info.url == null) return;
    try {
      final room = lk.Room(
        roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room; // assigned early so _cleanup can always release it
      room.addListener(_onRoomChanged);
      _events = room.createListener()
        ..on<lk.RoomDisconnectedEvent>((_) {
          if (_leaving || !mounted) return;
          setState(() {
            _phase = _Phase.failed;
            _error = 'You were disconnected from the call.';
          });
        });

      await room.connect(info.url!, info.token!);
      if (!mounted) return; // dispose() already released the room

      await _enableMedia(room);
      if (!mounted) return;

      setState(() {
        _info = info;
        _phase = _Phase.live;
        _connectedAt = DateTime.now();
      });
      _waitingPoll?.cancel();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      if (info.isHost) {
        _hostPoll?.cancel();
        _hostPoll = Timer.periodic(const Duration(seconds: 3), (_) {
          unawaited(_refreshWaitingCandidate());
        });
        unawaited(_refreshWaitingCandidate());
      }
    } catch (e) {
      await _cleanup();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e is InterviewException
            ? e.message
            : 'Couldn\'t connect to the call. Check your connection and try again.';
      });
    }
  }

  Future<void> _checkWaitingAdmission() async {
    if (_waitingPollBusy || !mounted || _phase != _Phase.waiting) return;
    _waitingPollBusy = true;
    try {
      final info = await ref
          .read(interviewRepositoryProvider)
          .joinToken(widget.interview.id);
      if (!mounted || _phase != _Phase.waiting) return;
      if (!info.waiting) {
        _waitingPoll?.cancel();
        setState(() => _phase = _Phase.connecting);
        await _connectWithInfo(info);
      }
    } catch (e) {
      if (e is InterviewException && e.statusCode == 409 && mounted) {
        _waitingPoll?.cancel();
        setState(() {
          _phase = _Phase.failed;
          _error = e.message;
        });
      }
      // Keep the lobby visible during a brief network interruption.
    } finally {
      _waitingPollBusy = false;
    }
  }

  Future<void> _refreshWaitingCandidate() async {
    if (_hostPollBusy || !mounted || _phase != _Phase.live) return;
    _hostPollBusy = true;
    try {
      final candidate = await ref
          .read(interviewRepositoryProvider)
          .waitingCandidate(widget.interview.id);
      if (mounted) setState(() => _waitingCandidate = candidate);
    } catch (_) {
      // The host controls remain available if the waiting-room check times out.
    } finally {
      _hostPollBusy = false;
    }
  }

  Future<void> _enableMedia(lk.Room room) async {
    final warnings = <String>[];
    try {
      await room.localParticipant?.setMicrophoneEnabled(true);
    } catch (_) {
      warnings
          .add('Microphone unavailable — allow microphone access to be heard.');
    }
    try {
      await room.localParticipant?.setCameraEnabled(true);
    } catch (_) {
      warnings.add('Camera unavailable — allow camera access to be seen.');
    }
    if (warnings.isNotEmpty && mounted) {
      setState(() => _mediaWarning = warnings.join('\n'));
    }
  }

  Future<void> _cleanup() async {
    _ticker?.cancel();
    _ticker = null;
    _waitingPoll?.cancel();
    _waitingPoll = null;
    _hostPoll?.cancel();
    _hostPoll = null;
    final events = _events;
    final room = _room;
    _events = null;
    _room = null;
    _info = null;
    _connectedAt = null;
    try {
      await events?.dispose();
    } catch (_) {}
    if (room != null) {
      room.removeListener(_onRoomChanged);
      try {
        await room.disconnect();
      } catch (_) {}
      try {
        await room.dispose();
      } catch (_) {}
    }
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------ controls --

  Future<void> _toggleMic() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    try {
      await local.setMicrophoneEnabled(!local.isMicrophoneEnabled());
    } catch (_) {
      if (mounted) toast(context, 'Couldn\'t access the microphone');
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    try {
      await local.setCameraEnabled(!local.isCameraEnabled());
    } catch (_) {
      if (mounted) toast(context, 'Couldn\'t access the camera');
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleShare() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    try {
      await local.setScreenShareEnabled(!local.isScreenShareEnabled());
    } catch (_) {
      if (mounted) toast(context, 'Couldn\'t start screen sharing');
    }
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    final i = widget.interview;
    final canFinalize =
        (_info?.isInterviewer ?? false) && i.isActive && i.hasStarted;
    final isWaiting = _phase == _Phase.waiting;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isWaiting ? 'Leave the waiting room?' : 'Leave the call?'),
        content: Text(isWaiting
            ? 'You will leave the lobby and need to request entry again.'
            : canFinalize
                ? 'You can also mark this interview as completed now.'
                : 'You can rejoin while the room is open.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'leave'),
              child: const Text('Leave')),
          if (canFinalize)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ivOrange),
              onPressed: () => Navigator.pop(ctx, 'finalize'),
              child: const Text('Leave & mark completed'),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'finalize') {
      try {
        await ref
            .read(interviewActionsProvider)
            .closeOut(i.id, InterviewStatus.completed);
      } catch (e) {
        if (mounted) toast(context, errorMessage(e));
      }
    }
    if (isWaiting) {
      try {
        await ref.read(interviewRepositoryProvider).cancelWaitingRequest(i.id);
      } catch (_) {}
    }
    _leaving = true;
    await _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _admitWaitingCandidate() async {
    if (_waitingCandidate == null || _admitting) return;
    setState(() => _admitting = true);
    try {
      await ref
          .read(interviewRepositoryProvider)
          .admitWaitingCandidate(widget.interview.id);
      if (!mounted) return;
      setState(() => _waitingCandidate = null);
      toast(context, 'Candidate admitted to the interview.');
    } catch (e) {
      if (mounted) toast(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _admitting = false);
    }
  }

  Future<void> _showWaitingRoom() async {
    await _refreshWaitingCandidate();
    if (!mounted) return;
    final candidate = _waitingCandidate;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: candidate == null
              ? const SizedBox(
                  height: 150,
                  child: Center(
                    child: Text('No one is waiting to join.',
                        style: TextStyle(color: Colors.white70)),
                  ),
                )
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Waiting to join',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IvAvatar(name: candidate.name, radius: 22),
                    title: Text(candidate.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(candidate.email,
                        style: const TextStyle(color: Colors.white60)),
                    trailing: const Icon(Icons.hourglass_top,
                        color: Color(0xFFFFC58E)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _admitting
                          ? null
                          : () async {
                              await _admitWaitingCandidate();
                              if (sheetContext.mounted &&
                                  _waitingCandidate == null) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                      style: FilledButton.styleFrom(
                          backgroundColor: ivOrange,
                          foregroundColor: Colors.white),
                      icon: _admitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login),
                      label: const Text('Admit to interview'),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Future<void> _showInvitePanel() async {
    try {
      final interviewers = await ref
          .read(interviewRepositoryProvider)
          .companyInterviewers(widget.interview.id);
      if (!mounted) return;
      if (interviewers.isEmpty) {
        toast(context, 'There are no other company recruiters to invite.');
        return;
      }
      final selectedIds = <String>{};
      var saving = false;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _panel,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Invite company recruiters',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'They will receive an in-app interview invitation.',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: interviewers.length,
                    itemBuilder: (context, index) {
                      final person = interviewers[index];
                      return CheckboxListTile(
                        value: selectedIds.contains(person.id),
                        activeColor: ivOrange,
                        onChanged: saving
                            ? null
                            : (checked) => setModalState(() {
                                  if (checked == true) {
                                    selectedIds.add(person.id);
                                  } else {
                                    selectedIds.remove(person.id);
                                  }
                                }),
                        secondary: IvAvatar(name: person.name, radius: 18),
                        title: Text(person.name,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(person.email,
                            style: const TextStyle(color: Colors.white60)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: selectedIds.isEmpty || saving
                        ? null
                        : () async {
                            setModalState(() => saving = true);
                            try {
                              final invited = await ref
                                  .read(interviewRepositoryProvider)
                                  .inviteInterviewers(widget.interview.id,
                                      selectedIds.toList());
                              if (!mounted || !sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              toast(context,
                                  'Invited ${invited.length} company member${invited.length == 1 ? '' : 's'}.');
                            } catch (e) {
                              if (!mounted || !sheetContext.mounted) return;
                              setModalState(() => saving = false);
                              toast(context, errorMessage(e));
                            }
                          },
                    style: FilledButton.styleFrom(
                        backgroundColor: ivOrange,
                        foregroundColor: Colors.white),
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(
                        saving ? 'Sending invitations…' : 'Invite selected'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) toast(context, errorMessage(e));
    }
  }

  Future<void> _switchInterview(Interview interview) async {
    _leaving = true;
    await _cleanup();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => InterviewRoomScreen(interview: interview),
    ));
  }

  void _showParticipants() {
    final room = _room;
    if (room == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (_) => ListenableBuilder(
        listenable: room,
        builder: (context, _) {
          final people = <lk.Participant>[
            if (room.localParticipant != null) room.localParticipant!,
            ...room.remoteParticipants.values,
          ];
          return SafeArea(
            child: ListView(shrinkWrap: true, children: [
              for (final p in people)
                ListTile(
                  leading: IvAvatar(name: _nameOf(p), radius: 18),
                  title: Text(
                      p == room.localParticipant
                          ? '${_nameOf(p)} (You)'
                          : _nameOf(p),
                      style: const TextStyle(color: Colors.white)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(p.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
                        size: 18,
                        color:
                            p.isMicrophoneEnabled() ? Colors.white70 : ivRed),
                    const SizedBox(width: 10),
                    Icon(
                        p.isCameraEnabled()
                            ? Icons.videocam
                            : Icons.videocam_off,
                        size: 18,
                        color: p.isCameraEnabled() ? Colors.white70 : ivRed),
                  ]),
                ),
            ]),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- helpers --

  String _nameOf(lk.Participant p) => p.name.isNotEmpty
      ? p.name
      : (p.identity.isNotEmpty ? p.identity : 'Guest');

  lk.VideoTrack? _video(lk.Participant p, {bool screen = false}) {
    for (final pub in p.videoTrackPublications) {
      if (pub.isScreenShare != screen || pub.muted) continue;
      final t = pub.track;
      if (t is lk.VideoTrack) return t;
    }
    return null;
  }

  String _elapsed() {
    final t = _connectedAt;
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ------------------------------------------------------------------ UI --

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_phase == _Phase.live || _phase == _Phase.waiting) {
          _leave();
        } else {
          _leaving = true;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: switch (_phase) {
            _Phase.connecting => _status(
                icon: null,
                title: 'Joining the interview…',
                message: widget.interview.candidate.name.isEmpty
                    ? null
                    : '${widget.interview.roundName} · ${widget.interview.jobTitle}'),
            _Phase.failed => _status(
                  icon: Icons.videocam_off_outlined,
                  title: 'Can\'t join the call',
                  message: _error,
                  actions: [
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: ivOrange),
                      onPressed: _join,
                      child: const Text('Try again'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ]),
            _Phase.waiting => _waiting(),
            _Phase.live => _live(wide),
          },
        ),
      ),
    );
  }

  Widget _waiting() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF171E4A), Color(0xFF273B68)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .1)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: ivOrange.withValues(alpha: .16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFFFFC58E), size: 36),
                ),
                const SizedBox(height: 18),
                const Text('You’re in the waiting room',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'The recruiter has been notified. You’ll join the call as soon as they let you in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .75), height: 1.45),
                ),
                const SizedBox(height: 18),
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFFC58E))),
                  SizedBox(width: 10),
                  Text('Waiting for the host…',
                      style: TextStyle(
                          color: Color(0xFFFFC58E),
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 20),
                Text(
                    '${widget.interview.roundName} · ${widget.interview.jobTitle}',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _leave,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38)),
                  icon: const Icon(Icons.close),
                  label: const Text('Leave waiting room'),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _status(
      {IconData? icon,
      required String title,
      String? message,
      List<Widget>? actions}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (icon == null)
            const CircularProgressIndicator(color: ivOrange)
          else
            Icon(icon, color: Colors.white54, size: 44),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          if (actions != null) ...[
            const SizedBox(height: 20),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ]),
      ),
    );
  }

  Widget _live(bool wide) {
    final room = _room!;
    final local = room.localParticipant;
    final reconnecting =
        room.connectionState == lk.ConnectionState.reconnecting;
    final remotes = room.remoteParticipants.values.toList();
    final i = widget.interview;

    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i.roundName}: ${i.jobTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(
                  '${_elapsed()} elapsed  ·  ${remotes.length + 1} in call  ·  Encrypted',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ]),
          ),
        ]),
      ),
      if (reconnecting)
        _banner('Connection lost — reconnecting…', ivOrange)
      else if (_mediaWarning != null)
        _banner(_mediaWarning!, const Color(0xFF7A5C00)),
      // Stage
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: wide
              ? Row(children: [
                  Expanded(child: _stage(local, remotes, true)),
                  const SizedBox(width: 12),
                  SizedBox(width: 270, child: _scheduledRail()),
                ])
              : _stage(local, remotes, false),
        ),
      ),
      // Controls
      Padding(
        padding: const EdgeInsets.only(bottom: 14, top: 4),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            _CtrlButton(
              icon: (local?.isMicrophoneEnabled() ?? false)
                  ? Icons.mic
                  : Icons.mic_off,
              label: 'Mic',
              off: !(local?.isMicrophoneEnabled() ?? false),
              onTap: _toggleMic,
            ),
            _CtrlButton(
              icon: (local?.isCameraEnabled() ?? false)
                  ? Icons.videocam
                  : Icons.videocam_off,
              label: 'Camera',
              off: !(local?.isCameraEnabled() ?? false),
              onTap: _toggleCamera,
            ),
            if (_canShareScreen)
              _CtrlButton(
                icon: Icons.screen_share_outlined,
                label: 'Share',
                active: local?.isScreenShareEnabled() ?? false,
                onTap: _toggleShare,
              ),
            _CtrlButton(
              icon: Icons.groups_outlined,
              label: 'People (${remotes.length + 1})',
              onTap: _showParticipants,
            ),
            if (_info?.isHost == true) ...[
              _CtrlButton(
                icon: Icons.hourglass_top_rounded,
                label: _waitingCandidate == null ? 'Waiting room' : 'Admit (1)',
                active: _waitingCandidate != null,
                onTap: _showWaitingRoom,
              ),
              _CtrlButton(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Invite team',
                onTap: _showInvitePanel,
              ),
            ],
            _CtrlButton(
              icon: Icons.call_end,
              label: 'Leave',
              danger: true,
              onTap: _leave,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _scheduledRail() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final range = (from: monday, to: monday.add(const Duration(days: 7)));
    return Container(
      decoration:
          BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upcoming interviews',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 10),
        Expanded(
            child: ref.watch(interviewsProvider(range)).when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const Text('Could not load your schedule.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  data: (items) {
                    final upcoming = items
                        .where((item) =>
                            item.id != widget.interview.id &&
                            item.isActive &&
                            item.endsAt.isAfter(now))
                        .toList()
                      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                    if (upcoming.isEmpty) {
                      return const Center(
                          child: Text('No other scheduled meetings this week.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)));
                    }
                    return ListView.separated(
                      itemCount: upcoming.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = upcoming[index];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFF202957),
                              borderRadius: BorderRadius.circular(10)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.candidate.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                const SizedBox(height: 3),
                                Text('${item.jobTitle} · ${item.roundName}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 10)),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          DateFormat('EEE · h:mm a')
                                              .format(item.startsAt),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10))),
                                  if (item.canJoinNow)
                                    TextButton(
                                        onPressed: () => _switchInterview(item),
                                        style: TextButton.styleFrom(
                                            foregroundColor: ivOrange,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(44, 28)),
                                        child: const Text('Join',
                                            style: TextStyle(fontSize: 11))),
                                ]),
                              ]),
                        );
                      },
                    );
                  },
                )),
      ]),
    );
  }

  Widget _banner(String text, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );

  Widget _tile(lk.Participant p, {required bool isLocal}) {
    // Remote screen shares take over that person's tile; for yourself the
    // camera stays visible.
    final screen = !isLocal ? _video(p, screen: true) : null;
    final track = screen ?? _video(p);
    return _ParticipantTile(
      name: isLocal ? '${_nameOf(p)} (You)' : _nameOf(p),
      track: track,
      isScreen: screen != null,
      speaking: p.isSpeaking,
      micOn: p.isMicrophoneEnabled(),
    );
  }

  Widget _stage(lk.LocalParticipant? local, List<lk.RemoteParticipant> remotes,
      bool wide) {
    if (remotes.isEmpty) {
      return Stack(children: [
        Positioned.fill(
            child: local == null
                ? const SizedBox.shrink()
                : _tile(local, isLocal: true)),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: _banner('Waiting for others to join the interview…',
              const Color(0xCC10163D)),
        ),
      ]);
    }

    if (remotes.length == 1) {
      final pip = wide ? const Size(220, 140) : const Size(104, 148);
      return Stack(children: [
        Positioned.fill(child: _tile(remotes.first, isLocal: false)),
        if (local != null)
          Positioned(
            right: 10,
            bottom: 10,
            width: pip.width,
            height: pip.height,
            child: _tile(local, isLocal: true),
          ),
      ]);
    }

    // Panel interview: simple grid, everyone equal.
    final all = <Widget>[
      for (final r in remotes) _tile(r, isLocal: false),
      if (local != null) _tile(local, isLocal: true),
    ];
    return GridView.count(
      crossAxisCount: wide ? 3 : 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: wide ? 16 / 10 : 3 / 4,
      children: all,
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.name,
    required this.track,
    required this.isScreen,
    required this.speaking,
    required this.micOn,
  });

  final String name;
  final lk.VideoTrack? track;
  final bool isScreen, speaking, micOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: speaking ? ivOrange : Colors.transparent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (track != null)
          lk.VideoTrackRenderer(
            track!,
            fit: isScreen ? lk.VideoViewFit.contain : lk.VideoViewFit.cover,
          )
        else
          Center(child: IvAvatar(name: name, radius: 30)),
        Positioned(
          left: 8,
          bottom: 8,
          right: 8,
          child: Row(children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!micOn) ...[
                    const Icon(Icons.mic_off, size: 12, color: ivRed),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(isScreen ? '$name · screen' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CtrlButton extends StatelessWidget {
  const _CtrlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.off = false,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool off, active, danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? ivRed
        : off
            ? const Color(0xFF5A2430)
            : active
                ? ivOrange
                : _panel;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icon, color: Colors.white, size: 22)),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}
