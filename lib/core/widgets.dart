// DDE-Mart vendor app — shared display widgets (original).
//
// Image handling with loading + fallback states, status pills, price
// display and section headers. Used across inbox, catalog, payouts and
// support so every screen looks like one app.

import 'package:flutter/material.dart';

import 'config.dart';

String? _resolveAsset(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final base = Uri.parse(AppConfig.apiBaseUrl);
  final root = '${base.scheme}://${base.authority}';
  return path.startsWith('/') ? '$root$path' : '$root/$path';
}

/// Network image that never leaves a hole: grey tile while loading,
/// branded icon tile when the URL is missing or fails.
class ApiImage extends StatelessWidget {
  const ApiImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.icon = Icons.image_outlined,
  });

  final String? path;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final url = _resolveAsset(path);
    final placeholder = Container(
      height: height,
      width: width,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        icon,
        size: 32,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (url == null) {
      return ClipRRect(borderRadius: borderRadius, child: placeholder);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            width: width,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

/// Selling price with an optional struck-through list price.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    this.was,
    this.style,
  });

  final double price;
  final double? was;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          price.toStringAsFixed(2),
          style: base?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (was != null && was! > price) ...[
          const SizedBox(width: 6),
          Text(
            was!.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

/// Indian veg / non-veg mark.
class VegMark extends StatelessWidget {
  const VegMark({super.key, required this.veg});

  final bool veg;

  @override
  Widget build(BuildContext context) {
    final color = veg ? Colors.green : const Color(0xFFB3261E);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: veg ? BoxShape.circle : BoxShape.rectangle,
          ),
        ),
      ),
    );
  }
}

/// Star rating display: green pill with average plus review count.
class StarsRow extends StatelessWidget {
  const StarsRow({super.key, this.avg, this.count, this.size = 16});

  final double? avg;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avg == null || avg! <= 0) {
      return Text(
        count != null && count! > 0 ? '$count ratings' : 'No ratings yet',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avg!.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size - 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.star, color: Colors.white, size: size - 2),
            ],
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '$count rating${count == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Colored status pill shared by orders, dine-in, payouts and coupons.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  static Color colorFor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'pending':
        return Colors.amber.shade700;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
      case 'seated':
        return Colors.deepOrange;
      case 'ongoing':
      case 'completed':
      case 'paid':
      case 'approved':
      case 'open':
      case 'active':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
      case 'expired':
        return Colors.red;
      case 'current':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// "Title … See all" row heading used by every section.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

/// Standard empty + error states so screens never render blank.
class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.message, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
