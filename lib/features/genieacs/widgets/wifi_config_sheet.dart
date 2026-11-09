import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/genieacs_provider.dart';
import '../../../data/models/device_detail.dart';

class WifiConfigSheet extends StatefulWidget {
  final String deviceId;
  final WlanInstance? wlan;
  final String? initialFocus; // 'ssid' or 'password'
  final VoidCallback? onSuccess;

  const WifiConfigSheet({
    super.key,
    required this.deviceId,
    this.wlan,
    this.initialFocus,
    this.onSuccess,
  });

  @override
  State<WifiConfigSheet> createState() => _WifiConfigSheetState();
}

class _WifiConfigSheetState extends State<WifiConfigSheet> {
  final _ssidFormKey = GlobalKey<FormState>();
  final _pwdFormKey = GlobalKey<FormState>();

  late TextEditingController _ssidController;
  late TextEditingController _pwdController;
  late FocusNode _ssidFocusNode;
  late FocusNode _pwdFocusNode;

  bool _obscurePassword = true;
  bool _isSubmittingSsid = false;
  bool _isSubmittingPassword = false;
  bool _isSubmittingAll = false;

  @override
  void initState() {
    super.initState();
    _ssidController = TextEditingController(text: widget.wlan?.ssid ?? '');
    _pwdController = TextEditingController(text: widget.wlan?.password ?? '');
    _ssidFocusNode = FocusNode();
    _pwdFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFocus == 'password') {
        _pwdFocusNode.requestFocus();
      } else if (widget.initialFocus == 'ssid') {
        _ssidFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _pwdController.dispose();
    _ssidFocusNode.dispose();
    _pwdFocusNode.dispose();
    super.dispose();
  }

  bool get _isAnySubmitting => _isSubmittingSsid || _isSubmittingPassword || _isSubmittingAll;

  /// Simpan hanya SSID
  Future<void> _submitSsid() async {
    if (!_ssidFormKey.currentState!.validate()) return;

    setState(() => _isSubmittingSsid = true);
    final provider = context.read<GenieAcsProvider>();
    final newSsid = _ssidController.text.trim();

    final success = await provider.commitWifiConfig(
      deviceId: widget.deviceId,
      newSsid: newSsid,
      newPassword: '', // Biarkan password kosong agar tidak disentuh
      wlanPath: widget.wlan?.path,
    );

    if (!mounted) return;
    setState(() => _isSubmittingSsid = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.signalGood,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nama SSID "$newSsid" berhasil dikirim ke antrian TR-069!',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      widget.onSuccess?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.signalBad,
          content: Text(
            provider.errorMessage ?? 'Gagal memperbarui SSID',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  /// Simpan hanya Kata Sandi
  Future<void> _submitPassword() async {
    if (!_pwdFormKey.currentState!.validate()) return;

    setState(() => _isSubmittingPassword = true);
    final provider = context.read<GenieAcsProvider>();
    final newPwd = _pwdController.text.trim();

    final success = await provider.commitWifiConfig(
      deviceId: widget.deviceId,
      newSsid: '', // Biarkan SSID kosong agar tidak disentuh
      newPassword: newPwd,
      wlanPath: widget.wlan?.path,
    );

    if (!mounted) return;
    setState(() => _isSubmittingPassword = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.signalGood,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.black),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kata sandi WiFi baru berhasil dikirim ke antrian TR-069!',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      widget.onSuccess?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.signalBad,
          content: Text(
            provider.errorMessage ?? 'Gagal memperbarui Kata Sandi',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  /// Simpan keduanya sekaligus (SSID dan Password)
  Future<void> _submitAll() async {
    final isSsidValid = _ssidFormKey.currentState!.validate();
    final isPwdValid = _pwdFormKey.currentState!.validate();
    if (!isSsidValid || !isPwdValid) return;

    setState(() => _isSubmittingAll = true);
    final provider = context.read<GenieAcsProvider>();

    final success = await provider.commitWifiConfig(
      deviceId: widget.deviceId,
      newSsid: _ssidController.text.trim(),
      newPassword: _pwdController.text.trim(),
      wlanPath: widget.wlan?.path,
    );

    if (!mounted) return;
    setState(() => _isSubmittingAll = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.signalGood,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.black),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SSID dan Kata Sandi berhasil dikirim ke antrian TR-069!',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      widget.onSuccess?.call();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.signalBad,
          content: Text(
            provider.errorMessage ?? 'Gagal memperbarui konfigurasi WiFi',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Indicator
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wifi_password, color: AppColors.accentCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pengaturan Wi-Fi Pelanggan',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Jalur: ${widget.wlan?.path ?? "Auto TR-069 Parameter"}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ================= SECTION 1: NAMA SSID =================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.35)),
                ),
                child: Form(
                  key: _ssidFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wifi, color: AppColors.accentCyan, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '1. Nama WiFi (SSID)',
                            style: TextStyle(
                              color: AppColors.accentCyan,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _ssidController,
                        focusNode: _ssidFocusNode,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contoh: ALIJAYA-WIFI',
                          prefixIcon: const Icon(Icons.drive_file_rename_outline, color: AppColors.accentCyan, size: 18),
                          filled: true,
                          fillColor: AppColors.backgroundCard,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nama SSID tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isAnySubmitting ? null : _submitSsid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                          icon: _isSubmittingSsid
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(
                            _isSubmittingSsid ? 'Menyimpan SSID...' : 'Simpan Nama SSID Saja',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ================= SECTION 2: PASSWORD =================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentEmerald.withOpacity(0.35)),
                ),
                child: Form(
                  key: _pwdFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, color: AppColors.accentEmerald, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '2. Kata Sandi (WPA/WPA2 Key)',
                            style: TextStyle(
                              color: AppColors.accentEmerald,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _pwdController,
                        focusNode: _pwdFocusNode,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Minimal 8 karakter',
                          prefixIcon: const Icon(Icons.key, color: AppColors.accentEmerald, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textMuted,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: AppColors.backgroundCard,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Kata sandi tidak boleh kosong';
                          }
                          if (val.trim().length < 8) {
                            return 'Kata sandi minimal 8 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isAnySubmitting ? null : _submitPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentEmerald,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                          icon: _isSubmittingPassword
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.lock_reset, size: 18),
                          label: Text(
                            _isSubmittingPassword ? 'Menyimpan Sandi...' : 'Simpan Password Saja',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ================= FOOTER: SIMPAN KEDUANYA & TUTUP =================
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isAnySubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Tutup', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isAnySubmitting ? null : _submitAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.signalWarning,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: _isSubmittingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.done_all, size: 18),
                      label: const Text(
                        'Simpan Keduanya',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
