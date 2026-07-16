/// Widget tests for the Animated Book Reader application.
///
/// Tests cover:
/// - App initialization and library screen display
/// - Book cover visibility and interactivity
/// - Navigation to reader screen
/// - Page navigation controls
/// - Page content verification

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:animated_book/main.dart';

void main() {
  group('Animated Book Reader App Tests', () {
    testWidgets('App initializes and displays library screen', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const AnimatedBookApp());

      // Verify library screen is displayed
      expect(find.text('My Library'), findsOneWidget);
      expect(find.text('Tap to explore stunning stories'), findsOneWidget);
    });

    testWidgets('Book cover is visible on library screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const AnimatedBookApp());

      // Verify book cover elements are present
      expect(find.text('The Art of'), findsOneWidget);
      expect(find.text('Interactive'), findsOneWidget);
      expect(find.text('Storytelling'), findsOneWidget);
      expect(find.text('By Author Name'), findsOneWidget);
    });

    testWidgets('Library displays feature list', (WidgetTester tester) async {
      await tester.pumpWidget(const AnimatedBookApp());

      // Verify features section
      expect(find.text('Features'), findsOneWidget);
      expect(find.text('Smooth page-turn animations'), findsOneWidget);
      expect(find.text('Elegant typography'), findsOneWidget);
      expect(find.text('Immersive reading experience'), findsOneWidget);
    });

    testWidgets('Tapping book cover navigates to reader screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const AnimatedBookApp());

      // Find and tap the book cover (it's the largest Container in the library)
      await tester.tap(find.byType(GestureDetector).first);

      // Wait for transition animation
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));

      // Verify reader screen is displayed
      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('Reader screen displays page navigation controls', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const AnimatedBookApp());

      // Navigate to reader
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));

      // Verify page counter is displayed
      expect(find.text('1/5'), findsOneWidget);

      // Verify navigation buttons are present
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
    });

    testWidgets('Next page button navigates forward', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const AnimatedBookApp());

      // Navigate to reader
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));

      // Verify starting page
      expect(find.text('1/5'), findsOneWidget);

      // Tap next page button (rightmost chevron)
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      // Verify page updated
      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('Previous page button navigates backward', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const AnimatedBookApp());

      // Navigate to reader
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));

      // Go to page 2 first
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));
      expect(find.text('2/5'), findsOneWidget);

      // Go back to page 1
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      // Verify we're back on page 1
      expect(find.text('1/5'), findsOneWidget);
    });

    testWidgets('Back button returns to library screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const AnimatedBookApp());

      // Navigate to reader
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));

      // Verify we're in reader
      expect(find.text('Reading'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      // Verify we're back in library
      expect(find.text('My Library'), findsOneWidget);
    });

    testWidgets('Page content displays with proper typography', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const AnimatedBookApp());

      // Navigate to reader
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));

      // Verify page content is displayed (first page starts with "The ancient library")
      expect(find.textContaining('ancient library'), findsOneWidget);
      expect(find.textContaining('worlds waiting'), findsOneWidget);
    });
  });
}
