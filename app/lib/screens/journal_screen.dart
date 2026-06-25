import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'home_screen.dart' show categoryColors, categoryIcons;
import 'quest_detail_sheet.dart';

enum _Range { yesterday, week, month }

/// Journal = a stats dashboard plus a filterable list of recent solo quests.
/// (Friend challenges are counted in the dashboard but not the quest list.)
class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.onChanged,
  });

  final ApiClient api;
  final UserProfile profile;
  final Future<void> Function() onChanged;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  JournalStats? _stats;
  List<Quest>? _quests;
  _Range _range = _Range.week;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadQuests();
  }

  Future<void> _loadStats() async {
    try {
      final s = await widget.api.journalStats();
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  ({DateTime since, DateTime? until}) _bounds() {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.yesterday:
        return (since: startToday.subtract(const Duration(days: 1)), until: startToday);
      case _Range.week:
        return (since: startToday.subtract(const Duration(days: 7)), until: null);
      case _Range.month:
        return (since: startToday.subtract(const Duration(days: 30)), until: null);
    }
  }

  Future<void> _loadQuests() async {
    setState(() => _quests = null);
    final b = _bounds();
    try {
      final q = await widget.api.history(since: b.since, until: b.until);
      if (mounted) setState(() => _quests = q);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _openDetail(Quest q) async {
    await showQuestDetail(
      context,
      api: widget.api,
      quest: q,
      onComplete: (_, {bool withPhoto = false}) async {},
      onSkip: (_) async {},
      onRestore: (_) async {},
      onUndo: (quest) async {
        try {
          await widget.api.undoQuest(quest);
          await widget.onChanged();
          await _loadStats();
          await _loadQuests();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.profile;
    final s = _stats;
    return RefreshIndicator(
      onRefresh: () async {
        await _loadStats();
        await _loadQuests();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // ── Weekly activity chart (the hero visual) ────────────
          _activityCard(s),
          const SizedBox(height: 14),
          // ── Compact inline stat strip ──────────────────────────
          _statStrip(p, s),
          const SizedBox(height: 18),
          // ── Lock-in summary ────────────────────────────────────
          _lockInCard(s),
          const SizedBox(height: 22),

          // ── Category breakdown ────────────────────────────────
          if (s != null && s.byCategory.isNotEmpty) ...[
            Text('By category',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 16)),
            const SizedBox(height: 10),
            _categoryBars(s.byCategory),
            const SizedBox(height: 22),
          ],

          // ── Recent quests + range dropdown ────────────────────
          Row(
            children: [
              Text('Recent quests',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 20)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_Range>(
                    value: _range,
                    isDense: true,
                    borderRadius: BorderRadius.circular(14),
                    style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface),
                    items: const [
                      DropdownMenuItem(
                          value: _Range.yesterday, child: Text('Yesterday')),
                      DropdownMenuItem(
                          value: _Range.week, child: Text('Last week')),
                      DropdownMenuItem(
                          value: _Range.month, child: Text('Last month')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _range = v);
                        _loadQuests();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _questsList(),
        ],
      ),
    );
  }

  /// Hero card: a 7-day bar chart of completions, with today highlighted.
  Widget _activityCard(JournalStats? s) {
    final scheme = Theme.of(context).colorScheme;
    final data = s?.weekActivity ?? List.filled(7, 0);
    final week = data.length == 7 ? data : List.filled(7, 0);
    final maxVal = week.fold<int>(1, (m, v) => v > m ? v : m);
    final total = week.fold<int>(0, (a, b) => a + b);

    // Day initials ending today (index 6 = today).
    const initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    final labels = [
      for (var i = 6; i >= 0; i--)
        initials[today.subtract(Duration(days: i)).weekday - 1]
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THIS WEEK',
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: '$total ',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface)),
                      TextSpan(
                          text: total == 1 ? 'quest done' : 'quests done',
                          style: GoogleFonts.outfit(
                              fontSize: 14, color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bar area (numbers + bars), kept separate from the day labels so a
          // tall bar can never clip the label row beneath it.
          SizedBox(
            height: 74,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(week[i] > 0 ? '${week[i]}' : '',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 3),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: week[i] / maxVal),
                            duration: Duration(milliseconds: 500 + i * 60),
                            curve: Curves.easeOutCubic,
                            builder: (context, t, _) => Container(
                              height: 8 + 44 * t,
                              decoration: BoxDecoration(
                                gradient: i == 6
                                    ? accentGradient(scheme.primary)
                                    : null,
                                color: i == 6
                                    ? null
                                    : (week[i] > 0
                                        ? scheme.primary.withValues(alpha: 0.45)
                                        : scheme.surfaceContainerHighest),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(labels[i],
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight:
                                i == 6 ? FontWeight.w700 : FontWeight.w500,
                            color: i == 6
                                ? scheme.primary
                                : scheme.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Lock-in summary: total study time + number of pomodoro sessions.
  Widget _lockInCard(JournalStats? s) {
    final scheme = Theme.of(context).colorScheme;
    final timeLabel = s?.lockinTimeLabel ?? '—';
    final sessions = s?.lockinSessions;
    final weekMin = s?.lockinMinutesWeek ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: accentGradient(scheme.primary),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.lock, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text('Lock-in',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 16)),
              const Spacer(),
              if (weekMin > 0)
                Text('$weekMin min this week',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _lockInStat(
                    Icons.timer, timeLabel, 'studied', const Color(0xFF38BDF8)),
              ),
              Container(
                  width: 1,
                  height: 38,
                  color: scheme.outlineVariant.withValues(alpha: 0.3)),
              Expanded(
                child: _lockInStat(Icons.local_fire_department,
                    '${sessions ?? '—'}', 'sessions', const Color(0xFFFF8A4C)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lockInStat(IconData icon, String value, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12.5, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  /// Compact pill chips instead of big number boxes.
  Widget _statStrip(UserProfile p, JournalStats? s) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(Icons.bolt, '${p.xp} XP', const Color(0xFFFACC15)),
        _chip(Icons.toll, '${p.coins}', const Color(0xFFF5A623)),
        _chip(Icons.check_circle, '${s?.soloCompleted ?? '—'} done',
            const Color(0xFF4ADE80)),
        _chip(Icons.local_fire_department, '${s?.activeDays ?? '—'} active days',
            const Color(0xFFFF8A4C)),
        _chip(Icons.group, '${s?.duoCompleted ?? '—'} challenges',
            const Color(0xFFF472B6)),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _categoryBars(Map<String, int> byCat) {
    final scheme = Theme.of(context).colorScheme;
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;
    return Column(
      children: [
        for (final e in entries.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(categoryIcons[e.key] ?? Icons.star,
                    size: 16, color: categoryColors[e.key] ?? scheme.primary),
                const SizedBox(width: 8),
                SizedBox(
                  width: 84,
                  child: Text(e.key,
                      style: GoogleFonts.outfit(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: e.value / max,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHigh,
                      color: categoryColors[e.key] ?? scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _questsList() {
    final scheme = Theme.of(context).colorScheme;
    final quests = _quests;
    if (quests == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (quests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('No quests completed in this period.',
              style: GoogleFonts.outfit(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    return Column(
      children: [
        for (final q in quests)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _questRow(q),
          ),
      ],
    );
  }

  Widget _questRow(Quest q) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryColors[q.category] ?? scheme.primary;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(q),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: accentGradient(accent),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(categoryIcons[q.category] ?? Icons.star,
                    size: 17, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.title,
                        style: GoogleFonts.outfit(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    Text(_when(q.completedAt),
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text('+${q.xpReward}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFACC15))),
            ],
          ),
        ),
      ),
    );
  }

  String _when(String? iso) {
    if (iso == null) return 'completed';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'completed';
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final diff = t0.difference(d).inDays;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
