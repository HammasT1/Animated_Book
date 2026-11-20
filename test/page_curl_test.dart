import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:animated_book/widgets/page_curl.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 360.0;
  Iterable<double> points() sync* {
    for (var u = 0.0; u <= width; u += 3) {
      yield u;
    }
  }

  group('CurlGeometry', () {
    test('a flat page leaves every point where it is', () {
      final g = CurlGeometry(width: width, progress: 0);
      for (final u in points()) {
        final p = g.map(u);
        expect(p.x, closeTo(u, 1e-9));
        expect(p.z, 0);
        expect(p.back, isFalse);
      }
      expect(g.extent, width);
    });

    test('a fully turned page has left the page area', () {
      final g = CurlGeometry(width: width, progress: 1);
      for (final u in points()) {
        expect(g.map(u).x, lessThanOrEqualTo(1e-9), reason: 'u=$u');
      }
      expect(g.extent, lessThanOrEqualTo(1e-9));
    });

    test('the page bends without tearing', () {
      for (final progress in [0.1, 0.35, 0.6, 0.85]) {
        final g = CurlGeometry(width: width, progress: progress);
        var previous = g.map(0);
        for (final u in points().skip(1)) {
          final p = g.map(u);
          // Neighbouring points of the paper stay neighbours.
          final gap = math.sqrt(
            math.pow(p.x - previous.x, 2) + math.pow(p.z - previous.z, 2),
          );
          expect(gap, lessThanOrEqualTo(3 + 1e-6), reason: 'u=$u @ $progress');
          // Nothing ever lands past the curl's furthest reach.
          expect(p.x, lessThanOrEqualTo(g.extent + 1e-9));
          previous = p;
        }
      }
    });

    test('the back shows only once the page has curled past upright', () {
      final g = CurlGeometry(width: width, progress: 0.5);
      expect(g.map(g.fold - 1).back, isFalse);
      expect(g.map(g.fold + g.radius * 0.5 * math.pi - 1).back, isFalse);
      expect(g.map(g.fold + g.radius * 0.5 * math.pi + 1).back, isTrue);
      expect(g.map(g.fold + g.arcLength + 1).back, isTrue);
    });

    test('the fold moves steadily across the page', () {
      var lastFold = double.infinity;
      for (var p = 0.0; p <= 1.0; p += 0.05) {
        final fold = CurlGeometry(width: width, progress: p).fold;
        expect(fold, lessThan(lastFold));
        lastFold = fold;
      }
    });
  });

  test('PageCurlPainter paints every stage in both directions', () {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 90, 120),
      Paint()..color = const Color(0xFFFAF8F3),
    );
    final image = recorder.endRecording().toImageSync(180, 240);
    addTearDown(image.dispose);

    for (final forward in [true, false]) {
      for (var p = 0.0; p <= 1.0; p += 0.1) {
        final canvasRecorder = ui.PictureRecorder();
        PageCurlPainter(
          image: image,
          progress: p,
          forward: forward,
          paperColor: const Color(0xFFFAF8F3),
        ).paint(Canvas(canvasRecorder), const Size(90, 120));
        canvasRecorder.endRecording().dispose();
      }
    }
  });
}
