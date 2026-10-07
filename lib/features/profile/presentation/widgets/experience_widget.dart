import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import '../../application/profile_provider.dart';
import '../../data/models/candidate_profile_model.dart';

class ExperienceTab extends ConsumerWidget {
  const ExperienceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(candidateProfileProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Experience History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(
                onPressed: () => _openExperienceForm(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Experience'),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 16),
          profileState.when(
            data: (profile) => profile.experience.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No experience added yet.',
                        style: TextStyle(
                            color: BrandColors.muted, fontSize: 12.5)),
                  )
                : Column(
                    children: List.generate(profile.experience.length, (index) {
                      final entry = profile.experience[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExperienceCard(
                          entry: entry,
                          onEdit: () => _openExperienceForm(context, ref,
                              index: index, entry: entry),
                          onDelete: () => ref
                              .read(candidateProfileProvider.notifier)
                              .removeExperienceAt(index),
                        ),
                      );
                    }),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text("Couldn't load experience.",
                  style: TextStyle(color: BrandColors.muted, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }

  void _openExperienceForm(BuildContext context, WidgetRef ref,
      {int? index, ExperienceEntry? entry}) {
    showDialog(
      context: context,
      builder: (_) => _ExperienceFormDialog(
        initial: entry,
        onSubmit: (result) {
          if (index == null) {
            ref.read(candidateProfileProvider.notifier).addExperience(result);
          } else {
            ref
                .read(candidateProfileProvider.notifier)
                .updateExperienceAt(index, result);
          }
        },
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard(
      {required this.entry, required this.onEdit, required this.onDelete});
  final ExperienceEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _initials(String? company) {
    if (company == null || company.trim().isEmpty) return '?';
    final words = company.trim().split(RegExp(r'\s+'));
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters;
  }

  String _dateRangeLabel() {
    final start = entry.startDate?.year.toString() ?? '';
    final end =
        entry.isCurrent ? 'PRESENT' : (entry.endDate?.year.toString() ?? '');
    if (start.isEmpty && end.isEmpty) return '';
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BrandColors.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_initials(entry.company),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if (_dateRangeLabel().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: entry.isCurrent
                              ? Colors.green.shade50
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _dateRangeLabel(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: entry.isCurrent
                                ? Colors.green.shade700
                                : BrandColors.muted,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline,
                          size: 15, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (entry.company != null && entry.company!.isNotEmpty)
                  Text(entry.company!,
                      style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                if (entry.description != null &&
                    entry.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(entry.description!,
                      style: const TextStyle(
                          color: BrandColors.muted,
                          fontSize: 12.5,
                          height: 1.4)),
                ],
                if (entry.achievements.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('KEY ACHIEVEMENTS',
                      style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 10,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  ...entry.achievements.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4, right: 6),
                              child: Icon(Icons.circle,
                                  size: 5, color: AppColors.orange),
                            ),
                            Expanded(
                              child: Text(a,
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.4)),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperienceFormDialog extends StatefulWidget {
  const _ExperienceFormDialog({this.initial, required this.onSubmit});
  final ExperienceEntry? initial;
  final ValueChanged<ExperienceEntry> onSubmit;

  @override
  State<_ExperienceFormDialog> createState() => _ExperienceFormDialogState();
}

class _ExperienceFormDialogState extends State<_ExperienceFormDialog> {
  late final _titleController =
      TextEditingController(text: widget.initial?.title ?? '');
  late final _companyController =
      TextEditingController(text: widget.initial?.company ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _startYearController = TextEditingController(
      text: widget.initial?.startDate?.year.toString() ?? '');
  late final _endYearController = TextEditingController(
      text: widget.initial?.endDate?.year.toString() ?? '');
  late final _achievementController = TextEditingController();
  late bool _isCurrent = widget.initial?.isCurrent ?? false;
  late final List<String> _achievements =
      List.of(widget.initial?.achievements ?? const []);

  void _addAchievement() {
    final value = _achievementController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _achievements.add(value);
      _achievementController.clear();
    });
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;

    final entry = ExperienceEntry(
      title: _titleController.text.trim(),
      company: _companyController.text.trim().isEmpty
          ? null
          : _companyController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startDate: _startYearController.text.trim().isEmpty
          ? null
          : DateTime(int.parse(_startYearController.text.trim())),
      endDate: _isCurrent || _endYearController.text.trim().isEmpty
          ? null
          : DateTime(int.parse(_endYearController.text.trim())),
      achievements: _achievements,
    );
    widget.onSubmit(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.initial == null ? 'Add Experience' : 'Edit Experience'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _companyController,
                decoration: const InputDecoration(labelText: 'Company'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startYearController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Start year'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _endYearController,
                      keyboardType: TextInputType.number,
                      enabled: !_isCurrent,
                      decoration: const InputDecoration(labelText: 'End year'),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _isCurrent,
                onChanged: (v) => setState(() => _isCurrent = v ?? false),
                title: const Text('I currently work here',
                    style: TextStyle(fontSize: 13)),
              ),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              const Text('Key Achievements',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ..._achievements.map((a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.circle,
                        size: 6, color: AppColors.orange),
                    title: Text(a, style: const TextStyle(fontSize: 12.5)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () => setState(() => _achievements.remove(a)),
                    ),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _achievementController,
                      decoration:
                          const InputDecoration(hintText: 'Add an achievement'),
                      onSubmitted: (_) => _addAchievement(),
                    ),
                  ),
                  IconButton(
                      onPressed: _addAchievement, icon: const Icon(Icons.add)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
