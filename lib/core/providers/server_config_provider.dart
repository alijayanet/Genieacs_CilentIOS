import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfigProvider extends ChangeNotifier {
  String _genieAcsUrl = 'http://192.168.8.89:7557';
  String _genieAcsUser = 'root';
  String _genieAcsPass = 'goodlife';

  bool _isLoggedIn = false;
  bool _isLoaded = false;

  String get genieAcsUrl => _genieAcsUrl;
  String get genieAcsUser => _genieAcsUser;
  String get genieAcsPass => _genieAcsPass;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoaded => _isLoaded;

  ServerConfigProvider() {
    loadConfig();
  }

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _genieAcsUrl = prefs.getString('genieacs_url') ?? 'http://192.168.8.89:7557';
    _genieAcsUser = prefs.getString('genieacs_user') ?? 'root';
    _genieAcsPass = prefs.getString('genieacs_pass') ?? 'goodlife';
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setLoggedIn(bool value) async {
    _isLoggedIn = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', value);
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
  }

  Future<void> saveGenieAcsConfig({
    required String url,
    required String user,
    required String pass,
  }) async {
    _genieAcsUrl = url;
    _genieAcsUser = user;
    _genieAcsPass = pass;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('genieacs_url', url);
    await prefs.setString('genieacs_user', user);
    await prefs.setString('genieacs_pass', pass);
  }

  Future<void> resetToDefault() async {
    _genieAcsUrl = 'http://192.168.8.89:7557';
    _genieAcsUser = 'root';
    _genieAcsPass = 'goodlife';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
