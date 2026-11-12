import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/views/cart_screen.dart';

/// Global Cart Bar that stays visible across customer browsing screens
/// whenever items exist in the cart.
class GlobalCartBar extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final double elevation;

  const GlobalCartBar({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(14, 0, 14, 10),
    this.elevation = 6,
  });

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: cartService.cartStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final items = snapshot.data!.docs;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        int totalCount = 0;
        double totalPrice = 0.0;

        for (final doc in items) {
          final data = doc.data();
          final q = (data['quantity'] as num?)?.toInt() ?? 1;
          final p = (data['price'] as num?)?.toDouble() ?? 0.0;
          totalCount += q;
          totalPrice += (p * q);
        }

        if (totalCount <= 0) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: Container(
            margin: margin,
            child: Material(
              elevation: elevation,
              shadowColor: AppColors.deepTeal.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
              color: AppColors.deepTeal,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$totalCount ${totalCount == 1 ? 'item' : 'items'} added',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalPrice.toStringAsFixed(0)} plus taxes',
                              style: TextStyle(
                                color: AppColors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.goldenOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'VIEW CART',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppColors.white,
                              size: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

