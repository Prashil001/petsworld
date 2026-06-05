import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/screen_export.dart';

import '../../../../constants.dart';

class Categories extends StatelessWidget {
  const Categories({
    super.key,
  });

  // Normalized ids/titles that represent pet types for the "Shop by pet" row.
  static const _petTypes = {'dogs', 'cats', 'dog', 'cat'};

  @override
  Widget build(BuildContext context) {
    final categories = context
        .watch<ProductProvider>()
        .discoverCategories
        .where((c) =>
            _petTypes.contains(c.title.toLowerCase().trim()) ||
            _petTypes.contains(c.id.toLowerCase().trim()))
        .toList();

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          ...List.generate(
            categories.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                right: index == categories.length - 1 ? 0 : defaultPadding / 2,
              ),
              child: CategoryBtn(
                category: categories[index].title,
                svgSrc: categories[index].svgSrc,
                isActive: index == 0,
                press: () {
                  Navigator.pushNamed(context, discoverScreenRoute);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryBtn extends StatelessWidget {
  const CategoryBtn({
    super.key,
    required this.category,
    this.svgSrc,
    required this.isActive,
    required this.press,
  });

  final String category;
  final String? svgSrc;
  final bool isActive;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: press,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: AnimatedContainer(
        duration: defaultDuration,
        constraints: const BoxConstraints(minWidth: 112),
        padding: const EdgeInsets.symmetric(
          horizontal: defaultPadding * 0.9,
          vertical: defaultPadding * 0.75,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: Border.all(
            color: isActive
                ? primaryColor.withValues(alpha: 0.4)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? primaryColor
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: Center(
                child: svgSrc != null && svgSrc!.isNotEmpty
                    ? SvgPicture.asset(
                        svgSrc!,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          isActive
                              ? Colors.white
                              : Theme.of(context).iconTheme.color!,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        Icons.pets_rounded,
                        size: 16,
                        color: isActive
                            ? Colors.white
                            : Theme.of(context).iconTheme.color,
                      ),
              ),
            ),
            const SizedBox(width: defaultPadding / 2),
            Text(
              category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
