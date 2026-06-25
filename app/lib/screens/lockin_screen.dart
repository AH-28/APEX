import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../theme.dart';
import 'leagues_screen.dart';
import 'study_space_screen.dart';

/// Lock in: pomodoro focus sessions → Lock-in coins → study-space shop,
/// plus weekly league leaderboards.
class LockInScreen extends StatefulWidget {
  const LockInScreen({
    super.key,
    required this.api,
    required this.coins,
    required this.onCoinsChanged,
  });

  final ApiClient api;
  final int coins;
  final Future<void> Function() onCoinsChanged;

  @override
  State<LockInScreen> createState() => _LockInScreenState();
}

enum _Phase { idle, focus, brk }

class _LockInScreenState extends State<LockInScreen> {
  int _focusMinutes = 50;
  int _breakMinutes = 10;
  _Phase _phase = _Phase.idle;
  int _remaining = 0; // seconds
  Timer? _timer;
  int _weeklyMinutes = 0;

  @override
  void initState() {
    super.initState();
    _loadWeekly();
  }

  Future<void> _loadWeekly() async {
    try {
      final m = await widget.api.weeklyFocusMinutes();
      if (mounted) setState(() => _weeklyMinutes = m);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _phase = _Phase.focus;
      _remaining = _focusMinutes * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (_remaining > 1) {
      setState(() => _remaining--);
      return;
    }
    if (_phase == _Phase.focus) {
      // Focus complete → award coins, move to break.
      _timer?.cancel();
      try {
        final res = await widget.api
            .completeFocusSession(_focusMinutes, _breakMinutes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(Icons.toll, color: Color(0xFFFACC15)),
                const SizedBox(width: 10),
                Text('Locked in! +${res.coinsEarned} coins '
                    '(${res.totalCoins} total)'),
              ],
            ),
          ));
        }
        await widget.onCoinsChanged();
        _loadWeekly();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
      if (!mounted) return;
      if (_breakMinutes == 0) {
        setState(() => _phase = _Phase.idle);
        return;
      }
      setState(() {
        _phase = _Phase.brk;
        _remaining = _breakMinutes * 60;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _timer?.cancel();
      setState(() => _phase = _Phase.idle);
    }
  }

  void _giveUp() {
    _timer?.cancel();
    setState(() => _phase = _Phase.idle);
  }

  String get _clock {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Coin balance + weekly stat row.
        Row(
          children: [
            _statChip(Icons.toll, '${widget.coins} coins', const Color(0xFFFACC15)),
            const SizedBox(width: 8),
            _statChip(Icons.timer, '$_weeklyMinutes min this week',
                scheme.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: 18),

        // ── Timer card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(
                switch (_phase) {
                  _Phase.idle => 'READY TO LOCK IN?',
                  _Phase.focus => 'LOCKED IN',
                  _Phase.brk => 'BREAK TIME',
                },
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: _phase == _Phase.focus
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 210,
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 210,
                      height: 210,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: _phase == _Phase.idle
                              ? 1.0
                              : _remaining /
                                  ((_phase == _Phase.focus
                                          ? _focusMinutes
                                          : _breakMinutes) *
                                      60),
                        ),
                        duration: const Duration(milliseconds: 400),
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: scheme.surfaceContainerHigh,
                          color: _phase == _Phase.brk
                              ? const Color(0xFF4ADE80)
                              : scheme.primary,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _phase == _Phase.idle
                              ? '$_focusMinutes:00'
                              : _clock,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _phase == _Phase.idle
                              ? '+${(_focusMinutes / 5).round()} coins'
                              : _phase == _Phase.focus
                                  ? 'stay with it'
                                  : 'breathe',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_phase == _Phase.idle) ...[
                _durationSlider(
                  'Lock in',
                  _focusMinutes,
                  10,
                  120,
                  (v) => setState(() => _focusMinutes = v),
                ),
                _durationSlider(
                  'Break',
                  _breakMinutes,
                  0,
                  30,
                  (v) => setState(() => _breakMinutes = v),
                ),
                const SizedBox(height: 8),
                GradientButton(
                  expand: true,
                  onPressed: _start,
                  icon: Icons.lock,
                  label: 'Lock in',
                ),
              ] else
                TextButton.icon(
                  onPressed: _giveUp,
                  icon: const Icon(Icons.close),
                  label: Text(
                      _phase == _Phase.focus ? 'Give up (no coins)' : 'Skip break'),
                  style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Links to study space & leagues ────────────────────────
        Row(
          children: [
            Expanded(
              child: _navCard(
                context,
                icon: Icons.desktop_windows,
                title: 'Study space',
                subtitle: 'Spend your coins',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudySpaceScreen(api: widget.api),
                    ),
                  );
                  widget.onCoinsChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _navCard(
                context,
                icon: Icons.emoji_events,
                title: 'Leagues',
                subtitle: 'Weekly leaderboards',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeaguesScreen(api: widget.api),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style:
                  GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _durationSlider(
      String label, int value, int min, int max, void Function(int) onChanged) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: scheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min) ~/ 5,
            onChanged: (v) => onChanged((v / 5).round() * 5),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text('$value min',
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _navCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: accentGradient(scheme.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 15)),
                Text(subtitle,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
