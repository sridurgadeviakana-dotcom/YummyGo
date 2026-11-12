class AppRoutes {
  AppRoutes._();

  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String customerHome = '/customer-home';
  static const String deliveryAddress = '/delivery-address';

  // Admin Routes
  static const String adminDashboard = '/admin';
  static const String adminRestaurants = '/admin/restaurants';
  static const String adminMenus = '/admin/menus';
  static const String adminOwners = '/admin/owners';
  static const String adminDelivery = '/admin/delivery';
  static const String adminOrders = '/admin/orders';
  static const String adminCategories = '/admin/categories';
  static const String adminOffers = '/admin/offers';

  // Restaurant Owner Routes
  static const String restaurantOwnerDashboard = '/restaurant-owner';
  static const String restaurantOwnerMenu = '/restaurant-owner/menu';
  static const String restaurantOwnerProfile = '/restaurant-owner/profile';
  static const String restaurantOwnerOrders = '/restaurant-owner/orders';

  // Delivery Partner Routes
  static const String deliveryDashboard = '/delivery-partner';
}
