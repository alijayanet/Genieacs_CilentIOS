import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/genieacs_provider.dart';
import 'device_detail_screen.dart';
import 'widgets/device_card.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GenieAcsProvider>();
      if (provider.devices.isEmpty && !provider.isLoading) {
        provider.fetchDevices();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenieAcsProvider>();
    if (_searchCtrl.text != provider.searchQuery) {
      _searchCtrl.value = TextEditingValue(
        text: provider.searchQuery,
        selection: TextSelection.collapsed(offset: provider.searchQuery.length),
      );
    }
    final devices = provider.filteredDevices;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manajemen Modem ONU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('GenieACS TR-069 Server', style: TextStyle(color: AppColors.accentCyan, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sinkronisasi Ulang',
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                  )
                : const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.fetchDevices(),
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter Vendor',
            icon: Icon(
              Icons.filter_list,
              color: provider.vendorFilter != null ? AppColors.accentCyan : AppColors.textPrimary,
            ),
            color: AppColors.backgroundCard,
            onSelected: (val) {
              provider.setVendorFilter(val == 'ALL' ? null : val);
            },
            itemBuilder: (ctx) {
              final vendors = ['ALL', ...provider.availableVendors];
              return vendors.map((v) {
                final isSelected = (v == 'ALL' && provider.vendorFilter == null) || provider.vendorFilter == v;
                return PopupMenuItem<String>(
                  value: v,
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: isSelected ? AppColors.accentCyan : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        v == 'ALL' ? 'Semua Vendor' : v,
                        style: TextStyle(
                          color: isSelected ? AppColors.accentCyan : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => provider.setSearchQuery(val),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cari nama, PPPoE, SSID, ODP, atau SN...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.accentCyan),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.backgroundCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.accentCyan),
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Semua (${provider.totalCount})',
                  filter: DeviceFilter.all,
                  current: provider.activeFilter,
                  onSelect: () => provider.setFilter(DeviceFilter.all),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Online (${provider.onlineCount})',
                  filter: DeviceFilter.online,
                  current: provider.activeFilter,
                  badgeColor: AppColors.signalGood,
                  onSelect: () => provider.setFilter(DeviceFilter.online),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Offline (${provider.offlineCount})',
                  filter: DeviceFilter.offline,
                  current: provider.activeFilter,
                  badgeColor: AppColors.signalBad,
                  onSelect: () => provider.setFilter(DeviceFilter.offline),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Kritis (${provider.criticalSignalCount})',
                  filter: DeviceFilter.criticalSignal,
                  current: provider.activeFilter,
                  badgeColor: AppColors.signalBad,
                  onSelect: () => provider.setFilter(DeviceFilter.criticalSignal),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Sedang (${provider.warningSignalCount})',
                  filter: DeviceFilter.warningSignal,
                  current: provider.activeFilter,
                  badgeColor: AppColors.signalWarning,
                  onSelect: () => provider.setFilter(DeviceFilter.warningSignal),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Bagus (${provider.idealSignalCount})',
                  filter: DeviceFilter.idealSignal,
                  current: provider.activeFilter,
                  badgeColor: AppColors.signalGood,
                  onSelect: () => provider.setFilter(DeviceFilter.idealSignal),
                ),
              ],
            ),
          ),

          // Vendor filter indicator if active
          if (provider.vendorFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  const Text('Filter Vendor: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accentCyan),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.vendorFilter!,
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => provider.setVendorFilter(null),
                          child: const Icon(Icons.close, size: 14, color: AppColors.accentCyan),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // Content List
          Expanded(
            child: provider.isLoading && provider.devices.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.accentCyan),
                        SizedBox(height: 16),
                        Text(
                          'Menghubungkan ke GenieACS 192.168.8.89...',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : provider.errorMessage != null && provider.devices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, size: 54, color: AppColors.signalBad),
                              const SizedBox(height: 16),
                              const Text(
                                'Koneksi ke GenieACS Gagal',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Lagi'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentCyan,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () => provider.fetchDevices(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : devices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tidak ada modem yang cocok',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _searchCtrl.text.isNotEmpty
                                      ? 'Coba kata kunci pencarian yang lain'
                                      : 'Semua filter sedang aktif',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.accentCyan,
                            backgroundColor: AppColors.backgroundCard,
                            onRefresh: () => provider.fetchDevices(),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: devices.length,
                              itemBuilder: (ctx, index) {
                                final item = devices[index];
                                return DeviceCard(
                                  device: item,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DeviceDetailScreen(device: item),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required DeviceFilter filter,
    required DeviceFilter current,
    required VoidCallback onSelect,
    Color? badgeColor,
  }) {
    final isSelected = filter == current;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentCyan.withOpacity(0.18) : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
