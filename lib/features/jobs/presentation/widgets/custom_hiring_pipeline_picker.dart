import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../hiring_pipeline/application/hiring_pipeline_provider.dart';
import '../../../hiring_pipeline/data/models/hiring_pipeline_model.dart';

Future<HiringPipeline?> showCustomHiringPipelinePicker(BuildContext context) =>
    showDialog<HiringPipeline?>(
      context: context,
      barrierColor: const Color(0xD90B142A),
      builder: (_) => const CustomHiringPipelinePickerDialog(),
    );

class CustomHiringPipelinePickerDialog extends ConsumerWidget {
  const CustomHiringPipelinePickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pipelinesProvider);
    final pipelines = (async.value ?? const <HiringPipeline>[])
        .where((pipeline) =>
            !pipeline.isSystemStandard &&
            !pipeline.isSystemPremium &&
            pipeline.state == 'ACTIVE')
        .toList(growable: false);
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: (size.width - 32).clamp(280.0, 720.0).toDouble(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * .86),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 18),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0DE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.alt_route_rounded,
                      color: BrandColors.orange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose a custom workflow',
                          style: TextStyle(
                              color: BrandColors.navy,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('Select one of your active saved pipelines.',
                          style: TextStyle(
                              color: BrandColors.muted, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: BrandColors.muted),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: async.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: BrandColors.orange)),
                error: (_, __) => const _PickerMessage(
                  icon: Icons.cloud_off_outlined,
                  title: "Couldn't load your workflows",
                  message:
                      'Check your connection and try selecting a custom pipeline again.',
                ),
                data: (_) => pipelines.isEmpty
                    ? const _PickerMessage(
                        icon: Icons.alt_route_outlined,
                        title: 'No active custom workflows yet',
                        message:
                            'Create and activate a custom hiring pipeline before assigning it to a job.',
                      )
                    : LayoutBuilder(builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 600 ? 2 : 1;
                        const gap = 12.0;
                        final width =
                            (constraints.maxWidth - (columns - 1) * gap) /
                                columns;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final pipeline in pipelines)
                                SizedBox(
                                  width: width,
                                  child: _PipelineCard(
                                    pipeline: pipeline,
                                    onSelect: () =>
                                        Navigator.pop(context, pipeline),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 15, color: BrandColors.muted),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'The selected workflow is linked to this job.',
                    style: TextStyle(fontSize: 10, color: BrandColors.muted),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.pipeline, required this.onSelect});
  final HiringPipeline pipeline;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final hasAssessment =
        pipeline.stages.any((stage) => isAssessmentType(stage.type));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E7F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.alt_route_rounded,
                    color: BrandColors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(pipeline.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: BrandColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
                if (hasAssessment)
                  const Tooltip(
                    message: 'Includes an assessment stage',
                    child: Icon(Icons.assignment_outlined,
                        color: Color(0xFF7B61B8), size: 17),
                  ),
              ]),
              if (pipeline.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(pipeline.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: BrandColors.muted, fontSize: 11, height: 1.4)),
              ],
              const SizedBox(height: 13),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final stage in pipeline.stages.take(5))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAssessmentType(stage.type)
                            ? const Color(0xFFF0EBFA)
                            : const Color(0xFFF2F5F9),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(stage.name,
                          style: TextStyle(
                              color: isAssessmentType(stage.type)
                                  ? const Color(0xFF7354B5)
                                  : BrandColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  if (pipeline.stages.length > 5)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F5F9),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text('+${pipeline.stages.length - 5} more stages',
                          style: const TextStyle(
                              color: BrandColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.check, size: 15),
                  label: const Text('Use this workflow'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: BrandColors.muted, size: 32),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: BrandColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: BrandColors.muted, fontSize: 11, height: 1.45)),
          ]),
        ),
      );
}
