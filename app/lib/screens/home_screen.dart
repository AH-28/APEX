import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../models.dart';
import '../onboarding.dart';
import '../theme.dart';
import 'friends_screen.dart';
import 'journal_screen.dart';
import 'lockin_screen.dart';
import 'profile_screen.dart';
import 'quest_detail_sheet.dart';

const categoryIcons = <String, IconData>{
  'Adventure': Icons.explore,
  'Photography': Icons.photo_camera,
  'Fitness': Icons.fitness_center,
  'Learning': Icons.school,
  'Social': Icons.people,
  'Creativity': Icons.palette,
  'Productivity': Icons.check_circle,
  'Food': Icons.restaurant,
  'Mindfulness': Icons.self_improvement,
  'Nature': Icons.park,
  'Kindness': Icons.favorite,
  'Music': Icons.music_note,
};

const categoryColors = <String, Color>{
  'Adventure': Color(0xFFFFB04D),
  'Photography': Color(0xFF38BDF8),
  'Fitness': Color(0xFFFF5A5F),
  'Learning': Color(0xFFC084FC),
  'Social': Color(0xFF2DD4BF),
  'Creativity': Color(0xFFF472B6),
  'Productivity': Color(0xFFA3E635),
  'Food': Color(0xFFFF8A4C),
  'Mindfulness': Color(0xFF7DD3FC),
  'Nature': Color(0xFF4ADE80),
  'Kindness': Color(0xFFFB7185),
  'Music': Color(0xFFFACC15),
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onLogout});

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _statusOrder = {'active': 0, 'skipped': 1, 'completed': 2};

  int _tab = 0;
  UserProfile? _profile;
  List<Quest>? _today;
  int _rerollsLeft = 0;
  bool _rerolling = false;
  String? _error;

  // ── Welcome tour ──────────────────────────────────────────────
  final _xpKey = GlobalKey();
  final _questCardKey = GlobalKey();
  final _rerollKey = GlobalKey();
  final _navKey = GlobalKey();
  final _lockStatsKey = GlobalKey();
  final _friendsAddKey = GlobalKey();
  bool _tourActive = false;
  bool _tourHandled = false; // ensures we only consider starting it once

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  List<Quest> _sorted(List<Quest> quests) => [...quests]..sort((a, b) =>
      (_statusOrder[a.status] ?? 3).compareTo(_statusOrder[b.status] ?? 3));

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      final profile = await widget.api.me();
      final today = await widget.api.todaysQuests();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _today = _sorted(today.quests);
        _rerollsLeft = today.rerollsLeft;
      });
      _maybeStartTour();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Starts the welcome tour once, for a freshly created account, after the
  /// first quests have loaded (so the cards and reroll button exist to point
  /// at). The pending flag is set at signup in [ApiClient.signup].
  Future<void> _maybeStartTour() async {
    if (_tourHandled || _today == null || _today!.isEmpty) return;
    _tourHandled = true;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(onboardingPendingKey(widget.api.myId)) ?? false;
    if (pending && mounted) {
      // Let this frame settle so the quest list is laid out and measurable.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tourActive = true);
      });
    }
  }

  Future<void> _finishTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(onboardingPendingKey(widget.api.myId));
    if (mounted) setState(() => _tourActive = false);
  }

  /// Replays the tour on demand (from the Profile screen). Starts on the Today
  /// tab so the first steps have their targets on screen.
  void _startTour() {
    if (_tourActive) return;
    setState(() {
      _tab = 0;
      _tourActive = true;
    });
  }

  List<TourStep> _tourSteps() {
    Rect Function(Rect) navSlice(int i) => (r) {
          const n = 5;
          final w = r.width / n;
          return Rect.fromLTWH(r.left + i * w, r.top, w, r.height);
        };
    return [
      const TourStep(
        tab: 0,
        icon: Icons.rocket_launch,
        title: 'Welcome to APEX',
        body: "Every day, APEX turns the real world into a handful of quick "
            "quests — explore, create, move, connect. Here's a 60-second tour. "
            "You can tap Skip anytime.",
      ),
      TourStep(
        tab: 0,
        targetKey: _xpKey,
        icon: Icons.bolt,
        title: 'Level & XP',
        body: 'Completing quests earns XP and fills this bar. Fill it to level '
            'up — higher levels unlock more daily quests.',
      ),
      TourStep(
        tab: 0,
        targetKey: _questCardKey,
        icon: Icons.explore,
        title: "Today's quests",
        body: 'Each card is a quest: its category, difficulty, XP reward and '
            'rough time. Tap a card for details, hit Done to complete it, or '
            'snap a photo when one asks for proof.',
      ),
      TourStep(
        tab: 0,
        targetKey: _rerollKey,
        icon: Icons.casino,
        title: 'Not feeling them?',
        body: 'Reroll swaps your unfinished quests for fresh ones — up to 3 '
            'times a day. Anything you already finished is kept.',
      ),
      TourStep(
        tab: 0,
        targetKey: _navKey,
        subRect: navSlice(0),
        icon: Icons.bolt,
        title: 'Today',
        body: 'Your daily quests live here — this is home base.',
      ),
      // ── Lock in (detailed) ──────────────────────────────────────
      TourStep(
        tab: 1,
        targetKey: _navKey,
        subRect: navSlice(1),
        icon: Icons.lock,
        title: 'Lock in',
        body: 'Your focus zone — a built-in timer to help you study or do deep '
            "work. Let's see how it works.",
      ),
      TourStep(
        tab: 1,
        targetKey: _lockStatsKey,
        icon: Icons.toll,
        title: 'Coins & weekly focus',
        body: 'Up here you can see the coins you\'ve earned and how many '
            'minutes you\'ve focused this week. You earn coins by finishing '
            'focus sessions.',
      ),
      const TourStep(
        tab: 1,
        revealScreen: true,
        icon: Icons.timer,
        title: 'How a session works',
        body: 'Drag the two sliders to set your focus length and your break, '
            'then tap "Lock in" to start. The ring counts down; when the focus '
            'block finishes you earn coins — about 1 coin for every 5 minutes '
            '(a 50-minute session = 10 coins). Give up partway and you earn '
            'nothing, so pick a length you can finish. After focus, a short '
            'break runs automatically.',
      ),
      const TourStep(
        tab: 1,
        revealScreen: true,
        icon: Icons.storefront,
        title: 'Spend & compete',
        body: 'At the bottom of this screen: open "Study space" to spend your '
            'coins decorating your own room, and "Leagues" to join weekly '
            'leaderboards and see who focuses the most among your friends.',
      ),
      // ── Friends (detailed) ──────────────────────────────────────
      TourStep(
        tab: 2,
        targetKey: _navKey,
        subRect: navSlice(2),
        icon: Icons.group,
        title: 'Friends',
        body: 'Add people and keep each other motivated. Here\'s how it all '
            'fits together.',
      ),
      TourStep(
        tab: 2,
        targetKey: _friendsAddKey,
        icon: Icons.person_add,
        title: 'Adding friends',
        body: 'Tap here to send a friend request by email. When someone adds '
            'you, their request appears on this screen with a green check to '
            'accept or a red cross to decline. Tip: long-press a friend to '
            'remove them.',
      ),
      const TourStep(
        tab: 2,
        revealScreen: true,
        icon: Icons.local_fire_department,
        title: '5-day habit challenges',
        body: 'Once you\'re friends, tap "Challenge" next to their name to '
            'start a shared 5-day habit (like "make your bed" or "read"). They '
            'accept, then a 5-day window begins and you each tap "Mark day done" '
            'once a day. Two rows of squares show both of your streaks side by '
            'side.',
      ),
      const TourStep(
        tab: 2,
        revealScreen: true,
        icon: Icons.emoji_events,
        title: 'Staying consistent pays',
        body: 'Finish all 5 days to earn the most XP (up to 250). Miss a day or '
            'two and you earn less; miss them all and you get nothing. It\'s a '
            'friendly nudge to keep each other accountable. Finished challenges '
            'show up under "Past challenges".',
      ),
      TourStep(
        tab: 3,
        targetKey: _navKey,
        subRect: navSlice(3),
        icon: Icons.auto_stories,
        title: 'Journal',
        body: 'Your memory log: completed quests, photos you took, and your '
            'all-time stats.',
      ),
      TourStep(
        tab: 4,
        targetKey: _navKey,
        subRect: navSlice(4),
        icon: Icons.person,
        title: 'Profile',
        body: 'Customise your avatar, tweak your interests and difficulty, pick '
            'a theme, and visit the shops. Better preferences mean better '
            'quests.',
      ),
      const TourStep(
        tab: 0,
        icon: Icons.celebration,
        title: "You're all set!",
        body: 'That\'s it — your first quests are waiting below. Have fun, and '
            'go make some memories.',
      ),
    ];
  }

  Future<void> _complete(Quest quest, {bool withPhoto = false}) async {
    try {
      List<int>? bytes;
      if (withPhoto) {
        final picked = await ImagePicker().pickImage(
          source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (picked == null) return; // user cancelled the camera
        bytes = await picked.readAsBytes();
      }
      final result = await widget.api.completeQuest(
        quest.id,
        photoBytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.celebration, color: Colors.amber),
              const SizedBox(width: 10),
              Text('+${result.xpAwarded} XP  •  Level ${result.level}'),
            ],
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _skip(Quest quest) async {
    await widget.api.skipQuest(quest.id);
    await _refresh();
  }

  Future<void> _undo(Quest quest) async {
    try {
      final result = await widget.api.undoQuest(quest);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Quest undone — ${result.xpRemoved} XP returned to the pool',
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _restore(Quest quest) async {
    try {
      await widget.api.restoreQuest(quest.id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reroll() async {
    final unfinished = _today?.where((q) => !q.isCompleted).length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reroll your quests?'),
        content: Text(
          'Your $unfinished unfinished quest${unfinished == 1 ? '' : 's'} will '
          'be replaced with fresh ones. Completed quests are kept.\n\n'
          '$_rerollsLeft reroll${_rerollsLeft == 1 ? '' : 's'} left today.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reroll'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rerolling = true);
    try {
      final result = await widget.api.rerollQuests();
      if (!mounted) return;
      setState(() {
        _today = _sorted(result.quests);
        _rerollsLeft = result.rerollsLeft;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Fresh quests! $_rerollsLeft reroll${_rerollsLeft == 1 ? '' : 's'} left today'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _rerolling = false);
    }
  }

  void _openDetail(Quest quest) {
    showQuestDetail(
      context,
      api: widget.api,
      quest: quest,
      onComplete: _complete,
      onSkip: _skip,
      onUndo: _undo,
      onRestore: _restore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => _questList(
        _today,
        key: const ValueKey('today'),
        emptyText: 'No quests yet — pull to refresh.',
        showReroll: true,
      ),
      1 => KeyedSubtree(
        key: const ValueKey('lockin'),
        child: LockInScreen(
          api: widget.api,
          coins: _profile?.coins ?? 0,
          onCoinsChanged: _refresh,
          statsKey: _lockStatsKey,
        ),
      ),
      2 => KeyedSubtree(
        key: const ValueKey('friends'),
        child: FriendsScreen(
          api: widget.api,
          onXpChanged: _refresh,
          addFriendKey: _friendsAddKey,
        ),
      ),
      3 => _profile == null
          ? const Center(
              key: ValueKey('journal-loading'),
              child: CircularProgressIndicator(),
            )
          : KeyedSubtree(
              key: const ValueKey('journal'),
              child: JournalScreen(
                api: widget.api,
                profile: _profile!,
                onChanged: _refresh,
              ),
            ),
      _ =>
        _profile == null
            ? const Center(
                key: ValueKey('profile-loading'),
                child: CircularProgressIndicator(),
              )
            : KeyedSubtree(
                key: const ValueKey('profile'),
                child: ProfileScreen(
                  api: widget.api,
                  profile: _profile!,
                  onChanged: _refresh,
                  onReplayTour: _startTour,
                  onLogout: () async {
                    await widget.api.logout();
                    widget.onLogout();
                  },
                ),
              ),
    };

    final scaffold = Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(profile: _profile, tab: _tab, xpKey: _xpKey),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.02),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: body,
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        key: _navKey,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Lock in',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );

    return Stack(
      children: [
        scaffold,
        if (_tourActive)
          Positioned.fill(
            child: OnboardingOverlay(
              steps: _tourSteps(),
              onFinish: _finishTour,
              onStep: (step) {
                if (step.tab != null && step.tab != _tab) {
                  setState(() => _tab = step.tab!);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _questList(
    List<Quest>? quests, {
    required Key key,
    required String emptyText,
    bool showReroll = false,
  }) {
    if (quests == null) {
      return Center(key: key, child: const CircularProgressIndicator());
    }
    if (quests.isEmpty) {
      return Center(
        key: key,
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    final hasUnfinished = quests.any((q) => !q.isCompleted);
    final header = showReroll && hasUnfinished ? 1 : 0;
    return RefreshIndicator(
      key: key,
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: quests.length + header,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          if (header == 1 && i == 0) return _rerollHeader(context);
          return QuestCard(
            key: i - header == 0 ? _questCardKey : null,
            quest: quests[i - header],
            onTap: _openDetail,
            onComplete: _complete,
            onSkip: _skip,
            onRestore: _restore,
          );
        },
      ),
    );
  }

  Widget _rerollHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final out = _rerollsLeft <= 0;
    return Row(
      key: _rerollKey,
      children: [
        Text(
          'Not feeling these?',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: out || _rerolling ? null : _reroll,
          icon: _rerolling
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.casino, size: 18),
          label: Text(
            out ? 'No rerolls left today' : 'Reroll ($_rerollsLeft left)',
          ),
        ),
      ],
    );
  }
}

/// Custom header: wordmark + level badge, big tab title, gradient XP bar.
class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.tab, this.xpKey});

  final UserProfile? profile;
  final int tab;
  final Key? xpKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = profile;
    final title = switch (tab) {
      0 => "Today's quests",
      1 => 'Lock in',
      2 => 'Friends',
      3 => 'Your journal',
      _ => 'Your profile',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ApexWordmark(),
              const Spacer(),
              if (p != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: accentGradient(scheme.primary),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'LV ${p.level}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              title,
              key: ValueKey(title),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(letterSpacing: -0.5),
            ),
          ),
          if (p != null) ...[
            const SizedBox(height: 12),
            Row(
              key: xpKey,
              children: [
                Expanded(child: _XpBar(progress: p.levelProgress)),
                const SizedBox(width: 12),
                Text(
                  '${p.xp} XP',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.02, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Container(
        height: 10,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: accentGradient(scheme.primary),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.onTap,
    required this.onComplete,
    required this.onSkip,
    required this.onRestore,
  });

  final Quest quest;
  final void Function(Quest) onTap;
  final Future<void> Function(Quest, {bool withPhoto}) onComplete;
  final Future<void> Function(Quest) onSkip;
  final Future<void> Function(Quest) onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryColors[quest.category] ?? scheme.primary;
    final done = quest.isCompleted;
    final skipped = quest.status == 'skipped';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: done ? 0.08 : 0.22)),
        boxShadow: [
          if (!done && !skipped)
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(quest),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: accentGradient(accent),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        categoryIcons[quest.category] ?? Icons.star,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quest.category.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (done)
                      const Icon(Icons.check_circle,
                          color: Color(0xFF4ADE80))
                    else if (skipped)
                      _pill(context, 'Skipped',
                          icon: Icons.remove_circle_outline)
                    else
                      _pill(
                        context,
                        quest.difficulty,
                        color: switch (quest.difficulty) {
                          'Easy' => const Color(0xFF4ADE80),
                          'Medium' => const Color(0xFFFFB04D),
                          _ => const Color(0xFFFF5A5F),
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  quest.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.45, fontSize: 15),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _pill(
                      context,
                      '${quest.xpReward} XP',
                      icon: Icons.bolt,
                      color: const Color(0xFFFACC15),
                    ),
                    _pill(
                      context,
                      '~${quest.estMinutes} min',
                      icon: Icons.schedule,
                    ),
                    if (quest.requiresPhoto)
                      _pill(context, 'photo', icon: Icons.photo_camera),
                  ],
                ),
                if (skipped) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => onRestore(quest),
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('Restore'),
                      ),
                    ],
                  ),
                ] else if (!done) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => onSkip(quest),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                        ),
                        child: const Text('Skip'),
                      ),
                      const SizedBox(width: 6),
                      GradientButton(
                        onPressed: () => onComplete(
                          quest,
                          withPhoto: quest.requiresPhoto,
                        ),
                        icon: quest.requiresPhoto
                            ? Icons.photo_camera
                            : Icons.check,
                        label: 'Done',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label,
      {IconData? icon, Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? scheme.onSurface).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
