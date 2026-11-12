import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';

// VEG / NON-VEG INDICATOR BADGE
class VegNonVegBadge extends StatelessWidget {
  final bool isVeg;
  final double size;

  const VegNonVegBadge({
    super.key,
    required this.isVeg,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? const Color(0xFF1B8A3C) : const Color(0xFFC62828);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// COMMON SECTION TITLE
class CartSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const CartSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// MODERN QUANTITY SELECTOR
class CartQuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const CartQuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDecrease,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  quantity <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                  color: quantity <= 1 ? AppColors.error : AppColors.deepTeal,
                  size: 16,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: AppColors.deepTeal,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onIncrease,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.teal,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// FOOD ITEM CARD
class CartItemCard extends StatelessWidget {
  final String name;
  final String image;
  final double price;
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final String? restaurant;
  final bool? isVeg;

  const CartItemCard({
    super.key,
    required this.name,
    required this.image,
    required this.price,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    this.restaurant,
    this.isVeg,
  });

  bool _detectVeg() {
    if (isVeg != null) return isVeg!;
    final lower = name.toLowerCase();
    const nonVegKeys = ['chicken', 'mutton', 'meat', 'fish', 'prawn', 'egg', 'beef', 'wings', 'pork', 'kebab'];
    for (final k in nonVegKeys) {
      if (lower.contains(k)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final vegStatus = _detectVeg();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Food Image with rounded border
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: VegNonVegBadge(isVeg: vegStatus, size: 13),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Food Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepTeal,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    height: 1.2,
                  ),
                ),
                if (restaurant != null && restaurant!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    restaurant!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '₹${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (quantity > 1) ...[
                      const SizedBox(width: 6),
                      Text(
                        '× $quantity = ₹${(price * quantity).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Stepper
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CartQuantitySelector(
                quantity: quantity,
                onIncrease: onIncrease,
                onDecrease: onDecrease,
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Remove',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.lightTeal,
      child: const Icon(
        Icons.restaurant_rounded,
        color: AppColors.teal,
        size: 28,
      ),
    );
  }
}

// FREE DELIVERY PROGRESS BAR
class FreeDeliveryProgressBar extends StatelessWidget {
  final double currentSubtotal;
  final double targetAmount;

  const FreeDeliveryProgressBar({
    super.key,
    required this.currentSubtotal,
    this.targetAmount = 499.0,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = currentSubtotal >= targetAmount;
    final progress = (currentSubtotal / targetAmount).clamp(0.0, 1.0);
    final remaining = (targetAmount - currentSubtotal).clamp(0.0, targetAmount);

    if (isUnlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightLime,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC7E7A5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎉 You unlocked FREE Delivery! (Saved ₹30)',
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightTeal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.electric_moped_rounded, color: AppColors.teal, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add ₹${remaining.toStringAsFixed(0)} more for FREE Delivery',
                  style: const TextStyle(
                    color: AppColors.deepTeal,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

// DELIVERY LOCATION & ETA HEADER CARD
class DeliveryAddressCard extends StatelessWidget {
  final String label;
  final String address;
  final String eta;
  final VoidCallback? onChange;

  const DeliveryAddressCard({
    super.key,
    this.label = 'Home',
    this.address = '402, Green Valley Heights, Downtown',
    this.eta = '25-30 mins',
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.lightTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Delivering to $label',
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.lightLime,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 12, color: AppColors.success),
                          Text(
                            eta,
                            style: const TextStyle(
                              color: AppColors.deepTeal,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.teal,
              ),
              child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// COOKING & DELIVERY INSTRUCTIONS SELECTOR
class DeliveryInstructionsCard extends StatelessWidget {
  final Set<String> selectedOptions;
  final ValueChanged<String> onToggle;
  final TextEditingController? noteController;

  const DeliveryInstructionsCard({
    super.key,
    required this.selectedOptions,
    required this.onToggle,
    this.noteController,
  });

  static const List<Map<String, String>> _options = [
    {'key': 'no_bell', 'label': 'Don\'t ring bell', 'icon': '🔕'},
    {'key': 'leave_door', 'label': 'Leave at door', 'icon': '🚪'},
    {'key': 'avoid_calling', 'label': 'Avoid calling', 'icon': '📵'},
    {'key': 'no_cutlery', 'label': 'No cutlery needed', 'icon': '🍴'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      // child: Column(
      //   crossAxisAlignment: CrossAxisAlignment.start,
      //   children: [
      //     const Row(
      //       children: [
      //         Icon(Icons.notes_rounded, color: AppColors.teal, size: 18),
      //         SizedBox(width: 8),
      //         Text(
      //           'Delivery Instructions',
      //           style: TextStyle(
      //             color: AppColors.deepTeal,
      //             fontSize: 14,
      //             fontWeight: FontWeight.w800,
      //           ),
      //         ),
      //       ],
      //     ),
      //     const SizedBox(height: 10),
      //     SingleChildScrollView(
      //       scrollDirection: Axis.horizontal,
      //       child: Row(
      //         children: _options.map((opt) {
      //           final isSelected = selectedOptions.contains(opt['key']);
      //           return Padding(
      //             padding: const EdgeInsets.only(right: 8),
      //             child: FilterChip(
      //               label: Text('${opt['icon']} ${opt['label']}'),
      //               selected: isSelected,
      //               onSelected: (_) => onToggle(opt['key']!),
      //               labelStyle: TextStyle(
      //                 color: isSelected ? AppColors.white : AppColors.deepTeal,
      //                 fontSize: 11.5,
      //                 fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      //               ),
      //               backgroundColor: AppColors.warmIvory,
      //               selectedColor: AppColors.deepTeal,
      //               checkmarkColor: AppColors.white,
      //               shape: RoundedRectangleBorder(
      //                 borderRadius: BorderRadius.circular(10),
      //                 side: BorderSide(
      //                   color: isSelected ? AppColors.deepTeal : AppColors.border,
      //                 ),
      //               ),
      //               padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      //             ),
      //           );
      //         }).toList(),
      //       ),
      //     ),
      //     if (noteController != null) ...[
      //       const SizedBox(height: 10),
      //       TextField(
      //         controller: noteController,
      //         style: const TextStyle(fontSize: 12.5, color: AppColors.deepTeal),
      //         decoration: InputDecoration(
      //           hintText: 'Add cooking note (e.g., make it less spicy)...',
      //           hintStyle: const TextStyle(fontSize: 12, color: AppColors.mutedText),
      //           prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.teal),
      //           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      //           filled: true,
      //           fillColor: AppColors.warmIvory,
      //           border: OutlineInputBorder(
      //             borderRadius: BorderRadius.circular(12),
      //             borderSide: BorderSide(color: AppColors.border),
      //           ),
      //           enabledBorder: OutlineInputBorder(
      //             borderRadius: BorderRadius.circular(12),
      //             borderSide: BorderSide(color: AppColors.border),
      //           ),
      //           focusedBorder: OutlineInputBorder(
      //             borderRadius: BorderRadius.circular(12),
      //             borderSide: const BorderSide(color: AppColors.teal),
      //           ),
      //         ),
      //       ),
      //     ],
      //   ],
      // ),
    );
  }
}

// COUPONS & OFFERS CARD
class CouponCard extends StatelessWidget {
  final String? appliedCoupon;
  final double discount;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  const CouponCard({
    super.key,
    required this.appliedCoupon,
    required this.discount,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoupon = appliedCoupon != null && appliedCoupon!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasCoupon ? AppColors.lightLime : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasCoupon ? const Color(0xFFC7E7A5) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: hasCoupon
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.goldenOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_offer_rounded,
              color: hasCoupon ? AppColors.success : AppColors.goldenOrange,
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
                  hasCoupon ? '$appliedCoupon Applied!' : 'Apply Coupon: YUMMY50',
                  style: TextStyle(
                    color: hasCoupon ? AppColors.success : AppColors.deepTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  hasCoupon
                      ? 'Saved ₹${discount.toStringAsFixed(0)} on this order'
                      : 'Get ₹50 OFF on orders above ₹199',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: hasCoupon ? onRemove : onApply,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: hasCoupon ? AppColors.error : AppColors.teal,
            ),
            child: Text(
              hasCoupon ? 'Remove' : 'Apply',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// TIP DELIVERY PARTNER CARD
class TipSelectorCard extends StatelessWidget {
  final double selectedTip;
  final ValueChanged<double> onTipSelected;

  const TipSelectorCard({
    super.key,
    required this.selectedTip,
    required this.onTipSelected,
  });

  static const List<double> _tipOptions = [0, 20, 30, 50];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.delivery_dining_rounded, color: AppColors.teal, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tip your delivery partner',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '100% of your tip goes to your partner',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _tipOptions.map((amount) {
              final isSelected = selectedTip == amount;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => onTipSelected(amount),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teal : AppColors.warmIvory,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.teal : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          amount == 0 ? 'No tip' : '₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isSelected ? AppColors.white : AppColors.deepTeal,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// COMMON BILL ROW
class CartBillRow extends StatelessWidget {
  final String title;
  final double amount;
  final bool isBold;
  final String? strikeThroughText;
  final String? badgeText;
  final Color? valueColor;

  const CartBillRow({
    super.key,
    required this.title,
    required this.amount,
    this.isBold = false,
    this.strikeThroughText,
    this.badgeText,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isBold ? AppColors.deepTeal : AppColors.mutedText,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              fontSize: isBold ? 15 : 13,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (strikeThroughText != null) ...[
                Text(
                  strikeThroughText!,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    decoration: TextDecoration.lineThrough,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (badgeText != null) ...[
                Text(
                  badgeText!,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: valueColor ?? (isBold ? AppColors.deepTeal : AppColors.deepTeal),
                    fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                    fontSize: isBold ? 17 : 13.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// MODERN BILL SUMMARY CARD
class CartBillSummary extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double platformFee;
  final double tax;
  final double total;
  final double discount;
  final double tip;

  const CartBillSummary({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.tax,
    required this.total,
    this.discount = 0,
    this.tip = 0,
  });

  @override
  Widget build(BuildContext context) {
    final deliverySaved = subtotal >= 499;
    final totalSavings = (deliverySaved ? 30.0 : 0.0) + discount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.teal, size: 20),
              SizedBox(width: 8),
              Text(
                'Bill Details',
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CartBillRow(
            title: 'Item total',
            amount: subtotal,
          ),
          CartBillRow(
            title: 'Delivery partner fee',
            amount: deliveryFee,
            strikeThroughText: deliverySaved ? '₹30.00' : null,
            badgeText: deliverySaved ? 'FREE' : null,
          ),
          CartBillRow(
            title: 'Platform fee',
            amount: platformFee,
          ),
          CartBillRow(
            title: 'Taxes & charges (GST 5%)',
            amount: tax,
          ),
          if (discount > 0)
            CartBillRow(
              title: 'Coupon discount',
              amount: -discount,
              valueColor: AppColors.success,
            ),
          if (tip > 0)
            CartBillRow(
              title: 'Delivery partner tip',
              amount: tip,
              valueColor: AppColors.deepTeal,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.border, height: 1),
          ),
          CartBillRow(
            title: 'To Pay',
            amount: total,
            isBold: true,
          ),
          if (totalSavings > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lightLime,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yay! You saved ₹${totalSavings.toStringAsFixed(0)} on this order',
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// CANCELLATION POLICY CARD
class CancellationPolicyCard extends StatelessWidget {
  const CancellationPolicyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.teal, size: 18),
              SizedBox(width: 8),
              Text(
                'Review your order details',
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Avoid cancellations as food cannot be restocked once cooking starts. 100% contactless delivery guaranteed.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// COMMON EMPTY CART
class EmptyCartWidget extends StatelessWidget {
  final VoidCallback onExplore;

  const EmptyCartWidget({
    super.key,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.lightTeal,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 64,
                  color: AppColors.teal,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Good food is always cooking!\nDiscover delicious dishes from top restaurants.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.restaurant_menu_rounded, size: 19),
              label: const Text(
                'Explore Food',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepTeal,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CHECKOUT STICKY BOTTOM BUTTON
class CartCheckoutButton extends StatelessWidget {
  final double total;
  final VoidCallback onPressed;
  final double? savings;
  final bool isLoading;

  const CartCheckoutButton({
    super.key,
    required this.total,
    required this.onPressed,
    this.savings,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'TO PAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedText,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (savings != null && savings! > 0)
                        Text(
                          'Saved ₹${savings!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Proceed to Pay',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.mutedText),
                SizedBox(width: 4),
                Text(
                  '100% Safe & Secure Payments via Razorpay',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
