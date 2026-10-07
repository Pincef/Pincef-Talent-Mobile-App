import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/messages_provider.dart';
import '../../application/presence_provider.dart';
import '../../data/messages_repository.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(messageThreadsProvider);

    return threads.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Unable to load messages: $error')),
      data: (items) {
        final selectedNotifier =
            ref.read(selectedMessageThreadProvider.notifier);

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            // Auto-selecting the top thread is desktop-only behavior — the
            // two-pane layout would otherwise show an empty "select a
            // conversation" pane on first load. On mobile this must NOT
            // run, or every visit (including tapping the back arrow, which
            // sets selection back to null and would immediately trigger
            // this again) jumps straight past the thread list.
            if (!compact &&
                ref.read(selectedMessageThreadProvider) == null &&
                items.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => selectedNotifier.state = items.first.id);
            }
            final selectedId = ref.watch(selectedMessageThreadProvider);
            // Null-safe on purpose: selectedId can point at a thread this
            // particular fetch doesn't have yet (a brand-new conversation,
            // or a stale id left over from a previous session/user) — that
            // should read as "nothing selected", not crash the screen.
            MessageThread? selectedThread;
            for (final t in items) {
              if (t.id == selectedId) {
                selectedThread = t;
                break;
              }
            }

            if (!compact) {
              return Column(
                children: [
                  const _MessagesHeader(compact: false),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                            width: 250, child: _ThreadList(threads: items)),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: selectedThread == null
                              ? const Center(
                                  child: Text('Select a conversation'))
                              : _ConversationPane(
                                  key: ValueKey(selectedThread.id),
                                  thread: selectedThread,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Mobile: list and conversation are two separate "screens" —
            // tapping a thread pushes into it, the header's back arrow pops
            // back to the list. Nothing shows both at once on a phone width.
            if (selectedThread == null) {
              return Column(
                children: [
                  const _MessagesHeader(compact: true),
                  Expanded(child: _ThreadList(threads: items)),
                ],
              );
            }
            return _ConversationPane(
              key: ValueKey(selectedThread.id),
              thread: selectedThread,
              onBack: () => selectedNotifier.state = null,
            );
          },
        );
      },
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding:
          EdgeInsets.fromLTRB(compact ? 16 : 26, 16, compact ? 16 : 26, 14),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages & Talent Outreach',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                SizedBox(height: 3),
                Text(
                  'Communicate directly with candidates, schedule next steps, and',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
                Text(
                  'deploy AI-assisted response templates.',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.tune, size: 12),
              label:
                  const Text('Filter Pipeline', style: TextStyle(fontSize: 9)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.group_add_outlined, size: 12),
              label: const Text('Message Team', style: TextStyle(fontSize: 9)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
              ),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 13),
            label:
                const Text('New Conversation', style: TextStyle(fontSize: 9)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadList extends ConsumerWidget {
  const _ThreadList({required this.threads});

  final List<MessageThread> threads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMessageThreadProvider);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search candidates',
                hintStyle: const TextStyle(fontSize: 9),
                prefixIcon: const Icon(Icons.search, size: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ),
          _InboxTabs(unreadCount: threads.where((t) => t.unread).length),
          Expanded(
            child: ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) {
                final thread = threads[i];
                final active = selected == thread.id;
                final online = ref.watch(presenceProvider
                    .select((p) => p[thread.partnerId]?.online ?? false));
                return InkWell(
                  onTap: () => ref
                      .read(selectedMessageThreadProvider.notifier)
                      .state = thread.id,
                  child: Container(
                    color: active ? const Color(0xFFFFF1E7) : null,
                    padding: const EdgeInsets.all(11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PresenceAvatar(
                            name: thread.name, size: 30, online: online),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      thread.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: thread.unread
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(thread.time,
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        color: thread.unread
                                            ? AppColors.orange
                                            : AppColors.textSecondary,
                                        fontWeight: thread.unread
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      )),
                                ],
                              ),
                              Text(thread.role,
                                  style: const TextStyle(
                                      fontSize: 8,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      thread.preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        color: thread.unread
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        fontWeight: thread.unread
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (thread.unread) ...[
                                    const SizedBox(width: 6),
                                    _UnreadBadge(count: thread.unreadCount),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              _StatusChip(label: thread.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxTabs extends StatelessWidget {
  const _InboxTabs({required this.unreadCount});
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      child: Row(
        children: [
          const _Tab(text: 'All', active: true),
          const SizedBox(width: 12),
          const _Tab(text: 'Shortlisted'),
          const Spacer(),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(3)),
              child: Text('$unreadCount',
                  style: const TextStyle(fontSize: 7, color: Colors.white)),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.text, this.active = false});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
        color: active ? AppColors.textPrimary : AppColors.textSecondary,
      ),
    );
  }
}

class _ConversationPane extends ConsumerStatefulWidget {
  const _ConversationPane({super.key, required this.thread, this.onBack});

  final MessageThread thread;
  // Non-null only in the mobile flow, where the header needs a back arrow
  // to return to the thread list.
  final VoidCallback? onBack;

  @override
  ConsumerState<_ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends ConsumerState<_ConversationPane> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    ref
        .read(conversationProvider(widget.thread.id).notifier)
        .send(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationProvider(widget.thread.id));

    return Container(
      color: const Color(0xFFF9FAFB),
      child: conversation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (messages) => Column(
          children: [
            _ConversationHeader(thread: widget.thread, onBack: widget.onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                children: [
                  const Center(
                    child: Text('Today',
                        style: TextStyle(
                            fontSize: 8, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 14),
                  ...messages.map((message) => _Bubble(message: message)),
                  const _InterviewCard(),
                ],
              ),
            ),
            const _SuggestedReplies(),
            _Composer(controller: _controller, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _ConversationHeader extends ConsumerWidget {
  const _ConversationHeader({required this.thread, this.onBack});

  final MessageThread thread;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence =
        ref.watch(presenceProvider.select((p) => p[thread.partnerId]));
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: onBack,
                padding: EdgeInsets.zero),
            const SizedBox(width: 4),
          ],
          _PresenceAvatar(
              name: thread.name, size: 36, online: presence?.online ?? false),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(thread.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800)),
                Text(
                  [thread.role, presence?.statusLabel]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(
                    fontSize: 8,
                    color: presence?.online == true
                        ? const Color(0xFF16A34A)
                        : AppColors.textSecondary,
                    fontWeight: presence?.online == true
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const _StatusChip(label: 'Match 90%'),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (message.status) {
      MessageStatus.sent => 'Sent',
      MessageStatus.delivered => 'Delivered',
      MessageStatus.read => 'Read',
      null => null,
    };
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isMine ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(5),
          boxShadow: message.isMine
              ? null
              : const [BoxShadow(color: Color(0x11000000), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                  fontSize: 9,
                  height: 1.4,
                  color: message.isMine ? Colors.white : AppColors.textPrimary),
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                statusLabel == null
                    ? _shortTime(message.time)
                    : '${_shortTime(message.time)}   $statusLabel',
                style: TextStyle(
                    fontSize: 7,
                    color: message.isMine
                        ? Colors.white70
                        : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _InterviewCard extends StatelessWidget {
  const _InterviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_month, size: 20, color: AppColors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Technical Architecture Discussion',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                Text('Thu, Oct 16 · 2:00 PM PST · Google Meet',
                    style:
                        TextStyle(fontSize: 8, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.check_circle, size: 13, color: AppColors.orange),
        ],
      ),
    );
  }
}

class _SuggestedReplies extends StatelessWidget {
  const _SuggestedReplies();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 7),
      child: const SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('✨ Suggested Next Steps',
                style: TextStyle(fontSize: 8, color: AppColors.orange)),
            SizedBox(width: 9),
            _Suggestion(text: 'Confirm Thursday slot'),
            _Suggestion(text: 'Share interview prep guidelines'),
            _Suggestion(text: 'Request a portfolio'),
          ],
        ),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(3)),
      child: Text(text, style: const TextStyle(fontSize: 7.5)),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              maxLines: null,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText:
                    'Type your message or use /template to insert\na formatted template...',
                hintStyle:
                    TextStyle(fontSize: 9, color: AppColors.textSecondary),
              ),
              style: const TextStyle(fontSize: 9),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                const Text('B   I   ◉   ◇   ⌁',
                    style:
                        TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                const Spacer(),
                FilledButton(
                  onPressed: onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    minimumSize: const Size(62, 25),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  child: const Text('Send  ▸', style: TextStyle(fontSize: 8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFFE8F7EF),
          borderRadius: BorderRadius.circular(3)),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 7, color: Color(0xFF15995A), fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PresenceAvatar extends StatelessWidget {
  const _PresenceAvatar(
      {required this.name, required this.size, required this.online});

  final String name;
  final double size;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final dotSize = size * .3;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _Avatar(name: name, size: size),
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 15),
      height: 15,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
            fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFFFDFC8),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1),
        style: TextStyle(
            fontSize: size * .38,
            fontWeight: FontWeight.w800,
            color: AppColors.orange),
      ),
    );
  }
}
