import 'package:flutter/material.dart';

import '../data/rooms_repository.dart';
import '../models/nook_room.dart';
import '../state/session.dart';
import '../theme/nook_theme.dart';
import '../widgets/room_card.dart';
import 'voice_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.onSignOut,
  });

  final Session session;
  final RoomsRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NookRoom> _rooms = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rooms = await widget.repository.listRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('rooms') && text.contains('does not exist')) {
      return 'The rooms table is missing. Run supabase/schema.sql in your Supabase project.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  Future<void> _openCreateSheet() async {
    final draft = await showModalBottomSheet<_RoomDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NookColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _CreateRoomSheet(),
    );
    if (draft == null) return;

    try {
      await widget.repository.createRoom(
        name: draft.name,
        topic: draft.topic,
        createdBy: widget.session.identity,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create room: $error')),
      );
    }
  }

  Future<void> _joinRoom(NookRoom room) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            VoiceRoomScreen(room: room, session: widget.session),
      ),
    );
    if (mounted) _load();
  }

  String get _firstName {
    final parts = widget.session.displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? widget.session.displayName : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const Text(
              'nook',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: NookColors.accentSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'voice rooms',
                style: TextStyle(
                  color: NookColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) {
              if (value == 'signout') widget.onSignOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  'Signed in as ${widget.session.displayName}',
                  style: const TextStyle(color: NookColors.muted, fontSize: 12),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'signout',
                child: Text('Change name'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: NookColors.accent,
        foregroundColor: NookColors.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New room',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: NookColors.accent,
        backgroundColor: NookColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Text(
              'Hey, $_firstName',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find a quiet corner and pull up.',
              style: TextStyle(color: NookColors.muted, fontSize: 15),
            ),
            if (widget.session.isDemo) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: NookColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NookColors.surfaceHigh),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: NookColors.muted,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo mode: rooms are stored locally. Voice runs on the '
                        'LiveKit dev server on this laptop.',
                        style: TextStyle(
                          color: NookColors.muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            Row(
              children: [
                const Text(
                  'Rooms open now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NookColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              _MessageCard(
                icon: Icons.cloud_off_rounded,
                message: _error!,
                actionLabel: 'Try again',
                onAction: _load,
              )
            else if (!_loading && _rooms.isEmpty)
              const _MessageCard(
                icon: Icons.nightlight_round,
                message:
                    'No rooms yet. Open the first one and see who shows up.',
              )
            else
              ..._rooms.map(
                (room) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RoomCard(room: room, onJoin: () => _joinRoom(room)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: NookColors.muted, size: 22),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: NookColors.muted,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: NookColors.accent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomDraft {
  const _RoomDraft({required this.name, required this.topic});

  final String name;
  final String topic;
}

class _CreateRoomSheet extends StatefulWidget {
  const _CreateRoomSheet();

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  final _name = TextEditingController();
  final _topic = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _topic.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _RoomDraft(name: name, topic: _topic.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NookColors.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Open a room',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Rooms are live the moment you create them.',
            style: TextStyle(color: NookColors.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Room name',
              hintText: 'Late Night Talks',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topic,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Topic (optional)',
              hintText: 'No agenda. Just talk.',
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _submit, child: const Text('Create room')),
        ],
      ),
    );
  }
}
