import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/genieacs_provider.dart';
import '../../../data/models/device_detail.dart';
import '../../../data/models/device_item.dart';
import '../map/network_map_screen.dart';
import 'widgets/add_wan_sheet.dart';
import 'widgets/signal_badge.dart';
import 'widgets/wifi_config_sheet.dart';

class DeviceDetailScreen extends StatefulWidget {
  final DeviceItem device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  DeviceDetail? _detail;
  bool _isLoading = true;
  bool _hideAdminPassword = true;
  String _vpSearchQuery = '';
  bool _showAllVps = false;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
    });

    final provider = context.read<GenieAcsProvider>();
    final res = await provider.fetchDeviceDetail(widget.device.id);

    if (!mounted) return;
    setState(() {
      _detail = res;
      _isLoading = false;
    });
  }

  void _openAddWanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddWanSheet(
        deviceId: widget.device.id,
        deviceModel: widget.device.manufacturer.isNotEmpty
            ? widget.device.manufacturer
            : widget.device.modelName,
        currentPppoeUser: _detail?.pppoeUsername ?? widget.device.pppoeUsername,
        existingWanList: _detail?.wanList ?? [],
        wlanList: _detail?.wlans ?? [],
        onWanConfigured: () {
          _fetchDetail();
        },
      ),
    );
  }

  Future<void> _handleReboot() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: AppColors.signalWarning),
            SizedBox(width: 8),
            Text('Restart Modem?', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          'Perangkat "${widget.device.displayCustomerOrSerial}" akan direstart melalui TR-069. Modem pelanggan akan offline sementara waktu selama proses booting.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.signalWarning, foregroundColor: Colors.black),
            child: const Text('Restart Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<GenieAcsProvider>();
    final ok = await provider.rebootDevice(widget.device.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.signalGood : AppColors.signalBad,
        content: Text(
          ok ? 'Perintah restart berhasil dijadwalkan!' : (provider.errorMessage ?? 'Gagal me-restart modem'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final provider = context.read<GenieAcsProvider>();
    final ok = await provider.refreshDevice(widget.device.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.accentCyan : AppColors.signalBad,
        content: Text(
          ok ? 'Sinkronisasi TR-069 dijadwalkan...' : (provider.errorMessage ?? 'Gagal meminta refresh'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );

    if (ok) {
      Future.delayed(const Duration(seconds: 3), _fetchDetail);
    }
  }

  void _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
      );
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.backgroundCard,
        content: Text('$label berhasil disalin: $value', style: const TextStyle(color: AppColors.accentCyan)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dev = widget.device;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dev.displayCustomerOrSerial,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${dev.manufacturer} ${dev.modelName}',
              style: const TextStyle(fontSize: 11, color: AppColors.accentCyan),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh TR-069',
            icon: const Icon(Icons.sync),
            onPressed: _handleRefresh,
          ),
          IconButton(
            tooltip: 'Reboot Device',
            icon: const Icon(Icons.restart_alt, color: AppColors.signalWarning),
            onPressed: _handleReboot,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.accentCyan),
                  SizedBox(height: 16),
                  Text('Memuat parameter TR-069...', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppColors.accentCyan,
              backgroundColor: AppColors.backgroundCard,
              onRefresh: _fetchDetail,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // Status Header Card
                  _buildHeaderStatusCard(dev),
                  const SizedBox(height: 16),

                  // Redaman & Optical Power Card
                  _buildOpticalCard(dev),
                  const SizedBox(height: 16),

                  // WiFi Info & Edit Card
                  _buildWifiCard(),
                  const SizedBox(height: 16),

                  // Network & WAN Card
                  _buildNetworkCard(dev),
                  const SizedBox(height: 16),

                  // Lokasi & ODP Card
                  _buildLocationCard(dev),
                  const SizedBox(height: 16),

                  // Akun Web GUI Admin Card
                  _buildAdminAccountCard(dev),
                  const SizedBox(height: 16),

                  // Perangkat Klien Terhubung Card
                  _buildConnectedClientsCard(dev),
                  const SizedBox(height: 16),

                  // VirtualParameters Universal Server Card
                  _buildVirtualParametersCard(dev),
                  const SizedBox(height: 16),

                  // Hardware & TR-069 Info
                  _buildHardwareCard(dev),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          border: Border(top: BorderSide(color: AppColors.cardBorder.withOpacity(0.6))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          minimum: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt, color: AppColors.signalWarning, size: 16),
                    label: const Text('Reboot', style: TextStyle(color: AppColors.signalWarning, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.signalWarning, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _handleReboot,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.alt_route, size: 16),
                    label: const Text('Add WAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentEmerald,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _openAddWanSheet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.wifi_password, size: 16),
                    label: const Text('WiFi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => WifiConfigSheet(
                          deviceId: widget.device.id,
                          wlan: _detail?.primaryWlan ??
                              WlanInstance(
                                index: 1,
                                ssid: dev.wlanSsid ?? '',
                                password: dev.wlanPassword ?? '',
                                enabled: true,
                                path: 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1',
                              ),
                          onSuccess: _fetchDetail,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatusCard(DeviceItem dev) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dev.isOnline
                  ? AppColors.signalGood.withOpacity(0.15)
                  : AppColors.signalBad.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.router,
              color: dev.isOnline ? AppColors.signalGood : AppColors.signalBad,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dev.isOnline ? AppColors.signalGood : AppColors.signalBad,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dev.isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: dev.isOnline ? AppColors.signalGood : AppColors.signalBad,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dev.displayCustomerOrSerial,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Last Inform: ${dev.lastInformFormatted}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          SignalBadge(rxPower: dev.opticalRxPower),
        ],
      ),
    );
  }

  Widget _buildOpticalCard(DeviceItem dev) {
    final rx = dev.opticalRxPower;
    final tx = _detail?.txPower;
    final temp = _detail?.temperature ?? dev.temperature;
    final voltage = _detail?.voltage;

    Color powerColor = AppColors.textMuted;
    String powerLabel = 'Tidak Terdeteksi';

    if (rx != null) {
      if (rx >= -24.0) {
        powerColor = AppColors.signalGood;
        powerLabel = 'Kualitas Bagus (Ideal)';
      } else if (rx >= -27.0) {
        powerColor = AppColors.signalWarning;
        powerLabel = 'Kualitas Sedang (Cukup)';
      } else {
        powerColor = AppColors.signalBad;
        powerLabel = 'Kualitas Kritis (Redaman Tinggi)';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Parameter Optik & Kondisi Modem',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                powerLabel,
                style: TextStyle(color: powerColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'RX POWER',
                  value: rx != null ? '${rx.toStringAsFixed(2)} dBm' : '-',
                  color: powerColor,
                  icon: Icons.download,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'TX POWER',
                  value: tx != null ? '${tx.toStringAsFixed(2)} dBm' : 'Auto',
                  color: AppColors.accentCyan,
                  icon: Icons.upload,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'SUHU MODEM',
                  value: temp != null ? '$temp °C' : '-',
                  color: (temp != null && temp > 65) ? AppColors.signalWarning : AppColors.textPrimary,
                  icon: Icons.thermostat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'TEGANGAN',
                  value: voltage != null ? '${voltage.toStringAsFixed(2)} V' : '3.3 V',
                  color: AppColors.textPrimary,
                  icon: Icons.bolt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWifiCard() {
    final wlan = _detail?.primaryWlan;
    final ssid = wlan?.ssid ?? widget.device.wlanSsid ?? '-';
    final pwd = wlan?.password ?? widget.device.wlanPassword ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, color: AppColors.accentEmerald, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Informasi Wi-Fi (WLAN)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentCyan,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Ubah', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => WifiConfigSheet(
                      deviceId: widget.device.id,
                      wlan: wlan ??
                          WlanInstance(
                            index: 1,
                            ssid: widget.device.wlanSsid ?? '',
                            password: widget.device.wlanPassword ?? '',
                            enabled: true,
                            path: 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1',
                          ),
                      onSuccess: _fetchDetail,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            label: 'Nama SSID',
            value: ssid,
            onCopy: () => _copyToClipboard('SSID', ssid),
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildInfoRow(
            label: 'Kata Sandi',
            value: pwd,
            isMonospace: true,
            onCopy: () => _copyToClipboard('Password WiFi', pwd),
          ),
          if (wlan != null) ...[
            const Divider(color: AppColors.cardBorder, height: 16),
            _buildInfoRow(
              label: 'Status Radio',
              value: wlan.enabled ? 'Aktif (Radio ON)' : 'Nonaktif (Radio OFF)',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkCard(DeviceItem dev) {
    final pppUser = _detail?.pppoeUsername ?? dev.pppoeUsername;
    final wanIp = _detail?.wanIp ?? dev.ipWan ?? '-';
    final mac = _detail?.macAddress ?? '-';
    final wanList = _detail?.wanList ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Jaringan & Koneksi WAN',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.alt_route, size: 14, color: AppColors.accentCyan),
                label: const Text('Add WAN', style: TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accentCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openAddWanSheet,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (wanList.isNotEmpty) ...[
            ...wanList.map((wan) {
              final isConnected = wan.status.toLowerCase().contains('connect');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: wan.slot == 'IP'
                                ? AppColors.accentEmerald.withOpacity(0.2)
                                : AppColors.accentCyan.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            wan.connectionType,
                            style: TextStyle(
                              color: wan.slot == 'IP' ? AppColors.accentEmerald : AppColors.accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            wan.name.isNotEmpty ? wan.name : 'WAN #${wan.instanceIndex}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected ? AppColors.signalGood : AppColors.signalBad,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wan.status,
                          style: TextStyle(
                            color: isConnected ? AppColors.signalGood : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (wan.username.isNotEmpty)
                          Text('User: ${wan.username}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontFamily: 'monospace')),
                        if (wan.ip.isNotEmpty && wan.ip != '-')
                          Text('IP: ${wan.ip}',
                              style: const TextStyle(
                                  color: AppColors.accentCyan,
                                  fontSize: 11,
                                  fontFamily: 'monospace')),
                        if (wan.vlanId != null && wan.vlanId! > 0)
                          Text('VLAN: ${wan.vlanId}',
                              style: const TextStyle(
                                  color: AppColors.accentEmerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const Divider(color: AppColors.cardBorder, height: 16),
          ],
          _buildInfoRow(
            label: 'PPPoE Username',
            value: pppUser,
            isMonospace: true,
            onCopy: () => _copyToClipboard('PPPoE User', pppUser),
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildInfoRow(
            label: 'IP WAN',
            value: wanIp,
            isMonospace: true,
            onCopy: () => _copyToClipboard('IP WAN', wanIp),
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildInfoRow(
            label: 'MAC Address',
            value: mac,
            isMonospace: true,
            onCopy: () => _copyToClipboard('MAC Address', mac),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(DeviceItem dev) {
    final odp = dev.odpName;
    final hasGps = dev.hasGps;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: AppColors.signalBad, size: 20),
              SizedBox(width: 8),
              Text(
                'Data ODP & Lokasi Lapangan',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(label: 'ODP Induk', value: odp ?? 'Belum terdata'),
          const Divider(color: AppColors.cardBorder, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Koordinat GPS', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      hasGps ? '${dev.latitude!.toStringAsFixed(6)}, ${dev.longitude!.toStringAsFixed(6)}' : 'Tidak ada tag lokasi',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              if (hasGps)
                ElevatedButton.icon(
                  onPressed: () => _openGoogleMaps(dev.latitude!, dev.longitude!),
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Maps', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan.withOpacity(0.2),
                    foregroundColor: AppColors.accentCyan,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.accentCyan),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => NetworkMapScreen(
                      focusDeviceId: dev.id,
                      showBackButton: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined, size: 16),
              label: Text(
                hasGps ? 'Buka di Peta Jaringan Leaflet' : 'Tandai Lokasi di Peta Jaringan',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasGps ? AppColors.accentCyan.withOpacity(0.15) : AppColors.backgroundElevated,
                foregroundColor: hasGps ? AppColors.accentCyan : AppColors.textSecondary,
                side: BorderSide(color: hasGps ? AppColors.accentCyan : AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccountCard(DeviceItem dev) {
    final adminUser = _detail?.adminUser ?? dev.superAdmin ?? 'admin';
    final adminPass = _detail?.adminPassword ?? dev.superPassword ?? 'admin';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: AppColors.signalWarning, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Akun Web GUI Admin (TR-069)',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 14, color: AppColors.signalWarning),
                label: const Text('Ubah', style: TextStyle(color: AppColors.signalWarning, fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.signalWarning),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showEditAdminDialog(adminUser, adminPass),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            label: 'Username Admin',
            value: adminUser,
            isMonospace: true,
            onCopy: () => _copyToClipboard('Username Admin', adminUser),
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Password Admin', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              Row(
                children: [
                  Text(
                    _hideAdminPassword ? '••••••••' : adminPass,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _hideAdminPassword = !_hideAdminPassword;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _hideAdminPassword ? Icons.visibility_off : Icons.visibility,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _copyToClipboard('Password Admin', adminPass),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy, size: 14, color: AppColors.accentCyan),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditAdminDialog(String currentUser, String currentPass) {
    final userCtrl = TextEditingController(text: currentUser);
    final passCtrl = TextEditingController(text: currentPass);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          return AlertDialog(
            backgroundColor: AppColors.backgroundCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            title: const Row(
              children: [
                Icon(Icons.security, color: AppColors.signalWarning, size: 20),
                SizedBox(width: 8),
                Text('Ubah Akun Admin ONU', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perbarui akun login Web GUI (superAdmin & superPassword) via TR-069:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: userCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'Username Baru',
                    labelStyle: TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.backgroundElevated,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'Password Baru',
                    labelStyle: TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.backgroundElevated,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dlgContext),
                child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final u = userCtrl.text.trim();
                        final p = passCtrl.text.trim();
                        if (u.isEmpty || p.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Username dan Password tidak boleh kosong')),
                          );
                          return;
                        }
                        setDlgState(() => isSaving = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(dlgContext);
                        final provider = context.read<GenieAcsProvider>();
                        final ok = await provider.setAdminAccount(
                          deviceId: widget.device.id,
                          username: u,
                          password: p,
                          manufacturer: widget.device.manufacturer,
                        );
                        if (!mounted) return;
                        nav.pop();
                        if (ok) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Akun Admin berhasil diperbarui ke modem!')),
                          );
                          _fetchDetail();
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Gagal mengirim konfigurasi akun admin.')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.signalWarning,
                  foregroundColor: Colors.black,
                ),
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectedClientsCard(DeviceItem dev) {
    final clients = _detail?.connectedClients ?? [];
    final activeCount = _detail?.activeDevices ?? dev.activeDevices;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Perangkat Klien Terhubung (${clients.isNotEmpty ? clients.length : activeCount})',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (clients.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeCount > 0
                          ? '$activeCount perangkat aktif terhubung via WiFi/LAN (Detail host belum ter-query).'
                          : 'Tidak ada perangkat aktif yang terhubung pada LAN/WiFi saat ini.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...clients.map((c) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, size: 20, color: AppColors.accentCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.hostName.isNotEmpty ? c.hostName : 'Klien Tanpa Nama',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'IP: ${c.ipAddress} • MAC: ${c.macAddress}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
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
  }

  Widget _buildVirtualParametersCard(DeviceItem dev) {
    final vps = _detail?.virtualParameters ?? {};
    final entries = vps.entries.where((e) {
      if (_vpSearchQuery.isEmpty) return true;
      final q = _vpSearchQuery.toLowerCase();
      return e.key.toLowerCase().contains(q) || e.value.toLowerCase().contains(q);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns, color: AppColors.accentEmerald, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parameter Virtual Universal (${vps.length} Terdata)',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'ZTE, Huawei, CIOT, FiberHome, dsb.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _showAllVps ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.accentEmerald,
                ),
                onPressed: () {
                  setState(() {
                    _showAllVps = !_showAllVps;
                  });
                },
              ),
            ],
          ),
          if (_showAllVps) ...[
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Cari nama parameter (misal: ppp, rx, mac, temp)...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.backgroundElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
              onChanged: (q) {
                setState(() {
                  _vpSearchQuery = q;
                });
              },
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Tidak ada parameter yang sesuai pencarian.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
                  itemBuilder: (ctx, i) {
                    final item = entries[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              item.key,
                              style: const TextStyle(
                                color: AppColors.accentCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: Text(
                              item.value.isNotEmpty ? item.value : '(kosong)',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: item.value.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _copyToClipboard(item.key, item.value),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.copy, size: 12, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHardwareCard(DeviceItem dev) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.memory, color: AppColors.textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Spesifikasi Perangkat',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(label: 'Vendor / Pabrik', value: dev.manufacturer),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildInfoRow(label: 'Tipe / Model', value: dev.modelName),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildInfoRow(
            label: 'Serial Number',
            value: dev.serialNumber,
            isMonospace: true,
            onCopy: () => _copyToClipboard('Serial Number', dev.serialNumber),
          ),
          if (_detail?.softwareVersion != null) ...[
            const Divider(color: AppColors.cardBorder, height: 16),
            _buildInfoRow(label: 'Software Version', value: _detail!.softwareVersion),
          ],
          if (_detail?.uptimeFormatted != null) ...[
            const Divider(color: AppColors.cardBorder, height: 16),
            _buildInfoRow(label: 'Uptime Perangkat', value: _detail!.uptimeFormatted),
          ],
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildInfoRow(
            label: 'GenieACS Device ID',
            value: dev.id,
            isMonospace: true,
            onCopy: () => _copyToClipboard('Device ID', dev.id),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    bool isMonospace = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: isMonospace ? 'monospace' : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 14, color: AppColors.accentCyan),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
