
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

/// Builds the themed, seamless top CommonAppBar for Login and Registration screens.
PreferredSizeWidget buildAuthAppBar({
  required String title,
  required VoidCallback onBackPressed,
  String? actionLabel,
  VoidCallback? onActionPressed,
}) {
  return CommonAppBar(
    title: title,
    centerTitle: true,
    backgroundColor: AppColors.deepTeal,
    foregroundColor: AppColors.white,
    leading: IconButton(
      tooltip: 'Back',
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: AppColors.white,
        size: 20,
      ),
      onPressed: onBackPressed,
    ),
    actions: actionLabel == null
        ? null
        : [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: TextButton(
                  onPressed: onActionPressed,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.white.withValues(alpha: 0.16),
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
  );
}



class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool seamlessWithAppBar;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.seamlessWithAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final bannerHeight = seamlessWithAppBar ? 182.0 : 245.0;

    return SizedBox(
      height: bannerHeight,
      child: ClipPath(
        clipper: AuthHeaderClipper(),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: seamlessWithAppBar
                ? const LinearGradient(
                    colors: [
                      AppColors.deepTeal,
                      AppColors.deepTeal,
                      AppColors.teal,
                    ],
                    stops: [0.0, 0.18, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [
                      AppColors.deepTeal,
                      AppColors.teal,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -55,
                right: -35,
                child: Container(
                  height: 190,
                  width: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: seamlessWithAppBar ? 14 : 28,
                left: 24,
                right: seamlessWithAppBar ? 156 : 165,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!seamlessWithAppBar) ...[
                      const Text(
                        'YummyGo',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: seamlessWithAppBar ? 25 : 27,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: seamlessWithAppBar ? 8 : 3,
                bottom: seamlessWithAppBar ? 22 : 28,
                child: Image.asset(
                  'assets/images/food_banner.png',
                  width: seamlessWithAppBar ? 142 : 165,
                  height: seamlessWithAppBar ? 124 : 145,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.fastfood_rounded,
                      color: AppColors.lime,
                      size: seamlessWithAppBar ? 90 : 105,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 55);

    path.quadraticBezierTo(
      size.width * 0.68,
      size.height + 15,
      size.width * 0.38,
      size.height - 15,
    );

    path.quadraticBezierTo(
      size.width * 0.15,
      size.height - 48,
      0,
      size.height - 20,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.color = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.65),
          elevation: 4,
          shadowColor: color.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 23,
                width: 23,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 34,
                    width: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: color,
                      size: 21,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AuthBottomLink extends StatelessWidget {
  final String message;
  final String actionText;
  final VoidCallback onTap;

  const AuthBottomLink({
    super.key,
    required this.message,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontSize: 13,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionText,
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
