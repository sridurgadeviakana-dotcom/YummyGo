import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';

enum UserRole {
  customer,
  restaurantOwner,
  deliveryPartner,
  admin;

  String get id {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.restaurantOwner:
        return 'restaurant_owner';
      case UserRole.deliveryPartner:
        return 'delivery_partner';
      case UserRole.admin:
        return 'admin';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.restaurantOwner:
        return 'Restaurant Owner';
      case UserRole.deliveryPartner:
        return 'Delivery Partner';
      case UserRole.admin:
        return 'Marketplace Admin';
    }
  }

  String get tagline {
    switch (this) {
      case UserRole.customer:
        return 'Order food, track live delivery & split bills';
      case UserRole.restaurantOwner:
        return 'Manage menus, incoming orders & restaurant growth';
      case UserRole.deliveryPartner:
        return 'Accept delivery requests & earn on every drop';
      case UserRole.admin:
        return 'Full control of restaurants, orders, partners & metrics';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.customer:
        return Icons.person_pin_rounded;
      case UserRole.restaurantOwner:
        return Icons.storefront_rounded;
      case UserRole.deliveryPartner:
        return Icons.delivery_dining_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.customer:
        return AppColors.teal;
      case UserRole.restaurantOwner:
        return AppColors.goldenOrange;
      case UserRole.deliveryPartner:
        return AppColors.limeGreen;
      case UserRole.admin:
        return AppColors.deepTeal;
    }
  }

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.customer;
    switch (role.trim().toLowerCase()) {
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      case 'restaurant_owner':
      case 'restaurant':
      case 'owner':
      case 'partner':
        return UserRole.restaurantOwner;
      case 'delivery_partner':
      case 'delivery':
      case 'driver':
      case 'rider':
        return UserRole.deliveryPartner;
      case 'customer':
      case 'user':
      default:
        return UserRole.customer;
    }
  }
}

