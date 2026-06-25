import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../avatar.dart';
import '../models.dart';
import '../theme.dart';

/// Character creator — Bitmoji-style tabbed editor.
///
/// A horizontally scrollable tab bar picks the category; every option is a
/// picture tile showing the character with that option applied.
///
/// Two modes:
///  - signup (`api` null): edits the shared config in place; parent submits it.
///  - profile (`api` set): loads/saves the avatar and offers the outfit shop.
class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({
    super.key,
    this.api,
    this.initial,
    this.xp = 0,
    this.onDone,
    this.embedded = false,
  });

  final ApiClient? api;
  final AvatarConfig? initial;
  final int xp;
  final void Function(AvatarConfig)? onDone;
  final bool embedded; // true inside signup flow (no Scaffold)

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _Tab {
  const _Tab(this.label, this.key);
  final String label;
  final String key;
}

const _tabs = [
  _Tab('Body', 'body'),
  _Tab('Face', 'face'),
  _Tab('Skin', 'skin'),
  _Tab('Eyes', 'eyes'),
  _Tab('Eye colour', 'eyeColor'),
  _Tab('Nose', 'nose'),
  _Tab('Hair', 'hair'),
  _Tab('Hair colour', 'hairColor'),
  _Tab('Outfit', 'outfit'),
  _Tab('Outfit colour', 'outfitColor'),
];

class _AvatarEditorScreenState extends State<AvatarEditorScreen>
    with SingleTickerProviderStateMixin {
  late AvatarConfig _config;
  late TabController _tabController;
  List<OutfitInfo> _outfits = [];
  Set<String> _owned = {};
  late int _xp;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initial ?? AvatarConfig();
    _xp = widget.xp;
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(() => setState(() {}));
    _loadOutfits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOutfits() async {
    final api = widget.api;
    if (api == null) {
      // Signup: only free outfits are wearable.
      String pretty(String id) => id
          .split('-')
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');
      setState(() {
        _outfits = outfitStyles.keys
            .where(_isFreeId)
            .map((id) => OutfitInfo(id: id, name: pretty(id), priceXp: 0))
            .toList();
      });
      return;
    }
    final all = await api.outfits();
    final owned = await api.ownedOutfits();
    if (mounted) {
      setState(() {
        _outfits = all;
        _owned = owned;
      });
    }
  }

  bool _isFreeId(String id) =>
      const {'tee-classic', 'tee-stripe', 'hoodie-cozy', 'tank-sport'}.contains(id);

  bool _wearable(OutfitInfo o) => o.isFree || _owned.contains(o.id);

  Future<void> _buy(OutfitInfo o) async {
    final api = widget.api;
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Buy ${o.name}?'),
        content: Text('This costs ${o.priceXp} XP. You have $_xp XP.\n'
            'Spending XP can lower your level.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buy')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final remaining = await api.buyOutfit(o.id);
      setState(() {
        _owned.add(o.id);
        _xp = remaining;
        _config.outfit = o.id;
        _config.outfitColor = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _save() async {
    if (widget.onDone != null) {
      widget.onDone!(_config);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api!.saveAvatar(_config.toJson());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      children: [
        // Live preview on a gradient pedestal.
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          height: widget.embedded ? 150 : 190,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primary.withValues(alpha: 0.20),
                scheme.surfaceContainerLow,
              ],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: AvatarView(
                config: _config, size: widget.embedded ? 105 : 135),
          ),
        ),
        const SizedBox(height: 8),
        // Horizontal category tabs.
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w500),
          tabs: [for (final t in _tabs) Tab(text: t.label, height: 40)],
        ),
        Expanded(child: _tabContent(_tabs[_tabController.index].key)),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your character',
            style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Colors.transparent,
      ),
      body: content,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: GradientButton(
            expand: true,
            onPressed: _saving ? null : _save,
            icon: Icons.check,
            label: _saving ? 'Saving…' : 'Save character',
          ),
        ),
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────
  Widget _tabContent(String key) {
    switch (key) {
      case 'body':
        return _optionGrid(bodyTypes, (v) => _config.body == v,
            (v) => _config.copyWith(body: v), (v) => setState(() => _config.body = v));
      case 'face':
        return _optionGrid(faceShapes, (v) => _config.face == v,
            (v) => _config.copyWith(face: v), (v) => setState(() => _config.face = v));
      case 'skin':
        return _indexGrid(skinTones.length, (i) => _config.skin == i,
            (i) => _config.copyWith(skin: i), (i) => setState(() => _config.skin = i),
            labeller: (i) => 'Tone ${i + 1}');
      case 'eyes':
        return _optionGrid(eyeShapes, (v) => _config.eyeShape == v,
            (v) => _config.copyWith(eyeShape: v),
            (v) => setState(() => _config.eyeShape = v));
      case 'eyeColor':
        return _indexGrid(eyeColors.length, (i) => _config.eyeColor == i,
            (i) => _config.copyWith(eyeColor: i),
            (i) => setState(() => _config.eyeColor = i),
            labeller: (i) =>
                ['Brown', 'Green', 'Blue', 'Grey', 'Violet', 'Amber'][i],
            swatch: (i) => eyeColors[i]);
      case 'nose':
        return _optionGrid(noseShapes, (v) => _config.nose == v,
            (v) => _config.copyWith(nose: v), (v) => setState(() => _config.nose = v));
      case 'hair':
        return _optionGrid(hairStyles, (v) => _config.hair == v,
            (v) => _config.copyWith(hair: v), (v) => setState(() => _config.hair = v));
      case 'hairColor':
        return _indexGrid(hairColors.length, (i) => _config.hairColor == i,
            (i) => _config.copyWith(hairColor: i),
            (i) => setState(() => _config.hairColor = i),
            labeller: (i) => [
                  'Black', 'Dark brown', 'Brown', 'Blonde',
                  'Ginger', 'Silver', 'Violet', 'Pink',
                ][i]);
      case 'outfit':
        return _outfitGrid();
      case 'outfitColor':
        final palette = outfitStyles[_config.outfit]?.palette ?? const [];
        return _indexGrid(palette.length, (i) => _config.outfitColor == i,
            (i) => _config.copyWith(outfitColor: i),
            (i) => setState(() => _config.outfitColor = i),
            labeller: (i) => 'Colour ${i + 1}');
      default:
        return const SizedBox.shrink();
    }
  }

  /// Grid of picture tiles for named options (body, face, eyes, nose, hair).
  Widget _optionGrid(
    List<String> options,
    bool Function(String) isSelected,
    AvatarConfig Function(String) previewConfig,
    void Function(String) onPick,
  ) {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.74,
      children: [
        for (final o in options)
          _pictureTile(
            label: o[0].toUpperCase() + o.substring(1),
            selected: isSelected(o),
            preview: AvatarView(config: previewConfig(o), size: 62),
            onTap: () => onPick(o),
          ),
      ],
    );
  }

  /// Grid of picture tiles for indexed options (colours). Shows the character
  /// with the colour applied, plus an optional swatch dot.
  Widget _indexGrid(
    int count,
    bool Function(int) isSelected,
    AvatarConfig Function(int) previewConfig,
    void Function(int) onPick, {
    required String Function(int) labeller,
    Color Function(int)? swatch,
  }) {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.74,
      children: [
        for (var i = 0; i < count; i++)
          _pictureTile(
            label: labeller(i),
            selected: isSelected(i),
            preview: AvatarView(config: previewConfig(i), size: 62),
            swatch: swatch?.call(i),
            onTap: () => onPick(i),
          ),
      ],
    );
  }

  Widget _outfitGrid() {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.68,
      children: [
        for (final o in _outfits)
          if (outfitStyles.containsKey(o.id))
            _pictureTile(
              label: o.name,
              selected: _config.outfit == o.id,
              preview: AvatarView(
                  config: _config.copyWith(outfit: o.id, outfitColor: 0),
                  size: 58),
              badge: _wearable(o)
                  ? (o.isFree ? 'Free' : 'Owned')
                  : '${o.priceXp} XP',
              badgeColor: _wearable(o)
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFFACC15),
              locked: !_wearable(o),
              onTap: () {
                if (_wearable(o)) {
                  setState(() {
                    _config.outfit = o.id;
                    _config.outfitColor = 0;
                  });
                } else {
                  _buy(o);
                }
              },
            ),
        if (widget.api != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '$_xp XP\navailable',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pictureTile({
    required String label,
    required bool selected,
    required Widget preview,
    required VoidCallback onTap,
    Color? swatch,
    String? badge,
    Color? badgeColor,
    bool locked = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.25),
                blurRadius: 12,
              ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: Opacity(
                        opacity: locked ? 0.45 : 1, child: preview),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                  child: Column(
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (badge != null)
                        Text(
                          badge,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (swatch != null)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: swatch,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
            if (locked)
              const Positioned(
                top: 7,
                left: 7,
                child:
                    Icon(Icons.lock, size: 14, color: Color(0xFFFACC15)),
              ),
          ],
        ),
      ),
    );
  }
}
