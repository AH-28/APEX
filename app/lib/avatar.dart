import 'package:flutter/material.dart';

/// Character configuration — stored as jsonb in profiles.avatar.
class AvatarConfig {
  AvatarConfig({
    this.body = 'regular',
    this.skin = 0,
    this.face = 'oval',
    this.nose = 'button',
    this.eyeShape = 'round',
    this.eyeColor = 0,
    this.hair = 'short',
    this.hairColor = 0,
    this.outfit = 'tee-classic',
    this.outfitColor = 0,
  });

  String body; // slim | regular | broad
  int skin; // index into skinTones
  String face; // round | oval | square | heart
  String nose; // button | pointed | round | wide
  String eyeShape; // round | almond | happy | sleepy
  int eyeColor; // index into eyeColors
  String hair; // none | buzz | short | curly | long | bun | spiky
  int hairColor; // index into hairColors
  String outfit; // outfit id (see outfitStyles)
  int outfitColor; // index into the outfit's palette

  factory AvatarConfig.fromJson(Map<String, dynamic> j) => AvatarConfig(
        body: j['body'] as String? ?? 'regular',
        skin: j['skin'] as int? ?? 0,
        face: j['face'] as String? ?? 'oval',
        nose: j['nose'] as String? ?? 'button',
        eyeShape: j['eyeShape'] as String? ?? 'round',
        eyeColor: j['eyeColor'] as int? ?? 0,
        hair: j['hair'] as String? ?? 'short',
        hairColor: j['hairColor'] as int? ?? 0,
        outfit: j['outfit'] as String? ?? 'tee-classic',
        outfitColor: j['outfitColor'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'body': body,
        'skin': skin,
        'face': face,
        'nose': nose,
        'eyeShape': eyeShape,
        'eyeColor': eyeColor,
        'hair': hair,
        'hairColor': hairColor,
        'outfit': outfit,
        'outfitColor': outfitColor,
      };

  AvatarConfig copyWith({
    String? body,
    int? skin,
    String? face,
    String? nose,
    String? eyeShape,
    int? eyeColor,
    String? hair,
    int? hairColor,
    String? outfit,
    int? outfitColor,
  }) =>
      AvatarConfig(
        body: body ?? this.body,
        skin: skin ?? this.skin,
        face: face ?? this.face,
        nose: nose ?? this.nose,
        eyeShape: eyeShape ?? this.eyeShape,
        eyeColor: eyeColor ?? this.eyeColor,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        outfit: outfit ?? this.outfit,
        outfitColor: outfitColor ?? this.outfitColor,
      );
}

const skinTones = [
  Color(0xFFFFDFC4),
  Color(0xFFF0C8A0),
  Color(0xFFDDA877),
  Color(0xFFB97D4F),
  Color(0xFF8D5B33),
  Color(0xFF5F3D22),
];

const eyeColors = [
  Color(0xFF5B4334), // brown
  Color(0xFF3E7C57), // green
  Color(0xFF4A7FC1), // blue
  Color(0xFF7A828F), // grey
  Color(0xFF8B5CF6), // violet
  Color(0xFFC98A2D), // amber
];

const hairColors = [
  Color(0xFF26201C), // black
  Color(0xFF4F3422), // dark brown
  Color(0xFF96613A), // brown
  Color(0xFFE3B873), // blonde
  Color(0xFFC25A2A), // ginger
  Color(0xFFA6ACB8), // silver
  Color(0xFF8B5CF6), // violet
  Color(0xFFF472B6), // pink
];

const bodyTypes = ['slim', 'regular', 'broad'];
const faceShapes = ['round', 'oval', 'square', 'heart'];
const noseShapes = ['button', 'pointed', 'round', 'wide'];
const eyeShapes = ['round', 'almond', 'happy', 'sleepy'];
const hairStyles = ['none', 'buzz', 'short', 'curly', 'long', 'bun', 'spiky'];

/// Visual definition of each outfit (palette + style key for the painter).
class OutfitStyle {
  const OutfitStyle(this.style, this.palette);
  final String style; // tee | stripe | tank | hoodie | jacket | shirt | suit | galaxy
  final List<Color> palette;
}

const outfitStyles = <String, OutfitStyle>{
  'tee-classic': OutfitStyle('tee',
      [Color(0xFFE8EAEF), Color(0xFF2A3140), Color(0xFF8B5CF6), Color(0xFF2FB57C)]),
  'tee-stripe': OutfitStyle('stripe',
      [Color(0xFF4A7FC1), Color(0xFFE45C82), Color(0xFF2FB57C)]),
  'hoodie-cozy': OutfitStyle('hoodie',
      [Color(0xFF7E8694), Color(0xFF2A3140), Color(0xFF7C3AED), Color(0xFFB05A1F)]),
  'tank-sport': OutfitStyle('tank',
      [Color(0xFF22272F), Color(0xFFE0483C), Color(0xFF1FA8C9)]),
  'hoodie-neon': OutfitStyle('hoodie',
      [Color(0xFFA3E635), Color(0xFF22D3EE), Color(0xFFF472B6)]),
  'jacket-bomber': OutfitStyle('jacket',
      [Color(0xFF454D5C), Color(0xFF275438), Color(0xFF7E2B26)]),
  'shirt-formal': OutfitStyle('shirt',
      [Color(0xFFF4F6FA), Color(0xFFBFDBFE), Color(0xFFFBCFE8)]),
  'suit-sharp': OutfitStyle('suit',
      [Color(0xFF22272F), Color(0xFF233D5C), Color(0xFF4C1D95)]),
  'galaxy-fit': OutfitStyle('galaxy',
      [Color(0xFF4C1D95), Color(0xFF0C4A6E)]),
};

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Renders an [AvatarConfig] in a friendly big-head cartoon style.
/// Pure vector — no assets.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.config, this.size = 160});

  final AvatarConfig config;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.3,
      child: CustomPaint(painter: _AvatarPainter(config)),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.c);

  final AvatarConfig c;

  @override
  void paint(Canvas canvas, Size size) {
    // Design space: 200 x 260. Big head, small body — Bitmoji proportions.
    final s = size.width / 200;
    canvas.scale(s, s);

    final skin = skinTones[c.skin.clamp(0, skinTones.length - 1)];
    final skinShadow = _darken(skin, 0.12);
    final skinPaint = Paint()..color = skin;
    final hairC = hairColors[c.hairColor.clamp(0, hairColors.length - 1)];
    final hairHi = _lighten(hairC, 0.10);
    final hairPaint = Paint()..color = hairC;
    final outline = Paint()
      ..color = const Color(0xFF2B1F18).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final outfit = outfitStyles[c.outfit] ?? outfitStyles['tee-classic']!;
    final outfitC =
        outfit.palette[c.outfitColor.clamp(0, outfit.palette.length - 1)];
    final outfitShade = _darken(outfitC, 0.10);

    // Head geometry per face shape (big head: ~115 wide, ~125 tall).
    final headRect = switch (c.face) {
      'round' => const Rect.fromLTWH(44, 42, 112, 120),
      'square' => const Rect.fromLTWH(46, 42, 108, 122),
      'heart' => const Rect.fromLTWH(45, 42, 110, 122),
      _ => const Rect.fromLTWH(48, 40, 104, 126), // oval
    };
    final headPath = switch (c.face) {
      'round' => Path()..addOval(headRect),
      'square' => (Path()
        ..addRRect(RRect.fromRectAndRadius(headRect, const Radius.circular(38)))),
      'heart' => (Path()
        ..moveTo(headRect.left, headRect.top + 46)
        ..quadraticBezierTo(headRect.left, headRect.top, headRect.center.dx,
            headRect.top)
        ..quadraticBezierTo(headRect.right, headRect.top, headRect.right,
            headRect.top + 46)
        ..quadraticBezierTo(headRect.right - 4, headRect.bottom - 28,
            headRect.center.dx + 14, headRect.bottom - 6)
        ..quadraticBezierTo(headRect.center.dx, headRect.bottom + 4,
            headRect.center.dx - 14, headRect.bottom - 6)
        ..quadraticBezierTo(headRect.left + 4, headRect.bottom - 28,
            headRect.left, headRect.top + 46)
        ..close()),
      _ => (Path()
        ..addRRect(RRect.fromRectAndCorners(headRect,
            topLeft: const Radius.circular(52),
            topRight: const Radius.circular(52),
            bottomLeft: const Radius.circular(60),
            bottomRight: const Radius.circular(60)))),
    };
    final hl = headRect.left;
    final hr = headRect.right;
    final ht = headRect.top;

    // ── Back hair (drawn behind head and torso) ─────────────────
    if (c.hair == 'long') {
      final back = Path()
        ..moveTo(hl - 10, 215)
        ..lineTo(hl - 10, ht + 34)
        ..quadraticBezierTo(hl - 8, ht - 18, 100, ht - 20)
        ..quadraticBezierTo(hr + 8, ht - 18, hr + 10, ht + 34)
        ..lineTo(hr + 10, 215)
        ..quadraticBezierTo(hr - 2, 224, hr - 16, 214)
        ..lineTo(hl + 16, 214)
        ..quadraticBezierTo(hl + 2, 224, hl - 10, 215)
        ..close();
      canvas.drawPath(back, hairPaint);
      canvas.drawPath(back, outline);
    }

    // ── Neck + torso ────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(100, 172), width: 26, height: 32),
          const Radius.circular(8)),
      skinPaint,
    );
    // Chin shadow on neck.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(100, 164), width: 26, height: 12),
          const Radius.circular(8)),
      Paint()..color = skinShadow.withValues(alpha: 0.55),
    );

    final shoulder = switch (c.body) {
      'slim' => 40.0,
      'broad' => 58.0,
      _ => 48.0,
    };
    final torso = Path()
      ..moveTo(100 - shoulder, 260)
      ..lineTo(100 - shoulder, 208)
      ..quadraticBezierTo(100 - shoulder, 182, 100 - shoulder + 22, 180)
      ..lineTo(100 + shoulder - 22, 180)
      ..quadraticBezierTo(100 + shoulder, 182, 100 + shoulder, 208)
      ..lineTo(100 + shoulder, 260)
      ..close();

    Paint torsoPaint = Paint()..color = outfitC;
    if (outfit.style == 'galaxy') {
      torsoPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [outfitC, const Color(0xFFE45C82), const Color(0xFF22D3EE)],
        ).createShader(Rect.fromLTWH(100 - shoulder, 180, shoulder * 2, 80));
    }
    canvas.drawPath(torso, torsoPaint);

    // Sleeve seams give the torso an arms silhouette.
    final seam = Paint()
      ..color = outfitShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(
      Path()
        ..moveTo(100 - shoulder + 14, 192)
        ..quadraticBezierTo(100 - shoulder + 17, 222, 100 - shoulder + 13, 260),
      seam,
    );
    canvas.drawPath(
      Path()
        ..moveTo(100 + shoulder - 14, 192)
        ..quadraticBezierTo(100 + shoulder - 17, 222, 100 + shoulder - 13, 260),
      seam,
    );

    _outfitDetails(canvas, outfit.style, outfitC, shoulder, skinPaint, torso);
    canvas.drawPath(torso, outline);

    // ── Ears (before head so head overlaps their inner edge) ───
    final earY = ht + 70;
    for (final ex in [hl + 2, hr - 2]) {
      canvas.drawCircle(Offset(ex, earY), 11, skinPaint);
      canvas.drawCircle(Offset(ex, earY), 11, outline);
      canvas.drawCircle(
          Offset(ex, earY), 4.5, Paint()..color = skinShadow.withValues(alpha: 0.6));
    }

    // ── Head ────────────────────────────────────────────────────
    canvas.drawPath(headPath, skinPaint);
    canvas.drawPath(headPath, outline);

    // ── Front hair ──────────────────────────────────────────────
    canvas.save();
    _frontHair(canvas, hairPaint, hairHi, outline, hl, hr, ht, headPath);
    canvas.restore();

    // ── Brows ───────────────────────────────────────────────────
    final browPaint = Paint()
      ..color = c.hair == 'none' ? _darken(skin, 0.25) : _darken(hairC, 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final browY = ht + 56;
    for (final ex in [76.0, 124.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(ex - 13, browY)
          ..quadraticBezierTo(ex, browY - 8, ex + 13, browY),
        browPaint,
      );
    }

    // ── Eyes ────────────────────────────────────────────────────
    final irisC = eyeColors[c.eyeColor.clamp(0, eyeColors.length - 1)];
    final eyeY = ht + 76.0;
    for (final ex in [76.0, 124.0]) {
      _eye(canvas, Offset(ex, eyeY), irisC, skin, skinShadow);
    }

    // ── Nose (subtle outline, cartoon style) ────────────────────
    final nosePaint = Paint()
      ..color = skinShadow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    final noseY = ht + 96.0;
    switch (c.nose) {
      case 'pointed':
        canvas.drawPath(
          Path()
            ..moveTo(99, noseY - 12)
            ..lineTo(93, noseY + 4)
            ..quadraticBezierTo(97, noseY + 9, 104, noseY + 5),
          nosePaint,
        );
      case 'round':
        canvas.drawPath(
          Path()
            ..moveTo(94, noseY - 2)
            ..quadraticBezierTo(91, noseY + 8, 100, noseY + 8)
            ..quadraticBezierTo(109, noseY + 8, 106, noseY - 2),
          nosePaint,
        );
      case 'wide':
        canvas.drawPath(
          Path()
            ..moveTo(90, noseY)
            ..quadraticBezierTo(89, noseY + 8, 96, noseY + 8)
            ..lineTo(104, noseY + 8)
            ..quadraticBezierTo(111, noseY + 8, 110, noseY),
          nosePaint,
        );
        canvas.drawCircle(Offset(93, noseY + 7), 1.6, Paint()..color = skinShadow);
        canvas.drawCircle(Offset(107, noseY + 7), 1.6, Paint()..color = skinShadow);
      default: // button
        canvas.drawPath(
          Path()
            ..moveTo(95, noseY + 2)
            ..quadraticBezierTo(100, noseY + 8, 105, noseY + 2),
          nosePaint,
        );
    }

    // ── Blush ───────────────────────────────────────────────────
    final blush = Paint()
      ..color = const Color(0xFFE8707C).withValues(alpha: 0.28);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(68, ht + 96), width: 18, height: 9), blush);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(132, ht + 96), width: 18, height: 9), blush);

    // ── Mouth (open smile with teeth) ───────────────────────────
    final mouthY = ht + 110.0;
    final mouth = Path()
      ..moveTo(86, mouthY)
      ..quadraticBezierTo(100, mouthY + 16, 114, mouthY)
      ..quadraticBezierTo(100, mouthY + 4, 86, mouthY)
      ..close();
    canvas.drawPath(mouth, Paint()..color = const Color(0xFF7C3A41));
    // Teeth.
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawRect(Rect.fromLTWH(88, mouthY, 24, 5), Paint()..color = Colors.white);
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(86, mouthY)
        ..quadraticBezierTo(100, mouthY + 16, 114, mouthY),
      Paint()
        ..color = const Color(0xFF5C2A30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _eye(Canvas canvas, Offset center, Color iris, Color skin, Color shadow) {
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = const Color(0xFF23180F);
    switch (c.eyeShape) {
      case 'happy':
        // Closed, joyful arc.
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - 12, center.dy + 3)
            ..quadraticBezierTo(
                center.dx, center.dy - 13, center.dx + 12, center.dy + 3),
          Paint()
            ..color = dark.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round,
        );
        return;
      case 'almond':
        final lid = Path()
          ..moveTo(center.dx - 13, center.dy + 2)
          ..quadraticBezierTo(center.dx, center.dy - 12, center.dx + 13, center.dy + 2)
          ..quadraticBezierTo(center.dx, center.dy + 10, center.dx - 13, center.dy + 2)
          ..close();
        canvas.drawPath(lid, white);
        canvas.save();
        canvas.clipPath(lid);
        _irisStack(canvas, center.translate(0, 0), iris, r: 7);
        canvas.restore();
        canvas.drawPath(
            lid,
            Paint()
              ..color = const Color(0xFF2B1F18).withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6);
      case 'sleepy':
        final lid = Path()
          ..moveTo(center.dx - 13, center.dy)
          ..quadraticBezierTo(center.dx, center.dy - 5, center.dx + 13, center.dy)
          ..quadraticBezierTo(center.dx, center.dy + 13, center.dx - 13, center.dy)
          ..close();
        canvas.drawPath(lid, white);
        canvas.save();
        canvas.clipPath(lid);
        _irisStack(canvas, center.translate(0, 3), iris, r: 6.5);
        canvas.restore();
        // Heavy upper lid line.
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - 13, center.dy)
            ..quadraticBezierTo(center.dx, center.dy - 5, center.dx + 13, center.dy),
          Paint()
            ..color = const Color(0xFF23180F).withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      default: // round
        canvas.drawOval(
            Rect.fromCenter(center: center, width: 24, height: 22), white);
        _irisStack(canvas, center.translate(0, 1), iris, r: 7.5);
        canvas.drawOval(
            Rect.fromCenter(center: center, width: 24, height: 22),
            Paint()
              ..color = const Color(0xFF2B1F18).withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6);
    }
  }

  void _irisStack(Canvas canvas, Offset at, Color iris, {required double r}) {
    canvas.drawCircle(at, r, Paint()..color = _darken(iris, 0.12));
    canvas.drawCircle(at, r - 1.4, Paint()..color = iris);
    canvas.drawCircle(at, r * 0.45, Paint()..color = const Color(0xFF23180F));
    canvas.drawCircle(
        at.translate(-r * 0.35, -r * 0.4), r * 0.22, Paint()..color = Colors.white);
  }

  void _frontHair(Canvas canvas, Paint hairPaint, Color hairHi, Paint outline,
      double hl, double hr, double ht, Path headPath) {
    final hi = Paint()
      ..color = hairHi
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    switch (c.hair) {
      case 'buzz':
        canvas.save();
        canvas.clipPath(headPath);
        canvas.drawPath(
          Path()
            ..moveTo(hl, ht + 40)
            ..quadraticBezierTo(100, ht - 4, hr, ht + 40)
            ..lineTo(hr, ht)
            ..lineTo(hl, ht)
            ..close(),
          Paint()..color = hairPaint.color.withValues(alpha: 0.65),
        );
        canvas.restore();
      case 'short':
        final p = Path()
          ..moveTo(hl - 3, ht + 52)
          ..quadraticBezierTo(hl - 6, ht - 12, 100, ht - 14)
          ..quadraticBezierTo(hr + 6, ht - 12, hr + 3, ht + 52)
          ..quadraticBezierTo(hr - 4, ht + 28, hr - 26, ht + 26)
          ..quadraticBezierTo(108, ht + 16, 84, ht + 24)
          ..quadraticBezierTo(hl + 14, ht + 32, hl - 3, ht + 52)
          ..close();
        canvas.drawPath(p, hairPaint);
        canvas.drawPath(p, outline);
        canvas.drawPath(
          Path()
            ..moveTo(74, ht + 2)
            ..quadraticBezierTo(96, ht - 6, 120, ht + 1),
          hi,
        );
      case 'curly':
        for (final d in [
          const Offset(-38, 16),
          const Offset(-26, 0),
          const Offset(-9, -8),
          const Offset(9, -8),
          const Offset(26, 0),
          const Offset(38, 16),
        ]) {
          canvas.drawCircle(Offset(100 + d.dx, ht + 8 + d.dy), 19, hairPaint);
        }
        canvas.drawCircle(Offset(hl + 4, ht + 40), 15, hairPaint);
        canvas.drawCircle(Offset(hr - 4, ht + 40), 15, hairPaint);
        for (final d in [const Offset(-22, -4), const Offset(4, -12), const Offset(28, 0)]) {
          canvas.drawCircle(Offset(100 + d.dx, ht + 8 + d.dy), 4,
              Paint()..color = hairHi.withValues(alpha: 0.8));
        }
      case 'long':
        final crown = Path()
          ..moveTo(hl - 4, ht + 56)
          ..quadraticBezierTo(hl - 6, ht - 14, 100, ht - 16)
          ..quadraticBezierTo(hr + 6, ht - 14, hr + 4, ht + 56)
          ..quadraticBezierTo(hr - 8, ht + 22, 100, ht + 18)
          ..quadraticBezierTo(hl + 8, ht + 22, hl - 4, ht + 56)
          ..close();
        canvas.drawPath(crown, hairPaint);
        canvas.drawPath(crown, outline);
        canvas.drawPath(
          Path()
            ..moveTo(72, ht)
            ..quadraticBezierTo(100, ht - 8, 128, ht),
          hi,
        );
      case 'bun':
        canvas.drawCircle(Offset(100, ht - 12), 19, hairPaint);
        canvas.drawCircle(Offset(100, ht - 12), 19, outline);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(100, ht + 2), width: 30, height: 8),
              const Radius.circular(4)),
          Paint()..color = _darken(hairPaint.color, 0.12),
        );
        final cap = Path()
          ..moveTo(hl - 2, ht + 48)
          ..quadraticBezierTo(100, ht - 16, hr + 2, ht + 48)
          ..quadraticBezierTo(100, ht + 24, hl - 2, ht + 48)
          ..close();
        canvas.drawPath(cap, hairPaint);
        canvas.drawPath(cap, outline);
      case 'spiky':
        final base = Path()
          ..moveTo(hl - 2, ht + 44)
          ..quadraticBezierTo(100, ht + 4, hr + 2, ht + 44)
          ..quadraticBezierTo(100, ht + 26, hl - 2, ht + 44)
          ..close();
        for (var i = 0; i < 6; i++) {
          final x = hl + 12 + i * (hr - hl - 24) / 5;
          canvas.drawPath(
            Path()
              ..moveTo(x - 9, ht + 26)
              ..lineTo(x, ht - 18 - (i.isEven ? 8 : 0))
              ..lineTo(x + 9, ht + 26)
              ..close(),
            hairPaint,
          );
        }
        canvas.drawPath(base, hairPaint);
        canvas.drawPath(base, outline);
    }
  }

  void _outfitDetails(Canvas canvas, String style, Color outfitC,
      double shoulder, Paint skinPaint, Path torso) {
    final white = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    switch (style) {
      case 'tee':
        // Collar.
        canvas.drawPath(
          Path()
            ..moveTo(86, 182)
            ..quadraticBezierTo(100, 194, 114, 182),
          Paint()
            ..color = _darken(outfitC, 0.14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      case 'stripe':
        canvas.save();
        canvas.clipPath(torso);
        final stripe = Paint()..color = Colors.white.withValues(alpha: 0.8);
        for (var y = 196.0; y < 260; y += 18) {
          canvas.drawRect(Rect.fromLTWH(100 - shoulder, y, shoulder * 2, 7), stripe);
        }
        canvas.restore();
      case 'hoodie':
        canvas.drawPath(
          Path()
            ..moveTo(80, 184)
            ..quadraticBezierTo(100, 206, 120, 184),
          Paint()
            ..color = _darken(outfitC, 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(const Offset(93, 200), const Offset(93, 226), white);
        canvas.drawLine(const Offset(107, 200), const Offset(107, 226), white);
      case 'jacket':
        canvas.drawLine(const Offset(100, 184), const Offset(100, 260),
            Paint()..color = _darken(outfitC, 0.2)..strokeWidth = 3);
        canvas.drawPath(
          Path()..moveTo(85, 182)..lineTo(100, 204)..lineTo(115, 182),
          Paint()
            ..color = _darken(outfitC, 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      case 'shirt':
        canvas.drawLine(const Offset(100, 188), const Offset(100, 260),
            Paint()..color = Colors.black.withValues(alpha: 0.18)..strokeWidth = 2);
        for (var y = 200.0; y < 256; y += 16) {
          canvas.drawCircle(Offset(100, y), 2,
              Paint()..color = Colors.black.withValues(alpha: 0.3));
        }
        // Collar wings.
        final collar = Paint()..color = _darken(outfitC, 0.08);
        canvas.drawPath(
            Path()..moveTo(88, 180)..lineTo(99, 182)..lineTo(90, 194)..close(), collar);
        canvas.drawPath(
            Path()..moveTo(112, 180)..lineTo(101, 182)..lineTo(110, 194)..close(), collar);
      case 'suit':
        final lapel = Paint()..color = Colors.white;
        canvas.drawPath(
            Path()..moveTo(86, 180)..lineTo(100, 208)..lineTo(114, 180)..close(), lapel);
        canvas.drawPath(
            Path()..moveTo(95, 208)..lineTo(100, 222)..lineTo(105, 208)..close(),
            Paint()..color = const Color(0xFFE0483C));
      case 'tank':
        canvas.drawRect(Rect.fromLTWH(100 - shoulder, 180, 14, 14), skinPaint);
        canvas.drawRect(Rect.fromLTWH(100 + shoulder - 14, 180, 14, 14), skinPaint);
    }
  }

  // The editor mutates one shared AvatarConfig instance, so comparing old
  // and new configs always says "unchanged". The paint is cheap — just
  // repaint whenever the widget rebuilds.
  @override
  bool shouldRepaint(_AvatarPainter old) => true;
}
