import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/genieacs_provider.dart';
import '../../../data/models/device_detail.dart';
import '../../../data/models/wan_models.dart';

class AddWanSheet extends StatefulWidget {
  final String deviceId;
  final String deviceModel;
  final String currentPppoeUser;
  final List<WanItem> existingWanList;
  final List<WlanInstance> wlanList;
  final VoidCallback onWanConfigured;

  const AddWanSheet({
    super.key,
    required this.deviceId,
    required this.deviceModel,
    required this.currentPppoeUser,
    required this.existingWanList,
    this.wlanList = const [],
    required this.onWanConfigured,
  });

  @override
  State<AddWanSheet> createState() => _AddWanSheetState();
}

class _AddWanSheetState extends State<AddWanSheet> {
  final _formKey = GlobalKey<FormState>();

  // Target: 'wan1', 'wan2', or 'new'
  String _selectedTarget = 'new';
  int _wanIndex = 1;

  // Connection type: 'PPPoE_Routed', 'IP_Routed', 'PPPoE_Bridged', 'IP_Bridged'
  String _connectionType = 'PPPoE_Routed';

  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _vlanCtrl;

  bool _vlanEnabled = false;
  String _serviceList = 'INTERNET';

  // Port Binding
  bool _bindLan1 = true;
  bool _bindLan2 = true;
  bool _bindLan3 = true;
  bool _bindLan4 = true;
  bool _bindWlan1 = true;
  bool _bindWlan2 = false;
  bool _bindWlan3 = false;
  bool _bindWlan4 = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController(
      text: (widget.currentPppoeUser.isNotEmpty && widget.currentPppoeUser != '-')
          ? widget.currentPppoeUser
          : '',
    );
    _passCtrl = TextEditingController();
    _vlanCtrl = TextEditingController();

    if (widget.existingWanList.isNotEmpty) {
      _selectedTarget = 'wan1';
      _applyWanToFields(widget.existingWanList.first);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _vlanCtrl.dispose();
    super.dispose();
  }

  void _applyWanToFields(WanItem wan) {
    _wanIndex = wan.instanceIndex;
    if (wan.username.isNotEmpty) {
      _userCtrl.text = wan.username;
    }
    if (wan.connectionType.toLowerCase().contains('bridge')) {
      if (wan.connectionType.toLowerCase().contains('ppp')) {
        _connectionType = 'PPPoE_Bridged';
      } else {
        _connectionType = 'IP_Bridged';
      }
      _serviceList = 'Other';
    } else if (wan.connectionType.toLowerCase().contains('ip')) {
      _connectionType = 'IP_Routed';
    } else {
      _connectionType = 'PPPoE_Routed';
    }

    if (wan.vlanId != null && wan.vlanId! > 0) {
      _vlanEnabled = true;
      _vlanCtrl.text = wan.vlanId.toString();
    } else {
      _vlanEnabled = false;
      _vlanCtrl.text = '';
    }
    setState(() {});
  }

  void _onTargetChanged(String target) {
    setState(() {
      _selectedTarget = target;
      if (target == 'wan1' && widget.existingWanList.isNotEmpty) {
        _applyWanToFields(widget.existingWanList.first);
      } else if (target == 'wan2' && widget.existingWanList.length > 1) {
        _applyWanToFields(widget.existingWanList[1]);
      } else {
        // New instance
        _wanIndex = widget.existingWanList.length + 1;
        _vlanEnabled = false;
        _vlanCtrl.text = '';
        _connectionType = 'PPPoE_Routed';
        _serviceList = 'INTERNET';
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final isNewInstance = _selectedTarget == 'new';
    final isPppoe = _connectionType == 'PPPoE_Routed';

    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    if (isPppoe && username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.signalBad,
          content: Text('Username PPPoE tidak boleh kosong!'),
        ),
      );
      return;
    }

    int vlanId = 0;
    if (_vlanEnabled) {
      final parsed = int.tryParse(_vlanCtrl.text.trim());
      if (parsed == null || parsed <= 0 || parsed > 4094) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.signalBad,
            content: Text('Masukkan VLAN ID valid (1 - 4094)!'),
          ),
        );
        return;
      }
      vlanId = parsed;
    }

    final slot = (_connectionType.startsWith('IP_') || _connectionType == 'IP_Routed')
        ? 'IP'
        : 'PPP';

    final params = WanConfigParams(
      isNewInstance: isNewInstance,
      wanSlot: slot,
      wanIndex: _wanIndex,
      connectionType: _connectionType,
      username: username,
      password: password,
      vlanEnabled: _vlanEnabled,
      vlanId: vlanId,
      serviceList: _serviceList,
      bindLan1: _bindLan1,
      bindLan2: _bindLan2,
      bindLan3: _bindLan3,
      bindLan4: _bindLan4,
      bindWlan1: _bindWlan1,
      bindWlan2: _bindWlan2,
      bindWlan3: _bindWlan3,
      bindWlan4: _bindWlan4,
      manufacturer: widget.deviceModel,
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      final genieProvider = context.read<GenieAcsProvider>();
      final msg = await genieProvider.configureWan(
        deviceId: widget.deviceId,
        params: params,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.signalGood,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ $msg',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      widget.onWanConfigured();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.signalBad,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '❌ Gagal: ${e.toString().replaceFirst('Exception: ', '')}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.alt_route, color: AppColors.accentCyan, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konfigurasi WAN / Add WAN',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Model: ${widget.deviceModel} | TR-069 Multi-Vendor',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.cardBorder, height: 1),

          // Scrollable Form Content
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // 1. Target Selector
                  _buildSectionTitle('1. Target Koneksi WAN'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        if (widget.existingWanList.isNotEmpty) ...[
                          RadioListTile<String>(
                            value: 'wan1',
                            groupValue: _selectedTarget,
                            activeColor: AppColors.accentCyan,
                            title: Text(
                              '⚙️ Timpa WAN 1 (${widget.existingWanList.first.name})',
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                            subtitle: Text(
                              'Mode: ${widget.existingWanList.first.connectionType} | VLAN: ${widget.existingWanList.first.vlanId ?? "-"}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            onChanged: (v) => _onTargetChanged(v!),
                          ),
                          if (widget.existingWanList.length > 1) ...[
                            const Divider(color: AppColors.cardBorder, height: 1),
                            RadioListTile<String>(
                              value: 'wan2',
                              groupValue: _selectedTarget,
                              activeColor: AppColors.accentCyan,
                              title: Text(
                                '⚙️ Timpa WAN 2 (${widget.existingWanList[1].name})',
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              ),
                              subtitle: Text(
                                'Mode: ${widget.existingWanList[1].connectionType} | VLAN: ${widget.existingWanList[1].vlanId ?? "-"}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              onChanged: (v) => _onTargetChanged(v!),
                            ),
                          ],
                          const Divider(color: AppColors.cardBorder, height: 1),
                        ],
                        RadioListTile<String>(
                          value: 'new',
                          groupValue: _selectedTarget,
                          activeColor: AppColors.accentEmerald,
                          title: const Text(
                            '➕ Buat WAN Baru (Instance Baru / addObject)',
                            style: TextStyle(fontSize: 13, color: AppColors.accentEmerald, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Menambahkan interface WAN koneksi baru via TR-069',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          onChanged: (v) => _onTargetChanged(v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Connection Type
                  _buildSectionTitle('2. Mode & Tipe Koneksi'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTypeChip('PPPoE_Routed', 'PPPoE (Routed)', Icons.lock_clock),
                      _buildTypeChip('IP_Routed', 'IPoE / DHCP (Routed)', Icons.router),
                      _buildTypeChip('PPPoE_Bridged', 'Bridge (PPPoE)', Icons.alt_route),
                      _buildTypeChip('IP_Bridged', 'Bridge (IPoE)', Icons.lan),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3. PPPoE Credentials (if applicable)
                  if (_connectionType == 'PPPoE_Routed') ...[
                    _buildSectionTitle('3. Kredensial Akun PPPoE'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _userCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Username PPPoE',
                        hintText: 'contoh: user@alijaya',
                        prefixIcon: const Icon(Icons.person, color: AppColors.accentCyan, size: 20),
                        filled: true,
                        fillColor: AppColors.backgroundElevated,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (v) {
                        if (_connectionType == 'PPPoE_Routed' && (v == null || v.trim().isEmpty)) {
                          return 'Username PPPoE wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Password PPPoE',
                        hintText: 'Biarkan kosong jika tidak diubah',
                        prefixIcon: const Icon(Icons.key, color: AppColors.accentCyan, size: 20),
                        filled: true,
                        fillColor: AppColors.backgroundElevated,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 4. VLAN Settings
                  _buildSectionTitle('4. Pengaturan VLAN 802.1Q'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tag, color: AppColors.accentCyan, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Aktifkan VLAN Tagging',
                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Switch(
                              value: _vlanEnabled,
                              activeColor: AppColors.accentCyan,
                              onChanged: (v) {
                                setState(() {
                                  _vlanEnabled = v;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_vlanEnabled) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _vlanCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'VLAN ID (1 - 4094)',
                              hintText: 'contoh: 100 / 200 / 300',
                              prefixIcon: const Icon(Icons.numbers, color: AppColors.accentCyan, size: 20),
                              filled: true,
                              fillColor: AppColors.backgroundCard,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 5. Service List
                  _buildSectionTitle('5. Service List Profile'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildServiceChip('INTERNET', 'INTERNET (Default)'),
                      _buildServiceChip('TR069,INTERNET', 'TR069,INTERNET (Dual)'),
                      _buildServiceChip('Other', 'Other (Bridge / Hotspot)'),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 6. Port Binding
                  _buildSectionTitle('6. Binding Port LAN & WLAN SSID'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Port LAN Fisik:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildPortCheckbox('LAN 1', _bindLan1, (v) => setState(() => _bindLan1 = v)),
                            _buildPortCheckbox('LAN 2', _bindLan2, (v) => setState(() => _bindLan2 = v)),
                            _buildPortCheckbox('LAN 3', _bindLan3, (v) => setState(() => _bindLan3 = v)),
                            _buildPortCheckbox('LAN 4', _bindLan4, (v) => setState(() => _bindLan4 = v)),
                          ],
                        ),
                        const Divider(color: AppColors.cardBorder, height: 16),
                        const Text('WLAN Wireless SSID:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildPortCheckbox('SSID 1', _bindWlan1, (v) => setState(() => _bindWlan1 = v)),
                            _buildPortCheckbox('SSID 2', _bindWlan2, (v) => setState(() => _bindWlan2 = v)),
                            _buildPortCheckbox('SSID 3', _bindWlan3, (v) => setState(() => _bindWlan3 = v)),
                            _buildPortCheckbox('SSID 4', _bindWlan4, (v) => setState(() => _bindWlan4 = v)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Multi-Vendor Safety Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.accentCyan, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sistem secara otomatis menyesuaikan parameter vendor (${widget.deviceModel.contains("ZTE") ? "ZTE X_CMCC_*" : widget.deviceModel.contains("Huawei") ? "Huawei X_HW_*" : "TR-098 Standard"}) untuk mencegah TR-069 Fault 9005.',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Submit Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              border: Border(top: BorderSide(color: AppColors.cardBorder.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.black)),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 18),
                              SizedBox(width: 8),
                              Text('Terapkan WAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.accentCyan,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _connectionType == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.black : AppColors.accentCyan),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.accentCyan,
      backgroundColor: AppColors.backgroundElevated,
      labelStyle: TextStyle(color: isSelected ? Colors.black : AppColors.textPrimary),
      side: BorderSide(color: isSelected ? AppColors.accentCyan : AppColors.cardBorder),
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _connectionType = type;
            if (type.contains('Bridge')) {
              _serviceList = 'Other';
            } else {
              _serviceList = 'INTERNET';
            }
          });
        }
      },
    );
  }

  Widget _buildServiceChip(String value, String label) {
    final isSelected = _serviceList == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.accentEmerald,
      backgroundColor: AppColors.backgroundElevated,
      labelStyle: TextStyle(color: isSelected ? Colors.black : AppColors.textPrimary),
      side: BorderSide(color: isSelected ? AppColors.accentEmerald : AppColors.cardBorder),
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _serviceList = value;
          });
        }
      },
    );
  }

  Widget _buildPortCheckbox(String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: value,
                  activeColor: AppColors.accentCyan,
                  checkColor: Colors.black,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => onChanged(v ?? false),
                ),
              ),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
