import 'package:flutter/material.dart';

import '../reading/pagination.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Opens the list of saved bookmarks for a book, numbered by its current
/// [pages].
///
/// Resolves to the page index the reader picked, or null if the sheet was
/// dismissed. Bookmarks can also be removed from the list; the sheet updates
/// live because it listens to [AppState].
Future<int?> showBookmarksSheet(
  BuildContext context, {
  required String bookId,
  required String text,
  required List<PageRange> pages,
  required int currentPage,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _BookmarksSheet(
      bookId: bookId,
      text: text,
      pages: pages,
      currentPage: currentPage,
    ),
  );
}

class _BookmarksSheet extends StatelessWidget {
  const _BookmarksSheet({
    required this.bookId,
    required this.text,
    required this.pages,
    required this.currentPage,
  });

  final String bookId;
  final String text;
  final List<PageRange> pages;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final palette = ReaderPalette.of(context);
    final theme = Theme.of(context);

    // Bookmarks are character offsets; list the pages they fall on now.
    // Ignore any past the end of the text (e.g. the book got shorter).
    final marked = {
      for (final offset in state.bookmarksFor(bookId))
        if (offset >= 0 && offset < text.length) pageIndexFor(pages, offset),
    }.toList()..sort();

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
                  if (marked.isNotEmpty)
                    Text('${marked.length}', style: labelStyle),
                ],
              ),
            ),
            if (marked.isEmpty)
              _EmptyState(palette: palette)
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: marked.length,
                  itemBuilder: (context, i) {
                    final page = marked[i];
                    final range = pages[page];
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
                        _snippet(text, range),
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
                        onPressed: () => state.removeBookmarksIn(
                          bookId,
                          range.start,
                          range.end,
                        ),
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

  /// The opening words of a page, collapsed to a single line.
  static String _snippet(String text, PageRange page) {
    final end = (page.start + 200).clamp(page.start, page.end);
    return text
        .substring(page.start, end)
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
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
