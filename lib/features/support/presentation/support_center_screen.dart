import 'package:flutter/material.dart';

const _supportNavy = Color(0xFF080D35);
const _supportOrange = Color(0xFFFF7625);
const _supportInk = Color(0xFF273248);
const _supportMuted = Color(0xFF748198);
const _supportBorder = Color(0xFFE2E8F1);

enum _SupportTab { help, faqs, contact, problem }

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  _SupportTab _tab = _SupportTab.faqs;
  String _category = 'All';
  String _query = '';
  final _searchController = TextEditingController();
  final _contactFormKey = GlobalKey<FormState>();
  final _problemFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _problemDescriptionController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _problemDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(wide ? 22 : 16, 22, wide ? 22 : 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tab == _SupportTab.faqs
                      ? 'Frequently Asked Questions'
                      : 'Support Centre',
                  style: TextStyle(
                    color: _supportInk,
                    fontSize: wide ? 30 : 25,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _tab == _SupportTab.faqs
                      ? 'Quick answers to common questions about candidates, billing, and system workflows.'
                      : 'Find answers and get help with your TalentBridge workspace.',
                  style: const TextStyle(color: _supportMuted, fontSize: 14),
                ),
                const SizedBox(height: 18),
                _tabs(),
                const SizedBox(height: 22),
                if (_tab == _SupportTab.faqs)
                  _faqContent(wide)
                else if (_tab == _SupportTab.help)
                  _helpContent(wide)
                else if (_tab == _SupportTab.contact)
                  _contactContent(wide)
                else
                  _problemContent(wide),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tabs() {
    final tabs = [
      (_SupportTab.help, 'Help Centre'),
      (_SupportTab.faqs, 'FAQs'),
      (_SupportTab.contact, 'Contact Support'),
      (_SupportTab.problem, 'Report a Problem'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((item) {
          final selected = _tab == item.$1;
          return InkWell(
            onTap: () => setState(() => _tab = item.$1),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? _supportOrange : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  color: selected ? _supportOrange : _supportMuted,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _faqContent(bool wide) {
    final faqs = _faqItems.where((faq) {
      final matchesCategory = _category == 'All' || faq.category == _category;
      final matchesQuery = _query.isEmpty ||
          faq.question.toLowerCase().contains(_query) ||
          faq.answer.toLowerCase().contains(_query);
      return matchesCategory && matchesQuery;
    }).toList();
    final list = Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          decoration: _inputDecoration('Search FAQs by keyword...', Icons.search),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'General', 'Candidate AI', 'Billing & Plans', 'Interviews']
                .map((category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                        selectedColor: _supportOrange,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _category == category ? Colors.white : _supportMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: _category == category ? _supportOrange : _supportBorder,
                        ),
                        shape: const StadiumBorder(),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        if (faqs.isEmpty)
          const _EmptyState(
            icon: Icons.search_off,
            title: 'No matching FAQs',
            description: 'Try another keyword or choose a different category.',
          )
        else
          ...faqs.map((faq) => _FaqTile(faq: faq, initiallyExpanded: faq == faqs.first)),
      ],
    );
    if (!wide) {
      return Column(children: [list, const SizedBox(height: 18), _liveChatCard()]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: list),
        const SizedBox(width: 32),
        Expanded(flex: 1, child: _liveChatCard()),
      ],
    );
  }

  Widget _liveChatCard() => Container(
        constraints: const BoxConstraints(minHeight: 350),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFF0C7B7)),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF0C7B7)),
              ),
              child: const Icon(Icons.chat_bubble_outline, color: Color(0xFFB84900), size: 32),
            ),
            const SizedBox(height: 24),
            const Text('Live Chat', style: TextStyle(color: _supportInk, fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            const Text(
              'Connect with a support specialist in under 2 minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF806E65), fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),
            const Wrap(spacing: -9, children: [
              CircleAvatar(radius: 16, backgroundColor: Color(0xFFE2E9F5), child: Icon(Icons.person, size: 18, color: _supportMuted)),
              CircleAvatar(radius: 16, backgroundColor: Color(0xFFFFE1D1), child: Icon(Icons.person, size: 18, color: _supportOrange)),
              CircleAvatar(radius: 16, backgroundColor: _supportOrange, child: Text('+12', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFB84900), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Coming Soon', style: TextStyle(color: Color(0xFFB84900), fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );

  Widget _helpContent(bool wide) {
    final sections = [
      ('Getting Started', 'Set up your workspace and invite your team.', Icons.rocket_launch_outlined),
      ('Candidates & AI', 'Learn about matching, ranking, and candidate profiles.', Icons.people_outline),
      ('Jobs & Hiring', 'Create jobs and move candidates through your pipeline.', Icons.work_outline),
      ('Billing & Plans', 'Manage your plan, invoices, and subscription.', Icons.credit_card_outlined),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('How can we help?', style: TextStyle(fontSize: 20, color: _supportInk, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text('Browse support topics to find step-by-step guidance.', style: TextStyle(color: _supportMuted)),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: wide ? 2 : 1,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: wide ? 3.1 : 2.8,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: sections.map((item) => _HelpTopic(title: item.$1, description: item.$2, icon: item.$3, onTap: () => setState(() => _tab = _SupportTab.faqs))).toList(),
      ),
      const SizedBox(height: 18),
      _liveChatCard(),
    ]);
  }

  Widget _contactContent(bool wide) => _FormPanel(
        title: 'Contact Support',
        description: 'Send our team a message and we’ll get back to you as soon as possible.',
        child: Form(
          key: _contactFormKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (wide) Row(children: [Expanded(child: _formField('Your name', _nameController)), const SizedBox(width: 14), Expanded(child: _formField('Email address', _emailController, keyboardType: TextInputType.emailAddress))]) else ...[_formField('Your name', _nameController), _formField('Email address', _emailController, keyboardType: TextInputType.emailAddress)],
            _formField('Subject', _subjectController),
            _formField('How can we help?', _messageController, maxLines: 5),
            const SizedBox(height: 6),
            FilledButton.icon(onPressed: () => _submit(_contactFormKey, 'Support request submission will be available soon.'), icon: const Icon(Icons.send_outlined, size: 17), label: const Text('Send Message'), style: FilledButton.styleFrom(backgroundColor: _supportOrange, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14))),
          ]),
        ),
      );

  Widget _problemContent(bool wide) => _FormPanel(
        title: 'Report a Problem',
        description: 'Tell us what went wrong. Details help us investigate and fix it faster.',
        child: Form(
          key: _problemFormKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('What is the issue related to?', style: TextStyle(color: _supportInk, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: 'Select a category',
              decoration: _inputDecoration('', null),
              items: const ['Select a category', 'Jobs', 'Candidates', 'Candidate AI', 'Billing & Plans', 'Interviews', 'Other'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),
            _formField('Describe the problem', _problemDescriptionController, maxLines: 6),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF7F8FB), borderRadius: BorderRadius.circular(9), border: Border.all(color: _supportBorder)), child: const Row(children: [Icon(Icons.attach_file, color: _supportMuted), SizedBox(width: 8), Expanded(child: Text('Attachments can be added when problem reporting is connected.', style: TextStyle(color: _supportMuted, fontSize: 12)))])),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => _submit(_problemFormKey, 'Problem reporting will be available soon.'), icon: const Icon(Icons.flag_outlined, size: 17), label: const Text('Submit Report'), style: FilledButton.styleFrom(backgroundColor: _supportOrange, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14))),
          ]),
        ),
      );

  Widget _formField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _supportInk, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            validator: (value) => value == null || value.trim().isEmpty ? 'Please complete this field' : null,
            decoration: _inputDecoration(maxLines > 1 ? 'Write your message...' : 'Enter ${label.toLowerCase()}', null),
          ),
        ]),
      );

  InputDecoration _inputDecoration(String hint, IconData? icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA4B0C1), fontSize: 14),
        prefixIcon: icon == null ? null : Icon(icon, color: _supportMuted, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _supportBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _supportBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _supportOrange, width: 1.5)),
      );

  void _submit(GlobalKey<FormState> key, String message) {
    if (!key.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FaqItem {
  const _FaqItem(this.category, this.question, this.answer);
  final String category;
  final String question;
  final String answer;
}

const _faqItems = [
  _FaqItem('Candidate AI', 'How does AI candidate matching work?', 'Our AI evaluates resumes against your specific job criteria by analyzing proven technical skills, role trajectory, and experience level. It delivers an objective, ranked percentage score so you can identify and contact top-fit talent instantly.'),
  _FaqItem('General', 'How do I invite teammates to review candidates?', 'Open your workspace settings and invite teammates by email. You can collaborate on candidate reviews and keep feedback in one place.'),
  _FaqItem('Interviews', 'Can I export interview scorecards and reports?', 'Yes. Open the relevant interview or report and use the export action to download a copy for your records.'),
  _FaqItem('Billing & Plans', 'How do plan quotas and renewals work?', 'Your plan includes monthly usage limits. Quotas refresh at the start of each billing cycle, and your current plan details are available under Payment & Subscription.'),
  _FaqItem('General', 'What happens when a job requisition closes?', 'A closed requisition is removed from active job listings. You can still review its candidates and hiring history from your jobs workspace.'),
];

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq, required this.initiallyExpanded});
  final _FaqItem faq;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _supportBorder), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x08080D35), blurRadius: 4, offset: Offset(0, 2))]),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: const Color(0xFF9AA8BE),
          collapsedIconColor: const Color(0xFF9AA8BE),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          title: Text(faq.question, style: const TextStyle(color: _supportInk, fontSize: 15, fontWeight: FontWeight.w600)),
          children: [Align(alignment: Alignment.centerLeft, child: Text(faq.answer, style: const TextStyle(color: _supportMuted, fontSize: 14, height: 1.55)))],
        ),
      );
}

class _HelpTopic extends StatelessWidget {
  const _HelpTopic({required this.title, required this.description, required this.icon, required this.onTap});
  final String title, description;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _supportBorder), borderRadius: BorderRadius.circular(12)), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFFF2EB), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _supportOrange)), const SizedBox(width: 14), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _supportInk, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(description, style: const TextStyle(color: _supportMuted, fontSize: 12))])), const Icon(Icons.arrow_forward_ios, size: 14, color: _supportMuted)])),
      );
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.title, required this.description, required this.child});
  final String title, description;
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _supportBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _supportInk, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(color: _supportMuted, fontSize: 13)),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 44), child: Column(children: [Icon(icon, color: _supportMuted, size: 32), const SizedBox(height: 8), Text(title, style: const TextStyle(color: _supportInk, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(description, textAlign: TextAlign.center, style: const TextStyle(color: _supportMuted))])));
}
