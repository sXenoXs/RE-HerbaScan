import 'dart:html' as html;
import 'package:supabase_flutter/supabase_flutter.dart';

class WebSessionStorage extends LocalStorage {
  static const _key = 'supabase.auth.token';

  const WebSessionStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return html.window.sessionStorage.containsKey(_key);
  }

  @override
  Future<String?> accessToken() async {
    return html.window.sessionStorage[_key];
  }

  @override
  Future<void> removePersistedSession() async {
    html.window.sessionStorage.remove(_key);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    html.window.sessionStorage[_key] = persistSessionString;
  }
}

LocalStorage? getWebSessionStorage() => const WebSessionStorage();
