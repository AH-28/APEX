import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../avatar.dart';
import '../models.dart';
import '../theme.dart';
import 'home_screen.dart' show categoryColors, categoryIcons;

/// Friends: friend requests, friend list, and 5-day shared habit challenges.
/// One friend sends a challenge, the other accepts, then both check in daily
/// for 5 days — staying consistent earns more XP (250 for all 5, less for
/// each missed day, nothing if you miss them all).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.api, required this.onXpChanged});

  final ApiClient api;
  final Future<void> Function() onXpChanged;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<FriendEntry>? _friends;
  List<DuoChallenge>? _challenges;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final friends = await widget.api.friends();
      // duoChallenges() also settles finished ones, so refresh XP after.
      final challenges = await widget.api.duoChallenges();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _challenges = challenges;
      });
      await widget.onXpChanged();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _addFriend() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a friend'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Their email',
            hintText: 'friend@example.com',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Send request')),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await widget.api.sendFriendRequest(email.trim());
      _snack('Request sent!');
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _sendChallenge(FriendEntry f) async {
    try {
      await widget.api.createDuoChallenge(f.friendId);
      _snack('Challenge sent to ${f.displayName} — they need to accept it.');
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _respondChallenge(DuoChallenge c, bool accept) async {
    try {
      await widget.api.respondDuoChallenge(c.id, accept);
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _checkin(DuoChallenge c) async {
    try {
      await widget.api.checkinDuoChallenge(c.id);
      _snack('Day ${c.dayInWindow} done — keep the streak alive!');
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_friends == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final pendingIn = _friends!.where((f) => !f.isFriend && f.incoming).toList();
    final pendingOut =
        _friends!.where((f) => !f.isFriend && !f.incoming).toList();
    final accepted = _friends!.where((f) => f.isFriend).toList();

    final chs = _challenges ?? [];
    final incomingChallenges = chs.where((c) => c.incoming).toList();
    final activeChallenges = chs.where((c) => c.isActive).toList();
    final sentChallenges =
        chs.where((c) => c.status == 'pending' && !c.incoming).toList();
    final doneChallenges = chs.where((c) => c.isCompleted).toList();
    final friendsWithOpen = {
      for (final c in chs)
        if (c.status == 'pending' || c.isActive) c.friendId,
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          GradientButton(
            expand: true,
            onPressed: _addFriend,
            icon: Icons.person_add,
            label: 'Add a friend by email',
          ),
          if (pendingIn.isNotEmpty) ...[
            _sectionTitle('Friend requests'),
            for (final f in pendingIn) _friendRequestRow(f),
          ],
          if (incomingChallenges.isNotEmpty) ...[
            _sectionTitle('Challenge requests'),
            for (final c in incomingChallenges) _challengeRequestCard(c),
          ],
          if (activeChallenges.isNotEmpty) ...[
            _sectionTitle('Active challenges'),
            for (final c in activeChallenges) _activeChallengeCard(c),
          ],
          if (sentChallenges.isNotEmpty) ...[
            _sectionTitle('Waiting to be accepted'),
            for (final c in sentChallenges) _sentChallengeRow(c),
          ],
          _sectionTitle('Friends'),
          if (accepted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No friends yet — add someone and start a habit challenge!',
                style: GoogleFonts.outfit(color: scheme.onSurfaceVariant),
              ),
            )
          else
            for (final f in accepted)
              _friendRow(f, hasOpen: friendsWithOpen.contains(f.friendId)),
          if (pendingOut.isNotEmpty) ...[
            _sectionTitle('Sent friend requests'),
            for (final f in pendingOut)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _avatarBubble(f.displayName, f.avatar),
                title: Text(f.displayName),
                subtitle: const Text('Waiting for them to accept'),
              ),
          ],
          if (doneChallenges.isNotEmpty) ...[
            _sectionTitle('Past challenges'),
            for (final c in doneChallenges.take(6)) _doneChallengeCard(c),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 16)),
      );

  Widget _avatarBubble(String name, Map<String, dynamic> avatar) {
    final scheme = Theme.of(context).colorScheme;
    if (avatar.isEmpty) {
      return CircleAvatar(
        backgroundColor: scheme.primary,
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(color: scheme.onPrimary)),
      );
    }
    return ClipOval(
      child: Container(
        width: 40,
        height: 40,
        color: scheme.surfaceContainerHigh,
        alignment: Alignment.topCenter,
        child: OverflowBox(
          maxHeight: 64,
          alignment: Alignment.topCenter,
          child: AvatarView(config: AvatarConfig.fromJson(avatar), size: 48),
        ),
      ),
    );
  }

  Widget _friendRequestRow(FriendEntry f) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _avatarBubble(f.displayName, f.avatar),
      title: Text(f.displayName),
      subtitle: Text('Level ${f.level}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Color(0xFF4ADE80)),
            onPressed: () async {
              try {
                await widget.api.respondFriendRequest(f.friendshipId, true);
                _load();
              } catch (e) {
                _snack(e.toString());
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Color(0xFFFF5A5F)),
            onPressed: () async {
              try {
                await widget.api.respondFriendRequest(f.friendshipId, false);
                _load();
              } catch (e) {
                _snack(e.toString());
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _friendRow(FriendEntry f, {required bool hasOpen}) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _avatarBubble(f.displayName, f.avatar),
      title: Text(f.displayName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      subtitle: Text('Level ${f.level} • ${f.xp} XP'),
      trailing: hasOpen
          ? Text('challenge on',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: scheme.onSurfaceVariant))
          : FilledButton.tonalIcon(
              onPressed: () => _sendChallenge(f),
              icon: const Icon(Icons.local_fire_department, size: 16),
              label: const Text('Challenge'),
            ),
      onLongPress: () async {
        final remove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove ${f.displayName}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove')),
            ],
          ),
        );
        if (remove == true) {
          try {
            await widget.api.removeFriend(f.friendshipId);
            _load();
          } catch (e) {
            _snack(e.toString());
          }
        }
      },
    );
  }

  Widget _challengeRequestCard(DuoChallenge c) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryColors[c.category] ?? scheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _challengeHeader(c, accent),
          const SizedBox(height: 8),
          Text(
            '${c.friendName} wants to do this with you for ${c.days} days. '
            'Stay consistent together to earn the most XP!',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondChallenge(c, false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  expand: true,
                  onPressed: () => _respondChallenge(c, true),
                  icon: Icons.check,
                  label: 'Accept',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sentChallengeRow(DuoChallenge c) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryColors[c.category] ?? scheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(categoryIcons[c.category] ?? Icons.star, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${c.title} — sent to ${c.friendName}',
                style: GoogleFonts.outfit(fontSize: 13.5)),
          ),
          Text('pending',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _activeChallengeCard(DuoChallenge c) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryColors[c.category] ?? scheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _challengeHeader(c, accent),
          const SizedBox(height: 14),
          _streakRow('You', c.startDate, c.days, c.myCheckinDays, accent,
              isMe: true),
          const SizedBox(height: 8),
          _streakRow(c.friendName, c.startDate, c.days, c.friendCheckinDays,
              accent),
          const SizedBox(height: 14),
          if (c.windowEnded)
            Text('Challenge over — settling rewards…',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: scheme.onSurfaceVariant))
          else if (c.checkedInToday)
            Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 18, color: Color(0xFF4ADE80)),
                const SizedBox(width: 8),
                Text("Day ${c.dayInWindow} done. See you tomorrow!",
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            )
          else
            GradientButton(
              expand: true,
              onPressed: () => _checkin(c),
              icon: Icons.bolt,
              label: "Mark day ${c.dayInWindow} done",
            ),
        ],
      ),
    );
  }

  Widget _doneChallengeCard(DuoChallenge c) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryColors[c.category] ?? scheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: accentGradient(accent),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(categoryIcons[c.category] ?? Icons.star,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: GoogleFonts.outfit(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text('with ${c.friendName} • you hit ${c.myDays}/${c.days} days',
                    style: GoogleFonts.outfit(
                        fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text('+${c.myReward ?? 0} XP',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: (c.myReward ?? 0) > 0
                      ? const Color(0xFFFACC15)
                      : scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _challengeHeader(DuoChallenge c, Color accent) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: accentGradient(accent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(categoryIcons[c.category] ?? Icons.star,
              size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 16)),
              Text('${c.days}-day habit • with ${c.friendName}',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  /// A 5-cell row showing which days were completed.
  Widget _streakRow(String who, String? startDate, int days,
      List<String> checkinDays, Color accent,
      {bool isMe = false}) {
    final scheme = Theme.of(context).colorScheme;
    final start = startDate != null ? DateTime.tryParse(startDate) : null;
    final done = checkinDays.toSet();
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w500)),
        ),
        for (var i = 0; i < days; i++)
          Builder(builder: (context) {
            final date = start?.add(Duration(days: i));
            final key = date == null
                ? ''
                : '${date.year.toString().padLeft(4, '0')}-'
                    '${date.month.toString().padLeft(2, '0')}-'
                    '${date.day.toString().padLeft(2, '0')}';
            final isDone = done.contains(key);
            return Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isDone ? accent : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text('${i + 1}',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
            );
          }),
      ],
    );
  }
}
