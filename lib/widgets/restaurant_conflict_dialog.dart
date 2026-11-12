import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';

/// Shows a confirmation dialog when a customer attempts to add an item
/// from a different restaurant to an individual or group cart.
///
/// Prompts the customer to either:
/// 1. "Continue with Current" (dismiss dialog, keep current cart items).
/// 2. "Clear Cart & Add" (returns `true`, allowing the caller to clear the cart and add the new item).
Future<bool?> showRestaurantConflictDialog(
  BuildContext context, {
  required String existingRestaurantName,
  required String newRestaurantName,
  bool isGroupOrder = false,
  String? actionButtonText,
}) {
  final safeExistingName = existingRestaurantName.trim().isNotEmpty
      ? existingRestaurantName.trim()
      : 'another restaurant';
  final safeNewName = newRestaurantName.trim().isNotEmpty
      ? newRestaurantName.trim()
      : 'this restaurant';

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: AppColors.goldenOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isGroupOrder ? 'Clear Group Cart?' : 'Replace Cart Items?',
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGroupOrder
                  ? 'The group cart contains items from "$safeExistingName".'
                  : 'Your cart contains items from "$safeExistingName".',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.charcoalBlack,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'YummyGo allows items from only one restaurant at a time. Would you like to clear the existing cart to order from "$safeNewName", or continue with the current restaurant?',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.charcoalBlack,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text(
              'Continue Current',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              actionButtonText ?? 'Clear Cart & Add',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}
