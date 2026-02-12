import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/admin/presentation/screens/admin_applications_screen.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/auth/presentation/screens/home_screen.dart';
import 'package:fitto/features/orders/presentation/screens/orders_screen.dart';
import 'package:fitto/features/products/presentation/screens/products_screen.dart';
import 'package:fitto/features/shops/presentation/screens/shops_screen.dart';
import 'package:fitto/features/shop_onboarding/presentation/controllers/shop_onboarding_providers.dart';
import 'package:fitto/features/shop_onboarding/presentation/screens/shop_application_screen.dart';
import 'package:fitto/features/shop_onboarding/presentation/screens/shop_portal_screen.dart';

const int mainTabHomeIndex = 0;
const int mainTabShopsIndex = 1;
const int mainTabProductsIndex = 2;
const int mainTabOrdersIndex = 3;
const int mainTabDynamicLastIndex = 4;

final mainTabIndexProvider = StateProvider<int>((ref) => 0);
final appReadyProvider = StateProvider<bool>((ref) => false);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(appReadyProvider)) {
        ref.read(appReadyProvider.notifier).state = true;
      }
    });
  }

  @override
  void dispose() {
    ref.read(appReadyProvider.notifier).state = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(mainTabIndexProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final currentUserDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final isAdmin = currentUserDoc?.role == 'admin';

    final hasApprovedShop = !isAdmin &&
        authUser != null &&
        ref
                .watch(shopUserLinkProvider(authUser.uid))
                .valueOrNull
                ?.shopId
                .isNotEmpty ==
            true;

    final tabs = <_ShellTab>[
      const _ShellTab(
        destination: NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        child: HomeScreen(),
      ),
      const _ShellTab(
        destination: NavigationDestination(
          icon: Icon(Icons.store_mall_directory_outlined),
          label: 'Shops',
        ),
        child: ShopsScreen(),
      ),
      const _ShellTab(
        destination: NavigationDestination(
          icon: Icon(Icons.checkroom_outlined),
          label: 'Products',
        ),
        child: ProductsScreen(),
      ),
      const _ShellTab(
        destination: NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Orders',
        ),
        child: OrdersScreen(),
      ),
    ];

    if (isAdmin) {
      tabs.add(
        const _ShellTab(
          destination: NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            label: 'Admin',
          ),
          child: AdminApplicationsScreen(),
        ),
      );
    } else if (hasApprovedShop) {
      tabs.add(
        const _ShellTab(
          destination: NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Shop Portal',
          ),
          child: ShopPortalScreen(),
        ),
      );
    } else {
      tabs.add(
        const _ShellTab(
          destination: NavigationDestination(
            icon: Icon(Icons.add_business_outlined),
            label: 'Apply',
          ),
          child: ShopApplicationScreen(),
        ),
      );
    }

    final maxIndex = tabs.length - 1;
    final safeIndex = selectedIndex.clamp(0, maxIndex);
    if (safeIndex != selectedIndex) {
      Future.microtask(() {
        ref.read(mainTabIndexProvider.notifier).state = safeIndex;
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: tabs.map((tab) => tab.child).toList(growable: false),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) {
          ref.read(mainTabIndexProvider.notifier).state = value;
        },
        destinations:
            tabs.map((tab) => tab.destination).toList(growable: false),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.destination,
    required this.child,
  });

  final NavigationDestination destination;
  final Widget child;
}
