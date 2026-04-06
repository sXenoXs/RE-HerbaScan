import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:herbascan/core/models/plant.dart';

/// Displays a plant image: Supabase URL (CachedNetworkImage) when [plant.imageUrl]
/// is set, otherwise [Image.asset] with [plant.imagePath], with optional fallback.
class PlantImage extends StatelessWidget {
  const PlantImage({
    super.key,
    required this.plant,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  final Plant plant;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.eco, size: 48, color: theme.colorScheme.primary),
    );

    if (plant.imageUrl != null && plant.imageUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: plant.imageUrl!,
        fit: fit,
        width: width,
        height: height,
        placeholder: placeholder != null
            ? (_, __) => placeholder!(context, plant.imageUrl!)
            : (_, __) => fallback,
        errorWidget: errorWidget != null
            ? (_, __, e) => errorWidget!(context, plant.imageUrl!, e)
            : (_, __, ___) => fallback,
      );
    }
    if (plant.imagePath.isNotEmpty) {
      return Image.asset(
        plant.imagePath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => errorWidget != null
            ? errorWidget!(context, plant.imagePath, null)
            : fallback,
      );
    }
    return fallback;
  }
}
