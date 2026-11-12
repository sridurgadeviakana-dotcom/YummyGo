import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';

/// Reusable Common AppBar across all screens in YummyGo.
/// Uses only AppColors for consistent theme styling.
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic title;
  final dynamic subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final Color backgroundColor;
  final Color foregroundColor;
  final double elevation;
  final VoidCallback? onBackPressed;

  const CommonAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.centerTitle = false,
    this.backgroundColor = AppColors.warmIvory,
    this.foregroundColor = AppColors.deepTeal,
    this.elevation = 0,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    Widget titleWidget;
    if (title is Widget) {
      titleWidget = title as Widget;
    } else {
      titleWidget = Text(
        title?.toString() ?? '',
        style: TextStyle(
          color: foregroundColor,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    if (subtitle != null) {
      final subtitleColor = foregroundColor == AppColors.white
          ? AppColors.darkBannerSubtext
          : AppColors.mutedText;
      final subWidget = subtitle is Widget
          ? (subtitle as Widget)
          : Text(
              subtitle.toString(),
              style: TextStyle(
                color: subtitleColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            );
      titleWidget = Column(
        crossAxisAlignment: (centerTitle ?? false)
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          titleWidget,
          const SizedBox(height: 2),
          subWidget,
        ],
      );
    }

    Widget? leadingWidget = leading;
    if (leadingWidget == null && automaticallyImplyLeading) {
      final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
      final bool canPop = parentRoute?.canPop ?? false;
      if (canPop) {
        leadingWidget = IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: foregroundColor,
            size: 20,
          ),
          onPressed: onBackPressed ?? () => Navigator.maybePop(context),
        );
      }
    }

    return AppBar(
      title: titleWidget,
      actions: actions,
      leading: leadingWidget,
      automaticallyImplyLeading: false,
      bottom: bottom,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      surfaceTintColor: Colors.transparent,
    );
  }
}

