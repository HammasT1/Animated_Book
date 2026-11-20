import 'package:flutter/material.dart';

import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Opens the list of saved bookmarks for [book].
///
/// Resolves to the page index the reader picked, or null if the sheet was
/// dismissed. Bookmarks can also be removed from the list; the sheet updates
/// live because it listens to [AppState].
Future<int?> showBookmarksSheet(
  BuildContext context, {
  required Book book,
  required int currentPage,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _BookmarksSheet(book: book, currentPage: currentPage),
  );
}

class _BookmarksSheet extends StatelessWidget {
  const _BookmarksSheet({required this.book, required this.currentPage});

  final Book book;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final palette = ReaderPalette.of(context);
    final theme = Theme.of(context);

    // Ignore bookmarks that point past the end (e.g. a book got shorter).
    final pages =
        state
            .bookmarksFor(book.id)
            .where((p) => p >= 0 && p < book.pages.length)
            .toList()
          ..sort();

    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text('Bookmarks', style: labelStyle),
                  const Spacer(),
                  if (pages.isNotEmpty)
                    Text('${pages.length}', style: labelStyle),
                ],
              ),
            ),
            if (pages.isEmpty)
              _EmptyState(palette: palette)
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: pages.length,
                  itemBuilder: (context, i) {
                    final page = pages[i];
                    final isCurrent = page == currentPage;
                    return ListTile(
                      key: ValueKey('bookmark-$page'),
                      contentPadding: const EdgeInsets.only(left: 20, right: 8),
                      leading: Icon(
                        Icons.bookmark,
                        color: isCurrent ? Colors.amber[700] : palette.icon,
                      ),
                      title: Text(
                        isCurrent
                            ? 'Page ${page + 1} · You are here'
                            : 'Page ${page + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _snippet(book.pages[page]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: state.font.family,
                          color: palette.ink.withValues(alpha: 0.7),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove bookmark',
                        icon: Icon(Icons.close, color: palette.muted),
                        onPressed: () => state.toggleBookmark(book.id, page),
                      ),
                      onTap: () => Navigator.pop(context, page),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// First non-empty paragraph of a page, collapsed to a single line.
  static String _snippet(String page) {
    final paragraph = page
        .split('\n\n')
        .map((p) => p.trim())
        .firstWhere((p) => p.isNotEmpty, orElse: () => '');
    return paragraph.replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette});

  final ReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: palette.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          Icon(Icons.bookmark_border, size: 40, color: palette.muted),
          const SizedBox(height: 12),
          Text(
            'No bookmarks yet',
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the bookmark icon or press B to save a page.',
            textAlign: TextAlign.center,
            style: style,
          ),
        ],
      ),
    );
  }
}
