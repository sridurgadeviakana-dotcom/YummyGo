import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/views/order_tracking_screen.dart';
import 'package:yummy_go_application/views/profile_feature_screens.dart';
import 'package:yummy_go_application/views/resturent_menu_screen.dart';
import 'package:yummy_go_application/views/split_bill_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String orderId;
  final String? paymentId;
  final String restaurantName;
  final String? restaurantId;
  final double totalAmount;
  final String paymentStatus;

  /// Optional fields for group bill splitting
  final String? groupId;
  final VoidCallback? onSplitBill;

  const PaymentSuccessScreen({
    super.key,
    required this.orderId,
    required this.restaurantName,
    required this.totalAmount,
    this.restaurantId,
    this.paymentId,
    this.paymentStatus = 'Paid',
    this.groupId,
    this.onSplitBill,
  });

  static const Color primary = AppColors.deepTeal;
  static const Color teal = AppColors.teal;
  static const Color successGreen = AppColors.success;
  static const Color background = AppColors.warmIvory;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateToHome(context);
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: CommonAppBar(
          backgroundColor: Colors.transparent,
          title: 'Order Confirmed',
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: primary,
              size: 24,
            ),
            tooltip: 'Close & Home',
            onPressed: () => _navigateToHome(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.home_outlined,
                color: teal,
                size: 24,
              ),
              tooltip: 'Home',
              onPressed: () => _navigateToHome(context),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: ConfettiPainter())),
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // 1. Animated Green Checkmark
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Transform.rotate(
                            angle: (1 - value) * 0.25,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        height: 110,
                        width: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF20CE83), Color(0xFF079D65)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF12B879).withOpacity(0.28),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 68,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 2. Titles
                    const Text(
                      "Payment Successful!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172D29),
                        letterSpacing: -0.6,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Your delicious food is on its way!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Amount Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8FBF2), Color(0xFFD6F7E6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: const Color(0xFFBCEECE)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF087C53).withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "TOTAL AMOUNT PAID",
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                              color: successGreen.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "₹${totalAmount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: successGreen,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: successGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "Paid to $restaurantName",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: successGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 4. Order & Transaction Details Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEDF1EF)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.035),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _detailRow(
                            icon: Icons.tag_rounded,
                            title: "Order ID",
                            value: orderId.startsWith('#') ? orderId : "#$orderId",
                            canCopy: true,
                            context: context,
                          ),
                          _divider(),
                          _detailRow(
                            icon: Icons.restaurant_rounded,
                            title: "Restaurant",
                            value: restaurantName,
                          ),
                          _divider(),
                          _detailRow(
                            icon: Icons.currency_rupee_rounded,
                            title: "Total Amount",
                            value: "₹${totalAmount.toStringAsFixed(2)}",
                          ),
                          _divider(),
                          _detailRow(
                            icon: Icons.check_circle_outline_rounded,
                            title: "Payment Status",
                            value: paymentStatus,
                            valueColor: successGreen,
                            isStatusBadge: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 5. Primary Action: Track Your Order
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderTrackingScreen(
                                orderId: orderId,
                                groupId: groupId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delivery_dining_rounded, size: 22),
                        label: const Text(
                          "Track Your Order",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: teal.withOpacity(0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 7. Button 3: Explore Other Restaurants
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToHome(context),
                        icon: const Icon(Icons.storefront_rounded, size: 20),
                        label: const Text(
                          "Explore All Restaurants",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: const BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Button 4: View All Orders in My Orders
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 18, color: teal),
                      label: const Text(
                        "View All Orders in My Orders",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: teal,
                        ),
                      ),
                    ),

                    // Optional Group Split Bill Button if group context exists
                    if (groupId != null && groupId!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFEDF1EF)),
                      const SizedBox(height: 12),
                      const Text(
                        "Enjoying food together?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF172D29),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Share the cost with your friends easily.",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (onSplitBill != null) {
                              onSplitBill!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupSplitBillScreen(
                                    groupId: groupId!,
                                    totalamount: totalAmount,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.call_split_rounded, size: 20),
                          label: const Text(
                            "Now Split Your Bill",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: AppColors.teal.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    const Text(
                      "Thank you for ordering with YummyGo! 🍔✨",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8B9994),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
      (route) => false,
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Divider(height: 1, color: Color(0xFFEDF1EF)),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
    bool isStatusBadge = false,
    bool canCopy = false,
    BuildContext? context,
  }) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF8F1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: teal, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF89938F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (isStatusBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFF0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBCEECE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 13, color: successGreen),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: successGreen,
                  ),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? const Color(0xFF263C35),
                    ),
                  ),
                ),
                if (canCopy && context != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$title copied to clipboard!'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Confetti Background Painter
class ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFF00BFA5),
      const Color(0xFFFFB52E),
      const Color(0xFFB56AFF),
      const Color(0xFFFF6B8A),
      const Color(0xFF26C6DA),
    ];

    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final pieces = [
      [0.08, 0.04, 0.3],
      [0.20, 0.09, -0.5],
      [0.37, 0.02, 0.7],
      [0.60, 0.06, -0.3],
      [0.85, 0.03, 0.5],
      [0.94, 0.12, -0.6],
      [0.04, 0.24, -0.4],
      [0.91, 0.27, 0.5],
      [0.13, 0.42, 0.3],
      [0.82, 0.45, -0.5],
      [0.05, 0.63, 0.6],
      [0.93, 0.66, -0.3],
    ];

    for (int i = 0; i < pieces.length; i++) {
      final x = size.width * pieces[i][0];
      final y = size.height * pieces[i][1];
      final angle = pieces[i][2];

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      paint.color = colors[i % colors.length];
      canvas.drawLine(const Offset(0, -4), const Offset(0, 4), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
