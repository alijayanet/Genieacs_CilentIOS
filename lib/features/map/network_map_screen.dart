import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/genieacs_provider.dart';
import '../../core/providers/server_config_provider.dart';
import '../../data/models/device_item.dart';
import '../genieacs/device_detail_screen.dart';

class NetworkMapScreen extends StatefulWidget {
  final String? focusDeviceId;
  final bool showBackButton;

  const NetworkMapScreen({
    super.key,
    this.focusDeviceId,
    this.showBackButton = false,
  });

  @override
  State<NetworkMapScreen> createState() => _NetworkMapScreenState();
}

class _NetworkMapScreenState extends State<NetworkMapScreen> {
  late final WebViewController _controller;
  bool _isMapLoaded = false;
  bool _isLoadingDevices = false;
  String? _pendingFocusDeviceId;
  String _desktopSearchQuery = '';

  bool get _isWindowsDesktop => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _pendingFocusDeviceId = widget.focusDeviceId;
    if (!_isWindowsDesktop) {
      _initWebView();
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.backgroundDark)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isMapLoaded = true;
            });
            _pushDevicesToMap();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Map WebView Error: ${error.description}');
          },
        ),
      )
      ..loadFlutterAsset('assets/map/peta.html');
  }

  void _pushDevicesToMap() {
    if (!_isMapLoaded) return;

    final provider = context.read<GenieAcsProvider>();
    final devices = provider.allDevices;
    final jsonList = devices.map((d) => d.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    // Call JavaScript renderMapDevices
    _controller.runJavaScript('renderMapDevices($jsonString);');

    // Focus on device if requested
    if (_pendingFocusDeviceId != null) {
      final devId = _pendingFocusDeviceId!;
      _pendingFocusDeviceId = null;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _controller.runJavaScript("focusDevice('$devId');");
        }
      });
    }
  }

  Future<void> _refreshMapData() async {
    setState(() {
      _isLoadingDevices = true;
    });

    final provider = context.read<GenieAcsProvider>();
    await provider.fetchDevices();

    if (!mounted) return;
    setState(() {
      _isLoadingDevices = false;
    });

    if (!_isWindowsDesktop) {
      _pushDevicesToMap();
    }
  }

  void _handleBridgeMessage(String rawMessage) async {
    try {
      final Map<String, dynamic> data = jsonDecode(rawMessage);
      final action = data['action']?.toString() ?? '';

      switch (action) {
        case 'openDeviceDetail':
          final deviceId = data['deviceId']?.toString() ?? '';
          final provider = context.read<GenieAcsProvider>();
          final dev = provider.allDevices.firstWhere(
            (d) => d.id == deviceId,
            orElse: () => provider.allDevices.first,
          );
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceDetailScreen(device: dev),
              ),
            );
          }
          break;

        case 'openGoogleMapsRoute':
          final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
          final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
              );
            }
          }
          break;

        case 'saveDeviceLocation':
          final deviceId = data['deviceId']?.toString() ?? '';
          final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
          final odpName = data['odpName']?.toString();
          final odpLat = (data['odpLat'] as num?)?.toDouble();
          final odpLng = (data['odpLng'] as num?)?.toDouble();

          final provider = context.read<GenieAcsProvider>();
          final dev = provider.allDevices.where((d) => d.id == deviceId).firstOrNull;
          final currentTags = dev?.tags ?? [];

          final success = await provider.saveDeviceLocation(
            deviceId: deviceId,
            currentTags: currentTags,
            lat: lat,
            lng: lng,
            odpName: odpName,
            odpLat: odpLat,
            odpLng: odpLng,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: success ? AppColors.signalGood : AppColors.signalBad,
              content: Text(
                success
                    ? '✓ Titik lokasi pelanggan & ODP berhasil disimpan ke GenieACS!'
                    : 'Gagal menyimpan tag lokasi pelanggan.',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          );
          if (success) {
            _refreshMapData();
          }
          break;

        case 'removeDeviceLocation':
          final deviceId = data['deviceId']?.toString() ?? '';
          final provider = context.read<GenieAcsProvider>();
          final dev = provider.allDevices.where((d) => d.id == deviceId).firstOrNull;
          final currentTags = dev?.tags ?? [];

          final success = await provider.removeDeviceLocation(deviceId, currentTags);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: success ? AppColors.signalGood : AppColors.signalBad,
              content: Text(
                success ? 'Titik lokasi pelanggan berhasil dihapus.' : 'Gagal menghapus tag lokasi.',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
          if (success) {
            _refreshMapData();
          }
          break;

        case 'summonDevice':
          final deviceId = data['deviceId']?.toString() ?? '';
          final provider = context.read<GenieAcsProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.accentCyan,
              content: Text('⚡ Mengirim Connection Request (Summon) ke modem...', style: TextStyle(color: Colors.black)),
            ),
          );
          final success = await provider.summonDevice(deviceId);
          if (!mounted) return;
          if (success) {
            Future.delayed(const Duration(seconds: 3), _refreshMapData);
          }
          break;

        case 'requestGps':
          // Set map center or standard location if GPS is called
          _controller.runJavaScript("console.log('GPS requested');");
          break;
      }
    } catch (e) {
      debugPrint('Error handling bridge message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenieAcsProvider>();
    final cfg = context.watch<ServerConfigProvider>();
    final devices = provider.allDevices;
    final total = devices.length;
    final mappedCount = devices.where((d) => d.isMapped).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.map, color: AppColors.accentCyan, size: 20),
                SizedBox(width: 8),
                Text('Peta Jaringan & ODP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            Text(
              'Total: $total ONU | Terpetakan: $mappedCount (${cfg.genieAcsUrl.replaceAll('http://', '')})',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sinkronisasi Peta',
            icon: (_isLoadingDevices || provider.isLoading)
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                  )
                : const Icon(Icons.refresh),
            onPressed: (_isLoadingDevices || provider.isLoading) ? null : _refreshMapData,
          ),
        ],
      ),
      body: _isWindowsDesktop
          ? _buildWindowsDesktopMap(context, provider, devices)
          : SafeArea(
              top: false,
              bottom: true,
              child: Stack(
              children: [
                // WebView Leaflet Map
                WebViewWidget(controller: _controller),

                // Loading Progress Bar
                if (!_isMapLoaded || _isLoadingDevices || provider.isLoading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    ),
                  ),
              ],
            ),
            ),
    );
  }

  Widget _buildWindowsDesktopMap(
    BuildContext context,
    GenieAcsProvider provider,
    List<DeviceItem> devices,
  ) {
    final filtered = devices.where((d) {
      if (_desktopSearchQuery.isEmpty) return true;
      final q = _desktopSearchQuery.toLowerCase();
      return d.displayCustomerOrSerial.toLowerCase().contains(q) ||
          d.pppoeUsername.toLowerCase().contains(q) ||
          (d.odpName?.toLowerCase().contains(q) ?? false) ||
          d.manufacturer.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentCyan.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withOpacity(0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.desktop_windows, color: AppColors.accentCyan, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peta Jaringan & Topologi ODP (Desktop Mode)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Untuk pengalaman navigasi peta layar penuh terbaik di PC, Anda dapat membuka Leaflet Map di Browser default (Chrome / Edge).',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _openMapInDesktopBrowser(devices),
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: const Text(
                    'Buka Peta di Browser',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search Field
          TextField(
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari pelanggan, ODP, atau PPPoE di peta...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.accentCyan),
              filled: true,
              fillColor: AppColors.backgroundCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (q) {
              setState(() {
                _desktopSearchQuery = q;
              });
            },
          ),
          const SizedBox(height: 16),

          // Devices List Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada perangkat yang sesuai.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
                      itemBuilder: (ctx, i) {
                        final d = filtered[i];
                        final hasGps = d.hasGps;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: d.isOnline ? AppColors.signalGood : AppColors.signalBad,
                            child: Icon(
                              d.isOnline ? Icons.wifi : Icons.wifi_off,
                              size: 16,
                              color: Colors.black,
                            ),
                          ),
                          title: Text(
                            d.displayCustomerOrSerial,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'ODP: ${d.odpName ?? "-"} • PPPoE: ${d.pppoeUsername} • GPS: ${hasGps ? "${d.lat!.toStringAsFixed(5)}, ${d.lng!.toStringAsFixed(5)}" : "Belum ada"}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasGps)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.directions, size: 14),
                                  label: const Text('Rute Maps', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accentCyan,
                                    side: const BorderSide(color: AppColors.accentCyan),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () {
                                    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${d.lat},${d.lng}');
                                    launchUrl(url, mode: LaunchMode.externalApplication);
                                  },
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.backgroundElevated,
                                  foregroundColor: AppColors.textPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: d)),
                                  );
                                },
                                child: const Text('Detail', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMapInDesktopBrowser(List<DeviceItem> devices) async {
    try {
      final template = await rootBundle.loadString('assets/map/peta.html');
      final jsonList = devices.map((d) => d.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      final injectedHtml = template.replaceFirst(
        '</body>',
        '''
<script>
  window.addEventListener("DOMContentLoaded", function() {
    setTimeout(function() {
      if (typeof renderMapDevices === "function") {
        renderMapDevices($jsonString);
      }
    }, 800);
  });
</script>
</body>
''',
      );

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/alijaya_peta.html');
      await file.writeAsString(injectedHtml);
      await launchUrl(Uri.file(file.path));
    } catch (e) {
      debugPrint('Error launching desktop browser map: $e');
    }
  }
}
