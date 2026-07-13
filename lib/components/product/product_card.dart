import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../network_image_with_loader.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.image,
    required this.brandName,
    required this.title,
    required this.price,
    this.priceAfetDiscount,
    this.dicountpercent,
    this.isSaved = false,
    this.onToggleSaved,
    this.onAddToCart,
    required this.press,
  });
  final String image, brandName, title;
  final double price;
  final double? priceAfetDiscount;
  final int? dicountpercent;
  final bool isSaved;
  final VoidCallback? onToggleSaved;
  final FutureOr<bool> Function()? onAddToCart;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final imageKey = GlobalKey();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    final iconColor = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.9);
    final surfaceColor = isDark ? const Color(0xFF171C26) : Colors.white;
    final imageSurface = isDark
        ? const Color(0xFF111722)
        : const Color(0xFFF8F5EE);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: press,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Ink(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Container(
                    key: imageKey,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: imageSurface,
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: NetworkImageWithLoader(
                              image,
                              fit: BoxFit.contain,
                              radius: 16,
                            ),
                          ),
                        ),
                        if (onToggleSaved != null)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: InkWell(
                              onTap: onToggleSaved,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(999),
                              ),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(
                                          0xFF262B36,
                                        ).withValues(alpha: 0.96)
                                      : Colors.white.withValues(alpha: 0.94),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(999),
                                  ),
                                ),
                                child: Icon(
                                  isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  size: 17,
                                  color: isSaved
                                      ? primaryColor
                                      : (iconColor ?? blackColor80),
                                ),
                              ),
                            ),
                          ),
                        if (dicountpercent != null)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: const BoxDecoration(
                                color: dealBadgeBg,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(999),
                                ),
                              ),
                              child: Text(
                                "$dicountpercent% OFF",
                                style: const TextStyle(
                                  color: dealBadgeText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        if (onAddToCart != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: _ProductCardIconButton(
                              icon: Icons.shopping_bag_outlined,
                              isDark: isDark,
                              iconColor: iconColor ?? blackColor80,
                              onTap: () async {
                                final added = await onAddToCart!();
                                if (added && context.mounted) {
                                  _runCartFlyAnimation(
                                    context: context,
                                    sourceKey: imageKey,
                                    imageUrl: image,
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  brandName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: secondaryText,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                priceAfetDiscount != null
                    ? Row(
                        children: [
                          Text(
                            "Rs ${priceAfetDiscount!.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: priceColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Rs ${price.toStringAsFixed(0)}",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        "Rs ${price.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: priceColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCardIconButton extends StatelessWidget {
  const _ProductCardIconButton({
    required this.icon,
    required this.isDark,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final bool isDark;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark
          ? const Color(0xFF262B36).withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.94),
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

void _runCartFlyAnimation({
  required BuildContext context,
  required GlobalKey sourceKey,
  required String imageUrl,
}) {
  final overlay = Overlay.maybeOf(context);
  final sourceContext = sourceKey.currentContext;
  if (overlay == null || sourceContext == null) {
    return;
  }

  final sourceBox = sourceContext.findRenderObject() as RenderBox?;
  if (sourceBox == null || !sourceBox.hasSize) {
    return;
  }

  final startRect = sourceBox.localToGlobal(Offset.zero) & sourceBox.size;
  final screenSize = MediaQuery.sizeOf(context);
  final start = startRect.center;
  final target = Offset(screenSize.width * 0.625, screenSize.height - 52);
  final startSize = startRect.shortestSide.clamp(52.0, 76.0);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 680),
          curve: Curves.easeInOutCubic,
          onEnd: () => entry.remove(),
          builder: (context, value, child) {
            final center = Offset.lerp(start, target, value)!;
            final size = lerpDouble(startSize, 24, value)!;
            final opacity = lerpDouble(1, 0.15, value)!;
            return Stack(
              children: [
                Positioned(
                  left: center.dx - size / 2,
                  top: center.dy - size / 2,
                  width: size,
                  height: size,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: lerpDouble(1, 0.8, value)!,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.shopping_bag_outlined);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  overlay.insert(entry);
}
