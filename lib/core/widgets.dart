// DDE-Mart vendor app — shared display widgets.
//
// Image handling with loading + fallback states, status pills, price
// display and section headers. Used across inbox, catalog, payouts and
// support so every screen looks like one app. Sleek layer (GradientHeader,
// StatCard, SleekCard, ShimmerBox, TimelineDots, BillRow, StoryStrip,
// SleekBottomBar) gives every screen the violet hero + soft-card look.

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'config.dart';
import 'theme.dart';

/// Tolerant id read for API-fed dropdowns: JSON numbers decode as int,
/// but string ids or nulls must degrade to null instead of throwing.
int? idAsInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

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

/// Card with the house style: radius 20, 1px outlineVariant border,
/// layered soft shadow instead of grey Material elevation.
class SleekCard extends StatelessWidget {
  const SleekCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DdeVendorTheme.radiusCard),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: DdeVendorTheme.softShadow(context),
      ),
      child: child,
    );
    if (onTap == null) {
      return Padding(padding: margin ?? EdgeInsets.zero, child: body);
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DdeVendorTheme.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(DdeVendorTheme.radiusCard),
          onTap: onTap,
          child: body,
        ),
      ),
    );
  }
}

/// Violet hero panel: gradient wash with title + subtitle + optional
/// trailing action. Box variant (drop into any scroll view).
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon = Icons.storefront_outlined,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [Color(0xFF4C1D95), Color(0xFF1E1B2E)]
              : const [DdeVendorTheme.primary, DdeVendorTheme.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(DdeVendorTheme.radiusCardLg),
        boxShadow: DdeVendorTheme.softShadow(context),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Gradient icon tile + big value + small label (payout totals, counts).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: SleekCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: DdeVendorTheme.accentGradient(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing placeholder block for shimmer loading states (no new packages).
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.height = 72,
    this.width = double.infinity,
    this.borderRadius = 20,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Opacity(
        opacity: 0.45 + 0.35 * _pulse.value,
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
    );
  }
}

/// Three pulsing rows — drop-in replacement for list loading spinners.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.rows = 3, this.height = 84});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : 12),
            child: ShimmerBox(height: height),
          ),
      ],
    );
  }
}

/// Vertical dot timeline for order history / booking progress.
class TimelineDots extends StatelessWidget {
  const TimelineDots({super.key, required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: entries[i].color ?? scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i != entries.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: scheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i == entries.length - 1 ? 0 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (entries[i].subtitle != null)
                          Text(
                            entries[i].subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class TimelineEntry {
  const TimelineEntry({required this.title, this.subtitle, this.color});

  final String title;
  final String? subtitle;
  final Color? color;
}

/// Label … value row for bills and payout breakdowns.
class BillRow extends StatelessWidget {
  const BillRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? const TextStyle(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Compact horizontal stories rail (GET /stories). Stories carrying a link
/// (video_url) open an in-app preview sheet on tap; link-less stories are
/// display-only. Expects the public story shape:
/// {id, store: {id, name}, video_url, thumbnail}.
class StoryStrip extends StatelessWidget {
  const StoryStrip({super.key, required this.stories});

  final List<Map<String, dynamic>> stories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final story = stories[index];
          final store = story['store'];
          final name =
              '${(store is Map ? store['name'] : null) ?? 'Story'}';
          final thumb = _resolveAsset(story['thumbnail'] as String?);
          final link = '${story['video_url'] ?? ''}';
          return GestureDetector(
            onTap: link.isEmpty ? null : () => _openStory(context, story),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: DdeVendorTheme.accentGradient(context),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: scheme.surfaceContainerHighest,
                      backgroundImage:
                          thumb != null ? NetworkImage(thumb) : null,
                      child: thumb != null
                          ? null
                          : Icon(
                              Icons.play_circle_outline,
                              color: scheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openStory(BuildContext context, Map<String, dynamic> story) {
    final store = story['store'];
    final name = '${(store is Map ? store['name'] : null) ?? 'Story'}';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusChip(status: 'story'),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ApiImage(
                path: story['thumbnail'] as String?,
                height: 180,
                width: double.infinity,
                icon: Icons.play_circle_outline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${story['video_url'] ?? ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating bottom bar: rounded-24 container with a 12 margin and a pill
/// indicator behind the selected destination.
class SleekBottomBar extends StatelessWidget {
  const SleekBottomBar({
    super.key,
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  static const items = [
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
    (Icons.table_restaurant_outlined, Icons.table_restaurant, 'Dine-in'),
    (Icons.storefront_outlined, Icons.storefront, 'Catalog'),
    (Icons.payments_outlined, Icons.payments, 'Payouts'),
    (Icons.chat_outlined, Icons.chat, 'Chat'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: DdeVendorTheme.softShadow(context),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == index
                        ? scheme.primary.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(DdeVendorTheme.radiusPill),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        i == index ? items[i].$2 : items[i].$1,
                        size: 22,
                        color: i == index
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: i == index
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: i == index
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: DdeVendorTheme.accentGradient(context),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
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
            Text(apiMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
