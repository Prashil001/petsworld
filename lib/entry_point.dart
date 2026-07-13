import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/route/screen_export.dart';

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  int _currentIndex = 0;
  String? _discoverCategoryTitle;
  int _discoverFilterSeed = 0;

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    context.watch<CartProvider>();

    SvgPicture svgIcon(String src, {Color? color}) {
      return SvgPicture.asset(
        src,
        height: 24,
        colorFilter: ColorFilter.mode(
          color ??
              Theme.of(context).iconTheme.color!.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.3
                    : 1,
              ),
          BlendMode.srcIn,
        ),
      );
    }

    final pages = <Widget>[
      HomeScreen(
        onOpenDiscover: () => _openDiscover(),
        onOpenCategory: (categoryTitle) =>
            _openDiscover(categoryTitle: categoryTitle),
      ),
      DiscoverScreen(
        initialCategoryTitle: _discoverCategoryTitle,
        filterSeed: _discoverFilterSeed,
      ),
      const CartScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: const SizedBox(),
        leadingWidth: 0,
        centerTitle: false,
        title: _BrandHeader(currentIndex: _currentIndex),
        actions: const [SizedBox(width: 6)],
      ),
      body: PageTransitionSwitcher(
        duration: defaultDuration,
        transitionBuilder: (child, animation, secondAnimation) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondAnimation,
            child: child,
          );
        },
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(
          left: defaultPadding,
          right: defaultPadding,
          bottom: 12,
          top: 0,
        ),
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2328) : Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    backgroundColor: isDark
                        ? const Color(0xFF1F2328)
                        : Colors.white,
                    indicatorColor: primaryColor,
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        color: selected
                            ? const Color(0xFF1F2328)
                            : (isDark ? Colors.white70 : Colors.black54),
                      );
                    }),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return TextStyle(
                        color: selected
                            ? primaryColor
                            : (isDark ? Colors.white70 : Colors.black54),
                        fontSize: 12,
                        fontFamily: null,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      );
                    }),
                  ),
                  child: NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      if (index != _currentIndex) {
                        setState(() {
                          _currentIndex = index;
                          if (index == 1) {
                            _discoverCategoryTitle = null;
                            _discoverFilterSeed++;
                          }
                        });
                      }
                    },
                    height: 56,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      NavigationDestination(
                        icon: svgIcon(
                          "assets/icons/Shop.svg",
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        selectedIcon: svgIcon(
                          "assets/icons/Shop.svg",
                          color: Colors.white,
                        ),
                        label: "Shop",
                      ),
                      NavigationDestination(
                        icon: svgIcon(
                          "assets/icons/Category.svg",
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        selectedIcon: svgIcon(
                          "assets/icons/Category.svg",
                          color: Colors.white,
                        ),
                        label: "Discover",
                      ),
                      NavigationDestination(
                        icon: svgIcon(
                          "assets/icons/Bag.svg",
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        selectedIcon: svgIcon(
                          "assets/icons/Bag.svg",
                          color: Colors.white,
                        ),
                        label: "Cart",
                      ),
                      NavigationDestination(
                        icon: svgIcon(
                          "assets/icons/Profile.svg",
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        selectedIcon: svgIcon(
                          "assets/icons/Profile.svg",
                          color: Colors.white,
                        ),
                        label: "Profile",
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDiscover({String? categoryTitle}) {
    setState(() {
      _currentIndex = 1;
      _discoverCategoryTitle = categoryTitle;
      _discoverFilterSeed++;
    });
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final subtitles = <String>[
      'Wellness curated for playful paws',
      'Browse care by category',
      'Your cart essentials',
      'Profile and preferences',
    ];
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.9),
            ),
          ),
          child: Image.asset(
            'assets/logo/petsworld_logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PetsWorld",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                subtitles[currentIndex],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
