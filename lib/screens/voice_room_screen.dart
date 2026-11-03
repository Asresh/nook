import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;

import '../config/app_config.dart';
import '../models/nook_room.dart';
import '../services/token_service.dart';
import '../state/session.dart';
import '../theme/nook_theme.dart';

class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({
    super.key,
    required this.room,
    required this.session,
  });

  final NookRoom room;
  final Session session;

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  static const _tokenService = TokenService(AppConfig.tokenEndpoint);

  Room? _livekit;
  bool _connecting = true;
  bool _micEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    Room? room;
    try {
      final credentials = await _tokenService.fetch(
        room: widget.room.id,
        identity: widget.session.identity,
        name: widget.session.displayName,
        fallbackUrl: AppConfig.livekitUrl,
      );

      room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      room.addListener(_handleRoomChange);
      await room.connect(credentials.url, credentials.token);

      if (!mounted) {
        await room.disconnect();
        await room.dispose();
        return;
      }

      setState(() {
        _livekit = room;
        _connecting = false;
      });

      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
        if (mounted) setState(() => _micEnabled = true);
      } catch (error) {
        if (mounted) _showMicError(error);
      }
    } catch (error) {
      if (room != null) {
        room.removeListener(_handleRoomChange);
        try {
          await room.disconnect();
        } catch (_) {
          // The connection never finished, so there is nothing to close.
        }
        await room.dispose();
      }
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = _friendlyError(error);
      });
    }
  }

  void _handleRoomChange() {
    if (mounted) setState(() {});
  }

  void _showMicError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Microphone unavailable: $error')),
    );
  }

  Future<void> _toggleMic() async {
    final room = _livekit;
    final local = room?.localParticipant;
    if (room == null || local == null) return;

    final next = !_micEnabled;
    try {
      await local.setMicrophoneEnabled(next);
      if (mounted) setState(() => _micEnabled = next);
    } catch (error) {
      if (mounted) _showMicError(error);
    }
  }

  @override
  void dispose() {
    final room = _livekit;
    if (room != null) {
      room.removeListener(_handleRoomChange);
      unawaited(room.disconnect());
      unawaited(room.dispose());
    }
    super.dispose();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Connection refused') ||
        text.contains('Failed to fetch')) {
      return 'Could not reach the local voice stack. Start LiveKit and the '
          'token server (./scripts/dev.sh), then try again.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final room = _livekit;
    final participants = <Participant>[
      if (room?.localParticipant != null) room!.localParticipant!,
      if (room != null) ...room.remoteParticipants.values,
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.room.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.room.topic.isNotEmpty)
              Text(
                widget.room.topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NookColors.muted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              _StatusPill(
                connecting: _connecting,
                count: participants.length,
                error: _error,
              ),
              const SizedBox(height: 22),
              Expanded(child: _buildStage(participants, room)),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage(List<Participant> participants, Room? room) {
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: NookColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: NookColors.danger,
                  size: 34,
                ),
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NookColors.muted,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Local dev: ./scripts/dev.sh',
                  style: TextStyle(color: NookColors.muted, fontSize: 11.5),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _join,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_connecting || room == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: NookColors.accent),
            SizedBox(height: 18),
            Text(
              'Opening the room…',
              style: TextStyle(color: NookColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 24,
          children: [
            for (final participant in participants)
              _ParticipantTile(
                participant: participant,
                isLocal: participant is LocalParticipant,
                micEnabled: participant is LocalParticipant && _micEnabled,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final connected = _livekit != null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              icon: _micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
              label: _micEnabled ? 'Mute' : 'Unmute',
              background: NookColors.surfaceHigh,
              foreground: NookColors.text,
              onPressed: connected ? _toggleMic : null,
            ),
            const SizedBox(width: 18),
            _ControlButton(
              icon: Icons.call_end_rounded,
              label: 'Leave',
              background: NookColors.danger,
              foreground: const Color(0xFF2A0A10),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Headphones recommended while testing on one machine.',
          style: TextStyle(color: NookColors.muted, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.connecting,
    required this.count,
    required this.error,
  });

  final bool connecting;
  final int count;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final active = !connecting && error == null;
    final label = error != null
        ? 'Not connected'
        : connecting
        ? 'Connecting…'
        : count == 1
        ? 'You are here alone for now'
        : '$count people in this room';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: error != null
                  ? NookColors.danger
                  : active
                  ? NookColors.live
                  : NookColors.muted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: NookColors.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.isLocal,
    required this.micEnabled,
  });

  final Participant participant;
  final bool isLocal;
  final bool micEnabled;

  @override
  Widget build(BuildContext context) {
    final rawName = participant.name.trim().isEmpty
        ? participant.identity
        : participant.name.trim();
    final name = isLocal ? '${rawName.split(' ').first} (you)' : rawName;
    final initial = rawName.isEmpty
        ? '?'
        : rawName.substring(0, 1).toUpperCase();
    final speaking = participant.isSpeaking;

    return SizedBox(
      width: 104,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NookColors.surfaceHigh,
              border: Border.all(
                color: speaking ? NookColors.live : Colors.transparent,
                width: 3,
              ),
              boxShadow: speaking
                  ? [
                      BoxShadow(
                        color: NookColors.live.withValues(alpha: 0.28),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: NookColors.text,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isLocal && !micEnabled) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.mic_off_rounded,
                  size: 13,
                  color: NookColors.muted,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: onPressed == null
              ? background.withValues(alpha: 0.45)
              : background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, color: foreground, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: NookColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
