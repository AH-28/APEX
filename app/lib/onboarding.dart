import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

/// One step of the guided tour.
///
/// A step either spotlights a target widget (found via its [targetKey]) or,
/// when no target is given (or it isn't on screen), shows a centred card with
/// no highlight — handy for the welcome / finish steps.
class TourStep {
  const TourStep({
    this.targetKey,
    this.subRect,
    this.tab,
    this.revealScreen = false,
    required this.title,
    required this.body,
    this.icon,
  });

  /// The widget to highlight. Null for a centred, un-highlighted step.
  final GlobalKey? targetKey;

  /// Optional transform from the target's global rect to the exact rect to
  /// spotlight — used to carve a single button out of the bottom nav bar.
  final Rect Function(Rect bounds)? subRect;

  /// The bottom-nav tab this step should be viewed on, if any. The host
  /// switches to it when the step is shown so the real screen is visible.
  final int? tab;

  /// For centred steps (no target): dim the screen only lightly, so the user
  /// can study the actual screen behind the explanation card.
  final bool revealScreen;

  final String title;
  final String body;
  final IconData? icon;
}

/// A full-screen guided tour: dims the app, cuts a spotlight hole around the
/// current target, and shows an explanatory card with a step counter plus
/// Back / Skip / Next controls.
///
/// [onFinish] is called once, whether the user reaches the end or taps Skip.
class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    this.onStep,
  });

  final List<TourStep> steps;
  final VoidCallback onFinish;

  /// Called whenever the visible step changes (and once on start), so the host
  /// can switch to that step's [TourStep.tab].
  final void Function(TourStep step)? onStep;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  int _i = 0;
  Rect? _hole;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _applyStep();
  }

  /// Tell the host which tab to show, then measure the target — twice, so the
  /// spotlight settles after any tab/content switch animation.
  void _applyStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onStep?.call(widget.steps[_i]);
      _locate();
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _locate();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Measure the current step's target after layout so the spotlight lands in
  /// the right place. Falls back to a centred card when the target is absent.
  void _locate() {
    final step = widget.steps[_i];
    Rect? rect;
    final ctx = step.targetKey?.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        rect = box.localToGlobal(Offset.zero) & box.size;
        if (step.subRect != null) rect = step.subRect!(rect);
        // If the target scrolled off-screen, fall back to a centred card
        // rather than spotlighting empty space.
        final screen = Offset.zero & MediaQuery.sizeOf(context);
        if (!rect.overlaps(screen)) rect = null;
      }
    }
    if (mounted) setState(() => _hole = rect);
  }

  void _go(int delta) {
    final next = _i + delta;
    if (next < 0) return;
    if (next >= widget.steps.length) {
      widget.onFinish();
      return;
    }
    setState(() {
      _i = next;
      _hole = null; // clear until re-measured to avoid a stale flash
    });
    _applyStep();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final size = MediaQuery.of(context).size;
    final hole = _hole;
    final scheme = Theme.of(context).colorScheme;
    // Lighten the scrim for centred explainer steps so the screen shows through.
    final scrimAlpha = (hole == null && step.revealScreen) ? 0.5 : 0.72;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dimmed backdrop with the spotlight cut out. The GestureDetector
          // absorbs taps so the app underneath can't be used mid-tour.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _SpotlightPainter(
                    hole: hole,
                    glow: 0.35 + 0.25 * _pulse.value,
                    scrim: Colors.black.withValues(alpha: scrimAlpha),
                    accent: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
          _card(context, step, size, hole),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, TourStep step, Size size, Rect? hole) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _i == widget.steps.length - 1;

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (step.icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: accentGradient(scheme.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(step.icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    step.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 8),
                // Step counter, e.g. 3/11.
                Text(
                  '${_i + 1}/${widget.steps.length}',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              step.body,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5, fontSize: 15),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: widget.onFinish,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  child: const Text('Skip'),
                ),
                const Spacer(),
                if (_i > 0)
                  TextButton(
                    onPressed: () => _go(-1),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 6),
                GradientButton(
                  onPressed: () => _go(1),
                  icon: isLast ? Icons.check : Icons.arrow_forward,
                  label: isLast ? 'Done' : 'Next',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Place the card opposite the hole: below a top target, above a bottom
    // one, and centred when there's no target to point at.
    if (hole == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: card));
    }
    final showBelow = hole.center.dy < size.height * 0.5;
    return Positioned(
      left: 16,
      right: 16,
      top: showBelow ? hole.bottom + 18 : null,
      bottom: showBelow ? null : size.height - hole.top + 18,
      child: Align(alignment: Alignment.topCenter, child: card),
    );
  }
}

/// Paints the dim scrim and clears a rounded spotlight hole, with a soft
/// accent ring around it.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.hole,
    required this.glow,
    required this.scrim,
    required this.accent,
  });

  final Rect? hole;
  final double glow;
  final Color scrim;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    if (hole == null) {
      canvas.drawRect(full, Paint()..color = scrim);
      return;
    }
    final rrect =
        RRect.fromRectAndRadius(hole!.inflate(8), const Radius.circular(18));

    // Scrim with the hole punched out.
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, Paint()..color = scrim);
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Glowing accent ring around the spotlight.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = accent.withValues(alpha: glow.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accent.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.glow != glow;
}
