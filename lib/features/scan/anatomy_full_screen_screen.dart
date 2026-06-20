import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_anatomy_part.dart';
import 'package:herbascan/core/widgets/anatomy_interactive_view.dart';

class AnatomyFullScreenScreen extends StatefulWidget {
  final Plant plant;
  final List<PlantAnatomyPart> parts;
  final bool isCarousel;

  const AnatomyFullScreenScreen({
    super.key,
    required this.plant,
    required this.parts,
    this.isCarousel = false,
  });

  @override
  State<AnatomyFullScreenScreen> createState() => _AnatomyFullScreenScreenState();
}

class _AnatomyFullScreenScreenState extends State<AnatomyFullScreenScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showAnatomyPartBottomSheet(
    BuildContext context,
    PlantAnatomyPart part,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Text(
                          part.title.isNotEmpty ? part.title : part.partName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (part.conditions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: part.conditions
                                .map(
                                  (c) => Chip(
                                    label: Text(c),
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (part.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            part.description,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInteractiveView(ThemeData theme, List<PlantAnatomyPart> partsToRender) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: AnatomyInteractiveView(
          parts: partsToRender,
          height: MediaQuery.of(context).size.height * 0.8,
          onPartTapped: (part) => _showAnatomyPartBottomSheet(context, part, theme),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: widget.isCarousel
                  ? PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) => setState(() => _currentPage = index),
                      itemCount: widget.parts.length,
                      itemBuilder: (context, index) {
                        return _buildInteractiveView(theme, [widget.parts[index]]);
                      },
                    )
                  : _buildInteractiveView(theme, widget.parts),
            ),
            if (widget.isCarousel) ...[
              const SizedBox(height: 16),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        tooltip: l10n.previousPart,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          widget.parts[_currentPage.clamp(0, widget.parts.length - 1)].title.isNotEmpty
                              ? widget.parts[_currentPage.clamp(0, widget.parts.length - 1)].title
                              : widget.parts[_currentPage.clamp(0, widget.parts.length - 1)].partName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage < widget.parts.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        tooltip: l10n.nextPart,
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
