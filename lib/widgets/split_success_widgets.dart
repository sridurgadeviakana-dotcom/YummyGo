import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';

class SuccessIconWidget extends StatelessWidget {
  const SuccessIconWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        height: 116,
        width: 116,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF20CE83),
              Color(0xFF079D65),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF12B879).withOpacity(0.25),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 72,
        ),
      ),
    );
  }
}


class SplitAmountCard extends StatelessWidget {
  final double totalAmount;

  const SplitAmountCard({
    super.key,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            AppColors.deepTeal,
            AppColors.teal,
          ],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Total Amount',
            style: TextStyle(
              fontSize: 15,
              color:AppColors.white ,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '₹${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}


class SplitSuccessButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const SplitSuccessButton({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [
              AppColors.deepTeal,
             AppColors.teal,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF12B879).withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class SplitConfettiPainter extends CustomPainter {
  const SplitConfettiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFFB000),
      const Color(0xFF20CE83),
      const Color(0xFF22B8E6),
      const Color(0xFFFF6384),
      const Color(0xFFFF8A00),
    ];

    final positions = [
      [0.08, 0.07],
      [0.19, 0.10],
      [0.73, 0.06],
      [0.90, 0.13],
      [0.12, 0.26],
      [0.84, 0.28],
      [0.04, 0.39],
      [0.94, 0.40],
      [0.16, 0.52],
      [0.88, 0.55],
    ];

    for (int i = 0; i < positions.length; i++) {
      final x = size.width * positions[i][0];
      final y = size.height * positions[i][1];

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + 8, y + 10),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}




class BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFE7FFF2),
          Color(0xFFC9F9DF),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.05,
        size.width * 0.5,
        size.height * 0.35,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.65,
        size.width,
        size.height * 0.25,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}




class FriendsIllustrationWidget extends StatelessWidget {
  const FriendsIllustrationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/yummygo_split_friends.png',
      height: 165,
      width: double.infinity,
      fit: BoxFit.contain,
    );
  }
}