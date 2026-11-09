import 'dart:math';

enum SignalQuality {
  ideal,    // >= -24.0 dBm
  warning,  // -24.1 to -27.0 dBm
  critical, // < -27.0 dBm
  unknown,
}

class OpticalPowerParser {
  /// Parses optical RX power from string or number across all ONU vendors
  /// (ZTE, Huawei, Fiberhome, CIOT, ZICG, VSOL, XPON, etc.)
  static double? parse(dynamic rawValue) {
    if (rawValue == null) return null;
    final str = rawValue.toString().replaceAll('dBm', '').replaceAll('dB', '').trim();
    if (str.isEmpty || str == '-' || str.toLowerCase() == 'n/a') return null;

    final raw = double.tryParse(str);
    if (raw == null) return null;

    double? result;

    if (raw >= -45.0 && raw <= -5.0) {
      // 1. Direct negative dBm (e.g. -17.50, -21.4)
      result = raw;
    } else if (raw >= 5.0 && raw <= 45.0) {
      // 2. Positive attenuation (e.g. 21.4 -> -21.4 dBm)
      result = -raw;
    } else if (raw >= -450.0 && raw <= -50.0) {
      // 3. 0.1 dBm scale negative
      result = raw / 10.0;
    } else if (raw >= 50.0 && raw <= 450.0) {
      // 3b. 0.1 dBm scale positive
      result = -(raw / 10.0);
    } else if (raw >= -4500.0 && raw <= -500.0) {
      // 4. Huawei / Fiberhome 0.01 dBm scale
      result = raw / 100.0;
    } else if (raw >= 1000.0 && raw <= 4500.0) {
      // 4b. Huawei / Fiberhome positive 0.01 dBm
      result = -(raw / 100.0);
    } else if (raw >= 5000.0 && raw <= 9900.0) {
      // 5. ZTE PON offset formula: (raw / 100) - 100
      result = (raw / 100.0) - 100.0;
    } else if (raw >= -45000.0 && raw <= -5000.0) {
      // 6. Milli-dBm (0.001 dBm)
      result = raw / 1000.0;
    } else if (raw >= 10000.0 && raw <= 45000.0) {
      result = -(raw / 1000.0);
    } else if (raw > 0.0 && raw < 1000.0) {
      // 7. CMCC raw microwatt to dBm
      result = 10.0 * (log(raw * 0.0001) / ln10);
    } else if (raw >= -60.0 && raw <= -1.0) {
      result = raw;
    }

    if (result != null) {
      return (result * 100.0).roundToDouble() / 100.0;
    }
    return null;
  }

  static SignalQuality getQuality(double? rxPower) {
    if (rxPower == null) return SignalQuality.unknown;
    if (rxPower >= -24.0) return SignalQuality.ideal;
    if (rxPower >= -27.0) return SignalQuality.warning;
    return SignalQuality.critical;
  }

  static String getStatusLabel(SignalQuality quality) {
    switch (quality) {
      case SignalQuality.ideal:
        return 'Bagus';
      case SignalQuality.warning:
        return 'Sedang';
      case SignalQuality.critical:
        return 'Kritis / Los';
      case SignalQuality.unknown:
        return 'Tidak Ada Sinyal';
    }
  }
}
