import 'dart:async';

/// Broadcasts terminal authentication failures from any shared Dio client to
/// the auth state, which in turn causes GoRouter to send the user to login.
class SessionExpiredEvent {
  SessionExpiredEvent._();

  static final SessionExpiredEvent instance = SessionExpiredEvent._();

  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);
}
