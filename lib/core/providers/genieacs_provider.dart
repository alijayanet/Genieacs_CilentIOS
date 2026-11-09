import 'package:flutter/foundation.dart';
import '../../core/utils/optical_power_parser.dart';
import '../../data/models/device_detail.dart';
import '../../data/models/device_item.dart';
import '../../data/models/wan_models.dart';
import '../../data/services/genieacs_service.dart';
import 'server_config_provider.dart';

enum DeviceFilter {
  all,
  online,
  offline,
  criticalSignal,
  warningSignal,
  idealSignal,
}

class GenieAcsProvider extends ChangeNotifier {
  final ServerConfigProvider _config;
  late GenieAcsService _service;

  List<DeviceItem> _allDevices = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  DeviceFilter _activeFilter = DeviceFilter.all;
  String? _vendorFilter;

  List<DeviceItem> get devices => _allDevices;
  List<DeviceItem> get allDevices => _allDevices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  DeviceFilter get activeFilter => _activeFilter;
  String? get vendorFilter => _vendorFilter;

  // Counts
  int get totalCount => _allDevices.length;
  int get onlineCount => _allDevices.where((d) => d.isOnline).length;
  int get offlineCount => _allDevices.where((d) => !d.isOnline).length;
  int get idealSignalCount => _allDevices.where((d) => d.signalQuality == SignalQuality.ideal).length;
  int get warningSignalCount => _allDevices.where((d) => d.signalQuality == SignalQuality.warning).length;
  int get criticalSignalCount => _allDevices.where((d) => d.signalQuality == SignalQuality.critical).length;

  List<String> get availableVendors {
    final set = <String>{};
    for (var d in _allDevices) {
      if (d.manufacturer.isNotEmpty && d.manufacturer != 'Unknown') {
        set.add(d.manufacturer);
      }
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  GenieAcsProvider(this._config) {
    _initService();
  }

  void _initService() {
    _service = GenieAcsService(
      baseUrl: _config.genieAcsUrl,
      username: _config.genieAcsUser,
      password: _config.genieAcsPass,
    );
  }

  void updateConfig(ServerConfigProvider newConfig) {
    _initService();
    fetchDevices();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(DeviceFilter filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void setVendorFilter(String? vendor) {
    _vendorFilter = vendor;
    notifyListeners();
  }

  List<DeviceItem> get filteredDevices {
    return _allDevices.where((device) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchPpp = device.pppoeUsername.toLowerCase().contains(q);
        final matchCust = device.customerName.toLowerCase().contains(q);
        final matchSn = device.serialNumber.toLowerCase().contains(q);
        final matchSsid = device.ssid.toLowerCase().contains(q);
        final matchOdp = (device.odpName ?? '').toLowerCase().contains(q);
        final matchProd = device.productClass.toLowerCase().contains(q);
        final matchIp = (device.ip ?? '').toLowerCase().contains(q);

        if (!matchPpp && !matchCust && !matchSn && !matchSsid && !matchOdp && !matchProd && !matchIp) {
          return false;
        }
      }

      // 2. Status & Signal Filter
      switch (_activeFilter) {
        case DeviceFilter.all:
          break;
        case DeviceFilter.online:
          if (!device.isOnline) return false;
          break;
        case DeviceFilter.offline:
          if (device.isOnline) return false;
          break;
        case DeviceFilter.criticalSignal:
          if (device.signalQuality != SignalQuality.critical) return false;
          break;
        case DeviceFilter.warningSignal:
          if (device.signalQuality != SignalQuality.warning) return false;
          break;
        case DeviceFilter.idealSignal:
          if (device.signalQuality != SignalQuality.ideal) return false;
          break;
      }

      // 3. Vendor Filter
      if (_vendorFilter != null && _vendorFilter != 'ALL') {
        if (!device.manufacturer.toLowerCase().contains(_vendorFilter!.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> fetchDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _initService(); // ensure latest credentials used
      _allDevices = await _service.getDevices();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<DeviceDetail?> fetchDeviceDetail(String deviceId) async {
    try {
      _initService();
      return await _service.getDeviceDetail(deviceId);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> rebootDevice(String deviceId) async {
    try {
      _initService();
      return await _service.rebootDevice(deviceId);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> refreshDevice(String deviceId) async {
    try {
      _initService();
      return await _service.refreshDevice(deviceId);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> commitWifiConfig({
    required String deviceId,
    required String newSsid,
    required String newPassword,
    String? wlanPath,
  }) async {
    try {
      _initService();
      final success = await _service.commitWifi(
        deviceId: deviceId,
        wlanIndex: 1,
        ssid: newSsid,
        password: newPassword,
      );
      if (success) {
        // Refresh local device list
        fetchDevices();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Login and authenticate against GenieACS (validates users collection / web UI)
  Future<bool> login({
    required String url,
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authService = GenieAcsService(
        baseUrl: url,
        username: username,
        password: password,
      );

      final success = await authService.authenticate(username, password);
      if (success) {
        await _config.saveGenieAcsConfig(
          url: url,
          user: username,
          pass: password,
        );
        await _config.setLoggedIn(true);
        _initService();
        _isLoading = false;
        notifyListeners();
        // Prefetch devices in background
        fetchDevices();
        return true;
      } else {
        throw Exception('Kredensial tidak valid');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Configure WAN (Add new instance or update existing WAN)
  Future<String> configureWan({
    required String deviceId,
    required WanConfigParams params,
  }) async {
    try {
      _initService();
      final message = await _service.configureWan(deviceId, params);
      // Refresh devices list & detail
      fetchDevices();
      return message;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Save Device GPS Location & ODP Info
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
      _initService();
      final ok = await _service.saveDeviceLocation(
        deviceId: deviceId,
        currentTags: currentTags,
        lat: lat,
        lng: lng,
        odpName: odpName,
        odpLat: odpLat,
        odpLng: odpLng,
      );
      if (ok) {
        fetchDevices();
      }
      return ok;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Remove Device GPS Location & ODP Tags
  Future<bool> removeDeviceLocation(String deviceId, List<String> currentTags) async {
    try {
      _initService();
      final ok = await _service.removeDeviceLocation(deviceId, currentTags);
      if (ok) {
        fetchDevices();
      }
      return ok;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Summon Device (Send Connection Request via TR-069)
  Future<bool> summonDevice(String deviceId) async {
    try {
      _initService();
      final ok = await _service.refreshDevice(deviceId);
      if (ok) {
        fetchDevices();
      }
      return ok;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Update Web GUI Admin Credentials via TR-069
  Future<bool> setAdminAccount({
    required String deviceId,
    required String username,
    required String password,
    String manufacturer = '',
  }) async {
    try {
      _initService();
      final ok = await _service.setAdminAccount(
        deviceId,
        username,
        password,
        manufacturer: manufacturer,
      );
      if (ok) {
        fetchDevices();
      }
      return ok;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
