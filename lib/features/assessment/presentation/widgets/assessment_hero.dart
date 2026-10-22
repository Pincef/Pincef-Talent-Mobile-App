import 'package:flutter/material.dart';

class AssessmentHeroMetric {
  const AssessmentHeroMetric(this.label, this.value);
  final String label;
  final String value;
}

class AssessmentHero extends StatelessWidget {
  const AssessmentHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.metrics = const [],
    this.action,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<AssessmentHeroMetric> metrics;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF101A3B), Color(0xFF273B68)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F101A3B), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final heading = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(eyebrow.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFFFFC58E),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1)),
                      ),
                      const SizedBox(height: 14),
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              height: 1.15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(description,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .78),
                              height: 1.4)),
                    ]),
              ),
              if (!compact) ...[
                const SizedBox(width: 14),
                _AssessmentMark(),
              ],
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (metrics.isNotEmpty || action != null) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...metrics.map((metric) => _MetricPill(metric: metric)),
                    if (action != null) action!,
                  ],
                ),
              ],
            ],
          );
        }),
      );
}

class _AssessmentMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .16))),
        child: const Icon(Icons.assignment_turned_in_outlined,
            color: Color(0xFFFFC58E), size: 36),
      );
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.metric});
  final AssessmentHeroMetric metric;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: .12))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(metric.value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(width: 7),
          Text(metric.label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .78), fontSize: 11)),
        ]),
      );
}
