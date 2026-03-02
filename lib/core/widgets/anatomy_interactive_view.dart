import 'package:flutter/material.dart';
import 'package:herbascan/core/models/plant_anatomy_part.dart';
import 'package:herbascan/core/utils/anatomy_scale_util.dart';

/// Paints anatomy parts in draw order (z_index). Selected part uses different opacity.
class SilhouettePainter extends CustomPainter {
  SilhouettePainter({
    required this.parts,
    this.selectedPartId,
  }) : partsOrdered = List<PlantAnatomyPart>.from(parts)
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  final List<PlantAnatomyPart> parts;
  final String? selectedPartId;

  final List<PlantAnatomyPart> partsOrdered;

  @override
  void paint(Canvas canvas, Size size) {
    for (final part in partsOrdered) {
      final isSelected = part.id == selectedPartId;
      final paint = Paint()
        ..color = part.color.withOpacity(isSelected ? 0.85 : 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawPath(part.path, paint);
      // Optional: stroke for selected
      if (isSelected) {
        final stroke = Paint()
          ..color = part.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawPath(part.path, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(SilhouettePainter oldDelegate) {
    return oldDelegate.parts != parts || oldDelegate.selectedPartId != selectedPartId;
  }
}

/// Interactive silhouette: path-based hit-testing, selection, and tap callback.
class InteractiveSilhouette extends StatefulWidget {
  const InteractiveSilhouette({
    super.key,
    required this.parts,
    required this.size,
    required this.onPartTapped,
  });

  final List<PlantAnatomyPart> parts;
  final Size size;
  final ValueChanged<PlantAnatomyPart> onPartTapped;

  @override
  State<InteractiveSilhouette> createState() => _InteractiveSilhouetteState();
}

class _InteractiveSilhouetteState extends State<InteractiveSilhouette> {
  String? _selectedPartId;

  /// Hit-test in reverse draw order so topmost part wins.
  PlantAnatomyPart? _hitTest(Offset localPosition) {
    final ordered = List<PlantAnatomyPart>.from(widget.parts)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    for (final part in ordered.reversed) {
      if (!part.isInteractive) continue;
      if (part.path.contains(localPosition)) return part;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final part = _hitTest(details.localPosition);
          if (part != null) {
            setState(() => _selectedPartId = part.id);
            widget.onPartTapped(part);
          } else {
            setState(() => _selectedPartId = null);
          }
        },
        child: CustomPaint(
          size: widget.size,
          painter: SilhouettePainter(
            parts: widget.parts,
            selectedPartId: _selectedPartId,
          ),
        ),
      ),
    );
  }
}

/// Wraps anatomy in a LayoutBuilder, scales parts to fit, and shows the interactive silhouette.
class AnatomyInteractiveView extends StatelessWidget {
  const AnatomyInteractiveView({
    super.key,
    required this.parts,
    required this.onPartTapped,
    this.height = 400,
  });

  final List<PlantAnatomyPart> parts;
  final ValueChanged<PlantAnatomyPart> onPartTapped;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final targetSize = Size(width, height);
        final scaled = scaleAnatomyToFit(parts, targetSize);
        return SizedBox(
          width: width,
          height: height,
          child: InteractiveSilhouette(
            parts: scaled,
            size: targetSize,
            onPartTapped: onPartTapped,
          ),
        );
      },
    );
  }
}
