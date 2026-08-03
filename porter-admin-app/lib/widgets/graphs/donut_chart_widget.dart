import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DonutSection {
  final String label;
  final double value;
  final Color color;
  const DonutSection({required this.label, required this.value, required this.color});
}

class DonutChartWidget extends StatefulWidget {
  final String title;
  final List<DonutSection> sections;
  final String centerText;

  const DonutChartWidget({
    super.key,
    required this.title,
    required this.sections,
    this.centerText = '',
  });

  @override
  State<DonutChartWidget> createState() => _DonutChartWidgetState();
}

class _DonutChartWidgetState extends State<DonutChartWidget> {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _bg      = Color(0xFFF7F8FA);

  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total  = widget.sections.fold<double>(0, (s, e) => s + e.value);
    final hasData = total > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Text(
            widget.title,
            style: const TextStyle(
              color: _textPri,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),

          // ── Chart ─────────────────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: hasData
                ? Row(
                    children: [
                      // Donut
                      Expanded(
                        flex: 5,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (event, response) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          response == null ||
                                          response.touchedSection == null) {
                                        _touchedIndex = -1;
                                        return;
                                      }
                                      _touchedIndex =
                                          response.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                sections: widget.sections.asMap().entries.map((e) {
                                  final i        = e.key;
                                  final s        = e.value;
                                  final touched  = i == _touchedIndex;
                                  final radius   = touched ? 68.0 : 58.0;
                                  return PieChartSectionData(
                                    color: s.color,
                                    value: s.value,
                                    title: '',
                                    radius: radius,
                                    borderSide: touched
                                        ? BorderSide(color: s.color, width: 2)
                                        : const BorderSide(color: Colors.transparent),
                                  );
                                }).toList(),
                                centerSpaceRadius: 52,
                                sectionsSpace: 2.5,
                                startDegreeOffset: -90,
                              ),
                            ),
                            // Center label
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_touchedIndex >= 0 &&
                                    _touchedIndex < widget.sections.length) ...[
                                  Text(
                                    widget.sections[_touchedIndex].value.toInt().toString(),
                                    style: TextStyle(
                                      color: widget.sections[_touchedIndex].color,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    widget.sections[_touchedIndex].label,
                                    style: const TextStyle(
                                      color: _textSec,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    widget.centerText.isNotEmpty
                                        ? widget.centerText
                                        : total.toInt().toString(),
                                    style: const TextStyle(
                                      color: _textPri,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      color: _textSec,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ── Legend (vertical, right side) ─────────────────────
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: widget.sections.asMap().entries.map((e) {
                            final i       = e.key;
                            final s       = e.value;
                            final pct     = total > 0
                                ? ((s.value / total) * 100).toStringAsFixed(1)
                                : '0.0';
                            final touched = i == _touchedIndex;

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _touchedIndex = touched ? -1 : i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: touched
                                      ? s.color.withOpacity(0.07)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: touched
                                        ? s.color.withOpacity(0.25)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: s.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.label,
                                            style: TextStyle(
                                              color: touched ? _textPri : _textSec,
                                              fontSize: 11,
                                              fontWeight: touched
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '$pct%  ·  ${s.value.toInt()}',
                                            style: TextStyle(
                                              color: touched ? s.color : _textSec,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(Icons.pie_chart_outline_rounded,
                              color: _textSec, size: 24),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No data available',
                          style: TextStyle(color: _textSec, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}