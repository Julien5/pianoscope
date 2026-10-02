import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pianoscope.dart';

class UserSettingsProvider extends ChangeNotifier {
  static const String _keyLocale = 'local';
  static const String _keyKeySignature = 'key_signature';

  late final SharedPreferencesWithCache _prefs;

  /// Initialize the service once when the app launches.
  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_keyLocale, _keyKeySignature},
      ),
    );
  }

  String get _localeSetting => _prefs.getString(_keyLocale) ?? "en";
  Locale get locale => Locale(_localeSetting);
  Future<void> setLocale(String value) async {
    if (_localeSetting == value) return;
    await _prefs.setString(_keyLocale, value);
    notifyListeners();
  }

  int get _keySignatureSetting => _prefs.getInt(_keyKeySignature) ?? 0;
  KeySignature get keySignature =>
      KeySignature(accidentals: _keySignatureSetting);
  Future<void> setKeySignature(KeySignature value) async {
    if (_keySignatureSetting == value.accidentals) return;
    await _prefs.setInt(_keyKeySignature, value.accidentals);
    notifyListeners();
  }
}
