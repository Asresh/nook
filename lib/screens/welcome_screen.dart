import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme/nook_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.store,
    required this.onSession,
  });

  final SessionStore store;
  final ValueChanged<Session> onSession;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Use at least 2 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = await widget.store.create(name);
      if (!mounted) return;
      widget.onSession(session);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.toLowerCase().contains('anonymous')) {
      return 'Enable anonymous sign-ins in Supabase (Authentication → Providers → Anonymous) and try again.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: NookColors.accentSoft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'n',
                        style: TextStyle(
                          color: NookColors.accent,
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'nook',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A quiet corner to talk.\nPull up, no agenda needed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NookColors.muted,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'What should people call you?',
                      hintText: 'First name or nickname',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: NookColors.danger,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: NookColors.onAccent,
                            ),
                          )
                        : const Text('Enter Nook'),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'No feed. No followers. Just a room and a voice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NookColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
