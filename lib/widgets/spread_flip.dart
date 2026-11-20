import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'page_flip.dart';

/// Space around the open book, and between each page's edge and its text.
const double _kOuterPadding = 16;
const double _kTextPadding = 24;

/// Whether a reading area is wide enough to show two pages side by side:
/// landscape tablets and desktop windows, but not phones turned sideways,
/// where each page would only fit a handful of lines.
bool useTwoPageSpread(Size pageArea) =>
    pageArea.width >= 960 && pageArea.width >= pageArea.height * 1.25;

/// The box the text of each page of a spread is set in.
Size spreadPageTextSize(Size pageArea) => Size(
  math.max(0, (pageArea.width - 2 * _kOuterPadding) / 2 - 2 * _kTextPadding),
  math.max(0, pageArea.height - 2 * _kOuterPadding - 2 * _kTextPadding),
);

/// An open book showing two pages. Turning moves a whole leaf over the
/// spine: going forward, the right page lifts, turns over, and its back
/// (the next left page) lands on the left; going back is the mirror image.
///
/// A null page is drawn as blank paper (a chapter that ends on a left page).
class SpreadFlipWidget extends StatelessWidget {
  const SpreadFlipWidget({
    super.key,
    required this.left,
    required this.right,
    required this.nextLeft,
    required this.nextRight,
    required this.previousLeft,
    required this.previousRight,
    required this.flipProgress,
    required this.dragOffset,
    required this.isDragging,
    required this.isFlippingForward,
    this.isLeftBookmarked = false,
    this.isRightBookmarked = false,
  });

  final InlineSpan? left;
  final InlineSpan? right;
  final InlineSpan? nextLeft;
  final InlineSpan? nextRight;
  final InlineSpan? previousLeft;
  final InlineSpan? previousRight;

  /// 0 = leaf flat where it started, 1 = turned over to the other side.
  final Animation<double> flipProgress;
  final double dragOffset;
  final bool isDragging;
  final bool isFlippingForward;
  final bool isLeftBookmarked;
  final bool isRightBookmarked;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final forward = isFlippingForward;

    // The lifted leaf leans out towards the reader; keep it inside the
    // reading area rather than over the toolbar and page tray.
    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.all(_kOuterPadding),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: flipProgress,
            builder: (context, _) {
              var progress = flipProgress.value;
              if (isDragging) {
                progress += dragOffsetToFlipProgress(dragOffset);
              }
              progress = progress.clamp(0.0, 1.0);
              final angle = progress * math.pi;
              final turning = progress > 0;

              // What lies flat on each side while the leaf is in the air.
              final staticLeft = forward || !turning ? left : previousLeft;
              final staticRight = !forward || !turning ? right : nextRight;

              return Row(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Page(
                          text: staticLeft,
                          side: _Side.left,
                          palette: palette,
                          bookmarked: !turning || forward
                              ? isLeftBookmarked
                              : false,
                        ),
                        // Shadow cast by the leaf as it nears this side.
                        if (turning) _castShadow(forward, angle, _Side.left),
                        if (turning) ..._leafOn(_Side.left, angle, palette),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Page(
                          text: staticRight,
                          side: _Side.right,
                          palette: palette,
                          bookmarked: !turning || !forward
                              ? isRightBookmarked
                              : false,
                        ),
                        if (turning) _castShadow(forward, angle, _Side.right),
                        if (turning) ..._leafOn(_Side.right, angle, palette),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The turning leaf, drawn on whichever side it is over. Before it stands
  /// upright (angle < π/2) it is still over the side it started from,
  /// showing its front; after, it is over the other side, showing its back.
  List<Widget> _leafOn(_Side side, double angle, ReaderPalette palette) {
    final forward = isFlippingForward;
    final startSide = forward ? _Side.right : _Side.left;
    final firstHalf = angle <= math.pi / 2;
    final overThisSide = firstHalf ? side == startSide : side != startSide;
    if (!overThisSide) return const [];

    // Front of the leaf, or its back (the page that lands on the far side).
    final InlineSpan? text;
    if (firstHalf) {
      text = forward ? right : left;
    } else {
      text = forward ? nextLeft : previousRight;
    }
    // How far the leaf is tilted out of the page, 0 (flat) to π/2 (upright).
    final tilt = firstHalf ? angle : math.pi - angle;
    // Rotate about the spine: the left edge of a right page, the right edge
    // of a left page. The sign makes the free edge lift towards the reader.
    final onRight = side == _Side.right;

    return [
      Transform(
        alignment: onRight ? Alignment.centerLeft : Alignment.centerRight,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.00025)
          ..rotateY(onRight ? tilt : -tilt),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Page(
              text: text,
              side: side,
              palette: palette,
              elevated: true,
              bookmarked: firstHalf
                  ? (forward ? isRightBookmarked : isLeftBookmarked)
                  : false,
            ),
            // Darker the more edge-on the leaf is, and darkest at the spine.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: onRight
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    end: onRight ? Alignment.centerRight : Alignment.centerLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.35 * tilt / math.pi * 2),
                      Colors.black.withValues(alpha: 0.12 * tilt / math.pi * 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// The shadow the leaf throws onto the flat page beneath it: strongest by
  /// the spine, reaching further out the lower the leaf hangs over a side.
  Widget _castShadow(bool forward, double angle, _Side side) {
    final startSide = forward ? _Side.right : _Side.left;
    final firstHalf = angle <= math.pi / 2;
    final overThisSide = firstHalf ? side == startSide : side != startSide;
    final tilt = firstHalf ? angle : math.pi - angle;
    // Over this side: the shadow is under the leaf, so it shows mainly
    // beyond the leaf's tip; the uncovered side gets a soft spine shadow.
    final strength = overThisSide ? 0.28 * (1 - tilt / math.pi) : 0.18;
    final reach = overThisSide ? 1.0 - math.cos(tilt) * 0.6 : 0.25;
    final onRight = side == _Side.right;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: onRight ? Alignment.centerLeft : Alignment.centerRight,
            end: onRight ? Alignment.centerRight : Alignment.centerLeft,
            stops: [0, reach.clamp(0.05, 1.0)],
            colors: [
              Colors.black.withValues(alpha: strength),
              Colors.black.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Side { left, right }

/// One page of the open book: paper, text, the gutter shading by the spine,
/// and a bookmark ribbon. Corners are rounded only on the outer edge.
class _Page extends StatelessWidget {
  const _Page({
    required this.text,
    required this.side,
    required this.palette,
    this.elevated = false,
    this.bookmarked = false,
  });

  final InlineSpan? text;
  final _Side side;
  final ReaderPalette palette;
  final bool elevated;
  final bool bookmarked;

  @override
  Widget build(BuildContext context) {
    final onLeft = side == _Side.left;
    const outer = Radius.circular(12);
    final radius = onLeft
        ? const BorderRadius.horizontal(left: outer)
        : const BorderRadius.horizontal(right: outer);
    final text = this.text;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: radius,
        boxShadow: elevated
            ? const [BoxShadow(color: Color(0x22000000), blurRadius: 6)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PaperTexture(opacity: palette.textureOpacity),
            // Gutter: paper curves down into the spine.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: onLeft ? Alignment.centerRight : Alignment.centerLeft,
                  end: onLeft ? Alignment.centerLeft : Alignment.centerRight,
                  stops: const [0, 0.08],
                  colors: const [Color(0x2E000000), Color(0x00000000)],
                ),
              ),
            ),
            if (bookmarked)
              Positioned(
                right: onLeft ? null : 16,
                left: onLeft ? 16 : null,
                top: 0,
                child: Container(
                  width: 14,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            if (text != null)
              Padding(
                padding: const EdgeInsets.all(_kTextPadding),
                child: PageText(text: text),
              ),
          ],
        ),
      ),
    );
  }
}
