import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/person.dart';

class BalanceBarsChart extends StatefulWidget {
  final Map<String, int> netBalances; // personId -> paise
  final List<Person> people;

  const BalanceBarsChart({
    super.key,
    required this.netBalances,
    required this.people,
  });

  @override
  State<BalanceBarsChart> createState() => _BalanceBarsChartState();
}

class _BalanceBarsChartState extends State<BalanceBarsChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    // Find maximum absolute balance for scaling
    int maxAbsPaise = 1;
    widget.netBalances.forEach((_, val) {
      if (val.abs() > maxAbsPaise) {
        maxAbsPaise = val.abs();
      }
    });

    final sortedEntries = widget.netBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return GlassSurface(
          level: GlassLevel.level2,
          borderRadius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Member balances',
                style: AppTypography.sectionHeader.copyWith(
                  color: theme.ink,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              for (final entry in sortedEntries) ...[
                Builder(builder: (context) {
                  final person = widget.people.firstWhere(
                    (p) => p.id == entry.key,
                    orElse: () => Person(
                      id: entry.key,
                      name: 'Member',
                      avatarInitials: 'M',
                    ),
                  );

                  final int paise = entry.value;
                  final double ratio = (paise.abs() / maxAbsPaise) * _animation.value;
                  final bool isOwed = paise > 0;
                  final bool isZero = paise == 0;

                  final Color barColor = isZero
                      ? theme.hairline
                      : (isOwed ? theme.emerald : theme.coral);

                  final Color textColor = isZero
                      ? theme.muted
                      : (isOwed ? theme.textEmerald : theme.textCoral);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              person.id == 'person_arjun' ? 'You (${person.name})' : person.name,
                              style: AppTypography.body.copyWith(
                                color: theme.ink,
                                fontWeight: person.id == 'person_arjun' ? FontWeight.w700 : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              isZero
                                  ? 'Settled'
                                  : CurrencyFormatter.formatPaise(
                                      paise,
                                      showSign: true,
                                      absolute: false,
                                    ),
                              style: AppTypography.caption.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Bi-directional bar centered at zero
                        SizedBox(
                          height: 6,
                          child: CustomPaint(
                            size: const Size(double.infinity, 6),
                            painter: _BalanceBarPainter(
                              ratio: ratio,
                              isOwed: isOwed,
                              isZero: isZero,
                              barColor: barColor,
                              trackColor: theme.raised,
                              hairlineColor: theme.hairline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BalanceBarPainter extends CustomPainter {
  final double ratio;
  final bool isOwed;
  final bool isZero;
  final Color barColor;
  final Color trackColor;
  final Color hairlineColor;

  const _BalanceBarPainter({
    required this.ratio,
    required this.isOwed,
    required this.isZero,
    required this.barColor,
    required this.trackColor,
    required this.hairlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;

    // Background track with rounded pill corners
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(3),
      ),
      trackPaint,
    );

    // Center divider tick
    final centerTickPaint = Paint()
      ..color = hairlineColor
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerTickPaint,
    );

    if (isZero || ratio <= 0.0) return;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final halfWidth = size.width / 2;
    final barLength = (halfWidth * ratio).clamp(0.0, halfWidth);

    if (isOwed) {
      // Positive/Owed: grows to the right from the center
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(halfWidth, 0, barLength, size.height),
          const Radius.circular(3),
        ),
        barPaint,
      );
    } else {
      // Negative/Owes: grows to the left from the center
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(halfWidth - barLength, 0, barLength, size.height),
          const Radius.circular(3),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceBarPainter oldDelegate) {
    return ratio != oldDelegate.ratio ||
        barColor != oldDelegate.barColor ||
        trackColor != oldDelegate.trackColor ||
        hairlineColor != oldDelegate.hairlineColor;
  }
}
