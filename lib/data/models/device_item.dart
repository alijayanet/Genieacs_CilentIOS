import '../../core/utils/optical_power_parser.dart';

class DeviceItem {
  final String id;
  final String serialNumber;
  final String productClass;
  final String manufacturer;
  final String pppoeUsername;
  final String customerName;
  final String ssid;
  final String? wlanPassword;
  final double? rxPower;
  final double? txPower;
  final String lastInform;
  final bool isOnline;
  final List<String> tags;
  final String? odpName;
  final double? odpLat;
  final double? odpLng;
  final double? lat;
  final double? lng;
  final String ponMode;
  final int? temp;
  final int activeDevices;
  final String? ip;
  final String? uptime;
  final String? mac;
  final String? vlan;
  final String? superAdmin;
  final String? superPassword;

  const DeviceItem({
    required this.id,
    required this.serialNumber,
    required this.productClass,
    required this.manufacturer,
    required this.pppoeUsername,
    required this.customerName,
    required this.ssid,
    this.wlanPassword,
    this.rxPower,
    this.txPower,
    required this.lastInform,
    required this.isOnline,
    this.tags = const [],
    this.odpName,
    this.odpLat,
    this.odpLng,
    this.lat,
    this.lng,
    this.ponMode = 'GPON',
    this.temp,
    this.activeDevices = 0,
    this.ip,
    this.uptime,
    this.mac,
    this.vlan,
    this.superAdmin,
    this.superPassword,
  });

  SignalQuality get signalQuality => OpticalPowerParser.getQuality(rxPower);
  double? get opticalRxPower => rxPower;
  String? get wlanSsid => ssid;
  String? get ipWan => ip;
  String get modelName => productClass;
  int? get temperature => temp;
  double? get latitude => lat;
  double? get longitude => lng;
  bool get hasGps => lat != null && lng != null;
  bool get isMapped => (odpName != null && odpName!.isNotEmpty) || hasGps;
  String get lastInformFormatted => lastInform;
  bool get isCriticalSignal => rxPower != null && rxPower! < -27.0;

  String get displayCustomerOrSerial {
    if (customerName.isNotEmpty && customerName != '-' && customerName != pppoeUsername) {
      return customerName;
    }
    if (pppoeUsername.isNotEmpty && pppoeUsername != '-') {
      return pppoeUsername;
    }
    return serialNumber;
  }

  factory DeviceItem.fromGenieAcsJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final devId = json['_deviceId'] as Map<String, dynamic>?;
    final manufacturer = devId?['_Manufacturer']?.toString() ?? 'Unknown';
    final productClass = devId?['_ProductClass']?.toString() ?? 'Modem';
    final serialNumber = devId?['_SerialNumber']?.toString() ?? id;

    // 1. Check last inform & online status (< 6 minutes threshold)
    final lastInformRaw = json['_lastInform']?.toString();
    bool online = false;
    String lastInformStr = '-';
    if (lastInformRaw != null) {
      final parsedDate = DateTime.tryParse(lastInformRaw);
      if (parsedDate != null) {
        final diff = DateTime.now().toUtc().difference(parsedDate);
        online = diff.inMinutes < 6;
        if (diff.inSeconds < 60) {
          lastInformStr = '${diff.inSeconds}d lalu';
        } else if (diff.inMinutes < 60) {
          lastInformStr = '${diff.inMinutes}m lalu';
        } else if (diff.inHours < 24) {
          lastInformStr = '${diff.inHours}j lalu';
        } else {
          lastInformStr = '${diff.inDays}h lalu';
        }
      }
    }

    // 2. Parse Tags
    final rawTags = json['_tags'];
    final List<String> tagsList = [];
    if (rawTags is List) {
      for (var t in rawTags) {
        if (t != null) tagsList.add(t.toString().trim());
      }
    }

    // 3. Extract Geo & ODP from Tags (LOC_${latE6}_${lngE6}, ODP_${name}_${latE6}_${lngE6})
    double? latitude;
    double? longitude;
    String? odp;
    double? odpLatitude;
    double? odpLongitude;

    for (var t in tagsList) {
      if (t.startsWith('LOC_') || t.startsWith('LOC:')) {
        final raw = t.contains(':') ? t.substring(t.indexOf(':') + 1) : t.substring(4);
        final parts = raw.split('_');
        if (parts.length >= 2) {
          final latRaw = double.tryParse(parts[0]);
          final lngRaw = double.tryParse(parts[1]);
          if (latRaw != null && lngRaw != null) {
            latitude = latRaw / 1000000.0;
            longitude = lngRaw / 1000000.0;
          }
        }
      } else if (t.startsWith('ODP_') || t.startsWith('ODP:') || t.startsWith('ODP-')) {
        final raw = t.contains(':')
            ? t.substring(t.indexOf(':') + 1)
            : (t.startsWith('ODP-') ? t.substring(4) : t.substring(4));
        final parts = raw.split('_');
        if (parts.isNotEmpty) {
          odp = parts[0].replaceAll('-', ' ');
          if (parts.length >= 3) {
            final oLatRaw = double.tryParse(parts[1]);
            final oLngRaw = double.tryParse(parts[2]);
            if (oLatRaw != null && oLngRaw != null) {
              odpLatitude = oLatRaw / 1000000.0;
              odpLongitude = oLngRaw / 1000000.0;
            }
          }
        }
      }
    }

    // 4. Intelligent VirtualParameters token matching (Universal Multi-Vendor GenieACS)
    final vp = json['VirtualParameters'] as Map<String, dynamic>? ?? {};

    String? findVpByTokens({
      required List<String> exactPriority,
      required List<String> tokens,
      List<String> excludeTokens = const [],
    }) {
      // 1. Exact priority lookup
      for (final exact in exactPriority) {
        if (vp.containsKey(exact)) {
          final v = vp[exact];
          if (v is Map && v.containsKey('_value')) {
            final val = v['_value'];
            if (val != null && val.toString().trim().isNotEmpty) {
              return val.toString().trim();
            }
          } else if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString().trim();
          }
        }
      }

      // 2. Case-insensitive token match
      for (final entry in vp.entries) {
        final lower = entry.key.toLowerCase();
        if (excludeTokens.any((t) => lower.contains(t))) continue;
        if (tokens.any((t) => lower.contains(t))) {
          final v = entry.value;
          if (v is Map && v.containsKey('_value')) {
            final val = v['_value'];
            if (val != null && val.toString().trim().isNotEmpty) {
              return val.toString().trim();
            }
          } else if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString().trim();
          }
        }
      }
      return null;
    }

    String? getNestedString(List<String> pathSegments) {
      dynamic current = json;
      for (final seg in pathSegments) {
        if (current is Map) {
          current = current[seg];
        } else {
          return null;
        }
      }
      if (current is Map && current.containsKey('_value')) {
        final val = current['_value'];
        return val?.toString().trim();
      }
      return current?.toString().trim();
    }

    // PPPoE Username across all 39 VirtualParameters conventions and TR-069 slots
    final pppoeUser = findVpByTokens(
      exactPriority: [
        'pppoeUsername', 'pppUsername', 'pppoeUsername2', 'pppoe_username', 'ppp_username',
        'Username', 'username', 'getpppoeuser', 'pppoeUser', 'user_pppoe', 'userpppoe',
        'wan_username', 'PPPoE'
      ],
      tokens: ['pppoe', 'pppuser', 'userpppoe', 'wanuser'],
      excludeTokens: ['pass', 'pwd', 'ip', 'mac', 'admin', 'remote', 'uptime'],
    ) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANConnectionDevice', '1', 'WANPPPConnection', '1', 'Username']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANConnectionDevice', '1', 'WANPPPConnection', '2', 'Username']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANConnectionDevice', '2', 'WANPPPConnection', '1', 'Username']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANConnectionDevice', '2', 'WANPPPConnection', '2', 'Username']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANConnectionDevice', '3', 'WANPPPConnection', '1', 'Username']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANConnectionDevice', '4', 'WANPPPConnection', '1', 'Username']) ??
    getNestedString(['Device', 'PPP', 'Interface', '1', 'Username']) ??
    getNestedString(['Device', 'PPP', 'Interface', '2', 'Username']) ??
    '-';

    // Customer Name matching
    String? customerName = findVpByTokens(
      exactPriority: [
        'customerName', 'CustomerName', 'customer_name', 'namaPelanggan', 'nama_pelanggan',
        'NamaPelanggan', 'nama', 'Nama', 'customer', 'Customer', 'clientName', 'client_name',
        'ClientName', 'pelanggan', 'Pelanggan', 'user_fullname', 'fullname'
      ],
      tokens: ['customer', 'pelanggan', 'nama', 'client', 'fullname'],
    );
    if (customerName == null || customerName.isEmpty) {
      for (final t in tagsList) {
        final u = t.toUpperCase();
        if (u.startsWith('NAMA:') || u.startsWith('NAME:') || u.startsWith('PLG:') ||
            u.startsWith('CUST:') || u.startsWith('CLIENT:') || u.startsWith('PELANGGAN:')) {
          customerName = t.substring(t.indexOf(':') + 1).trim();
          break;
        }
      }
    }
    customerName ??= (pppoeUser != '-' ? pppoeUser : serialNumber);

    // WiFi SSID matching
    final ssid = findVpByTokens(
      exactPriority: [
        'WlanSSID', 'SSID', 'ssid', 'wlanSSID', 'wlan_ssid', 'wifi_ssid', 'wifiName',
        'SSID1', 'ssid1', 'WLAN_SSID'
      ],
      tokens: ['ssid', 'wifi', 'wlan'],
      excludeTokens: ['pass', 'pwd', 'key', 'enable', 'hide', 'beacon', 'chan', 'mode'],
    ) ??
    getNestedString(['InternetGatewayDevice', 'LANDevice', '1', 'WLANConfiguration', '1', 'SSID']) ??
    getNestedString(['InternetGatewayDevice', 'LANDevice', '1', 'WLANConfiguration', '2', 'SSID']) ??
    getNestedString(['Device', 'WiFi', 'SSID', '1', 'SSID']) ??
    '-';

    // WiFi Password matching
    final wlanPass = findVpByTokens(
      exactPriority: [
        'WlanPassword', 'wlan_password', 'wifi_password', 'Password', 'password',
        'KeyPassphrase', 'PreSharedKey', 'WPAKey'
      ],
      tokens: ['wlanpass', 'wifipass', 'keypassphrase', 'presharedkey'],
    ) ??
    getNestedString(['InternetGatewayDevice', 'LANDevice', '1', 'WLANConfiguration', '1', 'PreSharedKey', '1', 'KeyPassphrase']) ??
    getNestedString(['InternetGatewayDevice', 'LANDevice', '1', 'WLANConfiguration', '1', 'KeyPassphrase']);

    // Optical RX Power (ZTE, Huawei, CIOT, Fiberhome, ZICG, etc.)
    final rxRaw = findVpByTokens(
      exactPriority: [
        'RXPower', 'rxPower', 'rx_power', 'redaman', 'Redaman', 'opticalPower',
        'optical_power', 'OpticalPower', 'RxOpticalPower', 'rxOpticalPower',
        'rx_optical_power', 'pon_rx', 'PonRx', 'optical_rx'
      ],
      tokens: ['rx', 'redaman', 'opticalpower', 'opticalrx', 'ponrx'],
      excludeTokens: ['tx', 'bias', 'temp', 'volt', 'alarm', 'state'],
    ) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANOFTCommonInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANOFTCommonInterfaceConfig', 'OpticalRxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_CT-COM_GponInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_CT-COM_WANPONInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_CT-COM_EponInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_CT-COM_WANEponInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_ZTE-COM_WANPONInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_ZTE-COM_PONInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_ZTE-COM_GponInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_HW_PONInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_HW_GponInterfaceConfig', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_HW_DEBUG', 'SMP', 'OPTIC', 'RxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_HW_DEBUG', 'SMP', 'OPTIC', 'RxOpticalPower']) ??
    getNestedString(['Device', 'Optical', 'Interface', '1', 'RxPower']);

    final rx = OpticalPowerParser.parse(rxRaw);

    // Optical TX Power
    final txRaw = findVpByTokens(
      exactPriority: ['TXPower', 'txPower', 'tx_power', 'OpticalTxPower', 'txOpticalPower'],
      tokens: ['txpower', 'opticaltx'],
    ) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANOFTCommonInterfaceConfig', 'TxPower']) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'X_HW_DEBUG', 'SMP', 'OPTIC', 'TxPower']);
    final tx = OpticalPowerParser.parse(txRaw);

    // Active Devices / Clients Connected
    final activeRaw = findVpByTokens(
      exactPriority: ['activedevices', 'userconnected', 'getAssociation', 'TotalAssociations', 'active_devices'],
      tokens: ['activedevice', 'userconnected', 'association'],
    );
    final activeCount = int.tryParse(activeRaw ?? '0') ?? 0;

    // Temperature
    final tempRaw = findVpByTokens(
      exactPriority: ['gettemp', 'temp', 'temperature', 'Temperature', 'device_temp'],
      tokens: ['temp'],
      excludeTokens: ['uptime', 'power'],
    );
    final tempVal = int.tryParse(tempRaw ?? '');

    // PON Mode / Access Type
    final rawPon = findVpByTokens(
      exactPriority: ['getponmode', 'PonMode', 'pon_mode', 'pon_type', 'getaccesstype', 'AccessType'],
      tokens: ['ponmode', 'accesstype'],
    ) ?? getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANCommonInterfaceConfig', 'WANAccessType']);

    final ponMode = (rawPon?.toUpperCase().contains('EPON') == true)
        ? 'EPON'
        : ((rawPon?.toUpperCase().contains('GPON') == true ||
            productClass.toUpperCase().contains('GPON') ||
            tagsList.any((t) => t.toUpperCase().contains('GPON')))
            ? 'GPON'
            : (rawPon?.isNotEmpty == true ? rawPon! : 'GPON'));

    // IP (WAN, PPPoE, TR-069)
    final ipVal = findVpByTokens(
      exactPriority: ['pppIP', 'pppoeIP', 'WanIP', 'IPTR069', 'wan_ip', 'ExternalIPAddress'],
      tokens: ['pppip', 'wanip', 'iptr069'],
    ) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANConnectionDevice', '1', 'WANPPPConnection', '1', 'ExternalIPAddress']);

    // MAC Address
    final macVal = findVpByTokens(
      exactPriority: ['MacAddress', 'PonMac', 'pppoeMac', 'WanMac', 'macAddress', 'mac_address'],
      tokens: ['macaddress', 'ponmac', 'wanmac', 'pppoemac'],
    ) ??
    getNestedString(['InternetGatewayDevice', 'WANDevice', '1', 'WANConnectionDevice', '1', 'WANPPPConnection', '1', 'MACAddress']);

    // Device Uptime
    final uptimeVal = findVpByTokens(
      exactPriority: ['uptimeDevice', 'getdeviceuptime', 'getpppuptime', 'uptime', 'UpTime'],
      tokens: ['uptime'],
    );

    // VLAN ID
    final vlanVal = findVpByTokens(
      exactPriority: ['VlanID', 'vlan', 'Vlan', 'vlanId', 'VLANID'],
      tokens: ['vlan'],
    );

    // Web GUI Admin credentials
    final superUser = findVpByTokens(
      exactPriority: ['superAdmin', 'userAdmin', 'adminUser', 'WebUsername'],
      tokens: ['adminuser', 'superadmin'],
    );
    final superPass = findVpByTokens(
      exactPriority: ['superPassword', 'userPassword', 'adminPassword', 'WebPassword'],
      tokens: ['adminpassword', 'superpassword'],
    );

    return DeviceItem(
      id: id,
      serialNumber: serialNumber,
      productClass: productClass,
      manufacturer: manufacturer,
      pppoeUsername: pppoeUser,
      customerName: customerName,
      ssid: ssid,
      wlanPassword: wlanPass,
      rxPower: rx,
      txPower: tx,
      lastInform: lastInformStr,
      isOnline: online,
      tags: tagsList,
      odpName: odp,
      odpLat: odpLatitude,
      odpLng: odpLongitude,
      lat: latitude,
      lng: longitude,
      ponMode: ponMode,
      temp: tempVal,
      activeDevices: activeCount,
      ip: ipVal,
      uptime: uptimeVal,
      mac: macVal,
      vlan: vlanVal,
      superAdmin: superUser,
      superPassword: superPass,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serialNumber': serialNumber,
      'productClass': productClass,
      'manufacturer': manufacturer,
      'pppoeUsername': pppoeUsername,
      'customerName': customerName,
      'ssid': ssid,
      'wlanPassword': wlanPassword,
      'rxPower': rxPower,
      'txPower': txPower,
      'lastInform': lastInform,
      'isOnline': isOnline,
      'tags': tags,
      'odpName': odpName,
      'odpLat': odpLat,
      'odpLng': odpLng,
      'lat': lat,
      'lng': lng,
      'ponMode': ponMode,
      'temp': temp,
      'activeDevices': activeDevices,
      'ip': ip,
      'uptime': uptime,
      'mac': mac,
      'vlan': vlan,
      'superAdmin': superAdmin,
      'superPassword': superPassword,
    };
  }
}
