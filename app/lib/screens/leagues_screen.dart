import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';

/// Weekly Lock-in leagues: create/join with a code, ranked by focus minutes
/// this week. Top 5 get coins every Monday (50/40/30/20/10), automatically.
class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  List<League> _leagues = [];
  final Map<String, List<Standing>> _standings = {};
  bool _loading = true;
  bool _optOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await widget.api.me();
      final leagues = await widget.api.leagues();
      final standings = <String, List<Standing>>{};
      for (final l in leagues) {
        standings[l.id] = await widget.api.leagueStandings(l.id);
      }
      if (!mounted) return;
      setState(() {
        _optOut = me.competeOptOut;
        _leagues = leagues;
        _standings
          ..clear()
          ..addAll(standings);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _create() async {
    final name = await _prompt('Create league', 'League name', 'e.g. Study Gang');
    if (name == null || name.trim().isEmpty) return;
    try {
      final league = await widget.api.createLeague(name.trim());
      _snack('League created! Share code ${league.code} with friends.');
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _join() async {
    final code = await _prompt('Join league', 'Invite code', 'e.g. 1AFEAD');
    if (code == null || code.trim().isEmpty) return;
    try {
      await widget.api.joinLeague(code.trim());
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<String?> _prompt(String title, String label, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Leagues', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        expand: true,
                        onPressed: _create,
                        icon: Icons.add,
                        label: 'Create',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _join,
                        icon: const Icon(Icons.tag, size: 18),
                        label: const Text('Join with code'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: !_optOut,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text('Compete on leaderboards',
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Turn off to hide your minutes from every league.',
                    style: GoogleFonts.outfit(fontSize: 12),
                  ),
                  onChanged: (v) async {
                    setState(() => _optOut = !v);
                    try {
                      await widget.api.setCompeteOptOut(!v);
                      _load();
                    } catch (e) {
                      _snack(e.toString());
                    }
                  },
                ),
                const SizedBox(height: 4),
                if (_leagues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        'No leagues yet.\nCreate one and share the code!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  for (final l in _leagues) _leagueCard(l),
                const SizedBox(height: 12),
                Text(
                  'Every Monday the top 5 of each league earn bonus coins: '
                  '50 / 40 / 30 / 20 / 10. Rewards from multiple leagues stack.',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }

  Widget _leagueCard(League l) {
    final scheme = Theme.of(context).colorScheme;
    final standings = _standings[l.id] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 17)),
              ),
              ActionChip(
                avatar: const Icon(Icons.copy, size: 14),
                label: Text(l.code,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: l.code));
                  _snack('Code ${l.code} copied — send it to a friend!');
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) async {
                  if (v == 'leave') {
                    try {
                      await widget.api.leaveLeague(l.id);
                      _load();
                    } catch (e) {
                      _snack(e.toString());
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'leave', child: Text('Leave league')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (standings.isEmpty)
            Text('No competitors yet this week.',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: scheme.onSurfaceVariant))
          else
            for (final s in standings.take(8)) _standingRow(s),
        ],
      ),
    );
  }

  Widget _standingRow(Standing s) {
    final scheme = Theme.of(context).colorScheme;
    final isMe = s.userId == widget.api.myId;
    final medal = switch (s.rank) {
      1 => const Color(0xFFFACC15),
      2 => const Color(0xFFB8BDC7),
      3 => const Color(0xFFB45309),
      _ => scheme.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#${s.rank}',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, color: medal)),
          ),
          Expanded(
            child: Text(
              isMe ? '${s.displayName} (you)' : s.displayName,
              style: GoogleFonts.outfit(
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                color: isMe ? scheme.primary : null,
              ),
            ),
          ),
          Text('${s.minutes} min',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
