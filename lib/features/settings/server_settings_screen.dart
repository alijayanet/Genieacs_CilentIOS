import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/genieacs_provider.dart';
import '../../core/providers/server_config_provider.dart';
import '../auth/login_screen.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _acsUrlCtrl;
  late TextEditingController _acsUserCtrl;
  late TextEditingController _acsPassCtrl;

  bool _testingAcs = false;
  String? _acsTestResult;
  bool _acsTestSuccess = false;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<ServerConfigProvider>();
    _acsUrlCtrl = TextEditingController(text: cfg.genieAcsUrl);
    _acsUserCtrl = TextEditingController(text: cfg.genieAcsUser);
    _acsPassCtrl = TextEditingController(text: cfg.genieAcsPass);
  }

  @override
  void dispose() {
    _acsUrlCtrl.dispose();
    _acsUserCtrl.dispose();
    _acsPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _testGenieAcs() async {
    setState(() {
      _testingAcs = true;
      _acsTestResult = null;
    });

    final provider = context.read<GenieAcsProvider>();
    final cfg = context.read<ServerConfigProvider>();
    await cfg.saveGenieAcsConfig(
      url: _acsUrlCtrl.text.trim(),
      user: _acsUserCtrl.text.trim(),
      pass: _acsPassCtrl.text.trim(),
    );

    await provider.fetchDevices();

    if (!mounted) return;
    setState(() {
      _testingAcs = false;
      if (provider.errorMessage == null && provider.devices.isNotEmpty) {
        _acsTestSuccess = true;
        _acsTestResult = 'Koneksi Sukses! Terbaca ${provider.devices.length} Modem ONU.';
      } else {
        _acsTestSuccess = false;
        _acsTestResult = provider.errorMessage ?? 'Gagal menghubungi server GenieACS';
      }
    });
  }

  Future<void> _saveAll() async {
    final cfg = context.read<ServerConfigProvider>();
    await cfg.saveGenieAcsConfig(
      url: _acsUrlCtrl.text.trim(),
      user: _acsUserCtrl.text.trim(),
      pass: _acsPassCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.signalGood,
        content: Text(
          'Konfigurasi server GenieACS berhasil disimpan!',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );

    context.read<GenieAcsProvider>().fetchDevices();
  }

  void _resetToDefault() async {
    final cfg = context.read<ServerConfigProvider>();
    await cfg.resetToDefault();
    setState(() {
      _acsUrlCtrl.text = cfg.genieAcsUrl;
      _acsUserCtrl.text = cfg.genieAcsUser;
      _acsPassCtrl.text = cfg.genieAcsPass;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan dikembalikan ke default (GenieACS 192.168.8.89:7557)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Pengaturan Server GenieACS', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('Default', style: TextStyle(color: AppColors.accentCyan)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // GenieACS Section Card
            _buildGenieAcsSection(),
            const SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              onPressed: _saveAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 20),
                  SizedBox(width: 8),
                  Text('Simpan Pengaturan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account & Session Section
            Consumer<ServerConfigProvider>(
              builder: (context, cfg, _) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_circle, color: AppColors.accentCyan, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User: ${cfg.genieAcsUser}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              cfg.isLoggedIn ? 'Sesi Login Aktif' : 'Belum Login',
                              style: TextStyle(
                                color: cfg.isLoggedIn ? AppColors.signalGood : AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout, size: 14, color: AppColors.signalBad),
                        label: const Text('Keluar', style: TextStyle(color: AppColors.signalBad, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.signalBad.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () async {
                          await cfg.logout();
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // App About
            Center(
              child: Column(
                children: [
                  Text(
                    'Alijaya NetSuite v1.0.0 (GenieACS Edition)',
                    style: TextStyle(color: AppColors.textMuted.withOpacity(0.7), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GenieACS NBI API & TR-069 Mobile Suite',
                    style: TextStyle(color: AppColors.textMuted.withOpacity(0.4), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenieAcsSection() {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_outlined, color: AppColors.accentCyan, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Server GenieACS NBI',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('URL GenieACS Server', _acsUrlCtrl, 'http://192.168.8.89:7557'),
          const SizedBox(height: 12),
          _buildTextField('Username NBI / Admin', _acsUserCtrl, 'admin / root'),
          const SizedBox(height: 12),
          _buildTextField('Password NBI / Admin', _acsPassCtrl, '••••••••', isPassword: true),
          const SizedBox(height: 16),

          if (_acsTestResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _acsTestSuccess ? AppColors.signalGood.withOpacity(0.1) : AppColors.signalBad.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _acsTestSuccess ? AppColors.signalGood : AppColors.signalBad),
              ),
              child: Row(
                children: [
                  Icon(
                    _acsTestSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _acsTestSuccess ? AppColors.signalGood : AppColors.signalBad,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _acsTestResult!,
                      style: TextStyle(color: _acsTestSuccess ? AppColors.signalGood : AppColors.signalBad, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          OutlinedButton.icon(
            onPressed: _testingAcs ? null : _testGenieAcs,
            icon: _testingAcs
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan))
                : const Icon(Icons.sync, size: 16),
            label: const Text('Tes Koneksi GenieACS'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentCyan,
              side: const BorderSide(color: AppColors.accentCyan),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: isPassword,
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.backgroundElevated,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accentCyan),
            ),
          ),
        ),
      ],
    );
  }
}
