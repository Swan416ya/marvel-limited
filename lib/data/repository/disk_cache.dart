import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 简单的 JSON 缓存（App 文档目录下按 key 存文件，带 TTL）。
///
/// 背景：wiki 补全一次要发几十个请求（限并发 6 也要转一两分钟），
/// 官网大响应又经常被 CDN 掐断。命中缓存时这些页面秒开。
/// Web 平台没有文件系统，退回 localStorage（shared_preferences）——
/// 否则浏览器里每次打开都要重新拉一遍几百 KB 的日历接口，
/// 就是「打开很慢」的来源。
class DiskCache {
  String? _root;

  /// Web 上的存储键前缀，和文件缓存共用同一套 key。
  static const _webPrefix = 'cache:';

  /// localStorage 一般只有 5MB，单条太大就不写（避免把配额撑爆）。
  static const _webMaxBytes = 900 * 1024;

  Future<String?> get _dir async {
    if (kIsWeb) return null;
    var root = _root;
    if (root != null) return root;
    try {
      final docs = await getApplicationDocumentsDirectory();
      root = '${docs.path}/cache';
      await Directory(root).create(recursive: true);
      _root = root;
      return root;
    } catch (_) {
      // 目录拿不到（极端环境）就当没有磁盘缓存
      _root = '';
      return null;
    }
  }

  /// 读缓存。过期或不存在返回 null。返回的是写入时的任意 JSON 结构。
  Future<Object?> read(String key, {required Duration ttl}) async {
    if (kIsWeb) return _webRead(key, ttl);
    final dir = await _dir;
    if (dir == null || dir.isEmpty) return null;
    final file = File('$dir/${_safeName(key)}.json');
    if (!await file.exists()) return null;
    try {
      final map = json.decode(await file.readAsString());
      if (map is! Map) return null;
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().difference(savedAt) > ttl) {
        return null;
      }
      return map['data'];
    } catch (_) {
      return null;
    }
  }

  /// 写缓存。data 必须可 JSON 序列化。
  Future<void> write(String key, Object? data) async {
    if (kIsWeb) return _webWrite(key, data);
    final dir = await _dir;
    if (dir == null || dir.isEmpty) return;
    try {
      final file = File('$dir/${_safeName(key)}.json');
      await file.writeAsString(jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'data': data,
      }));
    } catch (_) {
      // 磁盘满了之类——缓存写失败不影响主流程
    }
  }

  Future<Object?> _webRead(String key, Duration ttl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_webPrefix$key');
      if (raw == null) return null;
      final map = json.decode(raw);
      if (map is! Map) return null;
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > ttl) {
        return null;
      }
      return map['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> _webWrite(String key, Object? data) async {
    try {
      final payload = jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'data': data,
      });
      if (payload.length > _webMaxBytes) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webPrefix$key', payload);
    } catch (_) {
      // 配额满了之类——缓存写失败不影响主流程
    }
  }

  /// key 转文件名：只留安全字符，太长就截断加哈希。
  static String _safeName(String key) {
    final cleaned = key.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    if (cleaned.length <= 60) return cleaned;
    return '${cleaned.substring(0, 50)}_${key.hashCode & 0x7fffffff}';
  }
}