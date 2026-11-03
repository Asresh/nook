import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class Session {
  const Session({
    required this.identity,
    required this.displayName,
    required this.isDemo,
  });

  final String identity;
  final String displayName;
  final bool isDemo;
}

class SessionStore {
  static const _nameKey = 'nook.displayName';
  static const _identityKey = 'nook.identity';

  Future<Session?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey)?.trim();
    if (name == null || name.isEmpty) return null;

    if (AppConfig.hasSupabase) {
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;
      if (user == null) return null;
      return Session(identity: user.id, displayName: name, isDemo: false);
    }

    final identity = prefs.getString(_identityKey);
    if (identity == null || identity.isEmpty) return null;
    return Session(identity: identity, displayName: name, isDemo: true);
  }

  Future<Session> create(String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    final name = displayName.trim();

    if (AppConfig.hasSupabase) {
      final auth = Supabase.instance.client.auth;
      var user = auth.currentUser;
      if (user == null) {
        final response = await auth.signInAnonymously();
        user = response.user;
      }
      if (user == null) {
        throw Exception('Could not create a session.');
      }
      await prefs.setString(_nameKey, name);
      return Session(identity: user.id, displayName: name, isDemo: false);
    }

    final identity = prefs.getString(_identityKey) ?? _newDemoIdentity();
    await prefs.setString(_identityKey, identity);
    await prefs.setString(_nameKey, name);
    return Session(identity: identity, displayName: name, isDemo: true);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    if (AppConfig.hasSupabase) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  String _newDemoIdentity() {
    final random = Random.secure();
    final suffix = List.generate(
      6,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return 'guest-$suffix';
  }
}
