import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'forum_api.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage;
  ForumRepository repository;
  List<Topic> bookmarks = [];
  List<Draft> drafts = [];
  ThemeMode themeMode = ThemeMode.system;
  String? username;
  AppState(
    this.prefs, {
    FlutterSecureStorage? secureStorage,
    ForumRepository? repository,
  }) : secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             mOptions: MacOsOptions(usesDataProtectionKeychain: false),
           ),
       repository = repository ?? DemoRepository() {
    _loadLocalData();
    themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == prefs.getString('theme'),
      orElse: () => ThemeMode.system,
    );
  }
  String get _scope => repository.isDemo ? 'demo' : 'live-$username';
  void _loadLocalData() {
    bookmarks = _parseItems('$_scope-bookmarks', Topic.fromJson);
    drafts = _parseItems('$_scope-drafts', Draft.fromJson);
  }

  List<T> _parseItems<T>(String key, T Function(Map<String, dynamic>) parse) {
    final result = <T>[];
    for (final item in _readList(key)) {
      try {
        result.add(parse(item));
      } catch (_) {
        // 单条损坏数据不能阻塞启动或丢弃其他可恢复记录。
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _readList(String key) {
    try {
      return (jsonDecode(prefs.getString(key) ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> restoreSession() async {
    if (!communityAccessEnabled || prefs.getBool('live_mode') != true) return;
    final key = await secureStorage.read(key: 'shuiyuan_api_key');
    final id = await secureStorage.read(key: 'shuiyuan_client_id');
    if (key != null && id != null) await connect(key, id);
  }

  Future<void> connect(String key, String clientId) async {
    if (!communityAccessEnabled)
      throw const ForumException('当前构建为离线体验版，尚未启用真实社区联调。');
    final next = DiscourseRepository(
      apiKey: key.trim(),
      clientId: clientId.trim(),
    );
    try {
      final user = await next.currentUser();
      await secureStorage.write(key: 'shuiyuan_api_key', value: key.trim());
      await secureStorage.write(
        key: 'shuiyuan_client_id',
        value: clientId.trim(),
      );
      await prefs.setBool('live_mode', true);
      repository.close();
      repository = next;
      username = user;
      _loadLocalData();
      notifyListeners();
    } catch (_) {
      next.close();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await secureStorage.delete(key: 'shuiyuan_api_key');
    await secureStorage.delete(key: 'shuiyuan_client_id');
    await prefs.setBool('live_mode', false);
    repository.close();
    repository = DemoRepository();
    username = null;
    _loadLocalData();
    notifyListeners();
  }

  bool isBookmarked(Topic t) => bookmarks.any((e) => e.id == t.id);
  Future<void> toggleBookmark(Topic t) async {
    final next = [...bookmarks];
    isBookmarked(t) ? next.removeWhere((e) => e.id == t.id) : next.add(t);
    await prefs.setString(
      '$_scope-bookmarks',
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    bookmarks = next;
    notifyListeners();
  }

  Future<void> saveDraft(Draft d) async {
    final next = [...drafts.where((e) => e.id != d.id), d];
    await prefs.setString(
      '$_scope-drafts',
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    drafts = next;
    notifyListeners();
  }

  Future<void> deleteDraft(String id) async {
    final next = drafts.where((e) => e.id != id).toList();
    await prefs.setString(
      '$_scope-drafts',
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    drafts = next;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    await prefs.setString('theme', mode.name);
    themeMode = mode;
    notifyListeners();
  }

  @override
  void dispose() {
    repository.close();
    super.dispose();
  }
}
