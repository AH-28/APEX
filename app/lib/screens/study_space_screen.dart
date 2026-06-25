import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../models.dart';

const _itemColors = <String, Color>{
  'black': Color(0xFF2A2F3A),
  'white': Color(0xFFE5E7EB),
  'silver': Color(0xFFB8BDC7),
  'violet': Color(0xFF8B5CF6),
  'blue': Color(0xFF3B82F6),
  'pink': Color(0xFFF472B6),
  'green': Color(0xFF34D399),
  'red': Color(0xFFEF4444),
  'amber': Color(0xFFF59E0B),
  'oak': Color(0xFF9A6A3F),
  'walnut': Color(0xFF6B4423),
};

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Your virtual study space: a 3D-style isometric room where every item you
/// own appears on or around the desk (tap an item to recolour it), plus the
/// coin shop with drawn previews of every item.
class StudySpaceScreen extends StatefulWidget {
  const StudySpaceScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<StudySpaceScreen> createState() => _StudySpaceScreenState();
}

class _StudySpaceScreenState extends State<StudySpaceScreen> {
  List<StudyItem> _catalog = [];
  Map<String, String> _owned = {}; // item id -> colour
  int _coins = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await widget.api.studyItems();
      final owned = await widget.api.studySetup();
      final me = await widget.api.me();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _owned = owned;
        _coins = me.coins;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _buyOrRecolor(StudyItem item) async {
    final ownedColor = _owned[item.id];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ItemArt(itemId: item.id,
                    color: _itemColors[ownedColor ?? item.colors.first]!,
                    size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ownedColor == null
                            ? 'Buy ${item.name} — ${item.price} coins'
                            : 'Recolour ${item.name} — ${item.colorFee} coins',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ownedColor == null
                            ? 'Pick your starting colour (free choice).'
                            : 'Current colour: $ownedColor. Pick a new one.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in item.colors)
                  GestureDetector(
                    onTap: () => Navigator.pop(context, c),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _itemColors[c] ?? Colors.grey,
                        border: Border.all(
                          color: ownedColor == c
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.white24,
                          width: ownedColor == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      final remaining = ownedColor == null
          ? await widget.api.buyStudyItem(item.id, picked)
          : await widget.api.recolorStudyItem(item.id, picked);
      setState(() {
        _owned[item.id] = picked;
        _coins = remaining;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  StudyItem? _item(String id) {
    for (final i in _catalog) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title:
            Text('Study space', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.toll, size: 18, color: Color(0xFFFACC15)),
                const SizedBox(width: 6),
                Text('$_coins',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _RoomScene(
                  owned: _owned,
                  onTapItem: (id) {
                    final item = _item(id);
                    if (item != null) _buyOrRecolor(item);
                  },
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _owned.isEmpty
                        ? 'Just a basic desk… buy your first item below!'
                        : 'Tap anything in your room to recolour it.',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Shop',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  'Earn coins by locking in. First colour is free; '
                  'recolouring later costs a small fee.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.76,
                  children: [for (final item in _catalog) _shopTile(item)],
                ),
              ],
            ),
    );
  }

  /// Compact shop card: name, picture, price, colours — stacked top to bottom.
  Widget _shopTile(StudyItem item) {
    final scheme = Theme.of(context).colorScheme;
    final ownedColor = _owned[item.id];
    final previewColor =
        _itemColors[ownedColor ?? item.colors.first] ?? Colors.grey;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ownedColor != null
              ? const Color(0xFF4ADE80).withValues(alpha: 0.45)
              : scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _buyOrRecolor(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w700, height: 1.1),
                ),
                ItemArt(itemId: item.id, color: previewColor, size: 42),
                Text(
                  ownedColor != null
                      ? 'Owned · ${item.colorFee}c'
                      : '${item.price} coins',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ownedColor != null
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFFACC15),
                  ),
                ),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final c in item.colors.take(6))
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _itemColors[c],
                          border: ownedColor == c
                              ? Border.all(color: scheme.onSurface, width: 1.4)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════ The 3D-style room ═════════════════════════════════════════

/// Slot in the room: where an item sits and how big it is.
class _Slot {
  const _Slot(this.x, this.y, this.size);
  final double x; // fraction of scene width (item centre)
  final double y; // fraction of scene height (item bottom)
  final double size;
}

const _slots = <String, _Slot>{
  // On the wall (back, highest up).
  'poster-art': _Slot(0.20, 0.30, 58),
  'poster-band': _Slot(0.355, 0.30, 56),
  'clock': _Slot(0.50, 0.20, 42),
  'shelf': _Slot(0.34, 0.45, 90),
  'curtains': _Slot(0.735, 0.40, 150),
  // On the desk (desk surface sits at ~0.60 of scene height).
  'monitor': _Slot(0.46, 0.585, 96),
  'monitor-duo': _Slot(0.46, 0.585, 120),
  'laptop': _Slot(0.45, 0.59, 78),
  'speaker': _Slot(0.70, 0.575, 44),
  'lamp-round': _Slot(0.235, 0.565, 52),
  'lamp-arc': _Slot(0.235, 0.56, 60),
  'plant': _Slot(0.80, 0.565, 44),
  'headphones': _Slot(0.31, 0.59, 40),
  'coffee': _Slot(0.715, 0.60, 30),
  'soda': _Slot(0.275, 0.60, 26),
  'water': _Slot(0.555, 0.59, 26),
  'keyboard': _Slot(0.46, 0.665, 72),
  'mousepad-s': _Slot(0.63, 0.665, 44),
  'mousepad-m': _Slot(0.64, 0.668, 56),
  'mousepad-xl': _Slot(0.65, 0.672, 72),
  'mouse': _Slot(0.635, 0.655, 26),
  // On the floor.
  'pc-tower': _Slot(0.875, 0.93, 86),
  'chair': _Slot(0.42, 1.02, 150),
};

// Items further back are drawn first.
const _depthOrder = [
  // wall
  'curtains', 'poster-art', 'poster-band', 'clock', 'shelf',
  // desk back
  'lamp-arc', 'lamp-round', 'plant', 'speaker', 'headphones',
  'monitor', 'monitor-duo', 'laptop',
  // desk front
  'coffee', 'soda', 'water',
  'keyboard', 'mousepad-xl', 'mousepad-m', 'mousepad-s', 'mouse',
  // floor
  'pc-tower', 'chair',
];

class _RoomScene extends StatelessWidget {
  const _RoomScene({required this.owned, required this.onTapItem});

  final Map<String, String> owned;
  final void Function(String itemId) onTapItem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1.18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            return Stack(
              children: [
                // Room + desk backdrop. The desk takes the owned desk's
                // colour (default oak otherwise).
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoomPainter(
                      scheme.primary,
                      owned.containsKey('desk')
                          ? (_itemColors[owned['desk']] ?? const Color(0xFF9A6A3F))
                          : const Color(0xFF9A6A3F),
                    ),
                  ),
                ),
                // Owned items, back to front, each tappable.
                for (final id in _depthOrder)
                  if (owned.containsKey(id))
                    Positioned(
                      left: w * _slots[id]!.x - _slots[id]!.size / 2,
                      top: h * _slots[id]!.y - _slots[id]!.size,
                      child: GestureDetector(
                        onTap: () => onTapItem(id),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.6, end: 1),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          builder: (context, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: Tooltip(
                            message: 'Recolour',
                            child: ItemArt(
                              itemId: id,
                              color: _itemColors[owned[id]] ?? Colors.grey,
                              size: _slots[id]!.size,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Paints the room: walls, floor, window, rug and the desk — all in a
/// simple two-point-ish perspective so the space reads as 3D.
class _RoomPainter extends CustomPainter {
  _RoomPainter(this.accent, this.deskColor);

  final Color accent;
  final Color deskColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back wall.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.62),
        Paint()..color = const Color(0xFF232838));
    // Side wall (left, angled) for depth.
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w * 0.12, h * 0.06)
        ..lineTo(w * 0.12, h * 0.66)
        ..lineTo(0, h * 0.78)
        ..close(),
      Paint()..color = const Color(0xFF1B2030),
    );
    // Floor (perspective).
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.78)
        ..lineTo(w * 0.12, h * 0.66)
        ..lineTo(w, h * 0.62)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF2E2A3A),
    );
    // Floor boards.
    final board = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 2;
    for (var i = 1; i < 5; i++) {
      final t = i / 5;
      canvas.drawLine(Offset(w * 0.06 * (1 - t), h * (0.78 + 0.22 * t)),
          Offset(w, h * (0.62 + 0.38 * t)), board);
    }
    // Rug under the chair.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.45, h * 0.88), width: w * 0.52, height: h * 0.2),
      Paint()..color = accent.withValues(alpha: 0.16),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.45, h * 0.88), width: w * 0.4, height: h * 0.14),
      Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Window with night glow.
    final win = Rect.fromLTWH(w * 0.60, h * 0.08, w * 0.27, h * 0.30);
    canvas.drawRRect(
        RRect.fromRectAndRadius(win.inflate(5), const Radius.circular(10)),
        Paint()..color = const Color(0xFF161A26));
    canvas.drawRRect(RRect.fromRectAndRadius(win, const Radius.circular(6)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C3563), Color(0xFF581C87)],
          ).createShader(win));
    // Stars + moon.
    final star = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(win.left + win.width * 0.7, win.top + win.height * 0.25),
        win.width * 0.09, Paint()..color = const Color(0xFFF4F1DE));
    for (final p in [
      const Offset(0.2, 0.3), const Offset(0.35, 0.6),
      const Offset(0.55, 0.45), const Offset(0.8, 0.7), const Offset(0.15, 0.8),
    ]) {
      canvas.drawCircle(
          Offset(win.left + win.width * p.dx, win.top + win.height * p.dy),
          1.4, star);
    }
    // Window cross bars.
    final bar = Paint()..color = const Color(0xFF161A26)..strokeWidth = 4;
    canvas.drawLine(Offset(win.center.dx, win.top), Offset(win.center.dx, win.bottom), bar);
    canvas.drawLine(Offset(win.left, win.center.dy), Offset(win.right, win.center.dy), bar);

    // ── Desk (isometric) ────────────────────────────────────────
    final wood = deskColor;
    final deskTop = Path()
      ..moveTo(w * 0.13, h * 0.62)
      ..lineTo(w * 0.20, h * 0.565)
      ..lineTo(w * 0.86, h * 0.565)
      ..lineTo(w * 0.82, h * 0.62)
      ..close();
    canvas.drawPath(deskTop, Paint()..color = wood);
    // Desk front face.
    canvas.drawRect(Rect.fromLTRB(w * 0.13, h * 0.62, w * 0.82, h * 0.655),
        Paint()..color = _shade(wood, 0.10));
    // Desk side edge highlight.
    canvas.drawPath(
        deskTop,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Legs.
    final leg = Paint()..color = _shade(wood, 0.22);
    canvas.drawRect(Rect.fromLTWH(w * 0.16, h * 0.655, w * 0.025, h * 0.20), leg);
    canvas.drawRect(Rect.fromLTWH(w * 0.77, h * 0.655, w * 0.025, h * 0.185), leg);
    canvas.drawRect(Rect.fromLTWH(w * 0.225, h * 0.61, w * 0.018, h * 0.015), leg);
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.accent != accent || old.deskColor != deskColor;
}

// ════ Item art ══════════════════════════════════════════════════

/// Draws a study item in its colour — used in the room, the shop tiles and
/// the colour sheet. Pure vector.
class ItemArt extends StatelessWidget {
  const ItemArt(
      {super.key, required this.itemId, required this.color, this.size = 60});

  final String itemId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ItemPainter(itemId, color)),
    );
  }
}

class _ItemPainter extends CustomPainter {
  _ItemPainter(this.id, this.c);

  final String id;
  final Color c;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s, s);
    final fill = Paint()..color = c;
    final dark = Paint()..color = _shade(c, 0.14);
    final darker = Paint()..color = _shade(c, 0.26);

    switch (id) {
      case 'monitor':
        _monitor(canvas, const Offset(50, 0), 84, fill, dark);
      case 'monitor-duo':
        canvas.save();
        canvas.translate(2, 6);
        canvas.skew(0.06, 0);
        _monitor(canvas, const Offset(28, 0), 52, fill, dark);
        canvas.restore();
        canvas.save();
        canvas.translate(-2, 6);
        canvas.skew(-0.06, 0);
        _monitor(canvas, const Offset(72, 0), 52, fill, dark);
        canvas.restore();
      case 'laptop':
        // Screen tilted back.
        final screen = RRect.fromRectAndRadius(
            const Rect.fromLTWH(22, 18, 56, 40), const Radius.circular(4));
        canvas.drawRRect(screen, fill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 48, 32),
                const Radius.circular(2)),
            Paint()
              ..shader = const LinearGradient(
                colors: [Color(0xFF3B4C7A), Color(0xFF7C3AED)],
              ).createShader(const Rect.fromLTWH(26, 22, 48, 32)));
        // Base (keyboard deck) in perspective.
        canvas.drawPath(
            Path()
              ..moveTo(22, 58)..lineTo(78, 58)..lineTo(88, 74)..lineTo(12, 74)..close(),
            dark);
        canvas.drawPath(
            Path()
              ..moveTo(30, 62)..lineTo(70, 62)..lineTo(74, 68)..lineTo(26, 68)..close(),
            darker);
      case 'keyboard':
        canvas.drawPath(
            Path()
              ..moveTo(14, 76)..lineTo(24, 58)..lineTo(86, 58)..lineTo(94, 76)..close(),
            fill);
        for (var r = 0; r < 3; r++) {
          for (var k = 0; k < 8; k++) {
            canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromLTWH(26.0 + k * 7.4 + r * 1.6, 61.0 + r * 5, 5.4, 3.6),
                    const Radius.circular(1)),
                darker);
          }
        }
      case 'mouse':
        canvas.drawOval(const Rect.fromLTWH(30, 40, 40, 52), fill);
        canvas.drawLine(const Offset(50, 44), const Offset(50, 58),
            Paint()..color = _shade(c, 0.3)..strokeWidth = 3);
      case 'mousepad-s' || 'mousepad-m' || 'mousepad-xl':
        canvas.drawPath(
            Path()
              ..moveTo(8, 80)..lineTo(26, 56)..lineTo(92, 56)..lineTo(80, 80)..close(),
            fill);
        canvas.drawPath(
            Path()
              ..moveTo(8, 80)..lineTo(26, 56)..lineTo(92, 56)..lineTo(80, 80)..close(),
            Paint()
              ..color = _shade(c, 0.2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
      case 'lamp-round':
        canvas.drawRect(const Rect.fromLTWH(44, 60, 12, 34), dark);
        canvas.drawOval(const Rect.fromLTWH(30, 88, 40, 10), darker);
        // Glowing dome.
        canvas.drawCircle(const Offset(50, 42), 26,
            Paint()
              ..color = const Color(0xFFFFE9A8).withValues(alpha: 0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
        canvas.drawPath(
            Path()
              ..moveTo(24, 52)
              ..arcToPoint(const Offset(76, 52), radius: const Radius.circular(27)),
            fill);
        canvas.drawRect(const Rect.fromLTWH(24, 50, 52, 5), fill);
        canvas.drawOval(const Rect.fromLTWH(34, 52, 32, 7),
            Paint()..color = const Color(0xFFFFF3C4));
      case 'lamp-arc':
        canvas.drawOval(const Rect.fromLTWH(14, 88, 30, 8), darker);
        canvas.drawPath(
            Path()
              ..moveTo(28, 90)
              ..quadraticBezierTo(20, 30, 62, 26),
            Paint()
              ..color = c
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round);
        canvas.drawPath(
            Path()..moveTo(54, 24)..lineTo(78, 24)..lineTo(70, 42)..lineTo(58, 42)..close(),
            dark);
        canvas.drawCircle(const Offset(64, 46), 12,
            Paint()
              ..color = const Color(0xFFFFE9A8).withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      case 'headphones':
        canvas.drawPath(
            Path()
              ..moveTo(22, 56)
              ..arcToPoint(const Offset(78, 56), radius: const Radius.circular(30)),
            Paint()
              ..color = c
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7
              ..strokeCap = StrokeCap.round);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(14, 52, 18, 28),
                const Radius.circular(8)),
            dark);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(68, 52, 18, 28),
                const Radius.circular(8)),
            dark);
      case 'speaker':
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(28, 18, 44, 74),
                const Radius.circular(9)),
            fill);
        canvas.drawCircle(const Offset(50, 66), 15, darker);
        canvas.drawCircle(const Offset(50, 66), 8, dark);
        canvas.drawCircle(const Offset(50, 34), 7, darker);
      case 'plant':
        canvas.drawPath(
            Path()
              ..moveTo(34, 66)..lineTo(66, 66)..lineTo(60, 92)..lineTo(40, 92)..close(),
            Paint()..color = const Color(0xFFB05A1F));
        final leaf = Paint()..color = c;
        for (final a in [-0.7, -0.25, 0.25, 0.7, 0.0]) {
          canvas.save();
          canvas.translate(50, 64);
          canvas.rotate(a);
          canvas.drawOval(const Rect.fromLTWH(-7, -42, 14, 42), leaf);
          canvas.restore();
        }
      case 'chair':
        // Gaming chair, three-quarter view.
        final back = RRect.fromRectAndRadius(
            const Rect.fromLTWH(30, 4, 40, 52), const Radius.circular(13));
        canvas.drawRRect(back, fill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(38, 12, 24, 38),
                const Radius.circular(8)),
            dark);
        // Seat.
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(26, 54, 48, 14),
                const Radius.circular(7)),
            fill);
        // Armrests.
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(20, 44, 8, 18),
                const Radius.circular(4)),
            darker);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(72, 44, 8, 18),
                const Radius.circular(4)),
            darker);
        // Stem + star base with wheels.
        canvas.drawRect(const Rect.fromLTWH(47, 68, 6, 14), darker);
        for (final dx in [-22.0, -8.0, 8.0, 22.0]) {
          canvas.drawLine(const Offset(50, 82), Offset(50 + dx, 92),
              Paint()..color = _shade(c, 0.26)..strokeWidth = 4);
          canvas.drawCircle(Offset(50 + dx, 93), 3.4, darker);
        }
      case 'pc-tower':
        canvas.drawPath(
            Path()
              ..moveTo(30, 14)..lineTo(62, 14)..lineTo(70, 22)..lineTo(70, 90)
              ..lineTo(38, 90)..lineTo(30, 82)..close(),
            dark);
        canvas.drawRect(const Rect.fromLTWH(30, 14, 32, 68), fill);
        // Glass front glow strip.
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(35, 22, 5, 52),
                const Radius.circular(2)),
            Paint()
              ..color = const Color(0xFF22D3EE)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        canvas.drawCircle(const Offset(53, 24), 2.6,
            Paint()..color = const Color(0xFF4ADE80));
        for (var y = 36.0; y < 72; y += 9) {
          canvas.drawCircle(Offset(52, y), 5.5, darker);
        }
      case 'desk':
        // Little isometric desk.
        canvas.drawPath(
            Path()
              ..moveTo(14, 46)..lineTo(26, 36)..lineTo(90, 36)..lineTo(80, 46)..close(),
            fill);
        canvas.drawRect(const Rect.fromLTWH(14, 46, 66, 8), dark);
        canvas.drawRect(const Rect.fromLTWH(18, 54, 6, 34), darker);
        canvas.drawRect(const Rect.fromLTWH(72, 54, 6, 30), darker);
      case 'shelf':
        canvas.drawRect(const Rect.fromLTWH(14, 50, 72, 8), fill);
        canvas.drawRect(const Rect.fromLTWH(14, 50, 72, 3), darker);
        // Books on top.
        const bookCols = [
          Color(0xFFEF5350), Color(0xFF42A5F5), Color(0xFF66BB6A), Color(0xFFFFCA28),
        ];
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(Rect.fromLTWH(22.0 + i * 9, 30, 7, 20),
              Paint()..color = bookCols[i]);
        }
        canvas.drawCircle(const Offset(72, 42), 7, darker); // little plant pot
      case 'poster-art':
        final frame = const Rect.fromLTWH(22, 14, 56, 72);
        canvas.drawRect(frame, dark);
        canvas.drawRect(frame.deflate(4), fill);
        // Abstract shapes.
        canvas.drawCircle(const Offset(42, 38), 12,
            Paint()..color = Colors.white.withValues(alpha: 0.8));
        canvas.drawPath(
            Path()..moveTo(34, 74)..lineTo(54, 46)..lineTo(70, 74)..close(),
            Paint()..color = Colors.white.withValues(alpha: 0.55));
      case 'poster-band':
        final frame = const Rect.fromLTWH(22, 14, 56, 72);
        canvas.drawRect(frame, fill);
        // Sound bars.
        final bar = Paint()..color = Colors.white.withValues(alpha: 0.85);
        const hs = [22.0, 38.0, 30.0, 46.0, 26.0];
        for (var i = 0; i < 5; i++) {
          canvas.drawRect(Rect.fromLTWH(30.0 + i * 8, 70 - hs[i], 5, hs[i]), bar);
        }
      case 'clock':
        canvas.drawCircle(const Offset(50, 50), 30, fill);
        canvas.drawCircle(const Offset(50, 50), 30,
            Paint()
              ..color = darker.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
        canvas.drawCircle(const Offset(50, 50), 3, darker);
        final hand = Paint()
          ..color = darker.color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(50, 50), const Offset(50, 32), hand);
        canvas.drawLine(const Offset(50, 50), const Offset(64, 54), hand);
      case 'curtains':
        // Two drapes framing a glowing window.
        canvas.drawRect(const Rect.fromLTWH(30, 14, 40, 70),
            Paint()..color = const Color(0xFF2C3563));
        canvas.drawRect(const Rect.fromLTWH(20, 8, 60, 8), darker); // rod
        for (final side in [const Rect.fromLTWH(20, 12, 18, 76),
                            const Rect.fromLTWH(62, 12, 18, 76)]) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(side, const Radius.circular(6)), fill);
          for (var i = 0; i < 3; i++) {
            canvas.drawLine(
                Offset(side.left + 4 + i * 5, side.top),
                Offset(side.left + 4 + i * 5, side.bottom),
                Paint()
                  ..color = darker.color.withValues(alpha: 0.5)
                  ..strokeWidth = 2);
          }
        }
      case 'coffee':
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(34, 44, 32, 38),
                const Radius.circular(5)),
            fill);
        canvas.drawOval(const Rect.fromLTWH(34, 40, 32, 10), darker);
        // Handle.
        canvas.drawArc(const Rect.fromLTWH(60, 50, 18, 22), -1.2, 2.6, false,
            Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 4);
        // Steam.
        final steam = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
            Path()..moveTo(44, 36)..quadraticBezierTo(48, 30, 44, 24), steam);
        canvas.drawPath(
            Path()..moveTo(56, 36)..quadraticBezierTo(60, 30, 56, 24), steam);
      case 'soda':
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(38, 26, 24, 56),
                const Radius.circular(6)),
            fill);
        canvas.drawRect(const Rect.fromLTWH(38, 40, 24, 14),
            Paint()..color = Colors.white.withValues(alpha: 0.8));
        canvas.drawOval(const Rect.fromLTWH(40, 22, 20, 7), darker);
      case 'water':
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(40, 30, 20, 54),
                const Radius.circular(8)),
            Paint()..color = c.withValues(alpha: 0.5));
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(40, 52, 20, 32),
                const Radius.circular(8)),
            fill);
        canvas.drawRect(const Rect.fromLTWH(44, 20, 12, 12), darker); // cap
      default:
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(25, 25, 50, 50),
                const Radius.circular(10)),
            fill);
    }
  }

  void _monitor(Canvas canvas, Offset center, double width, Paint fill, Paint dark) {
    final h = width * 0.62;
    final rect = Rect.fromLTWH(center.dx - width / 2, 16, width, h);
    // Stand.
    canvas.drawRect(
        Rect.fromLTWH(center.dx - 4, 16 + h, 8, 90 - (16 + h) - 8), dark);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - width * 0.22, 84, width * 0.44, 7),
            const Radius.circular(3)),
        dark);
    // Bezel + screen.
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(6)), fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF35406B), Color(0xFF7C3AED), Color(0xFF22D3EE)],
          ).createShader(rect));
    // Code lines on screen.
    final line = Paint()..color = Colors.white.withValues(alpha: 0.55)..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
          Offset(rect.left + 6, rect.top + 8 + i * 8),
          Offset(rect.left + 6 + (i.isEven ? rect.width * 0.5 : rect.width * 0.32),
              rect.top + 8 + i * 8),
          line);
    }
  }

  @override
  bool shouldRepaint(_ItemPainter old) => old.id != id || old.c != c;
}
