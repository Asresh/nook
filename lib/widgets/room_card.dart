import 'package:flutter/material.dart';

import '../models/nook_room.dart';
import '../theme/nook_theme.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, required this.onJoin});

  final NookRoom room;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final name = room.name.trim();
    final initial = name.isEmpty ? 'N' : name.substring(0, 1).toUpperCase();

    return Material(
      color: NookColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onJoin,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: NookColors.accentSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: NookColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (room.topic.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        room.topic,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NookColors.muted,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: NookColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(
                    color: NookColors.onAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
