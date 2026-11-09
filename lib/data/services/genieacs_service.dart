import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../../core/utils/optical_power_parser.dart';
import '../models/device_detail.dart';
import '../models/device_item.dart';
import '../models/wan_models.dart';

class GenieAcsService {
  final String baseUrl;
  final String username;
  final String password;
  late final Dio _dio;

  GenieAcsService({
    required this.baseUrl,
    this.username = 'root',
    this.password = 'goodlife',
  }) {
    final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final authHeader = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    _dio = Dio(
      BaseOptions(
        baseUrl: cleanUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Authorization': authHeader,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  /// PBKDF2 HMAC SHA-512 implementation matching GenieACS & Kotlin reference
  static String hashPbkdf2(String password, String salt) {
    final saltBytes = utf8.encode(salt);
    final pwdBytes = utf8.encode(password);
    final hmac = Hmac(sha512, pwdBytes);

    const int iterations = 10000;
    const int keyLengthBytes = 128; // 128 bytes = 256 hex chars
    final numBlocks = (keyLengthBytes / 64).ceil();
    final result = Uint8List(numBlocks * 64);

    for (int block = 1; block <= numBlocks; block++) {
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      var u = hmac.convert([...saltBytes, ...blockBytes.buffer.asUint8List()]).bytes;
      final t = List<int>.from(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int k = 0; k < 64; k++) {
          t[k] ^= u[k];
        }
      }

      result.setRange((block - 1) * 64, block * 64, t);
    }

    final sub = Uint8List.sublistView(result, 0, keyLengthBytes);
    return sub.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Authenticate against GenieACS Web UI accounts & NBI
  Future<bool> authenticate(String user, String pass) async {
    if (user.trim().isEmpty) {
      throw Exception('Username server tidak boleh kosong.');
    }
    if (pass.isEmpty) {
      throw Exception('Password server tidak boleh kosong.');
    }

    // 1. Check GenieACS /users collection (Web UI user accounts)
    try {
      final usersRes = await _dio.get('/users');
      if (usersRes.statusCode == 200 && usersRes.data is List) {
        final usersList = usersRes.data as List;
        if (usersList.isNotEmpty) {
          Map<String, dynamic>? targetUser;
          for (var item in usersList) {
            if (item is Map && item['_id']?.toString().toLowerCase() == user.trim().toLowerCase()) {
              targetUser = Map<String, dynamic>.from(item);
              break;
            }
          }

          // If user entered web UI username (like admin or alijaya) but it does not exist
          if (targetUser == null && user.trim().toLowerCase() != 'root') {
            throw Exception('Username "$user" tidak terdaftar di server GenieACS!');
          }

          if (targetUser != null) {
            final storedHash = targetUser['password']?.toString() ?? '';
            final salt = targetUser['salt']?.toString() ?? '';

            if (storedHash.isNotEmpty && salt.isNotEmpty) {
              final computedHash = hashPbkdf2(pass, salt);
              if (computedHash.toLowerCase() != storedHash.toLowerCase()) {
                throw Exception('Password yang Anda masukkan salah untuk user "$user"!');
              } else {
                return true; // Match found in /users!
              }
            }
          }
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401 || dioErr.response?.statusCode == 403) {
        throw Exception('Akses Ditolak: Kredensial server salah! (HTTP ${dioErr.response?.statusCode})');
      }
      // If error was thrown intentionally above, rethrow it
      if (dioErr.error is Exception) {
        throw dioErr.error as Exception;
      }
    } catch (e) {
      if (e.toString().contains('tidak terdaftar') || e.toString().contains('salah untuk user')) {
        rethrow;
      }
    }

    // 2. Fallback check to GenieACS Web UI port 3000 /login if accessible
    try {
      final uri = Uri.parse(baseUrl);
      final uiUrl = '${uri.scheme}://${uri.host}:3000/login';
      final uiDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ));

      final uiRes = await uiDio.post(
        uiUrl,
        data: {'username': user, 'password': pass},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (uiRes.statusCode == 200 || (uiRes.statusCode != null && uiRes.statusCode! >= 300 && uiRes.statusCode! < 400)) {
        return true;
      } else if (uiRes.statusCode == 400 || uiRes.statusCode == 401) {
        final bodyStr = uiRes.data?.toString() ?? '';
        if (bodyStr.contains('Incorrect') || bodyStr.contains('password') || bodyStr.contains('username')) {
          throw Exception('Username atau Password salah! (Ditolak oleh GenieACS UI)');
        }
      }
    } catch (e) {
      if (e.toString().contains('Ditolak oleh GenieACS UI')) {
        rethrow;
      }
    }

    // 3. Fallback check: Test basic NBI call with these credentials
    try {
      final authHeader = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
      final testDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        headers: {'Authorization': authHeader},
      ));
      final res = await testDio.get('/devices?limit=1');
      if (res.statusCode == 200) {
        return true;
      }
      throw Exception('Username atau Password server salah!');
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401 || dioErr.response?.statusCode == 403) {
        throw Exception('Username atau Password server salah! (HTTP ${dioErr.response?.statusCode})');
      }
      throw Exception('Gagal menghubungi GenieACS: ${dioErr.message}');
    }
  }

  /// Test connection to GenieACS NBI
  Future<bool> testConnection() async {
    try {
      final res = await _dio.get('/devices?limit=1');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch devices list using targeted projection
  Future<List<DeviceItem>> getDevices() async {
    try {
      final projectionFields = [
        '_id',
        '_lastInform',
        '_deviceId',
        '_tags',
        'VirtualParameters',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.Username',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.2.Username',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.2.WANPPPConnection.1.Username',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.2.WANPPPConnection.2.Username',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.3.WANPPPConnection.1.Username',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.4.WANPPPConnection.1.Username',
        'Device.PPP.Interface.1.Username',
        'Device.PPP.Interface.2.Username',
        'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID',
        'InternetGatewayDevice.LANDevice.1.WLANConfiguration.2.SSID',
        'InternetGatewayDevice.LANDevice.1.WLANConfiguration.3.SSID',
        'InternetGatewayDevice.LANDevice.1.WLANConfiguration.4.SSID',
        'InternetGatewayDevice.LANDevice.1.WLANConfiguration.5.SSID',
        'Device.WiFi.SSID.1.SSID',
        'Device.WiFi.SSID.2.SSID',
        'InternetGatewayDevice.WANDevice.1.WANOFTCommonInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.WANOFTCommonInterfaceConfig.OpticalRxPower',
        'InternetGatewayDevice.WANDevice.1.X_CT-COM_GponInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_CT-COM_WANPONInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_CT-COM_EponInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_CT-COM_WANEponInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_ZTE-COM_WANPONInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_ZTE-COM_PONInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_ZTE-COM_GponInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_HW_PONInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_HW_GponInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_HW_DEBUG.SMP.OPTIC.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_HW_DEBUG.SMP.OPTIC.RxOpticalPower',
        'Device.Optical.Interface.1.RxPower',
        'InternetGatewayDevice.WANDevice.1.WANCommonInterfaceConfig.WANAccessType',
      ].join(',');

      final response = await _dio.get(
        '/devices',
        queryParameters: {'projection': projectionFields},
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List)
            .map((e) => DeviceItem.fromGenieAcsJson(e as Map<String, dynamic>))
            .toList();
        return list;
      }
      return [];
    } catch (e) {
      throw Exception('Gagal memuat daftar perangkat: $e');
    }
  }

  /// Fetch full device details
  Future<DeviceDetail> getDeviceDetail(String deviceId) async {
    try {
      final queryParam = jsonEncode({'_id': deviceId});
      final res = await _dio.get('/devices', queryParameters: {'query': queryParam});

      if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
        final doc = (res.data as List).first as Map<String, dynamic>;
        return _parseDeviceDetail(deviceId, doc);
      }
      throw Exception('Perangkat tidak ditemukan di server.');
    } catch (e) {
      throw Exception('Gagal mengambil detail perangkat: $e');
    }
  }

  /// Add TR-069 Object (e.g. new WAN connection instance)
  Future<bool> addObject(String deviceId, String objectName) async {
    try {
      final encId = Uri.encodeComponent(deviceId);
      final res = await _dio.post(
        '/devices/$encId/tasks',
        queryParameters: {'connection_request': ''},
        data: jsonEncode({
          'name': 'addObject',
          'objectName': objectName,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (_) {
      return false;
    }
  }

  /// Configure WAN connection (Add or Edit) matching reference app
  Future<String> configureWan(String deviceId, WanConfigParams params) async {
    try {
      final mfgLower = params.manufacturer.toLowerCase();
      final isZte = mfgLower.contains('zte') || mfgLower.contains('zicg');
      final isHuawei = mfgLower.contains('huawei');
      final isCiot = mfgLower.contains('ciot') || mfgLower.contains('fiberhome');

      final slotName = (params.wanSlot == 'IP' || params.connectionType.startsWith('IP_'))
          ? 'WANIPConnection'
          : 'WANPPPConnection';

      // 1. If requested new instance, call addObject
      if (params.isNewInstance) {
        final ok = await addObject(
          deviceId,
          'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.$slotName',
        );
        if (!ok) {
          // Fallback attempt for standard TR-098
          await addObject(deviceId, 'InternetGatewayDevice.WANDevice.1.WANConnectionDevice');
        }
      }

      // 2. Build parameterValues
      final wanIdx = params.wanIndex;
      final basePath = 'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.$slotName.$wanIdx';

      final isBridge = params.connectionType.contains('Bridge');
      final isPppoe = params.connectionType == 'PPPoE_Routed';

      final paramValues = <List<dynamic>>[];

      // Enable
      paramValues.add(['$basePath.Enable', 'true', 'xsd:boolean']);

      // ConnectionType
      paramValues.add(['$basePath.ConnectionType', params.connectionType, 'xsd:string']);

      // Connection Name
      final typeCode = isBridge ? 'B' : 'R';
      final connName = (params.vlanEnabled && params.vlanId > 0)
          ? '${wanIdx}_INTERNET_${typeCode}_VID_${params.vlanId}'
          : '${wanIdx}_INTERNET_${typeCode}_VID_';
      paramValues.add(['$basePath.Name', connName, 'xsd:string']);

      // PPPoE Credentials & NAT
      if (isPppoe) {
        paramValues.add(['$basePath.Username', params.username.trim(), 'xsd:string']);
        if (params.password.isNotEmpty) {
          paramValues.add(['$basePath.Password', params.password, 'xsd:string']);
        }
        paramValues.add(['$basePath.NATEnabled', 'true', 'xsd:boolean']);
        paramValues.add(['$basePath.TransportType', 'PPPoE', 'xsd:string']);
      } else if (isBridge && slotName == 'WANPPPConnection') {
        paramValues.add(['$basePath.NATEnabled', 'false', 'xsd:boolean']);
      }

      // Brand-specific Service List
      if (isZte) {
        paramValues.add(['$basePath.X_CMCC_ServiceList', params.serviceList, 'xsd:string']);
      } else if (isHuawei) {
        paramValues.add(['$basePath.X_HW_SERVICELIST', params.serviceList, 'xsd:string']);
      } else if (isCiot) {
        paramValues.add(['$basePath.X_CT-COM_ServiceList', params.serviceList, 'xsd:string']);
      } else {
        paramValues.add(['$basePath.X_CMCC_ServiceList', params.serviceList, 'xsd:string']);
      }

      // Brand-specific VLAN
      if (params.vlanEnabled && params.vlanId > 0) {
        if (isZte) {
          paramValues.add(['$basePath.X_CMCC_VLANMode', '1', 'xsd:int']);
          paramValues.add(['$basePath.X_CMCC_VLANIDMark', params.vlanId.toString(), 'xsd:int']);
        } else if (isHuawei) {
          paramValues.add(['$basePath.X_HW_VLAN', params.vlanId.toString(), 'xsd:unsignedInt']);
        } else if (isCiot) {
          paramValues.add(['$basePath.X_CT-COM_VlanID', params.vlanId.toString(), 'xsd:int']);
          paramValues.add([
            'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.VLANID',
            params.vlanId.toString(),
            'xsd:int'
          ]);
        } else {
          paramValues.add(['$basePath.X_CMCC_VLANMode', '1', 'xsd:int']);
          paramValues.add(['$basePath.X_CMCC_VLANIDMark', params.vlanId.toString(), 'xsd:int']);
        }
      } else {
        if (isZte) {
          paramValues.add(['$basePath.X_CMCC_VLANMode', '0', 'xsd:int']);
          paramValues.add(['$basePath.X_CMCC_VLANIDMark', '0', 'xsd:int']);
        } else if (isHuawei) {
          paramValues.add(['$basePath.X_HW_VLAN', '0', 'xsd:unsignedInt']);
        }
      }

      // Brand-specific Port Binding
      final lanList = <String>[];
      final hwLanList = <String>[];

      if (params.bindLan1) {
        lanList.add('InternetGatewayDevice.LANDevice.1.LANEthernetInterfaceConfig.1');
        hwLanList.add('Lan1');
      }
      if (params.bindLan2) {
        lanList.add('InternetGatewayDevice.LANDevice.1.LANEthernetInterfaceConfig.2');
        hwLanList.add('Lan2');
      }
      if (params.bindLan3) {
        lanList.add('InternetGatewayDevice.LANDevice.1.LANEthernetInterfaceConfig.3');
        hwLanList.add('Lan3');
      }
      if (params.bindLan4) {
        lanList.add('InternetGatewayDevice.LANDevice.1.LANEthernetInterfaceConfig.4');
        hwLanList.add('Lan4');
      }
      if (params.bindWlan1) {
        lanList.add('InternetGatewayDevice.LANDevice.1.WLANConfiguration.1');
        hwLanList.add('SSID1');
      }
      if (params.bindWlan2) {
        lanList.add('InternetGatewayDevice.LANDevice.1.WLANConfiguration.2');
        hwLanList.add('SSID2');
      }
      if (params.bindWlan3) {
        lanList.add('InternetGatewayDevice.LANDevice.1.WLANConfiguration.3');
        hwLanList.add('SSID3');
      }
      if (params.bindWlan4) {
        lanList.add('InternetGatewayDevice.LANDevice.1.WLANConfiguration.4');
        hwLanList.add('SSID4');
      }

      if (lanList.isNotEmpty) {
        if (isHuawei) {
          paramValues.add(['$basePath.X_HW_LANInterface', hwLanList.join(','), 'xsd:string']);
        } else if (isCiot) {
          paramValues.add(['$basePath.X_CT-COM_LanInterface', lanList.join(','), 'xsd:string']);
        } else {
          paramValues.add(['$basePath.X_CMCC_LanInterface', lanList.join(','), 'xsd:string']);
        }
      }

      final encId = Uri.encodeComponent(deviceId);
      final res = await _dio.post(
        '/devices/$encId/tasks',
        queryParameters: {'connection_request': ''},
        data: jsonEncode({
          'name': 'setParameterValues',
          'parameterValues': paramValues,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 202) {
        return 'Konfigurasi WAN berhasil dikirim ke antrian TR-069 modem!';
      }
      throw Exception('Gagal mengirim konfigurasi WAN (HTTP ${res.statusCode})');
    } catch (e) {
      throw Exception('Gagal konfigurasi WAN: $e');
    }
  }

  /// Reboot ONU remotely via TR-069
  Future<bool> rebootDevice(String deviceId) async {
    try {
      final encId = Uri.encodeComponent(deviceId);
      final res = await _dio.post(
        '/devices/$encId/tasks',
        queryParameters: {'connection_request': ''},
        data: jsonEncode({'name': 'reboot'}),
      );
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (e) {
      throw Exception('Gagal me-reboot perangkat: $e');
    }
  }

  /// Summon / Refresh device via TR-069
  Future<bool> refreshDevice(String deviceId) async {
    try {
      final encId = Uri.encodeComponent(deviceId);
      final res = await _dio.post(
        '/devices/$encId/tasks',
        queryParameters: {'connection_request': ''},
        data: jsonEncode({
          'name': 'refreshObject',
          'objectName': '',
        }),
      );
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (e) {
      throw Exception('Gagal me-refresh perangkat: $e');
    }
  }

  /// Add Tag to Device
  Future<bool> addTag(String deviceId, String tag) async {
    try {
      final encId = Uri.encodeComponent(deviceId);
      final encTag = Uri.encodeComponent(tag);
      final res = await _dio.put('/devices/$encId/tags/$encTag');
      return res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Remove Tag from Device
  Future<bool> removeTag(String deviceId, String tag) async {
    try {
      final encId = Uri.encodeComponent(deviceId);
      final encTag = Uri.encodeComponent(tag);
      final res = await _dio.delete('/devices/$encId/tags/$encTag');
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Save Device GPS Location & ODP Info as TR-069 Tags
  Future<bool> saveDeviceLocation({
    required String deviceId,
    required List<String> currentTags,
    required double lat,
    required double lng,
    String? odpName,
    double? odpLat,
    double? odpLng,
  }) async {
    try {
      // 1. Remove old LOC tags
      final oldLocTags = currentTags.where((t) {
        final u = t.toUpperCase();
        return u.startsWith('LOC:') || u.startsWith('LOC_') || u.startsWith('LOC-');
      }).toList();
      for (var t in oldLocTags) {
        await removeTag(deviceId, t);
      }

      // 2. Add new LOC tag using micro-degrees integer (LOC_${latE6}_${lngE6})
      final latE6 = (lat * 1000000).round();
      final lngE6 = (lng * 1000000).round();
      final newLocTag = 'LOC_${latE6}_$lngE6';
      final locOk = await addTag(deviceId, newLocTag);
      if (!locOk) return false;

      // 3. Handle ODP tags
      final oldOdpTags = currentTags.where((t) {
        final u = t.toUpperCase();
        return u.startsWith('ODP:') || u.startsWith('ODP_') || u.startsWith('ODP-');
      }).toList();
      for (var t in oldOdpTags) {
        await removeTag(deviceId, t);
      }

      if (odpName != null && odpName.trim().isNotEmpty) {
        final cleanOdp = odpName.trim().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
        final String newOdpTag;
        if (odpLat != null && odpLng != null && odpLat != 0.0 && odpLng != 0.0) {
          final oLatE6 = (odpLat * 1000000).round();
          final oLngE6 = (odpLng * 1000000).round();
          newOdpTag = 'ODP_${cleanOdp}_${oLatE6}_$oLngE6';
        } else {
          newOdpTag = 'ODP_$cleanOdp';
        }
        await addTag(deviceId, newOdpTag);
      }

      return true;
    } catch (e) {
      throw Exception('Gagal menyimpan lokasi perangkat: $e');
    }
  }

  /// Remove Device GPS Location & ODP Tags
  Future<bool> removeDeviceLocation(String deviceId, List<String> currentTags) async {
    try {
      final geoTags = currentTags.where((t) {
        final u = t.toUpperCase();
        return u.startsWith('LOC') || u.startsWith('ODP');
      }).toList();
      for (var t in geoTags) {
        await removeTag(deviceId, t);
      }
      return true;
    } catch (e) {
      throw Exception('Gagal menghapus lokasi perangkat: $e');
    }
  }

  /// Commit WiFi SSID & Password via setParameterValues
  Future<bool> commitWifi({
    required String deviceId,
    required int wlanIndex,
    required String ssid,
    required String password,
  }) async {
    try {
      final encId = Uri.encodeComponent(deviceId);
      final paramValues = <List<dynamic>>[];

      if (ssid.trim().isNotEmpty) {
        paramValues.add([
          'InternetGatewayDevice.LANDevice.1.WLANConfiguration.$wlanIndex.SSID',
          ssid.trim(),
          'xsd:string'
        ]);
        if (wlanIndex == 1) {
          paramValues.add(['VirtualParameters.WlanSSID', ssid.trim(), 'xsd:string']);
        }
      }

      if (password.trim().isNotEmpty) {
        paramValues.add([
          'InternetGatewayDevice.LANDevice.1.WLANConfiguration.$wlanIndex.PreSharedKey.1.KeyPassphrase',
          password.trim(),
          'xsd:string'
        ]);
        paramValues.add([
          'InternetGatewayDevice.LANDevice.1.WLANConfiguration.$wlanIndex.KeyPassphrase',
          password.trim(),
          'xsd:string'
        ]);
        if (wlanIndex == 1) {
          paramValues.add(['VirtualParameters.WlanPassword', password.trim(), 'xsd:string']);
        }
      }

      final res = await _dio.post(
        '/devices/$encId/tasks',
        queryParameters: {'connection_request': ''},
        data: jsonEncode({
          'name': 'setParameterValues',
          'parameterValues': paramValues,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (e) {
      throw Exception('Gagal memperbarui konfigurasi WiFi: $e');
    }
  }

  /// Set Admin account credentials (Web GUI) via TR-069 and VirtualParameters
  Future<bool> setAdminAccount(
    String deviceId,
    String username,
    String password, {
    String manufacturer = '',
  }) async {
    try {
      final encId = Uri.encodeComponent(deviceId);
      final mfgLower = manufacturer.toLowerCase();
      final idLower = deviceId.toLowerCase();
      final isZte = mfgLower.contains('zte') || idLower.contains('zte') || mfgLower.contains('zicg') || mfgLower.contains('rteg');
      final isHuawei = mfgLower.contains('huawei') || idLower.contains('hwtc') || idLower.contains('hg8');

      final paramValues = <dynamic>[
        // Universal VirtualParameters
        if (username.trim().isNotEmpty)
          ['VirtualParameters.superAdmin', username.trim(), 'xsd:string'],
        if (password.trim().isNotEmpty)
          ['VirtualParameters.superPassword', password.trim(), 'xsd:string'],
      ];

      // Direct vendor specific hardware paths
      if (isZte) {
        paramValues.addAll([
          ['InternetGatewayDevice.DeviceInfo.X_CMCC_TeleComAccount.Enable', 'true', 'xsd:boolean'],
          if (username.trim().isNotEmpty)
            ['InternetGatewayDevice.DeviceInfo.X_CMCC_TeleComAccount.Username', username.trim(), 'xsd:string'],
          if (password.trim().isNotEmpty)
            ['InternetGatewayDevice.DeviceInfo.X_CMCC_TeleComAccount.Password', password.trim(), 'xsd:string'],
          if (username.trim().isNotEmpty)
            ['InternetGatewayDevice.UserInterface.X_ZTE-COM_WebUserInfo.AdminName', username.trim(), 'xsd:string'],
          if (password.trim().isNotEmpty)
            ['InternetGatewayDevice.UserInterface.X_ZTE-COM_WebUserInfo.AdminPassword', password.trim(), 'xsd:string'],
        ]);
      } else if (isHuawei) {
        if (username.trim().isNotEmpty) {
          paramValues.add(['InternetGatewayDevice.UserInterface.X_HW_WebUserInfo.2.UserName', username.trim(), 'xsd:string']);
        }
        if (password.trim().isNotEmpty) {
          paramValues.add(['InternetGatewayDevice.UserInterface.X_HW_WebUserInfo.2.Password', password.trim(), 'xsd:string']);
        }
      }

      final res = await _dio.post(
        '/devices/$encId/tasks',
        queryParameters: {'connection_request': ''},
        data: jsonEncode({
          'name': 'setParameterValues',
          'parameterValues': paramValues,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (e) {
      throw Exception('Gagal memperbarui akun administrator: $e');
    }
  }

  DeviceDetail _parseDeviceDetail(String id, Map<String, dynamic> doc) {
    final devId = doc['_deviceId'] as Map<String, dynamic>?;
    final manufacturer = devId?['_Manufacturer']?.toString() ?? 'Unknown';
    final productClass = devId?['_ProductClass']?.toString() ?? 'Modem';
    final serialNumber = devId?['_SerialNumber']?.toString() ?? id;

    // 1. Flatten entire JSON for deep scanning
    final flatParams = <String, String>{};
    _flattenJson(doc, '', flatParams);

    // 2. Collect ALL 39 Universal VirtualParameters reported by the server
    final allVps = <String, String>{};
    final vpObj = doc['VirtualParameters'] as Map<String, dynamic>? ?? {};
    for (final entry in vpObj.entries) {
      final k = entry.key;
      final val = entry.value;
      if (val is Map && val.containsKey('_value')) {
        final v = val['_value'];
        if (v != null) allVps[k] = v.toString().trim();
      } else if (val != null) {
        allVps[k] = val.toString().trim();
      }
    }
    // Also include any flat VirtualParameters.*
    for (final entry in flatParams.entries) {
      if (entry.key.startsWith('VirtualParameters.')) {
        final vpName = entry.key.substring('VirtualParameters.'.length);
        if (!allVps.containsKey(vpName) && entry.value.trim().isNotEmpty) {
          allVps[vpName] = entry.value.trim();
        }
      }
    }

    String? findVp(List<String> keys, [List<String>? trFallback]) {
      for (final k in keys) {
        if (allVps.containsKey(k) && allVps[k]!.isNotEmpty) {
          return allVps[k];
        }
      }
      if (trFallback != null) {
        for (final p in trFallback) {
          if (flatParams.containsKey(p) && flatParams[p]!.isNotEmpty) {
            return flatParams[p];
          }
        }
      }
      return null;
    }

    // PPPoE Username
    final pppUser = findVp(
      ['pppoeUsername', 'pppUsername', 'pppoeUsername2', 'pppoe_username', 'Username', 'username', 'getpppoeuser', 'pppoeUser', 'user_pppoe', 'wan_username', 'PPPoE'],
      [
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.Username',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.2.Username',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.2.WANPPPConnection.1.Username',
        'Device.PPP.Interface.1.Username',
      ],
    ) ?? '-';

    // IP Address (WAN / PPPoE / TR-069)
    final pppIp = findVp(
      ['pppIP', 'pppoeIP', 'WanIP', 'IPTR069', 'wan_ip'],
      [
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.ExternalIPAddress',
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress',
      ],
    ) ?? '-';

    // MAC Address
    final mac = findVp(
      ['MacAddress', 'PonMac', 'pppoeMac', 'WanMac'],
      [
        'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.MACAddress',
        'InternetGatewayDevice.LANDevice.1.LANHostConfigManagement.MACAddress',
      ],
    ) ?? '-';

    // Uptime
    final uptime = findVp(
      ['uptimeDevice', 'getdeviceuptime', 'getpppuptime', 'uptime', 'UpTime'],
      ['InternetGatewayDevice.DeviceInfo.UpTime', 'Device.DeviceInfo.UpTime'],
    ) ?? '-';

    // PON Mode
    final ponModeRaw = findVp(
      ['getponmode', 'PonMode', 'pon_mode', 'getaccesstype', 'AccessType'],
      ['InternetGatewayDevice.WANDevice.1.WANCommonInterfaceConfig.WANAccessType'],
    );
    final ponMode = (ponModeRaw?.toUpperCase().contains('EPON') == true)
        ? 'EPON'
        : ((ponModeRaw?.toUpperCase().contains('GPON') == true || productClass.toUpperCase().contains('GPON'))
            ? 'GPON'
            : (ponModeRaw?.isNotEmpty == true ? ponModeRaw! : 'GPON'));

    // Temperature
    final tempStr = findVp(['gettemp', 'temp', 'temperature']);
    final tempVal = int.tryParse(tempStr ?? '');

    // Optical RX Power
    final rxRaw = findVp(
      ['RXPower', 'redaman', 'rxPower', 'opticalPower', 'RxOpticalPower'],
      [
        'InternetGatewayDevice.WANDevice.1.WANOFTCommonInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.WANOFTCommonInterfaceConfig.OpticalRxPower',
        'InternetGatewayDevice.WANDevice.1.X_CT-COM_GponInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_ZTE-COM_WANPONInterfaceConfig.RxPower',
        'InternetGatewayDevice.WANDevice.1.X_HW_PONInterfaceConfig.RxPower',
      ],
    );
    final rx = OpticalPowerParser.parse(rxRaw);

    // Optical TX Power
    final txRaw = findVp(
      ['TXPower', 'txPower', 'OpticalTxPower'],
      ['InternetGatewayDevice.WANDevice.1.WANOFTCommonInterfaceConfig.TxPower'],
    );
    final tx = OpticalPowerParser.parse(txRaw);

    // Admin Credentials
    final adminUser = findVp(
      ['superAdmin', 'userAdmin', 'adminUser'],
      [
        'InternetGatewayDevice.DeviceInfo.X_CMCC_TeleComAccount.Username',
        'InternetGatewayDevice.UserInterface.X_HW_WebUserInfo.2.UserName',
        'InternetGatewayDevice.DeviceInfo.X_CT-COM_TeleComAccount.Username',
        'InternetGatewayDevice.UserInterface.X_ZTE-COM_WebUserInfo.AdminName',
      ],
    ) ?? 'admin';

    final adminPassword = findVp(
      ['superPassword', 'userPassword', 'adminPassword'],
      [
        'InternetGatewayDevice.DeviceInfo.X_CMCC_TeleComAccount.Password',
        'InternetGatewayDevice.UserInterface.X_HW_WebUserInfo.2.Password',
        'InternetGatewayDevice.DeviceInfo.X_CT-COM_TeleComAccount.Password',
        'InternetGatewayDevice.UserInterface.X_ZTE-COM_WebUserInfo.AdminPassword',
      ],
    ) ?? 'admin';

    // VLAN ID
    final vlanId = findVp(['VlanID', 'vlan', 'Vlan']);

    // Active Devices
    final activeRaw = findVp(['activedevices', 'userconnected', 'getAssociation', 'TotalAssociations']);
    final activeCount = int.tryParse(activeRaw ?? '0') ?? 0;

    // 3. Dynamic WLAN instance discovery (e.g. SSID 1 2.4G, SSID 5 5G)
    final wlanIndices = <int>{};
    for (final k in flatParams.keys) {
      if (k.contains('LANDevice.1.WLANConfiguration.')) {
        final parts = k.split('.');
        final idxPos = parts.indexOf('WLANConfiguration');
        if (idxPos != -1 && idxPos + 1 < parts.length) {
          final parsed = int.tryParse(parts[idxPos + 1]);
          if (parsed != null) wlanIndices.add(parsed);
        }
      }
    }
    if (wlanIndices.isEmpty) {
      wlanIndices.add(1);
    }
    final sortedIndices = wlanIndices.toList()..sort();
    final wlans = <WlanInstance>[];

    for (final wIdx in sortedIndices) {
      final prefix = 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.$wIdx.';
      final wSsid = flatParams['${prefix}SSID'] ??
          (wIdx == 1 ? (allVps['WlanSSID'] ?? allVps['SSID'] ?? 'WiFi-Pelanggan') : '');
      final wPass = flatParams['${prefix}PreSharedKey.1.KeyPassphrase'] ??
          flatParams['${prefix}KeyPassphrase'] ??
          (wIdx == 1 ? (allVps['WlanPassword'] ?? allVps['Password'] ?? '') : '');
      final enableVal = flatParams['${prefix}Enable'] ?? 'true';
      final isEnabled = enableVal.toLowerCase() == 'true' || enableVal == '1';
      final beacon = flatParams['${prefix}BeaconType'] ?? 'WPA2-PSK';
      final ssidAd = flatParams['${prefix}SSIDAdvertisementEnabled'];
      final isHidden = ssidAd?.toLowerCase() == 'false' || ssidAd == '0';
      final bandLabel = wIdx <= 4 ? '2.4G' : '5G';

      wlans.add(WlanInstance(
        index: wIdx,
        label: 'SSID $wIdx ($bandLabel)',
        ssid: wSsid.isNotEmpty ? wSsid : 'SSID $wIdx',
        password: wPass,
        isEnabled: isEnabled,
        isHidden: isHidden,
        securityMode: beacon,
        path: 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.$wIdx',
      ));
    }

    // 4. Extract Connected Clients
    final clients = <ConnectedClient>[];
    final hostIndices = <String>{};
    for (final k in flatParams.keys) {
      if (k.contains('Hosts.Host.') || k.contains('AssociatedDevice.')) {
        final parts = k.split('.');
        final idxPos = parts.indexWhere((p) => p == 'Host' || p == 'AssociatedDevice');
        if (idxPos != -1 && idxPos + 1 < parts.length) {
          hostIndices.add(parts[idxPos + 1]);
        }
      }
    }
    for (final idx in hostIndices) {
      final name = flatParams.entries.firstWhere(
        (e) => e.key.contains('.Host.$idx.HostName') || e.key.contains('AssociatedDevice.$idx.AssociatedDeviceAuthenticationState'),
        orElse: () => MapEntry('', 'Perangkat #$idx'),
      ).value;
      final cIp = flatParams.entries.firstWhere(
        (e) => e.key.contains('.Host.$idx.IPAddress') || e.key.contains('AssociatedDevice.$idx.AssociatedDeviceIPAddress'),
        orElse: () => const MapEntry('', '-'),
      ).value;
      final cMac = flatParams.entries.firstWhere(
        (e) => e.key.contains('.Host.$idx.MACAddress') || e.key.contains('AssociatedDevice.$idx.AssociatedDeviceMACAddress'),
        orElse: () => const MapEntry('', '-'),
      ).value;
      if (cIp != '-' || cMac != '-') {
        clients.add(ConnectedClient(hostName: name, ipAddress: cIp, macAddress: cMac));
      }
    }

    // 5. Extract WAN Connection List
    final wanList = <WanItem>[];
    for (int connDev = 1; connDev <= 4; connDev++) {
      for (var type in ['WANPPPConnection', 'WANIPConnection']) {
        for (int inst = 1; inst <= 4; inst++) {
          final prefix = 'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.$connDev.$type.$inst.';
          final name = flatParams['${prefix}Name'] ??
              flatParams['${prefix}X_CMCC_VLANName'] ??
              (flatParams.containsKey('${prefix}Enable') ? '$type $connDev-$inst' : null);

          if (name != null) {
            final connType = flatParams['${prefix}ConnectionType'] ??
                (type == 'WANPPPConnection' ? 'PPPoE_Routed' : 'IP_Routed');
            final user = flatParams['${prefix}Username'] ?? '';
            final isEnabled = flatParams['${prefix}Enable'] == 'true' || flatParams['${prefix}Enable'] == '1';
            final status = flatParams['${prefix}ConnectionStatus'] ?? 'Connected';
            final ip = flatParams['${prefix}ExternalIPAddress'] ?? '-';
            final vlan = int.tryParse(flatParams['${prefix}X_CMCC_VLANIDMark'] ??
                flatParams['${prefix}X_HW_VLAN'] ??
                flatParams['${prefix}X_CT-COM_VlanID'] ??
                flatParams['${prefix}VLANID'] ??
                '');

            wanList.add(WanItem(
              instanceIndex: inst,
              name: name,
              connectionType: connType,
              username: user,
              isEnabled: isEnabled,
              ipAddress: ip,
              status: status,
              vlanId: vlan,
            ));
          }
        }
      }
    }

    // If no WANs discovered from flatParams, fallback to default WAN 1
    if (wanList.isEmpty) {
      wanList.add(WanItem(
        instanceIndex: 1,
        name: 'WAN 1 (Default)',
        connectionType: 'PPPoE_Routed',
        username: pppUser,
        isEnabled: true,
        ipAddress: pppIp,
        status: pppIp != '-' ? 'Connected' : 'Disconnected',
        vlanId: int.tryParse(vlanId ?? ''),
      ));
    }

    // 6. Tags & Geo parsing
    final rawTags = doc['_tags'];
    final List<String> tags = [];
    if (rawTags is List) {
      for (var t in rawTags) {
        if (t != null) tags.add(t.toString().trim());
      }
    }

    double? latitude;
    double? longitude;
    String? odp;
    double? odpLatitude;
    double? odpLongitude;

    for (var t in tags) {
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

    return DeviceDetail(
      id: id,
      serialNumber: serialNumber,
      productClass: productClass,
      manufacturer: manufacturer,
      lastInform: doc['_lastInform']?.toString() ?? '-',
      isOnline: true,
      pppoeUser: pppUser,
      pppoeIp: pppIp,
      macAddress: mac,
      rxPower: rx,
      txPower: tx,
      temp: tempVal,
      uptime: uptime,
      ponMode: ponMode,
      adminUser: adminUser,
      adminPassword: adminPassword,
      vlanId: vlanId,
      activeDevices: activeCount,
      connectedClients: clients,
      wlans: wlans,
      wanList: wanList,
      tags: tags,
      rawParameters: doc,
      virtualParameters: allVps,
      lat: latitude,
      lng: longitude,
      odpName: odp,
      odpLat: odpLatitude,
      odpLng: odpLongitude,
    );
  }

  void _flattenJson(dynamic element, String path, Map<String, String> target) {
    if (element is Map) {
      if (element.containsKey('_value') && element['_value'] != null) {
        target[path] = element['_value'].toString();
      }
      for (var entry in element.entries) {
        final key = entry.key.toString();
        if (key.startsWith('_') && key != '_value') continue;
        final subPath = path.isEmpty ? key : '$path.$key';
        _flattenJson(entry.value, subPath, target);
      }
    }
  }
}
