// lib/core/widgets/summary_fullscreen_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// Full-screen reading mode for Summary tab
class SummaryFullScreenView extends StatelessWidget {
  final String explanationText;
  final VoidCallback onRegenerate;

  const SummaryFullScreenView({
    super.key,
    required this.explanationText,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          color: theme.colorScheme.onSurface,
        ),
        title: Text(
          'Identification Summary',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              onRegenerate();
              Navigator.of(context).pop();
            },
            color: theme.colorScheme.onSurface,
            tooltip: 'Regenerate Summary',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: MarkdownBody(
          data: explanationText,
          styleSheet: MarkdownStyleSheet(
            // Headings with proper hierarchy and spacing for fullscreen readability
            h1: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
              fontSize: 26,
              height: 1.3,
            ),
            h1Padding: const EdgeInsets.only(bottom: 8, top: 16),
            h2: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
              fontSize: 24,
              height: 1.3,
            ),
            h2Padding: const EdgeInsets.only(bottom: 6, top: 12),
            h3: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              fontSize: 22,
              height: 1.3,
            ),
            h3Padding: const EdgeInsets.only(bottom: 6, top: 10),
            // Body text with optimal line height and spacing for fullscreen reading
            p: theme.textTheme.bodyMedium?.copyWith(
              height:
                  1.8, // Increased line height for better readability in fullscreen
              color: theme.colorScheme.onSurface.withOpacity(0.87),
              fontSize: 17.0, // Slightly larger for fullscreen reading
            ),
            pPadding: const EdgeInsets.only(bottom: 10, top: 4),
            // Bold text (for section headers like **Plant Identification Summary**)
            strong: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              fontSize: 19,
              height: 1.5,
            ),
            // Italic text
            em: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontSize: 17,
            ),
            // Lists with proper indentation
            listBullet: theme.textTheme.bodyMedium?.copyWith(
              color: theme.primaryColor,
              fontSize: 19,
            ),
            listIndent:
                32.0, // Increased indentation for better visual hierarchy
            listBulletPadding: const EdgeInsets.only(right: 10),
            // Block quotes
            blockquote: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontStyle: FontStyle.italic,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              fontSize: 17,
            ),
            blockquotePadding: const EdgeInsets.all(16),
            blockquoteDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border(
                left: BorderSide(
                  color: theme.primaryColor,
                  width: 4,
                ),
              ),
            ),
            // Code blocks
            code: theme.textTheme.bodySmall?.copyWith(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              fontFamily: 'monospace',
              fontSize: 15,
              color: theme.colorScheme.onSurface,
            ),
            codeblockPadding: const EdgeInsets.all(16),
            codeblockDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            // Horizontal rule
            horizontalRuleDecoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            // Links
            a: theme.textTheme.bodyMedium?.copyWith(
              color: theme.primaryColor,
              decoration: TextDecoration.underline,
              fontSize: 17,
            ),
            // Table styling
            tableHead: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              fontSize: 17,
            ),
            tableBody: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.87),
              fontSize: 17,
            ),
            tableBorder: TableBorder.all(
              color: theme.dividerColor,
              width: 1,
            ),
            tableHeadAlign: TextAlign.center,
            tableCellsPadding: const EdgeInsets.all(12),
            // Spacing between blocks
            blockSpacing: 16.0, // Increased spacing for better readability
            textScaleFactor: 1.0,
          ),
        ),
      ),
    );
  }
}
