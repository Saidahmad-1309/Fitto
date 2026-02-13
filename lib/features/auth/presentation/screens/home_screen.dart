import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/cart/presentation/screens/cart_screen.dart';
import 'package:fitto/features/admin/presentation/screens/admin_applications_screen.dart';
import 'package:fitto/features/orders/presentation/screens/orders_screen.dart';
import 'package:fitto/features/products/presentation/screens/products_screen.dart';
import 'package:fitto/features/profile/presentation/controllers/profile_providers.dart';
import 'package:fitto/features/shops/presentation/screens/shops_screen.dart';
import 'package:fitto/features/shop_onboarding/presentation/controllers/shop_onboarding_providers.dart';
import 'package:fitto/features/shop_onboarding/presentation/screens/shop_application_screen.dart';
import 'package:fitto/features/shop_onboarding/presentation/screens/shop_portal_screen.dart';

import '../controllers/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(authRepositoryProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final currentUserDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final role = currentUserDoc?.role ?? 'user';
    final isAdmin = role == 'admin';

    if (authUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profileAsync = ref.watch(userProfileProvider(authUser.uid));
    final shopLinkAsync = ref.watch(shopUserLinkProvider(authUser.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminApplicationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Admin',
            ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OrdersScreen(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'My Orders',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CartScreen(),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Cart',
          ),
          IconButton(
            onPressed: () async => repo.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }

          final stylesText = profile.stylePreferences.join(', ');
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Fitto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Gender: ${profile.gender ?? '-'}'),
                        Text('Age: ${profile.age?.toString() ?? '-'}'),
                        Text('Budget: ${profile.budget ?? '-'}'),
                        Text(
                            'Styles: ${stylesText.isEmpty ? '-' : stylesText}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ShopsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.store_mall_directory_outlined),
                  label: const Text('Browse Shops'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProductsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.checkroom_outlined),
                  label: const Text('Browse Products'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OrdersScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('My Orders'),
                ),
                const SizedBox(height: 10),
                if (!isAdmin)
                  shopLinkAsync.when(
                    data: (link) {
                      if (link != null && link.shopId.isNotEmpty) {
                        return OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ShopPortalScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.dashboard_customize_outlined),
                          label: const Text('My Shop Portal'),
                        );
                      }
                      final latestAppAsync = ref
                          .watch(latestOwnerApplicationProvider(authUser.uid));
                      return latestAppAsync.when(
                        data: (application) {
                          var label = 'Register Your Shop';
                          if (application != null &&
                              application.status.toLowerCase() == 'pending') {
                            label = 'Application Pending';
                          } else if (application != null &&
                              application.status.toLowerCase() == 'rejected') {
                            label = 'Resubmit Shop Application';
                          }

                          return OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ShopApplicationScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.storefront_outlined),
                            label: Text(label),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                        error: (_, __) => OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ShopApplicationScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Register Your Shop'),
                        ),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                    error: (_, __) => OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ShopApplicationScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Register Your Shop'),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load profile: $e'),
          ),
        ),
      ),
    );
  }
}
