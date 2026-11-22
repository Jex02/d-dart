import 'package:flutter/material.dart';
import 'responsive_shell.dart';

/// Formats and normalizes an individual item string into "ItemName × Qty"
String formatRunnerItemLine(String raw) {
  var item = raw.trim();
  if (item.isEmpty) return '';

  // Strip leading bullets / numbering if already present
  if (item.startsWith('- ') || item.startsWith('• ') || item.startsWith('* ')) {
    item = item.substring(2).trim();
  } else if (RegExp(r'^\d+[\.\)]\s+').hasMatch(item)) {
    item = item.replaceFirst(RegExp(r'^\d+[\.\)]\s+'), '').trim();
  }

  // Case 1: Suffix with × or x or X (e.g. "Burger × 2" or "Burger x 2" or "Burger X 2")
  final suffixMatch = RegExp(r'^(.+?)\s*[xX×]\s*(\d+)$').firstMatch(item);
  if (suffixMatch != null) {
    final name = suffixMatch.group(1)!.trim();
    final qty = suffixMatch.group(2)!.trim();
    return '$name × $qty';
  }

  // Case 2: Prefix with x or X (e.g. "2x Burger" or "2 x Burger" or "2X Burger")
  final prefixMatch = RegExp(r'^(\d+)\s*[xX]\s+(.+)$').firstMatch(item);
  if (prefixMatch != null) {
    final qty = prefixMatch.group(1)!.trim();
    final name = prefixMatch.group(2)!.trim();
    return '$name × $qty';
  }

  // Case 3: "2 orders Burger" or "2 order Burger"
  final ordersMatch = RegExp(r'^(\d+)\s+orders?\s+(.+)$', caseSensitive: false).firstMatch(item);
  if (ordersMatch != null) {
    final qty = ordersMatch.group(1)!.trim();
    final name = ordersMatch.group(2)!.trim();
    return '$name × $qty';
  }

  // Case 4: "1 C2 Apple" or "2 Coke Zero" (leading quantity count followed by item name)
  final numNameMatch = RegExp(r'^(\d+)\s+([A-Za-z].+)$').firstMatch(item);
  if (numNameMatch != null) {
    final qty = numNameMatch.group(1)!.trim();
    final name = numNameMatch.group(2)!.trim();
    return '$name × $qty';
  }

  return item;
}

/// Parses an order description string (which may be separated by newlines, pipes, semicolons, or commas)
/// into a list of normalized individual item strings.
List<String> parseRunnerOrderItems(String description) {
  final clean = description.trim();
  if (clean.isEmpty) return const [];

  List<String> rawParts;
  if (clean.contains('\n')) {
    rawParts = clean.split('\n');
  } else if (clean.contains('|')) {
    rawParts = clean.split('|');
  } else if (clean.contains(';')) {
    rawParts = clean.split(';');
  } else if (clean.contains(',')) {
    rawParts = clean.split(',');
  } else {
    rawParts = [clean];
  }

  final items = <String>[];
  for (final part in rawParts) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) {
      final formatted = formatRunnerItemLine(trimmed);
      if (formatted.isNotEmpty) {
        items.add(formatted);
      }
    }
  }

  return items.isEmpty ? [clean] : items;
}

/// A vertical, one-item-per-line list widget specifically designed for runner order views.
class RunnerOrderItemsList extends StatelessWidget {
  final String description;
  final TextStyle? textStyle;
  final Color? bulletColor;
  final double spacing;
  final bool showHeader;

  const RunnerOrderItemsList({
    super.key,
    required this.description,
    this.textStyle,
    this.bulletColor,
    this.spacing = 3.5,
    this.showHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = parseRunnerOrderItems(description);
    if (items.isEmpty) {
      return Text(
        'No item details provided',
        style: textStyle ??
            TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: DDartTheme.textSecondary(context),
            ),
      );
    }

    final effectiveBulletColor =
        bulletColor ?? (DDartTheme.isDark(context) ? const Color(0xFFE5A824) : const Color(0xFF7F0000));
    final effectiveTextStyle = textStyle ??
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: DDartTheme.textPrimary(context),
          height: 1.35,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) ...[
          Text(
            'Ordered Items (${items.length}):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: DDartTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
        ],
        ...items.map((item) {
          return Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '- ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: effectiveBulletColor,
                    height: 1.35,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    softWrap: true,
                    style: effectiveTextStyle,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
