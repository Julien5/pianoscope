import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pianoscope.dart';

class UserSettingsProvider extends ChangeNotifier {
  static const String _keyLocale = 'local';
  static const String _keyKeySignature = 'key_signature';
  static const String _keySplitPoint = 'key_split_point';
  static const String _keyEmail = 'email';
  static const String _keyHideMicrophoneWarning = 'hide_microphone_warning';

  late final SharedPreferencesWithCache _prefs;

  /// Initialize the service once when the app launches.
  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {
          _keyLocale,
          _keyKeySignature,
          _keySplitPoint,
          _keyEmail,
          _keyHideMicrophoneWarning,
        },
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

  int get _splitPointSetting => _prefs.getInt(_keySplitPoint) ?? 60;
  int get splitPoint => _splitPointSetting;
  Future<void> setSplitPoint(int value) async {
    if (_splitPointSetting == value) return;
    await _prefs.setInt(_keySplitPoint, value);
    notifyListeners();
  }

  String get _emailSetting => _prefs.getString(_keyEmail) ?? '';
  String get email => _emailSetting;
  Future<void> setEmail(String value) async {
    if (_emailSetting == value) return;
    await _prefs.setString(_keyEmail, value);
    notifyListeners();
  }

  bool get hideMicrophoneWarning =>
      _prefs.getBool(_keyHideMicrophoneWarning) ?? false;
  Future<void> setHideMicrophoneWarning(bool value) async {
    if (hideMicrophoneWarning == value) return;
    await _prefs.setBool(_keyHideMicrophoneWarning, value);
    notifyListeners();
  }
}
