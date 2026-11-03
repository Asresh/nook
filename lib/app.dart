import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'data/rooms_repository.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/session.dart';
import 'theme/nook_theme.dart';

class NookApp extends StatefulWidget {
  const NookApp({super.key, required this.store, this.initialSession});

  final SessionStore store;
  final Session? initialSession;

  @override
  State<NookApp> createState() => _NookAppState();
}

class _NookAppState extends State<NookApp> {
  late Session? _session = widget.initialSession;
  late final RoomsRepository _rooms = AppConfig.hasSupabase
      ? const SupabaseRoomsRepository()
      : DemoRoomsRepository();

  Future<void> _signOut() async {
    await widget.store.signOut();
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return MaterialApp(
      title: 'Nook',
      debugShowCheckedModeBanner: false,
      theme: buildNookTheme(),
      home: session == null
          ? WelcomeScreen(
              store: widget.store,
              onSession: (next) => setState(() => _session = next),
            )
          : HomeScreen(
              session: session,
              repository: _rooms,
              onSignOut: _signOut,
            ),
    );
  }
}
