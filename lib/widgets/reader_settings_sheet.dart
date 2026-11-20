import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Opens the "Aa" panel: paper style, typeface, text size and line spacing.
/// Every change applies live to the page behind the sheet and is saved.
Future<void> showReaderSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _ReaderSettingsSheet(),
  );
}

class _ReaderSettingsSheet extends StatelessWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final palette = ReaderPalette.of(context);
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paper', style: labelStyle),
            const SizedBox(height: 8),
            SegmentedButton<ReaderTheme>(
              segments: [
                for (final t in ReaderTheme.values)
                  ButtonSegment(
                    value: t,
                    label: Text(t.label),
                    icon: _Swatch(color: ReaderPalette.forTheme(t).paper),
                  ),
              ],
              selected: {state.readerTheme},
              showSelectedIcon: false,
              onSelectionChanged: (s) => state.setReaderTheme(s.first),
            ),
            const SizedBox(height: 20),

            Text('Typeface', style: labelStyle),
            const SizedBox(height: 8),
            SegmentedButton<ReaderFont>(
              segments: [
                for (final f in ReaderFont.values)
                  ButtonSegment(
                    value: f,
                    label: Text(
                      f.label,
                      style: TextStyle(fontFamily: f.family),
                    ),
                  ),
              ],
              selected: {state.font},
              showSelectedIcon: false,
              onSelectionChanged: (s) => state.setFont(s.first),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Text('Text size', style: labelStyle),
                const Spacer(),
                Text('${state.fontSize.round()} pt', style: labelStyle),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.text_decrease, size: 18),
                Expanded(
                  child: Slider(
                    value: state.fontSize,
                    min: AppState.minFontSize,
                    max: AppState.maxFontSize,
                    divisions:
                        ((AppState.maxFontSize - AppState.minFontSize) / 2)
                            .round(),
                    label: '${state.fontSize.round()}',
                    onChanged: state.setFontSize,
                  ),
                ),
                const Icon(Icons.text_increase, size: 22),
              ],
            ),

            Row(
              children: [
                Text('Line spacing', style: labelStyle),
                const Spacer(),
                Text(state.lineHeight.toStringAsFixed(1), style: labelStyle),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.density_small, size: 18),
                Expanded(
                  child: Slider(
                    value: state.lineHeight,
                    min: AppState.minLineHeight,
                    max: AppState.maxLineHeight,
                    divisions:
                        ((AppState.maxLineHeight - AppState.minLineHeight) * 10)
                            .round(),
                    label: state.lineHeight.toStringAsFixed(1),
                    onChanged: (v) =>
                        state.setLineHeight((v * 10).roundToDouble() / 10),
                  ),
                ),
                const Icon(Icons.density_large, size: 18),
              ],
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: state.resetTypography,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset text'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}
