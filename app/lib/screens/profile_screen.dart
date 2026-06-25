import 'package:flutter/material.dart';

import '../api_client.dart';
import '../avatar.dart';
import '../models.dart';
import '../theme.dart';
import 'avatar_editor_screen.dart';
import 'home_screen.dart' show categoryIcons;

const _ageRanges = ['13-17', '18-24', '25-34', '35-49', '50+'];
const _difficulties = ['Easy', 'Medium', 'Hard'];
const _difficultyBlurb = {
  'Easy': 'Quick wins — gentle quests that slot into any day.',
  'Medium': 'A little push — quests that take some intention.',
  'Hard': 'Bring it on — quests that stretch your comfort zone.',
};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.onChanged,
    required this.onLogout,
  });

  final ApiClient api;
  final UserProfile profile;
  final Future<void> Function() onChanged;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // The catalogue's categories (icons/colors are keyed off the same map).
  final List<String> _allCategories = categoryIcons.keys.toList();
  late Set<String> _interests;
  late String _difficulty;
  String? _ageRange;
  late TextEditingController _location;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _interests = widget.profile.interests.toSet();
    _difficulty = widget.profile.difficulty;
    _ageRange = widget.profile.ageRange;
    _location = TextEditingController(text: widget.profile.location ?? '');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.api.updateProfile(
        interests: _interests.toList(),
        difficulty: _difficulty,
        location: _location.text.trim(),
        ageRange: _ageRange,
        timezone: DateTime.now().timeZoneName,
      );
      setState(() => _dirty = false);
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved! Tomorrow\'s quests will use this ✨'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'New email'),
            ),
            const SizedBox(height: 12),
            Text(
              'Confirmation links will be emailed to verify the change.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send confirmation'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    final email = controller.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _snack('Please enter a valid email address.');
      return;
    }
    try {
      await widget.api.changeEmail(email);
      _snack('Confirmation sent — check your old and new inboxes.');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _changePassword() async {
    final pass = TextEditingController();
    final confirm = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pass,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 8 characters',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Repeat new password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update password'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    if (pass.text.length < 8) {
      _snack('Password must be at least 8 characters.');
      return;
    }
    if (pass.text != confirm.text) {
      _snack('Passwords do not match.');
      return;
    }
    try {
      await widget.api.changePassword(pass.text);
      _snack('Password updated ✔');
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Apply the theme to the app immediately, then persist it to the account.
  void _setTheme(ThemeSettings next) {
    applyTheme(next);
    widget.api.saveTheme(next.presetName, next.mode.name).catchError((_) {
      // If the save fails the change still holds for this session.
      _snack('Could not save your theme — it will reset next login.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _HeroCard(
              profile: widget.profile,
              onEditCharacter: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AvatarEditorScreen(
                      api: widget.api,
                      initial: widget.profile.avatar.isEmpty
                          ? null
                          : AvatarConfig.fromJson(widget.profile.avatar),
                      xp: widget.profile.xp,
                    ),
                  ),
                );
                if (changed == true) widget.onChanged();
              },
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.interests,
              title: 'Interests',
              subtitle: 'Your quests lean towards what you love.',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _allCategories)
                    FilterChip(
                      avatar: Icon(
                        categoryIcons[c] ?? Icons.star,
                        size: 16,
                        color: _interests.contains(c)
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      label: Text(c),
                      showCheckmark: false,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _interests.contains(c)
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: _interests.contains(c)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      selected: _interests.contains(c),
                      onSelected: (sel) => setState(() {
                        sel ? _interests.add(c) : _interests.remove(c);
                        _dirty = true;
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.speed,
              title: 'Quest style',
              subtitle: _difficultyBlurb[_difficulty]!,
              child: SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: BorderSide.none,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                showSelectedIcon: false,
                segments: [
                  for (final d in _difficulties)
                    ButtonSegment(value: d, label: Text(d)),
                ],
                selected: {_difficulty},
                onSelectionChanged: (s) => setState(() {
                  _difficulty = s.first;
                  _dirty = true;
                }),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.tune,
              title: 'About you',
              subtitle: 'Optional — makes quests feel local and right-sized.',
              child: Column(
                children: [
                  TextField(
                    controller: _location,
                    onChanged: (_) => setState(() => _dirty = true),
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.place_outlined),
                      hintText: 'e.g. Cairo, EG',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _ageRange,
                    borderRadius: BorderRadius.circular(16),
                    decoration: const InputDecoration(
                      labelText: 'Age range',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    items: [
                      for (final a in _ageRanges)
                        DropdownMenuItem(value: a, child: Text(a)),
                    ],
                    onChanged: (v) => setState(() {
                      _ageRange = v;
                      _dirty = true;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: 'Pick your colours — applied instantly, saved to your account.',
              child: ValueListenableBuilder<ThemeSettings>(
                valueListenable: themeController,
                builder: (context, settings, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final preset in themePresets)
                          _ThemeSwatch(
                            preset: preset,
                            selected: settings.presetName == preset.name,
                            onTap: () =>
                                _setTheme(settings.copyWith(presetName: preset.name)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<ThemeMode>(
                      style: SegmentedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide.none,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode, size: 16),
                          label: Text('Dark'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode, size: 16),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto, size: 16),
                          label: Text('Auto'),
                        ),
                      ],
                      selected: {settings.mode},
                      onSelectionChanged: (s) =>
                          _setTheme(settings.copyWith(mode: s.first)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.lock_outline,
              title: 'Account',
              subtitle: 'Update how you sign in.',
              child: Column(
                children: [
                  _AccountAction(
                    icon: Icons.alternate_email,
                    label: 'Change email',
                    onTap: _changeEmail,
                  ),
                  const SizedBox(height: 8),
                  _AccountAction(
                    icon: Icons.password,
                    label: 'Change password',
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log out'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        // Save bar slides up only when there is something to save.
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: AnimatedSlide(
            offset: _dirty ? Offset.zero : const Offset(0, 2),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _dirty ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save changes'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient header with avatar, name and level progress ring.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile, required this.onEditCharacter});

  final UserProfile profile;
  final VoidCallback onEditCharacter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : profile.email.split('@').first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            Color.alphaBlend(scheme.primary.withValues(alpha: 0.25),
                scheme.surfaceContainerHigh),
          ],
        ),
      ),
      child: Row(
        children: [
          // Avatar wrapped in an animated level-progress ring.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: profile.levelProgress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.onPrimaryContainer
                          .withValues(alpha: 0.15),
                      color: scheme.primary,
                    ),
                  ),
                  profile.avatar.isEmpty
                      ? CircleAvatar(
                          radius: 30,
                          backgroundColor: scheme.primary,
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimary,
                            ),
                          ),
                        )
                      : ClipOval(
                          child: Container(
                            width: 60,
                            height: 60,
                            color: scheme.surface.withValues(alpha: 0.3),
                            alignment: Alignment.topCenter,
                            child: OverflowBox(
                              maxHeight: 90,
                              alignment: Alignment.topCenter,
                              child: AvatarView(
                                config:
                                    AvatarConfig.fromJson(profile.avatar),
                                size: 72,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatPill(
                        icon: Icons.military_tech,
                        label: 'Level ${profile.level}'),
                    _StatPill(icon: Icons.bolt, label: '${profile.xp} XP'),
                    _StatPill(
                        icon: Icons.toll, label: '${profile.coins} coins'),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: onEditCharacter,
                  icon: const Icon(Icons.face_retouching_natural, size: 17),
                  label: Text(profile.avatar.isEmpty
                      ? 'Create character'
                      : 'Edit character'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Soft rounded section card with an icon header.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(icon, size: 18, color: scheme.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          subtitle,
                          key: ValueKey(subtitle),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Tappable colour circle for the theme picker.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: preset.name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: preset.seed,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

/// Row-style button used in the Account section.
class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
