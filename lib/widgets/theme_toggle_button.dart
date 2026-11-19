import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Sun/moon button that flips between light and dark paper.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return IconButton(
      tooltip: state.isDark ? 'Light mode' : 'Dark mode',
      onPressed: state.toggleDark,
      icon: Icon(
        state.isDark ? Icons.light_mode : Icons.dark_mode,
        color: state.isDark ? Colors.amber : ReaderPalette.of(context).icon,
      ),
    );
  }
}
