import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PingToolScreen extends StatefulWidget {
  const PingToolScreen({super.key});

  @override
  State<PingToolScreen> createState() => _PingToolScreenState();
}

class _PingToolScreenState extends State<PingToolScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _hostCtrl = TextEditingController(text: '192.168.8.89');
  final ScrollController _logScrollCtrl = ScrollController();

  bool _isPinging = false;
  final List<String> _logs = [];
  int _sent = 0;
  int _received = 0;
  double _minMs = 9999;
  double _maxMs = 0;
  double _sumMs = 0;
  Timer? _pingTimer;

  // Optical Budget Calculator state
  double _oltPower = 4.0; // dBm
  double _distanceKm = 3.5; // km
  String _splitter = '1:8'; // dB loss
  int _spliceCount = 2;
  final double _connectorLoss = 0.5;

  final Map<String, double> _splitterLossMap = {
    '1:2': 3.5,
    '1:4': 7.2,
    '1:8': 10.5,
    '1:16': 13.8,
    '1:32': 17.2,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _hostCtrl.dispose();
    _logScrollCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startPing() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _isPinging = true;
      _logs.clear();
      _sent = 0;
      _received = 0;
      _minMs = 9999;
      _maxMs = 0;
      _sumMs = 0;
      _logs.add('--- Memulai Ping ke $host ---');
    });

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!_isPinging) {
        timer.cancel();
        return;
      }
      await _executeOnePing(host);
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    setState(() => _isPinging = false);
    _addLog('--- Selesai: $_sent dikirim, $_received diterima (${_lossPct.toStringAsFixed(1)}% loss) ---');
  }

  Future<void> _executeOnePing(String host) async {
    _sent++;
    final sw = Stopwatch()..start();
    try {
      // Connect with short socket timeout to measure TCP / ping latency
      final sock = await Socket.connect(
        host,
        host.contains('7557') ? 7557 : (host == '192.168.8.89' ? 7557 : (host == '192.168.8.1' ? 8291 : 80)),
        timeout: const Duration(milliseconds: 1500),
      );
      sw.stop();
      await sock.close();

      final ms = sw.elapsedMicroseconds / 1000.0;
      _received++;
      if (ms < _minMs) _minMs = ms;
      if (ms > _maxMs) _maxMs = ms;
      _sumMs += ms;

      _addLog('Reply dari $host: time=${ms.toStringAsFixed(1)}ms seq=$_sent');
    } catch (e) {
      sw.stop();
      // Try ICMP fallback via raw socket lookup
      try {
        final lookupSw = Stopwatch()..start();
        final addrs = await InternetAddress.lookup(host).timeout(const Duration(milliseconds: 1200));
        lookupSw.stop();
        if (addrs.isNotEmpty) {
          final ms = lookupSw.elapsedMicroseconds / 1000.0;
          _received++;
          if (ms < _minMs) _minMs = ms;
          if (ms > _maxMs) _maxMs = ms;
          _sumMs += ms;
          _addLog('DNS Host Resolved ($host): time=${ms.toStringAsFixed(1)}ms seq=$_sent');
        } else {
          _addLog('Request timed out untuk seq=$_sent');
        }
      } catch (_) {
        _addLog('Request timed out atau host tidak merespon seq=$_sent');
      }
    }
  }

  void _addLog(String log) {
    if (!mounted) return;
    setState(() {
      _logs.add(log);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.animateTo(
          _logScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  double get _lossPct => _sent > 0 ? ((_sent - _received) / _sent) * 100 : 0;
  double get _avgMs => _received > 0 ? _sumMs / _received : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Network Field Tools', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentCyan,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.network_ping, size: 20), text: 'Ping & Latency'),
            Tab(icon: Icon(Icons.calculate_outlined, size: 20), text: 'Kalkulator Redaman'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPingTab(),
          _buildOpticalBudgetTab(),
        ],
      ),
    );
  }

  Widget _buildPingTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Input Host & Start Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hostCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'IP atau Hostname',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.backgroundCard,
                    prefixIcon: const Icon(Icons.language, color: AppColors.accentCyan),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isPinging ? _stopPing : _startPing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPinging ? AppColors.signalBad : AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(_isPinging ? Icons.stop : Icons.play_arrow, size: 20),
                    const SizedBox(width: 6),
                    Text(_isPinging ? 'Stop' : 'Ping', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip('GenieACS', '192.168.8.89'),
                const SizedBox(width: 8),
                _buildPresetChip('Gateway', '192.168.8.1'),
                const SizedBox(width: 8),
                _buildPresetChip('Google DNS', '8.8.8.8'),
                const SizedBox(width: 8),
                _buildPresetChip('Cloudflare', '1.1.1.1'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatPill('Sent', '$_sent'),
                _buildStatPill('Loss', '${_lossPct.toStringAsFixed(0)}%'),
                _buildStatPill('Min', _minMs < 9000 ? '${_minMs.toStringAsFixed(0)}ms' : '-'),
                _buildStatPill('Avg', _avgMs > 0 ? '${_avgMs.toStringAsFixed(0)}ms' : '-'),
                _buildStatPill('Max', _maxMs > 0 ? '${_maxMs.toStringAsFixed(0)}ms' : '-'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Terminal Output
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF03070E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Pilih preset atau masukkan host, lalu tekan Ping',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollCtrl,
                      itemCount: _logs.length,
                      itemBuilder: (ctx, idx) {
                        final log = _logs[idx];
                        final isError = log.contains('timed out') || log.contains('tidak merespon');
                        final isHeader = log.startsWith('---');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: isHeader
                                  ? AppColors.accentCyan
                                  : (isError ? AppColors.signalBad : AppColors.signalGood),
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
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

  Widget _buildPresetChip(String label, String host) {
    final isCurrent = _hostCtrl.text == host;
    return InkWell(
      onTap: () {
        setState(() => _hostCtrl.text = host);
        if (_isPinging) _startPing();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.accentCyan.withOpacity(0.2) : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isCurrent ? AppColors.accentCyan : AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isCurrent ? AppColors.accentCyan : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildOpticalBudgetTab() {
    // Optical Math:
    // Loss Fiber = distance * 0.35 dB/km (1310/1490nm)
    // Loss Splitter = _splitterLossMap[_splitter]
    // Loss Splicing = _spliceCount * 0.1 dB
    // Loss Connector = _connectorLoss * 2 (OLT & ONU)
    final fiberLoss = _distanceKm * 0.35;
    final splitterLoss = _splitterLossMap[_splitter] ?? 10.5;
    final spliceLoss = _spliceCount * 0.1;
    final totalLoss = fiberLoss + splitterLoss + spliceLoss + (_connectorLoss * 2);
    final calculatedRx = _oltPower - totalLoss;

    Color powerColor = AppColors.signalGood;
    String powerStatus = 'Kualitas Bagus (Ideal)';

    if (calculatedRx < -27.0) {
      powerColor = AppColors.signalBad;
      powerStatus = 'Kritis (Terlalu Rendah)';
    } else if (calculatedRx < -24.0) {
      powerColor = AppColors.signalWarning;
      powerStatus = 'Sedang (Cukup)';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Result Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: powerColor.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              const Text('ESTIMASI REDAMAN RX ONU', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(
                '${calculatedRx.toStringAsFixed(2)} dBm',
                style: TextStyle(
                  color: powerColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: powerColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  powerStatus,
                  style: TextStyle(color: powerColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Total Redaman Link: ${totalLoss.toStringAsFixed(2)} dB',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Parameter Sliders & Inputs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Parameter Jaringan Fiber Optik', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),

              // OLT Output
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Power Output SFP OLT', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text('${_oltPower.toStringAsFixed(1)} dBm', style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _oltPower,
                min: 0.0,
                max: 10.0,
                divisions: 20,
                activeColor: AppColors.accentCyan,
                onChanged: (val) => setState(() => _oltPower = val),
              ),
              const SizedBox(height: 10),

              // Jarak Kabel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Panjang Kabel Fiber Optik', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text('${_distanceKm.toStringAsFixed(1)} km', style: const TextStyle(color: AppColors.accentEmerald, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _distanceKm,
                min: 0.1,
                max: 20.0,
                divisions: 40,
                activeColor: AppColors.accentEmerald,
                onChanged: (val) => setState(() => _distanceKm = val),
              ),
              const SizedBox(height: 10),

              // Rasio Splitter Dropdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rasio Splitter PLC/FBT', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  DropdownButton<String>(
                    value: _splitter,
                    dropdownColor: AppColors.backgroundElevated,
                    style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold),
                    underline: const SizedBox(),
                    items: _splitterLossMap.keys.map((k) {
                      return DropdownMenuItem<String>(
                        value: k,
                        child: Text('$k (~${_splitterLossMap[k]} dB)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _splitter = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Jumlah Sambungan Fusion Splicing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Titik Sambungan Splicing', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text('$_spliceCount titik (~${(_spliceCount * 0.1).toStringAsFixed(1)} dB)', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _spliceCount.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                activeColor: AppColors.accentCyan,
                onChanged: (val) => setState(() => _spliceCount = val.toInt()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
