import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Where each vertical line of a page ends up while the page curls away.
///
/// Works in "u" coordinates: distance from the edge that stays put (the
/// left edge for a forward turn). The free edge of the page wraps around an
/// upright cylinder of [radius] whose base sits at [fold]:
///
/// * `u <= fold`: still lying flat, unchanged.
/// * `fold < u <= fold + πr`: wrapped around the cylinder. Its front faces
///   the reader for the first quarter turn, its back after that.
/// * beyond that: folded right over, lying flat on top, back side up.
///
/// [fold] moves from the free edge (progress 0) to `-radius` (progress 1),
/// where the whole page, cylinder included, has left the page area.
@immutable
class CurlGeometry {
  factory CurlGeometry({required double width, required double progress}) {
    final radius = (width * 0.12).clamp(16.0, 56.0);
    final p = progress.clamp(0.0, 1.0);
    return CurlGeometry._(width, radius, width - p * (width + radius));
  }

  const CurlGeometry._(this.width, this.radius, this.fold);

  final double width;
  final double radius;
  final double fold;

  /// Length of page wrapped around the cylinder (half its circumference).
  double get arcLength => math.pi * radius;

  /// Where the page point at [u] lands, how high it is lifted, and whether
  /// the reader sees its back.
  ({double x, double z, bool back}) map(double u) {
    if (u <= fold) return (x: u, z: 0, back: false);
    final s = u - fold;
    if (s <= arcLength) {
      final theta = s / radius;
      return (
        x: fold + radius * math.sin(theta),
        z: radius * (1 - math.cos(theta)),
        back: theta > math.pi / 2,
      );
    }
    return (x: fold - (s - arcLength), z: 2 * radius, back: true);
  }

  /// The furthest the curled page reaches towards the free edge; the page
  /// underneath is uncovered beyond this.
  double get extent {
    final wrapped = width - fold;
    if (wrapped <= 0) return width;
    if (wrapped >= arcLength / 2) return fold + radius;
    return fold + radius * math.sin(wrapped / radius);
  }
}

/// Paints a page snapshot curling away from the reader, with shading on the
/// curve, a translucent paper back, and shadows along the fold and on the
/// page underneath.
class PageCurlPainter extends CustomPainter {
  PageCurlPainter({
    required this.image,
    required this.progress,
    required this.forward,
    required this.paperColor,
    this.backOpacity = 0.88,
    this.inset = 4,
    this.cornerRadius = 12,
  });

  /// The flat page, captured at the same logical size as the canvas.
  final ui.Image image;

  /// 0 = flat, 1 = gone.
  final double progress;

  /// Forward turns peel from the right edge; backward from the left.
  final bool forward;

  /// Colour of the back of the paper.
  final Color paperColor;

  /// How opaque the back of the paper is; the rest is the page's own text
  /// showing through, mirrored.
  final double backOpacity;

  /// Transparent margin around the page inside the snapshot (Card margin).
  final double inset;
  final double cornerRadius;

  static const Color _shadow = Color(0xFF000000);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final g = CurlGeometry(width: w, progress: progress);
    final c = g.fold;
    final r = g.radius;
    final scale = image.width / w;

    // u (distance from the fixed edge) -> canvas x.
    double toX(double u) => forward ? u : w - u;
    Rect span(double u0, double u1) {
      final a = toX(u0);
      final b = toX(u1);
      return Rect.fromLTRB(math.min(a, b), 0, math.max(a, b), h);
    }

    final imagePaint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = false;

    // Copies the page between u0..u1 onto u-positions x0..x1, mirroring the
    // strip when the page has folded back over itself.
    void strip(double u0, double u1, double x0, double x1) {
      final s0 = toX(u0), s1 = toX(u1), d0 = toX(x0), d1 = toX(x1);
      final src = Rect.fromLTRB(
        math.min(s0, s1) * scale,
        0,
        math.max(s0, s1) * scale,
        image.height.toDouble(),
      );
      // A hair of overlap hides seams between neighbouring strips.
      final dst = Rect.fromLTRB(
        math.min(d0, d1) - 0.35,
        0,
        math.max(d0, d1) + 0.35,
        h,
      );
      if ((s1 - s0) * (d1 - d0) >= 0) {
        canvas.drawImageRect(image, src, dst, imagePaint);
      } else {
        canvas
          ..save()
          ..translate(dst.left + dst.right, 0)
          ..scale(-1, 1)
          ..drawImageRect(image, src, dst, imagePaint)
          ..restore();
      }
    }

    // Shadow that fades from u0 (strongest) to u1.
    void shade(double u0, double u1, double opacity) {
      if ((u1 - u0).abs() < 0.5) return;
      final rect = span(u0, u1);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(toX(u0), 0),
            Offset(toX(u1), 0),
            [_shadow.withValues(alpha: opacity), _shadow.withValues(alpha: 0)],
          ),
      );
    }

    final backPaint = Paint()
      ..color = paperColor.withValues(alpha: backOpacity);

    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(inset),
          Radius.circular(cornerRadius),
        ),
      );

    // 1. The part still lying flat.
    if (c > 0) strip(0, math.min(c, w), 0, math.min(c, w));

    // 2. Shadow the lifted page casts onto the page underneath.
    final extent = g.extent;
    if (extent < w) shade(extent, math.min(w, extent + r * 1.2), 0.28);

    // 3. Shadow the folded-over flap casts on the flat part, at its edge.
    final flapStart = c + g.arcLength;
    final flapEdge = g.map(w).x;
    if (w > flapStart && flapEdge > 0) {
      shade(flapEdge, math.max(0, flapEdge - 14), 0.2);
    }

    // 4. The part wrapped around the cylinder, back to front by height.
    final sStart = math.max(0.0, -c);
    final sEnd = math.min(g.arcLength, w - c);
    if (sEnd > sStart) {
      final n = ((sEnd - sStart) / 2).ceil().clamp(4, 120);
      for (var i = 0; i < n; i++) {
        final s0 = sStart + (sEnd - sStart) * i / n;
        final s1 = sStart + (sEnd - sStart) * (i + 1) / n;
        final x0 = c + r * math.sin(s0 / r);
        final x1 = c + r * math.sin(s1 / r);
        strip(c + s0, c + s1, x0, x1);

        final theta = (s0 + s1) / (2 * r);
        final dst = span(x0, x1).inflate(0.35);
        final back = theta > math.pi / 2;
        if (back) canvas.drawRect(dst, backPaint);
        // Darkest where the surface turns edge-on to the reader.
        final darkness = back
            ? 0.42 * (1 + math.cos(theta))
            : 0.42 * (1 - math.cos(theta));
        canvas.drawRect(
          dst,
          Paint()..color = _shadow.withValues(alpha: darkness),
        );
      }
    }

    // 5. The part folded right over, lying on top, back side up.
    if (w > flapStart) {
      final u0 = math.max(0.0, flapStart);
      final x0 = g.map(u0).x;
      strip(u0, w, x0, flapEdge);
      canvas.drawRect(span(x0, flapEdge), backPaint);
      // Shadow along the fold, where the flap meets the curve.
      shade(x0, math.max(flapEdge, x0 - r), 0.18);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(PageCurlPainter old) =>
      old.image != image ||
      old.progress != progress ||
      old.forward != forward ||
      old.paperColor != paperColor ||
      old.backOpacity != backOpacity;
}
