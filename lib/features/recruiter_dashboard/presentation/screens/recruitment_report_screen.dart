import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/recruitment_report_provider.dart';
import '../../data/model/recruitment_report_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (sampled from the design screenshot)
// ─────────────────────────────────────────────────────────────────────────────

const _navy = Color(0xFF080D35);
const _orange = Color(0xFFFF7625);
const _ink = Color(0xFF111936);
const _muted = Color(0xFF6B7385);
const _subtle = Color(0xFF9AA1B2);
const _line = Color(0xFFE4E9F2);
const _green = Color(0xFF08B765);
const _red = Color(0xFFE62B31);

const _pageBg = Colors.white;
const _controlBorder = Color(0xFFD3D8E3);
const _track = Color(0xFFE3EAF8);
const _tableRule = Color(0xFFEFE6E1);
const _headerRule = Color(0xFFEBCDBD);

const _panelTitleStyle = TextStyle(
  fontSize: 24,
  height: 1.25,
  color: _navy,
  fontWeight: FontWeight.w500,
);

const _panelSubtitleStyle = TextStyle(fontSize: 13, color: _muted);

const _sectionLabelStyle = TextStyle(
  fontSize: 12,
  height: 1.35,
  color: _ink,
  fontWeight: FontWeight.w700,
);

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// 1284 -> "1,284"
String _withCommas(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

IconData _sourceIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('linkedin')) return Icons.camera_alt_outlined;
  if (n.contains('referral')) return Icons.share_outlined;
  if (n.contains('board')) return Icons.public;
  if (n.contains('direct')) return Icons.bolt_outlined;
  return Icons.circle_outlined;
}

/// Custom bar (avoids the Material 3 end-dot / gap that
/// LinearProgressIndicator draws on newer Flutter versions).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.color,
    this.height = 6,
    this.track = _track,
  });

  final double value;
  final Color color;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(32),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen (async state handling)
// ─────────────────────────────────────────────────────────────────────────────

class RecruitmentReportScreen extends ConsumerWidget {
  const RecruitmentReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(recruitmentReportProvider);

    return Container(
      color: _pageBg,
      child: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load report: $e'),
              TextButton(
                onPressed: () => ref.invalidate(recruitmentReportProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _ReportContent(data: data),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report content (page layout)
// ─────────────────────────────────────────────────────────────────────────────

class _ReportContent extends StatefulWidget {
  const _ReportContent({required this.data});

  final RecruitmentReport data;

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  String _period = 'Q';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final data = widget.data;
    final side = wide ? 28.0 : 14.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(side, wide ? 20 : 14, side, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(wide: wide, screenWidth: width),
          const SizedBox(height: 30),
          _buildMetrics(data),
          const SizedBox(height: 34),
          _buildVolumeAndSources(data),
          const SizedBox(height: 21),
          _FunnelCard(stages: data.stages),
          const SizedBox(height: 17),
          _DiagnosticCard(reasons: data.dropOffReasons),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader({required bool wide, required double screenWidth}) {
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    );
    const buttonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: wide ? 460 : screenWidth - 28,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Senior Product Manager\nAnalytics and Report',
                style: TextStyle(
                  fontSize: 32,
                  height: 1.25,
                  color: _navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Measuring recruitment efficiency across 12 global regions.',
                style: TextStyle(color: _muted, fontSize: 15),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildPeriodSwitcher(),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: const Text('Oct 1 - Dec 31'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                backgroundColor: Colors.white,
                minimumSize: const Size(0, 39),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                side: const BorderSide(color: _controlBorder),
                shape: buttonShape,
                textStyle: buttonText,
              ),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 17),
              label: const Text('Export PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 39),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: buttonShape,
                textStyle: buttonText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSwitcher() {
    const periods = ['W', 'M', 'Q', 'Y'];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        border: Border.all(color: _controlBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((p) {
          final selected = _period == p;
          return InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => setState(() => _period = p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? _navy : _muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Metric cards ──────────────────────────────────────────────────────────

  Widget _buildMetrics(RecruitmentReport data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns = w > 850 ? 4 : (w > 540 ? 2 : 1);

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            mainAxisExtent: 178,
          ),
          children: [
            const _MetricCard(
              title: 'TOTAL APPLICANTS',
              value: '42.8k',
              icon: Icons.face_outlined,
              dark: true,
            ),
            _MetricCard(
              title: 'AVG. TIME TO FILL',
              value: '${data.avgDaysToFill} Days',
              icon: Icons.schedule,
              iconColor: const Color(0xFF5B6B9A),
              iconBg: const Color(0xFFEEF0FB),
              badge: '↘ -2d',
              badgeColor: _orange,
            ),
            _MetricCard(
              title: 'PIPELINE HEALTH',
              value: '${data.pipelineHealth}%',
              icon: Icons.health_and_safety_outlined,
              iconColor: _green,
              iconBg: const Color(0xFFE3F8EC),
              badge: 'OPTIMAL',
              badgeColor: _green,
              badgePill: true,
            ),
            _MetricCard(
              title: 'TOTAL HIRES',
              value: _withCommas(data.totalHires),
              icon: Icons.person_add_alt,
              iconColor: _orange,
              iconBg: const Color(0xFFFFF1E8),
              badge: '↗ +12%',
              badgeColor: _green,
            ),
          ],
        );
      },
    );
  }

  // ── Volume trend + source effectiveness ───────────────────────────────────

  Widget _buildVolumeAndSources(RecruitmentReport data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: _VolumeCard()),
                const SizedBox(width: 26),
                SizedBox(width: 292, child: _SourceCard(items: data.sources)),
              ],
            ),
          );
        }

        return Column(
          children: [
            const _VolumeCard(),
            const SizedBox(height: 14),
            _SourceCard(items: data.sources),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric card
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = _navy,
    this.iconBg = const Color(0xFFEEF0FB),
    this.dark = false,
    this.badge,
    this.badgeColor = _green,
    this.badgePill = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool dark;
  final String? badge;
  final Color badgeColor;
  final bool badgePill;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? _navy : Colors.white,
        border: dark ? null : Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (dark)
            Positioned(
              right: -6,
              bottom: -10,
              child: Icon(
                Icons.bar_chart,
                size: 104,
                color: Colors.white.withValues(alpha: .09),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white12 : iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: dark ? Colors.white : iconColor,
                      ),
                    ),
                    if (badge != null) _buildBadge(),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: .6,
                        color: dark ? Colors.white70 : _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.2,
                        color: dark ? Colors.white : _navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    if (!badgePill) {
      return Text(
        badge!,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        badge!,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Applicant volume trend
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeCard extends StatelessWidget {
  const _VolumeCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Applicant Volume Trends', style: _panelTitleStyle),
                  SizedBox(height: 2),
                  Text(
                    'Comparing current quarter to previous projection',
                    style: _panelSubtitleStyle,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legend(_orange, 'Active'),
                  const SizedBox(width: 18),
                  _legend(_navy, 'Projection'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 38),
          const SizedBox(height: 270, child: _TrendChart()),
        ],
      ),
    );
  }

  static Widget _legend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  static const _months = ['OCT', 'NOV', 'DEC', 'JAN', 'FEB', 'MAR'];
  static const _labelStyle = TextStyle(
    color: _muted,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final gridHeight = size.height - 30;

    // 5 horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFEFF1F5)
      ..strokeWidth = 1;

    for (var i = 0; i < 5; i++) {
      final y = gridHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Month labels, centred in 6 equal bands
    final band = size.width / _months.length;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < _months.length; i++) {
      tp
        ..text = TextSpan(text: _months[i], style: _labelStyle)
        ..layout();
      tp.paint(
        canvas,
        Offset(band * (i + .5) - tp.width / 2, gridHeight + 14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Source effectiveness
// ─────────────────────────────────────────────────────────────────────────────

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.items});

  final List<RecruitmentSource> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Source Effectiveness', style: _panelTitleStyle),
          const SizedBox(height: 22),
          ...items.map(_buildSourceRow),
          const SizedBox(height: 4),
          Center(
            child: InkWell(
              onTap: () {},
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Detailed Breakdown',
                    style: TextStyle(
                      color: _orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16, color: _orange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow(RecruitmentSource s) {
    final color = Color(s.colorValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_sourceIcon(s.name), size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${s.percent}%',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(value: s.percent / 100, color: color, height: 7),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Funnel velocity table
// ─────────────────────────────────────────────────────────────────────────────

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.stages});

  final List<FunnelStage> stages;

  // Column flex values (stage, duration, pass-through, volume, status, trend)
  static const _cols = [198, 161, 183, 100, 112, 135];

  static const _headerStyle = TextStyle(
    fontSize: 12,
    height: 1.35,
    letterSpacing: .6,
    color: Color(0xFF4A5062),
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 32, 14, 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recruitment Funnel Velocity',
                          style: _panelTitleStyle),
                      SizedBox(height: 2),
                      Text(
                        'Tracking speed of movement through each stage',
                        style: TextStyle(color: _muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_vert, size: 20, color: _ink),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _headerRule),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth =
                  constraints.maxWidth < 760 ? 760.0 : constraints.maxWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _buildHeaderRow(),
                      for (var i = 0; i < stages.length; i++)
                        _buildRow(stages[i], isLast: i == stages.length - 1),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cell(int index, Widget child,
      {Alignment align = Alignment.centerLeft}) {
    return Expanded(
      flex: _cols[index],
      child: Align(alignment: align, child: child),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      height: 66,
      color: const Color(0xFFFAF9F8),
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          _cell(0, const Text('STAGE NAME', style: _headerStyle)),
          _cell(1, const Text('AVERAGE\nDURATION', style: _headerStyle)),
          _cell(2, const Text('PASS-THROUGH\nRATE', style: _headerStyle)),
          _cell(3, const Text('VOLUME\n(ACTIVE)', style: _headerStyle)),
          _cell(4, const Text('STATUS', style: _headerStyle),
              align: Alignment.center),
          _cell(5, const Text('TREND', style: _headerStyle),
              align: Alignment.center),
        ],
      ),
    );
  }

  Widget _buildRow(FunnelStage s, {required bool isLast}) {
    final statusColor = s.congested ? _orange : _green;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.only(left: 32, top: 14, bottom: 14),
      decoration: BoxDecoration(
        border:
            isLast ? null : const Border(bottom: BorderSide(color: _tableRule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cell(
            0,
            SizedBox(
              width: 140,
              child: Text(
                s.name,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 16,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          _cell(
            1,
            Text(
              '${s.days} Days',
              style: const TextStyle(color: _ink, fontSize: 14),
            ),
          ),
          _cell(
            2,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  child: _ProgressBar(
                    value: s.passThrough / 100,
                    color: statusColor,
                    height: 5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${s.passThrough}%',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _cell(
            3,
            Text(
              _withCommas(s.volume),
              style: const TextStyle(color: _ink, fontSize: 14),
            ),
          ),
          _cell(
            4,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: s.congested
                    ? const Color(0xFFFFF2ED)
                    : const Color(0xFFD8FBE5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s.congested ? 'CONGESTED' : 'OPTIMAL',
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            align: Alignment.center,
          ),
          _cell(
            5,
            Icon(_trendIcon(s.trend), size: 22, color: statusColor),
            align: Alignment.center,
          ),
        ],
      ),
    );
  }

  IconData _trendIcon(num trend) {
    if (trend > 0) return Icons.trending_up;
    if (trend < 0) return Icons.trending_down;
    return Icons.trending_flat;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drop-off & attrition diagnostic
// ─────────────────────────────────────────────────────────────────────────────

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({required this.reasons});

  final List<DropOffReason> reasons;

  static const _barColors = [_red, _orange, Color(0xFF334155)];
  static const _labelColors = [_red, _orange, _ink];

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const stages = _FunnelStages();
                const recommendation = _RecoveryRecommendation();
                final details = _buildReasons();

                if (constraints.maxWidth > 760) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: stages),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: details,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const SizedBox(width: 184, child: recommendation),
                    ],
                  );
                }

                return Column(
                  children: [
                    stages,
                    const SizedBox(height: 20),
                    details,
                    const SizedBox(height: 16),
                    recommendation,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Navy banner ───────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: _navy,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5A5F),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'FUNNEL DROP-OFF & ATTRITION\nDIAGNOSTIC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .2),
                  border: Border.all(color: _red.withValues(alpha: .5)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'HIGH\nIMPACT',
                  style: TextStyle(
                    color: Color(0xFFFF8F8F),
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Critical leakage points & AI root-cause analysis',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Primary reasons column ────────────────────────────────────────────────

  Widget _buildReasons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'PRIMARY REASONS FOR STAGE 2 DROP-OFF',
                style: _sectionLabelStyle,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFEF),
                border: Border.all(color: const Color(0xFFFFC9C9)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '900 Candidates\nLost',
                style: TextStyle(
                  color: _red,
                  fontSize: 10,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(
          reasons.length,
          (i) => _buildReasonRow(reasons[i], i),
        ),
      ],
    );
  }

  Widget _buildReasonRow(DropOffReason r, int index) {
    final barColor = _barColors[index % _barColors.length];
    final labelColor = _labelColors[index % _labelColors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  r.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${r.percent}% of drops',
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ProgressBar(
            value: r.percent / 100,
            color: barColor,
            height: 5,
            track: const Color(0xFFE9ECF2),
          ),
          const SizedBox(height: 5),
          Text(
            r.detail,
            style: const TextStyle(
              color: Color(0xFF8D95A8),
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prescriptive recovery recommendation
// ─────────────────────────────────────────────────────────────────────────────

class _RecoveryRecommendation extends StatelessWidget {
  const _RecoveryRecommendation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        border: Border.all(color: const Color(0xFFFFE2B8)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRESCRIPTIVE RECOVERY RECOMMENDATION',
            style: TextStyle(
              color: _ink,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
              children: [
                TextSpan(
                  text: 'Relax strict micro-frontend weighting by 10% to '
                      'instantly recover ',
                ),
                TextSpan(
                  text: '~ 180 high-caliber near-match',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' candidates for second review.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage-by-stage quantitative drop-off (static sample data)
// ─────────────────────────────────────────────────────────────────────────────

enum _StageKind { normal, bottleneck, success }

class _DropStage {
  const _DropStage(
    this.number,
    this.label,
    this.change,
    this.volume, {
    this.kind = _StageKind.normal,
    this.changeColor = _subtle,
  });

  final String number;
  final String label;
  final String change;
  final String volume;
  final _StageKind kind;
  final Color changeColor;
}

class _FunnelStages extends StatelessWidget {
  const _FunnelStages();

  static const _rows = [
    _DropStage('1', 'Applied', '100% volume', '1,000'),
    _DropStage(
      '2',
      'AI Match /\nScreened',
      '-90%\nDROP',
      '100\n(10%)',
      kind: _StageKind.bottleneck,
    ),
    _DropStage('3', 'Top Ranked', '-80% drop', '20 (20%)',
        changeColor: _orange),
    _DropStage('4', 'Assessed', '40% pass rate', '8'),
    _DropStage('5', 'Interviewed', '37.5% pass rate', '3'),
    _DropStage('6', 'Final Hire', '33.3% conversion', '1 Hired',
        kind: _StageKind.success, changeColor: _green),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'STAGE-BY-STAGE QUANTITATIVE DROP-OFF',
                style: _sectionLabelStyle,
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text(
                'Cohort sample: 1,000 Candidates',
                style: TextStyle(color: _subtle, fontSize: 10, height: 1.35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _rows.length; i++) _buildStage(_rows[i], i),
      ],
    );
  }

  Widget _buildStage(_DropStage r, int index) {
    // The first row is full-width; the rest hang off a vertical timeline line.
    if (index == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _normalBox(r),
      );
    }

    final lineColor = switch (r.kind) {
      _StageKind.bottleneck => _red,
      _StageKind.success => _green,
      _StageKind.normal => const Color(0xFFD5DBE6),
    };

    final box = switch (r.kind) {
      _StageKind.bottleneck => _bottleneckBox(r),
      _StageKind.success => _successBox(r),
      _StageKind.normal => _normalBox(r),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 12),
            Container(width: 2, color: lineColor),
            const SizedBox(width: 10),
            Expanded(child: box),
          ],
        ),
      ),
    );
  }

  // ── Row variants ──────────────────────────────────────────────────────────

  Widget _normalBox(_DropStage r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _numberCircle(r.number, bg: const Color(0xFFE6EBF2), fg: _ink),
          const SizedBox(width: 8),
          Expanded(child: _label(r.label)),
          Text(
            r.change,
            style: TextStyle(
              color: r.changeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          _valueChip(r.volume),
        ],
      ),
    );
  }

  Widget _bottleneckBox(_DropStage r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        border: Border.all(color: const Color(0xFFFF9A9A), width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _numberCircle(r.number, bg: _red, fg: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.label,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  r.change,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _valueChip(r.volume, fontSize: 13),
            ],
          ),
          const SizedBox(height: 8),
          const Text.rich(
            TextSpan(
              style: TextStyle(
                color: Color(0xFFC62828),
                fontSize: 10,
                height: 1.4,
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.report_problem,
                      size: 11,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
                TextSpan(
                  text: 'Primary Drop-Off Bottleneck:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' 900 applicants eliminated at initial keyword & '
                      'experience weighting.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _successBox(_DropStage r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEBFBF2),
        border: Border.all(color: _green.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _numberCircle(r.number, bg: _green, fg: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: _label(r.label)),
          Text(
            r.change,
            style: TextStyle(
              color: r.changeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              r.volume,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Small parts ───────────────────────────────────────────────────────────

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _numberCircle(String n, {required Color bg, required Color fg}) {
    return CircleAvatar(
      radius: 10,
      backgroundColor: bg,
      child: Text(
        n,
        style: TextStyle(
          fontSize: 9,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _valueChip(String text, {double fontSize = 11}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _ink,
          fontSize: fontSize,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
