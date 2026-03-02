import 'package:flutter/material.dart';

/// A medical condition for Condition Search (synced from catalog_conditions).
class CatalogCondition {
  const CatalogCondition({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorHex,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String iconKey;
  final String colorHex;
  final bool isDefault;
  final int sortOrder;

  /// Parse color from hex string (with or without leading # or 0x).
  Color get color {
    String hex = colorHex.replaceFirst(RegExp(r'^#'), '').replaceFirst(RegExp(r'^0x'), '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon_key': iconKey,
        'color_hex': colorHex,
        'is_default': isDefault,
        'sort_order': sortOrder,
      };

  static CatalogCondition fromRow(Map<String, dynamic> row) {
    final isDefaultRaw = row['is_default'];
    final isDefault = isDefaultRaw == true ||
        isDefaultRaw == 1 ||
        (isDefaultRaw is bool && isDefaultRaw) ||
        (isDefaultRaw is int && isDefaultRaw == 1);
    return CatalogCondition(
      id: row['id'] is int ? row['id'] as int : int.tryParse(row['id'].toString()) ?? 0,
      name: row['name'] as String? ?? '',
      iconKey: row['icon_key'] as String? ?? 'healing',
      colorHex: row['color_hex'] as String? ?? 'FF6366F1',
      isDefault: isDefault,
      sortOrder: row['sort_order'] is int ? row['sort_order'] as int : int.tryParse(row['sort_order'].toString()) ?? 0,
    );
  }
}
