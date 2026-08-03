import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BarData {
  final String label;
  final double value;
  final Color color;
  const BarData({required this.label, required this.value, required this.color});
}

class BarChartWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<BarData> bars;
  final String unit;
  final double height;

  const BarChartWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.bars,
    this.unit = '',
    this.height = 220,
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _primary = Color(0xFF1A1A2E);

  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final bars   = widget.bars;
    final maxVal = bars.isEmpty ? 1.0 : bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);
    final maxY   = maxVal <= 0 ? 10.0 : maxVal * 1.3;

    // Summary: highest bar label + value
    final highIdx  = bars.isEmpty ? -1 : bars.indexOf(bars.reduce((a, b) => a.value > b.value ? a : b));
    final totalVal = bars.fold<double>(0, (s, b) => s + b.value);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(color: _textSec, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              // Total summary pill
              if (bars.isNotEmpty && totalVal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    'Total: ${widget.unit}${_compact(totalVal)}',
                    style: const TextStyle(
                      color: _textSec,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Chart ─────────────────────────────────────────────────────────
          SizedBox(
            height: widget.height,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: List.generate(bars.length, (i) {
                  final isTouched = _touchedIndex == i;
                  final bar = bars[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: bar.value < 0 ? 0 : bar.value,
                        width: isTouched ? 22 : 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(5),
                          topRight: Radius.circular(5),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            bar.color,
                            bar.color.withOpacity(isTouched ? 1.0 : 0.75),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: _bg,
                        ),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= bars.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            bars[idx].label,
                            style: TextStyle(
                              color: _touchedIndex == idx ? _textPri : _textSec,
                              fontSize: 10.5,
                              fontWeight: _touchedIndex == idx
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: widget.unit.isEmpty ? 32 : 48,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == maxY) return const SizedBox();
                        final display = widget.unit.isEmpty
                            ? value.toInt().toString()
                            : '${widget.unit}${_compact(value)}';
                        return Text(
                          display,
                          style: const TextStyle(color: _textSec, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: _border,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (event is FlTapUpEvent || event is FlPanEndEvent) {
                        _touchedIndex = null;
                      } else if (response?.spot != null) {
                        _touchedIndex = response!.spot!.touchedBarGroupIndex;
                      } else {
                        _touchedIndex = null;
                      }
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipColor: (_) => _primary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final b = bars[groupIndex];
                      return BarTooltipItem(
                        '${b.label}\n',
                        const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '${widget.unit}${rod.toY.toStringAsFixed(widget.unit.isEmpty ? 0 : 2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              swapAnimationDuration: const Duration(milliseconds: 380),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),

          // ── Legend / highlight row ────────────────────────────────────────
          if (bars.isNotEmpty && highIdx >= 0) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 12),
            Row(
              children: [
                // Highest bar callout
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: bars[highIdx].color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Highest: ${bars[highIdx].label}',
                  style: const TextStyle(color: _textSec, fontSize: 11),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.unit}${_compact(bars[highIdx].value)}',
                  style: const TextStyle(
                    color: _textPri,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Color legend dots
                ...bars.take(5).map((b) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: b.color,
                        shape: BoxShape.circle,
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}