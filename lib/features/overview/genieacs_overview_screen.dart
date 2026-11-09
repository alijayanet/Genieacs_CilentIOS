import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/genieacs_provider.dart';
import '../../core/providers/server_config_provider.dart';
import '../../data/models/device_item.dart';
import 'widgets/donut_chart_view.dart';

class GenieAcsOverviewScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateTab;

  const GenieAcsOverviewScreen({
    super.key,
    this.onNavigateTab,
  });

  void _openDeviceListWithFilter(
    BuildContext context, {
    DeviceFilter? filter,
    String? vendor,
    String? search,
  }) {
    final provider = context.read<GenieAcsProvider>();
    if (filter != null) provider.setFilter(filter);
    if (vendor != null) provider.setVendorFilter(vendor);
    if (search != null) provider.setSearchQuery(search);

    if (onNavigateTab != null) {
      onNavigateTab!(1); // Switch to Tab 1 (Modem ONU List)
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenieAcsProvider>();
    final cfg = context.watch<ServerConfigProvider>();
    final devices = provider.allDevices;
    final total = devices.length;

    final onlineCount = provider.onlineCount;
    final offlineCount = provider.offlineCount;
    final badRxCount = devices.where((d) => d.rxPower != null && d.rxPower! < -27.0).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart, color: AppColors.accentCyan, size: 20),
                SizedBox(width: 8),
                Text(
                  'Overview GenieACS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            Text(
              cfg.genieAcsUrl,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui Data',
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentCyan,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.fetchDevices(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentCyan,
        backgroundColor: AppColors.backgroundCard,
        onRefresh: () => provider.fetchDevices(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // 1. Top Summary Strip Card
            _buildSummaryStrip(
              context: context,
              total: total,
              online: onlineCount,
              offline: offlineCount,
              badRx: badRxCount,
            ),
            const SizedBox(height: 14),

            // 2. 6 Donut Charts in 2-Column Responsive Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final cardWidth = isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // CHART 1: Online Status
                    SizedBox(
                      width: cardWidth,
                      child: _buildOnlineStatusCard(context, total, onlineCount, offlineCount),
                    ),

                    // CHART 2: Optical RX Power (Redaman)
                    SizedBox(
                      width: cardWidth,
                      child: _buildOpticalRxCard(context, total, devices, badRxCount),
                    ),

                    // CHART 3: Vendor & Model ONT
                    SizedBox(
                      width: cardWidth,
                      child: _buildVendorCard(context, total, devices),
                    ),

                    // CHART 4: Access Type / PON
                    SizedBox(
                      width: cardWidth,
                      child: _buildAccessTypeCard(context, total, devices),
                    ),

                    // CHART 5: Field Mapping & ODP
                    SizedBox(
                      width: cardWidth,
                      child: _buildMappingCard(context, total, devices),
                    ),

                    // CHART 6: Customer Tag Distribution
                    SizedBox(
                      width: cardWidth,
                      child: _buildTagsCard(context, total, devices),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- Summary Strip ---
  Widget _buildSummaryStrip({
    required BuildContext context,
    required int total,
    required int online,
    required int offline,
    required int badRx,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStripItem(
            label: 'TOTAL ONU',
            value: total.toString(),
            color: AppColors.textPrimary,
            onTap: () => _openDeviceListWithFilter(context, filter: DeviceFilter.all),
          ),
          _buildVerticalDivider(),
          _buildStripItem(
            label: 'ONLINE',
            value: online.toString(),
            color: const Color(0xFF10B981),
            onTap: () => _openDeviceListWithFilter(context, filter: DeviceFilter.online),
          ),
          _buildVerticalDivider(),
          _buildStripItem(
            label: 'OFFLINE',
            value: offline.toString(),
            color: const Color(0xFFEF4444),
            onTap: () => _openDeviceListWithFilter(context, filter: DeviceFilter.offline),
          ),
          _buildVerticalDivider(),
          _buildStripItem(
            label: 'KRITIS',
            value: badRx.toString(),
            color: const Color(0xFFEF4444),
            onTap: () => _openDeviceListWithFilter(context, filter: DeviceFilter.criticalSignal),
          ),
        ],
      ),
    );
  }

  Widget _buildStripItem({
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.cardBorder.withOpacity(0.8),
    );
  }

  // --- Chart 1: Online Status ---
  Widget _buildOnlineStatusCard(BuildContext context, int total, int online, int offline) {
    final slices = [
      DonutSlice(label: 'Online', count: online, color: const Color(0xFF10B981)),
      DonutSlice(label: 'Offline', count: offline, color: const Color(0xFFEF4444)),
    ];
    final rate = total > 0 ? (online * 100 / total).round() : 0;

    return _buildChartContainer(
      title: '📡 Status Koneksi',
      onTitleTap: () => _openDeviceListWithFilter(context, filter: DeviceFilter.online),
      chart: DonutChartView(
        slices: slices,
        primaryText: online.toString(),
        secondaryText: 'Online ($rate%)',
      ),
      legends: slices.map((s) {
        return DonutLegendItem(
          slice: s,
          total: total,
          onTap: () {
            if (s.label == 'Online') {
              _openDeviceListWithFilter(context, filter: DeviceFilter.online);
            } else {
              _openDeviceListWithFilter(context, filter: DeviceFilter.offline);
            }
          },
        );
      }).toList(),
    );
  }

  // --- Chart 2: Optical RX Power ---
  Widget _buildOpticalRxCard(BuildContext context, int total, List<DeviceItem> devices, int badRxCount) {
    final goodRx = devices.where((d) => d.rxPower != null && d.rxPower! >= -24.0).length;
    final warnRx = devices.where((d) => d.rxPower != null && d.rxPower! < -24.0 && d.rxPower! >= -27.0).length;
    final critRx = badRxCount;
    final unkRx = total - (goodRx + warnRx + critRx);

    final slices = <DonutSlice>[
      if (goodRx > 0) DonutSlice(label: 'Bagus (≥-24 dBm)', count: goodRx, color: const Color(0xFF3B82F6)),
      if (warnRx > 0) DonutSlice(label: 'Sedang (-24..-27)', count: warnRx, color: const Color(0xFFF59E0B)),
      if (critRx > 0) DonutSlice(label: 'Kritis (<-27 dBm)', count: critRx, color: const Color(0xFFEF4444)),
      if (unkRx > 0) DonutSlice(label: 'N/A / Offline', count: unkRx, color: const Color(0xFF64748B)),
    ];

    final safePercent = total > 0 ? (((goodRx + warnRx) * 100 / total)).round() : 0;

    return _buildChartContainer(
      title: '💡 Kualitas Optik (RX)',
      onTitleTap: () => _openDeviceListWithFilter(context, filter: DeviceFilter.criticalSignal),
      chart: DonutChartView(
        slices: slices,
        primaryText: '$safePercent%',
        secondaryText: 'Sinyal Aman',
      ),
      legends: slices.map((s) {
        return DonutLegendItem(
          slice: s,
          total: total,
          onTap: () {
            if (s.label.contains('Kritis')) {
              _openDeviceListWithFilter(context, filter: DeviceFilter.criticalSignal);
            } else if (s.label.contains('Sedang')) {
              _openDeviceListWithFilter(context, filter: DeviceFilter.warningSignal);
            } else if (s.label.contains('Bagus')) {
              _openDeviceListWithFilter(context, filter: DeviceFilter.idealSignal);
            } else {
              _openDeviceListWithFilter(context, filter: DeviceFilter.offline);
            }
          },
        );
      }).toList(),
    );
  }

  // --- Chart 3: Vendor & Model ONT ---
  Widget _buildVendorCard(BuildContext context, int total, List<DeviceItem> devices) {
    final groupCounts = <String, int>{};
    for (final dev in devices) {
      final m = dev.manufacturer.toUpperCase();
      String vendorName;
      if (m.contains('ZTE') || m.contains('ZICG')) {
        vendorName = 'ZTE';
      } else if (m.contains('HUAWEI')) {
        vendorName = 'Huawei';
      } else if (m.contains('FIBERHOME') || m.contains('CIOT')) {
        vendorName = 'FiberHome';
      } else if (m.contains('VSOL') || m.contains('CDATA') || m.contains('C-DATA')) {
        vendorName = 'VSOL / C-Data';
      } else if (m.contains('HSGQ') || m.contains('BDCOM')) {
        vendorName = 'HSGQ / BDCOM';
      } else if (dev.productClass.isNotEmpty && dev.productClass != 'Modem') {
        vendorName = dev.productClass;
      } else {
        vendorName = 'Lainnya';
      }
      groupCounts[vendorName] = (groupCounts[vendorName] ?? 0) + 1;
    }

    final sorted = groupCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFFF97316),
      Color(0xFF06B6D4),
      Color(0xFF64748B),
    ];

    final slices = <DonutSlice>[];
    final topVendors = sorted.take(5).toList();
    for (int i = 0; i < topVendors.length; i++) {
      slices.add(DonutSlice(
        label: topVendors[i].key,
        count: topVendors[i].value,
        color: colors[i % colors.length],
      ));
    }
    final otherCount = sorted.skip(5).fold<int>(0, (sum, e) => sum + e.value);
    if (otherCount > 0) {
      slices.add(DonutSlice(
        label: 'Lainnya',
        count: otherCount,
        color: const Color(0xFF64748B),
      ));
    }

    return _buildChartContainer(
      title: '🏷️ Merek & Model ONU',
      chart: DonutChartView(
        slices: slices,
        primaryText: sorted.length.toString(),
        secondaryText: 'Model Merek',
      ),
      legends: slices.map((s) {
        return DonutLegendItem(
          slice: s,
          total: total,
          onTap: () => _openDeviceListWithFilter(context, vendor: s.label == 'Lainnya' ? null : s.label),
        );
      }).toList(),
    );
  }

  // --- Chart 4: Access Type / PON ---
  Widget _buildAccessTypeCard(BuildContext context, int total, List<DeviceItem> devices) {
    int gpon = 0;
    int epon = 0;
    int ethernet = 0;

    for (final dev in devices) {
      final p = dev.ponMode.toUpperCase();
      if (p.contains('EPON')) {
        epon++;
      } else if (p.contains('ETHERNET')) {
        ethernet++;
      } else {
        gpon++;
      }
    }

    final slices = <DonutSlice>[
      if (gpon > 0) DonutSlice(label: 'GPON', count: gpon, color: const Color(0xFF06B6D4)),
      if (epon > 0) DonutSlice(label: 'EPON', count: epon, color: const Color(0xFF84CC16)),
      if (ethernet > 0) DonutSlice(label: 'Ethernet', count: ethernet, color: const Color(0xFF6366F1)),
    ];

    final mainPon = gpon >= epon ? 'GPON' : 'EPON';

    return _buildChartContainer(
      title: '⚡ Access Type / PON',
      chart: DonutChartView(
        slices: slices,
        primaryText: mainPon,
        secondaryText: 'Mode Utama',
      ),
      legends: slices.map((s) {
        return DonutLegendItem(
          slice: s,
          total: total,
          onTap: () => _openDeviceListWithFilter(context, search: s.label),
        );
      }).toList(),
    );
  }

  // --- Chart 5: Field Mapping & ODP ---
  Widget _buildMappingCard(BuildContext context, int total, List<DeviceItem> devices) {
    final mappedOdp = devices.where((d) => d.isMapped && (d.odpName?.isNotEmpty ?? false)).length;
    final mappedGpsOnly = devices.where((d) => d.hasGps && (d.odpName == null || d.odpName!.isEmpty)).length;
    final unmapped = total - (mappedOdp + mappedGpsOnly);

    final slices = <DonutSlice>[
      if (mappedOdp > 0) DonutSlice(label: 'Terpetakan ODP', count: mappedOdp, color: const Color(0xFF3B82F6)),
      if (mappedGpsOnly > 0) DonutSlice(label: 'Titik GPS Saja', count: mappedGpsOnly, color: const Color(0xFF10B981)),
      if (unmapped > 0) DonutSlice(label: 'Belum Ada Titik', count: unmapped, color: const Color(0xFF64748B)),
    ];

    final mapRate = total > 0 ? (((total - unmapped) * 100 / total)).round() : 0;

    return _buildChartContainer(
      title: '📍 Pemetaan Lapangan',
      onTitleTap: () {
        if (onNavigateTab != null) onNavigateTab!(2);
      },
      chart: DonutChartView(
        slices: slices,
        primaryText: '$mapRate%',
        secondaryText: 'Terpetakan',
      ),
      legends: slices.map((s) {
        return DonutLegendItem(
          slice: s,
          total: total,
          onTap: () {
            if (onNavigateTab != null) onNavigateTab!(2);
          },
        );
      }).toList(),
    );
  }

  // --- Chart 6: Customer Tag Distribution ---
  Widget _buildTagsCard(BuildContext context, int total, List<DeviceItem> devices) {
    final tagCounts = <String, int>{};
    for (final dev in devices) {
      for (final tag in dev.tags) {
        if (!tag.toUpperCase().startsWith('LOC_') && !tag.toUpperCase().startsWith('LOC:')) {
          final clean = tag.trim();
          if (clean.isNotEmpty) {
            tagCounts[clean] = (tagCounts[clean] ?? 0) + 1;
          }
        }
      }
    }

    final sorted = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const tagColors = [
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF64748B),
    ];

    final topTags = sorted.take(4).toList();
    final slices = <DonutSlice>[];
    for (int i = 0; i < topTags.length; i++) {
      slices.add(DonutSlice(
        label: topTags[i].key,
        count: topTags[i].value,
        color: tagColors[i % tagColors.length],
      ));
    }
    final otherTagsCount = sorted.skip(4).fold<int>(0, (sum, e) => sum + e.value);
    if (otherTagsCount > 0) {
      slices.add(DonutSlice(
        label: 'Tag Lainnya',
        count: otherTagsCount,
        color: const Color(0xFF64748B),
      ));
    }

    return _buildChartContainer(
      title: '🔖 Distribusi Tag Pelanggan',
      chart: DonutChartView(
        slices: slices,
        primaryText: sorted.length.toString(),
        secondaryText: 'Total Tag',
      ),
      legends: slices.map((s) {
        return DonutLegendItem(
          slice: s,
          total: total,
          onTap: () => _openDeviceListWithFilter(context, search: s.label == 'Tag Lainnya' ? null : s.label),
        );
      }).toList(),
    );
  }

  // --- Card Container Helper ---
  Widget _buildChartContainer({
    required String title,
    required Widget chart,
    required List<Widget> legends,
    VoidCallback? onTitleTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTitleTap,
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onTitleTap != null)
                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(child: chart),
          const SizedBox(height: 12),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 8),
          Column(
            children: legends.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Tidak ada data',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  ]
                : legends,
          ),
        ],
      ),
    );
  }
}
