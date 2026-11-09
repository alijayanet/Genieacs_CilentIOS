class WanItem {
  final int instanceIndex;
  final String name;
  final String connectionType;
  final String username;
  final bool isEnabled;
  final String ipAddress;
  final String status;
  final int? vlanId;

  const WanItem({
    required this.instanceIndex,
    required this.name,
    required this.connectionType,
    this.username = '',
    this.isEnabled = true,
    this.ipAddress = '-',
    this.status = 'Unknown',
    this.vlanId,
  });

  String get ip => ipAddress;
  String get slot => connectionType.toLowerCase().contains('ip') ? 'IP' : 'PPP';
}

class WanConfigParams {
  final bool isNewInstance;
  final String wanSlot; // "PPP" or "IP"
  final int wanIndex;
  final String connectionType; // "PPPoE_Routed", "IP_Routed", "PPPoE_Bridged", "IP_Bridged"
  final String username;
  final String password;
  final bool vlanEnabled;
  final int vlanId;
  final String serviceList; // "INTERNET", "TR069,INTERNET", "Other"
  final bool bindLan1;
  final bool bindLan2;
  final bool bindLan3;
  final bool bindLan4;
  final bool bindWlan1;
  final bool bindWlan2;
  final bool bindWlan3;
  final bool bindWlan4;
  final String manufacturer;

  const WanConfigParams({
    required this.isNewInstance,
    this.wanSlot = 'PPP',
    this.wanIndex = 1,
    this.connectionType = 'PPPoE_Routed',
    this.username = '',
    this.password = '',
    this.vlanEnabled = false,
    this.vlanId = 0,
    this.serviceList = 'INTERNET',
    this.bindLan1 = true,
    this.bindLan2 = true,
    this.bindLan3 = true,
    this.bindLan4 = true,
    this.bindWlan1 = true,
    this.bindWlan2 = false,
    this.bindWlan3 = false,
    this.bindWlan4 = false,
    this.manufacturer = 'ZTE',
  });
}


class ConnectedClient {
  final String hostName;
  final String ipAddress;
  final String macAddress;

  const ConnectedClient({
    required this.hostName,
    required this.ipAddress,
    required this.macAddress,
  });
}
