import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/brand_color.dart';
import '../application/assessment_provider.dart';
import 'widgets/assessment_hero.dart';

class CandidateAssessmentSessionScreen extends ConsumerStatefulWidget {
  const CandidateAssessmentSessionScreen(
      {super.key, required this.assessmentId});
  final String assessmentId;
  @override
  ConsumerState<CandidateAssessmentSessionScreen> createState() =>
      _CandidateAssessmentSessionScreenState();
}

class _CandidateAssessmentSessionScreenState
    extends ConsumerState<CandidateAssessmentSessionScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _test;
  List<Map<String, dynamic>> _questions = [];
  final Map<String, String> _answers = {};
  int _index = 0;
  int _violations = 0;
  int _secondsLeft = 0;
  bool _busy = false;
  bool _loading = true;
  bool _finished = false;
  String? _error;
  Timer? _clock;
  Timer? _autosave;
  DateTime? _lastBackgroundEvent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _autosave?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished ||
        _session?['external'] == true ||
        _loading ||
        (state != AppLifecycleState.hidden &&
            state != AppLifecycleState.paused)) return;
    final now = DateTime.now();
    if (_lastBackgroundEvent != null &&
        now.difference(_lastBackgroundEvent!).inSeconds < 3) return;
    _lastBackgroundEvent = now;
    _recordViolation();
  }

  Future<void> _start() async {
    try {
      final response = await ref
          .read(assessmentRepositoryProvider)
          .start(widget.assessmentId);
      if (!mounted) return;
      if (response['external'] == true) {
        final url = Uri.tryParse(response['url']?.toString() ?? '');
        if (url != null)
          await launchUrl(url, mode: LaunchMode.externalApplication);
        setState(() {
          _session = response;
          _loading = false;
        });
        return;
      }
      _session = Map<String, dynamic>.from(response['assessment'] as Map);
      _test = Map<String, dynamic>.from(response['test'] as Map);
      _questions = (response['test']['questions'] as List? ?? const [])
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList();
      for (final answer in (_session!['answers'] as List? ?? const [])) {
        final item = Map<String, dynamic>.from(answer as Map);
        final questionId = _idValue(item['questionId']);
        if (questionId != null) {
          _answers[questionId] = item['answer']?.toString() ?? '';
        }
      }
      final deadline =
          DateTime.tryParse(_session!['deadlineAt']?.toString() ?? '')
              ?.toLocal();
      _secondsLeft = deadline == null
          ? (int.tryParse('${_test!['durationMinutes']}') ?? 60) * 60
          : deadline.difference(DateTime.now()).inSeconds;
      setState(() => _loading = false);
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _finished) return;
        if (_secondsLeft <= 1) {
          setState(() => _secondsLeft = 0);
          _submit(timedOut: true);
        } else
          setState(() => _secondsLeft--);
      });
      if (_secondsLeft <= 0) _submit(timedOut: true);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  String? _idValue(dynamic value) {
    if (value is Map) {
      final nested = value['_id'] ?? value['id'] ?? value['questionId'];
      return nested?.toString();
    }
    final id = value?.toString();
    return id == null || id.isEmpty || id == 'null' ? null : id;
  }

  String _questionKey(Map<String, dynamic> question, int index) =>
      _idValue(question['questionId'] ?? question['_id'] ?? question['id']) ??
      'question-$index';

  void _answer(String questionId, String value) {
    setState(() => _answers[questionId] = value);
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 700), _saveDraftAnswers);
  }

  List<Map<String, dynamic>> get _answerPayload => _answers.entries
      .map((entry) => {'questionId': entry.key, 'answer': entry.value})
      .toList();

  Future<void> _saveDraftAnswers() async {
    if (_finished) return;
    try {
      await ref
          .read(assessmentRepositoryProvider)
          .saveAnswers(widget.assessmentId, _answerPayload);
    } catch (_) {
      /* The final submit still attempts to save the latest answers. */
    }
  }

  Future<void> _recordViolation() async {
    if (_finished) return;
    try {
      final result = await ref
          .read(assessmentRepositoryProvider)
          .recordViolation(widget.assessmentId);
      if (!mounted) return;
      _violations =
          (result['violationCount'] as num?)?.toInt() ?? (_violations + 1);
      if (_violations >= 3 || result['forceSubmit'] == true) {
        await _submit(timedOut: false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Stay on the assessment screen. Warning $_violations of 3.')));
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                title: const Text('Assessment focus warning'),
                content: Text(
                    'Switching away from the assessment has been recorded ($_violations of 3). Repeated focus changes will submit your current answers.'),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Return to assessment'))
                ],
              ));
    } catch (_) {}
  }

  Future<void> _submit({required bool timedOut}) async {
    if (_finished || _busy) return;
    setState(() => _busy = true);
    _autosave?.cancel();
    _clock?.cancel();
    try {
      final result = await ref
          .read(assessmentRepositoryProvider)
          .submit(widget.assessmentId, _answerPayload);
      if (!mounted) return;
      setState(() {
        _finished = true;
        _busy = false;
        _session = result;
      });
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                title: Text(timedOut ? 'Time is up' : 'Assessment submitted'),
                content: Text(
                    'Your response has been recorded. Your score is ${result['overallScore'] ?? 0}%. You can safely leave this screen.'),
                actions: [
                  FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go('/my-assessments');
                      },
                      child: const Text('Done'))
                ],
              ));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not submit assessment: $e')));
      }
    }
  }

  Future<void> _completeExternal() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(assessmentRepositoryProvider)
          .completeExternal(widget.assessmentId);
      ref.invalidate(candidateAssessmentsProvider);
      if (mounted) context.go('/my-assessments');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!),
        OutlinedButton(onPressed: _start, child: const Text('Retry'))
      ]));
    if (_session?['external'] == true) return _externalView();
    if (_finished)
      return Center(
          child: Text(
              'Assessment submitted. Score: ${_session?['overallScore'] ?? 0}%'));
    if (_questions.isEmpty)
      return const Center(
          child:
              Text('This assessment has no questions. Contact the recruiter.'));
    final question = _questions[_index];
    final questionId = _questionKey(question, _index);
    final compact = MediaQuery.sizeOf(context).width < 520;
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _AssessmentEscapeIntent()
      },
      child: Focus(
          canRequestFocus: false,
          onKeyEvent: (node, event) => KeyEventResult.ignored,
          child: SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 12 : 24),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AssessmentHero(
                              eyebrow: 'Assessment in progress',
                              title: _test?['title']?.toString() ??
                                  'Competency assessment',
                              description:
                                  'Take each question one step at a time. Your progress is saved as you go.',
                              metrics: [
                                AssessmentHeroMetric('Question',
                                    '${_index + 1}/${_questions.length}'),
                                AssessmentHeroMetric('Answered',
                                    '${_answers.length}/${_questions.length}'),
                              ],
                              action: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 9),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: .16))),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined,
                                          color: Color(0xFFFFC58E), size: 17),
                                      const SizedBox(width: 7),
                                      Text(_clockLabel(),
                                          style: TextStyle(
                                              color: _secondsLeft < 300
                                                  ? const Color(0xFFFF9B8D)
                                                  : Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800)),
                                    ]),
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                                value: (_index + 1) / _questions.length,
                                color: BrandColors.orange),
                            const SizedBox(height: 10),
                            Text(
                                'Question ${_index + 1} of ${_questions.length} · ${question['points'] ?? 1} points',
                                style:
                                    const TextStyle(color: BrandColors.muted)),
                            const SizedBox(height: 16),
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              question['text']?.toString() ??
                                                  '',
                                              style: const TextStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.4)),
                                          const SizedBox(height: 18),
                                          if (question['type'] ==
                                              'multiple_choice') ...[
                                            for (final entry
                                                in (question['options']
                                                            as List? ??
                                                        const [])
                                                    .map((e) => e.toString())
                                                    .indexed)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 10),
                                                child: _CandidateAnswerOption(
                                                  index: entry.$1,
                                                  option: entry.$2,
                                                  selected:
                                                      _answers[questionId] ==
                                                          entry.$2,
                                                  enabled: !_busy,
                                                  onTap: () => _answer(
                                                      questionId, entry.$2),
                                                ),
                                              ),
                                          ] else
                                            TextFormField(
                                                initialValue:
                                                    _answers[questionId],
                                                minLines: 7,
                                                maxLines: 14,
                                                decoration: const InputDecoration(
                                                    hintText:
                                                        'Write your response…',
                                                    border:
                                                        OutlineInputBorder()),
                                                onChanged: (value) =>
                                                    _answer(questionId, value)),
                                        ]))),
                            Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  OutlinedButton(
                                      onPressed: _index > 0
                                          ? () => setState(() => _index--)
                                          : null,
                                      child: const Text('Previous')),
                                  Text(
                                      '${_answers.length}/${_questions.length} answered'),
                                  if (_index < _questions.length - 1)
                                    FilledButton(
                                        onPressed: () =>
                                            setState(() => _index++),
                                        style: FilledButton.styleFrom(
                                            backgroundColor: BrandColors.navy),
                                        child: const Text('Next'))
                                  else
                                    FilledButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _submit(timedOut: false),
                                        style: FilledButton.styleFrom(
                                            backgroundColor:
                                                BrandColors.orange),
                                        child: Text(_busy
                                            ? 'Submitting…'
                                            : 'Submit assessment'))
                                ]),
                            const SizedBox(height: 10),
                            const Center(
                                child: Text(
                                    'Stay on this screen. Leaving or changing tabs triggers a warning.',
                                    style:
                                        TextStyle(color: BrandColors.muted))),
                          ]))))),
    );
  }

  Widget _externalView() {
    final url = Uri.tryParse(_session?['url']?.toString() ?? '');
    return Center(
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.open_in_new,
                          size: 42, color: BrandColors.orange),
                      const SizedBox(height: 12),
                      const Text('Complete the external assessment',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text(
                          'The external provider opens in a new window. Return here when you finish and confirm completion.'),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                          onPressed: url == null
                              ? null
                              : () => launchUrl(url,
                                  mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.launch),
                          label: const Text('Open assessment'),
                          style: FilledButton.styleFrom(
                              backgroundColor: BrandColors.orange)),
                      TextButton(
                          onPressed: _busy ? null : _completeExternal,
                          child: Text(_busy
                              ? 'Recording…'
                              : 'I completed the assessment')),
                    ])))));
  }

  String _clockLabel() =>
      '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';
}

class _AssessmentEscapeIntent extends Intent {
  const _AssessmentEscapeIntent();
}

class _CandidateAnswerOption extends StatelessWidget {
  const _CandidateAnswerOption({
    required this.index,
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: 'Option $label: $option',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF5EC) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? BrandColors.orange : BrandColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? BrandColors.orange : BrandColors.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 17, color: Colors.white)
                      : Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: BrandColors.muted,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: BrandColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? BrandColors.orange : BrandColors.muted,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
