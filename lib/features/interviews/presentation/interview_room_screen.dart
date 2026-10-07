import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

enum _Phase { connecting, live, failed }

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

      final room = lk.Room();
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

      await room.connect(
        info.url,
        info.token,
        roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      if (!mounted) return; // dispose() already released the room

      await _enableMedia(room);
      if (!mounted) return;

      setState(() {
        _info = info;
        _phase = _Phase.live;
        _connectedAt = DateTime.now();
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
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

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the call?'),
        content: Text(canFinalize
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
    _leaving = true;
    await _cleanup();
    if (mounted) Navigator.of(context).pop();
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_phase == _Phase.live) {
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
            _Phase.live => _live(wide),
          },
        ),
      ),
    );
  }

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
          child: _stage(local, remotes, wide),
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
