import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/optical_power_parser.dart';

class SignalBadge extends StatelessWidget {
  final double? rxPower;
  final bool showLabel;

  const SignalBadge({
    super.key,
    required this.rxPower,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final quality = OpticalPowerParser.getQuality(rxPower);

    Color bg;
    Color fg;
    IconData icon;

    switch (quality) {
      case SignalQuality.ideal:
        bg = AppColors.signalIdeal.withOpacity(0.15);
        fg = AppColors.signalIdeal;
        icon = Icons.signal_cellular_alt;
        break;
      case SignalQuality.warning:
        bg = AppColors.signalWarning.withOpacity(0.18);
        fg = AppColors.signalWarning;
        icon = Icons.signal_cellular_alt_2_bar;
        break;
      case SignalQuality.critical:
        bg = AppColors.signalCritical.withOpacity(0.18);
        fg = AppColors.signalCritical;
        icon = Icons.signal_cellular_connected_no_internet_0_bar;
        break;
      case SignalQuality.unknown:
        bg = AppColors.signalUnknown.withOpacity(0.15);
        fg = AppColors.signalUnknown;
        icon = Icons.signal_cellular_off;
        break;
    }

    final powerText = rxPower != null ? '${rxPower!.toStringAsFixed(2)} dBm' : 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            powerText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
              fontFamily: 'monospace',
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              '(${OpticalPowerParser.getStatusLabel(quality)})',
              style: TextStyle(
                fontSize: 10,
                color: fg.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
