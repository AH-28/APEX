import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'home_screen.dart' show categoryIcons, categoryColors;

/// Expanded quest view, opened by tapping a quest card.
///
/// Shows the full description, all metadata, the proof photo (if any), and
/// the actions for the quest's current state — including Undo for
/// completed quests.
Future<void> showQuestDetail(
  BuildContext context, {
  required ApiClient api,
  required Quest quest,
  required Future<void> Function(Quest, {bool withPhoto}) onComplete,
  required Future<void> Function(Quest) onSkip,
  required Future<void> Function(Quest) onUndo,
  required Future<void> Function(Quest) onRestore,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _QuestDetailSheet(
      api: api,
      quest: quest,
      onComplete: onComplete,
      onSkip: onSkip,
      onUndo: onUndo,
      onRestore: onRestore,
    ),
  );
}

class _QuestDetailSheet extends StatelessWidget {
  const _QuestDetailSheet({
    required this.api,
    required this.quest,
    required this.onComplete,
    required this.onSkip,
    required this.onUndo,
    required this.onRestore,
  });

  final ApiClient api;
  final Quest quest;
  final Future<void> Function(Quest, {bool withPhoto}) onComplete;
  final Future<void> Function(Quest) onSkip;
  final Future<void> Function(Quest) onUndo;
  final Future<void> Function(Quest) onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryColors[quest.category] ?? scheme.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Hero header: big tinted icon + title + category.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: accentGradient(accent),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    categoryIcons[quest.category] ?? Icons.star,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quest.category,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (quest.isCompleted) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Completed${_completedWhen()}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('The quest', style: _sectionStyle(context)),
            const SizedBox(height: 8),
            Text(
              quest.description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),
            Text('Details', style: _sectionStyle(context)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _detail(
                  context,
                  Icons.bolt,
                  '${quest.xpReward} XP reward',
                  color: Colors.amber,
                ),
                _detail(
                  context,
                  Icons.schedule,
                  '~${quest.estMinutes} minutes',
                ),
                _detail(
                  context,
                  Icons.speed,
                  quest.difficulty,
                  color: switch (quest.difficulty) {
                    'Easy' => Colors.green,
                    'Medium' => Colors.orange,
                    _ => Colors.redAccent,
                  },
                ),
                _detail(
                  context,
                  quest.requiresPhoto
                      ? Icons.photo_camera
                      : Icons.no_photography_outlined,
                  quest.requiresPhoto
                      ? 'Photo proof encouraged'
                      : 'No photo needed',
                ),
                _detail(context, Icons.event, quest.date),
              ],
            ),
            if (quest.isCompleted && quest.photoPath != null) ...[
              const SizedBox(height: 24),
              Text('Your proof', style: _sectionStyle(context)),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: api.photoUrl(quest.photoPath!),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      snap.data!,
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 80,
                        child: Center(child: Text('Could not load photo')),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 32),
            // Actions for the quest's current state.
            if (quest.status == 'active') ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onComplete(quest, withPhoto: quest.requiresPhoto);
                },
                icon: Icon(
                  quest.requiresPhoto ? Icons.photo_camera : Icons.check,
                ),
                label: Text(
                  quest.requiresPhoto ? 'Complete with photo' : 'Mark as done',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onSkip(quest);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Skip this quest'),
              ),
            ] else if (quest.isCompleted)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onUndo(quest);
                },
                icon: const Icon(Icons.undo),
                label: Text('Undo — give back ${quest.xpReward} XP'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: scheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
            else if (quest.status == 'skipped')
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);
                  onRestore(quest);
                },
                icon: const Icon(Icons.replay),
                label: const Text('Restore this quest'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              )
            else
              Center(
                child: Text(
                  'This quest was ${quest.status}.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _completedWhen() {
    final raw = quest.completedAt;
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return ' on ${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} at $h:$m';
  }

  TextStyle? _sectionStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
      );

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
