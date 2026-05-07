// @file       simple_bar_chart.dart
// @brief      Widget for Simple Bar Chart.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';

/* Public classes ----------------------------------------------------- */
class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final List<Color>? barColors;
  final double height;

  // max possible value
  final double maxValue;

  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.barColors,
    this.height = 220,
    this.maxValue = 150,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = maxValue <= 0 ? 150.0 : maxValue;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final rawValue = i < values.length ? values[i] : 0.0;
          final value = rawValue < 0 ? 0.0 : rawValue;
          final frac = (value / safeMax).clamp(0.0, 1.0);

          final color = barColors != null && i < barColors!.length
              ? barColors![i]
              : Theme.of(context).colorScheme.primary;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withValues(alpha: 0.03),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          FractionallySizedBox(
                            heightFactor: frac,
                            widthFactor: 1,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: value > 0 ? color : Colors.transparent,
                              ),
                            ),
                          ),

                          // Value display in the middle of the bar
                          Center(
                            child: Text(
                              value > 0 ? '${value.toStringAsFixed(1)} km' : '',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: frac > 0.35
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
