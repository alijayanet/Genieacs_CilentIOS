import 'wan_models.dart';

class WlanInstance {
  final int index;
  final String label;
  String ssid;
  String password;
  bool isEnabled;
  bool isHidden;
  String securityMode;
  final String? path;

  bool get enabled => isEnabled;

  WlanInstance({
    required this.index,
    this.label = 'WLAN 2.4GHz',
    required this.ssid,
    this.password = '',
    this.isEnabled = true,
    bool? enabled,
    this.isHidden = false,
    this.securityMode = 'WPA2-PSK',
    this.path,
  }) {
    if (enabled != null) {
      isEnabled = enabled;
    }
  }
}

class DeviceDetail {
  final String id;
  final String serialNumber;
  final String productClass;
  final String manufacturer;
  final String softwareVersion;
  final String hardwareVersion;
  final String lastInform;
  final bool isOnline;
  final String pppoeUser;
  final String pppoeIp;
  final String macAddress;
  final double? rxPower;
  final double? txPower;
  final int? temp;
  final String uptime;
  final String ponMode;
  final String adminUser;
  final String adminPassword;
  final String? vlanId;
  final int activeDevices;
  final List<ConnectedClient> connectedClients;
  final List<WlanInstance> wlans;
  final List<WanItem> wanList;
  final List<String> tags;
  final Map<String, dynamic> rawParameters;
  final Map<String, String> virtualParameters;
  final double? lat;
  final double? lng;
  final String? odpName;
  final double? odpLat;
  final double? odpLng;

  WlanInstance? get primaryWlan => wlans.isNotEmpty ? wlans.first : null;
  int? get temperature => temp;
  double? get voltage => 3.3;
  String get pppoeUsername => pppoeUser;
  String get wanIp => pppoeIp;
  String get uptimeFormatted => uptime;
  double? get latitude => lat;
  double? get longitude => lng;
  bool get hasGps => lat != null && lng != null;
  bool get isMapped => (odpName != null && odpName!.isNotEmpty) || hasGps;

  DeviceDetail({
    required this.id,
    required this.serialNumber,
    required this.productClass,
    required this.manufacturer,
    this.softwareVersion = '-',
    this.hardwareVersion = '-',
    required this.lastInform,
    required this.isOnline,
    required this.pppoeUser,
    required this.pppoeIp,
    required this.macAddress,
    this.rxPower,
    this.txPower,
    this.temp,
    required this.uptime,
    required this.ponMode,
    this.adminUser = 'admin',
    this.adminPassword = 'admin',
    this.vlanId,
    this.activeDevices = 0,
    this.connectedClients = const [],
    required this.wlans,
    this.wanList = const [],
    this.tags = const [],
    this.rawParameters = const {},
    this.virtualParameters = const {},
    this.lat,
    this.lng,
    this.odpName,
    this.odpLat,
    this.odpLng,
  });
}
