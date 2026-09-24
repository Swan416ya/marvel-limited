import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 句柄：各域 mixin 共享同一个实例。
///
/// `load()` 之前 instance 为 null，各域的写入自动 no-op
/// （与拆分前 `_prefs?.setString…` 的行为一致）。
class PrefsStorage {
  SharedPreferences? instance;

  bool get isReady => instance != null;
}

/// 解码一条 JSON 存档；损坏条目按空对象兜底，别让一条坏数据拖垮整个列表。
T decodePrefsEntry<T>(String raw, T Function(Map) fromJson) {
  try {
    return fromJson(jsonDecode(raw) as Map);
  } catch (_) {
    return fromJson(const {});
  }
}
