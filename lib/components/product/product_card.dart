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
    required this.press,
  });
  final String image, brandName, title;
  final double price;
  final double? priceAfetDiscount;
  final int? dicountpercent;
  final bool isSaved;
  final VoidCallback? onToggleSaved;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    final iconColor = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.9);
    final surfaceColor = isDark ? const Color(0xFF171C26) : Colors.white;
    final imageSurface = isDark ? const Color(0xFF111722) : const Color(0xFFF8F5EE);

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
                                      ? const Color(0xFF262B36).withValues(alpha: 0.96)
                                      : Colors.white.withValues(alpha: 0.94),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(999),
                                  ),
                                ),
                                child: Icon(
                                  isSaved ? Icons.bookmark : Icons.bookmark_border,
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
