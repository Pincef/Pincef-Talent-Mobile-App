import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/candidate_messages_provider.dart';
import '../../application/presence_provider.dart';
import '../../data/candidate_messages_repository.dart';
import '../../data/messages_repository.dart' show ChatMessage, MessageStatus;

class CandidateMessagesScreen extends ConsumerWidget {
  const CandidateMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(candidateContactsProvider);

    return contacts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Unable to load messages: $e')),
      data: (items) {
        final selectedNotifier =
            ref.read(selectedCandidateContactProvider.notifier);

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 830;
            // Desktop-only auto-select — see the matching comment in
            // messages_screen.dart for why this must not run on mobile
            // (it was previously overriding the back button immediately).
            if (!compact &&
                ref.read(selectedCandidateContactProvider) == null &&
                items.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => selectedNotifier.state = items.first.id);
            }
            final selectedId = ref.watch(selectedCandidateContactProvider);
            CandidateChatContact? selectedContact;
            for (final c in items) {
              if (c.id == selectedId) {
                selectedContact = c;
                break;
              }
            }

            if (!compact) {
              return Column(
                children: [
                  const _CandidateHeader(compact: false),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                            width: 250,
                            child: _CandidateInbox(contacts: items)),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: selectedContact == null
                              ? const Center(
                                  child: Text('Select a conversation'))
                              : _CandidateConversation(
                                  key: ValueKey(selectedContact.id),
                                  contact: selectedContact,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Same phone-width flow as the recruiter screen: the list and
            // the open conversation are never shown at the same time, and
            // the header's back arrow is how you get from one to the other.
            if (selectedContact == null) {
              return Column(
                children: [
                  const _CandidateHeader(compact: true),
                  Expanded(child: _CandidateInbox(contacts: items)),
                ],
              );
            }
            return _CandidateConversation(
              key: ValueKey(selectedContact.id),
              contact: selectedContact,
              onBack: () => selectedNotifier.state = null,
            );
          },
        );
      },
    );
  }
}

class _CandidateHeader extends StatelessWidget {
  const _CandidateHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding:
          EdgeInsets.fromLTRB(compact ? 16 : 26, 15, compact ? 16 : 26, 14),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TALENT WORKSPACE  •  Active Conversations',
                  style: TextStyle(
                      fontSize: 8,
                      color: AppColors.orange,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 5),
                Text('Messages',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                Text(
                  'Chat directly with hiring managers, recruiters, and interview panels.',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const _HeaderBadge(
                icon: Icons.circle, text: '2 Unread', color: AppColors.orange),
            const SizedBox(width: 7),
            const _HeaderBadge(
                icon: Icons.event,
                text: '1 Interview Scheduled',
                color: AppColors.orange),
          ],
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge(
      {required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 8),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CandidateInbox extends ConsumerWidget {
  const _CandidateInbox({required this.contacts});

  final List<CandidateChatContact> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCandidateContactProvider);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search recruiters...',
                hintStyle: const TextStyle(fontSize: 9),
                prefixIcon: const Icon(Icons.search, size: 14),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final contact = contacts[index];
                final online = ref.watch(presenceProvider
                    .select((p) => p[contact.partnerId]?.online ?? false));
                return InkWell(
                  onTap: () => ref
                      .read(selectedCandidateContactProvider.notifier)
                      .state = contact.id,
                  child: Container(
                    color:
                        selected == contact.id ? const Color(0xFFF1F2F5) : null,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CandidatePresenceAvatar(
                            name: contact.name, online: online),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      contact.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: contact.unread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(contact.time,
                                      style: const TextStyle(
                                          fontSize: 7,
                                          color: AppColors.orange)),
                                ],
                              ),
                              Text(contact.company,
                                  style: const TextStyle(
                                      fontSize: 7.5,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      contact.preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9,
                                        height: 1.25,
                                        fontWeight: contact.unread
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: contact.unread
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (contact.unread) ...[
                                    const SizedBox(width: 6),
                                    _CandidateUnreadBadge(
                                        count: contact.unreadCount),
                                  ],
                                ],
                              ),
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

class _CandidateConversation extends ConsumerStatefulWidget {
  const _CandidateConversation({super.key, required this.contact, this.onBack});

  final CandidateChatContact contact;
  final VoidCallback? onBack;

  @override
  ConsumerState<_CandidateConversation> createState() =>
      _CandidateConversationState();
}

class _CandidateConversationState
    extends ConsumerState<_CandidateConversation> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    ref
        .read(conversationProvider(widget.contact.id).notifier)
        .send(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationProvider(widget.contact.id));

    return Container(
      color: const Color(0xFFFAFBFC),
      child: conversation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (messages) => Column(
          children: [
            _CandidateConversationHeader(
                contact: widget.contact, onBack: widget.onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 19, 28, 10),
                children: [
                  const Center(
                    child: Text('Today',
                        style: TextStyle(
                            fontSize: 8, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 16),
                  ...messages
                      .map((message) => _CandidateBubble(message: message)),
                ],
              ),
            ),
            _CandidateComposer(controller: _controller, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _CandidateConversationHeader extends ConsumerWidget {
  const _CandidateConversationHeader({required this.contact, this.onBack});

  final CandidateChatContact contact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence =
        ref.watch(presenceProvider.select((p) => p[contact.partnerId]));
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: onBack,
                padding: EdgeInsets.zero),
            const SizedBox(width: 4),
          ],
          _CandidatePresenceAvatar(
              name: contact.name, online: presence?.online ?? false),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800)),
                Text(
                  [contact.company, presence?.statusLabel]
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
          if (MediaQuery.sizeOf(context).width >= 500) ...[
            const _HeaderBadge(
                icon: Icons.work_outline,
                text: 'View Job Spec',
                color: AppColors.textPrimary),
            const SizedBox(width: 6),
            const _HeaderBadge(
                icon: Icons.business_outlined,
                text: 'Company Profile',
                color: AppColors.textPrimary),
          ],
        ],
      ),
    );
  }
}

class _CandidateBubble extends StatelessWidget {
  const _CandidateBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isMine ? AppColors.navy : const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(7),
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
                _shortTime(message.time),
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

class _CandidateComposer extends StatelessWidget {
  const _CandidateComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Type your reply...',
                    hintStyle: TextStyle(fontSize: 9),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  minimumSize: const Size(30, 30),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
                child: const Icon(Icons.send, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Row(
            children: [
              Text('Press Enter to send',
                  style:
                      TextStyle(fontSize: 7.5, color: AppColors.textSecondary)),
              Spacer(),
              Text('🔒 End-to-end encrypted recruiter communication',
                  style: TextStyle(fontSize: 7.5, color: AppColors.orange)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidatePresenceAvatar extends StatelessWidget {
  const _CandidatePresenceAvatar({required this.name, required this.online});

  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _CandidateAvatar(name: name),
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 9,
                height: 9,
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

class _CandidateUnreadBadge extends StatelessWidget {
  const _CandidateUnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
            fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

class _CandidateAvatar extends StatelessWidget {
  const _CandidateAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: AppColors.navy,
      child: Text(
        name.isEmpty
            ? '?'
            : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(),
        style: const TextStyle(
            fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
