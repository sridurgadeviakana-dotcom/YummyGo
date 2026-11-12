import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/firebase_options.dart';
import 'package:yummy_go_application/services/auth_router.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/routes/app_routes.dart';
import 'package:yummy_go_application/views/admin/admin_dashboard.dart';
import 'package:yummy_go_application/views/admin/categories_offers_management.dart';
import 'package:yummy_go_application/views/admin/delivery_management.dart';
import 'package:yummy_go_application/views/admin/order_management.dart';
import 'package:yummy_go_application/views/admin/owner_management.dart';
import 'package:yummy_go_application/views/admin/restaurant_management.dart';
import 'package:yummy_go_application/views/auth/login_screen.dart';
import 'package:yummy_go_application/views/auth/role_selection_screen.dart';
import 'package:yummy_go_application/views/auth/signup_screen.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/views/delivery_partner/delivery_dashboard.dart';
import 'package:yummy_go_application/views/restaurant_owner/menu_management.dart';
import 'package:yummy_go_application/views/restaurant_owner/owner_dashboard.dart';
import 'package:yummy_go_application/views/restaurant_owner/restaurant_profile_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YummyGo',
      debugShowCheckedModeBanner: false,
      theme: AppColors.theme,
      home: const AuthRouter(),
      routes: {
        AppRoutes.roleSelection: (_) => const RoleSelectionScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.signup: (_) => const CustomerRegistrationScreen(),
        AppRoutes.customerHome: (_) => const CustomerHomeScreen(),
        AppRoutes.adminDashboard: (_) => const AdminDashboard(),
        AppRoutes.adminRestaurants: (_) => const RestaurantManagementScreen(),
        AppRoutes.adminMenus: (_) => const CategoriesOffersManagementScreen(initialIndex: 0),
        AppRoutes.adminCategories: (_) => const CategoriesOffersManagementScreen(initialIndex: 0),
        AppRoutes.adminOffers: (_) => const CategoriesOffersManagementScreen(initialIndex: 1),
        AppRoutes.adminOwners: (_) => const OwnerManagementScreen(),
        AppRoutes.adminDelivery: (_) => const DeliveryManagementScreen(),
        AppRoutes.adminOrders: (_) => const OrderManagementScreen(),
        AppRoutes.restaurantOwnerDashboard: (_) => const RestaurantOwnerDashboard(),
        AppRoutes.restaurantOwnerMenu: (_) => const MenuManagementScreen(),
        AppRoutes.restaurantOwnerProfile: (_) => const RestaurantProfileScreen(),
        AppRoutes.restaurantOwnerOrders: (_) => const RestaurantOwnerDashboard(),
        AppRoutes.deliveryDashboard: (_) => const DeliveryDashboardScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        title: widget.title,
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_functions/cloud_functions.dart';

// import 'package:yummy_go_application/firebase_options.dart';
// import 'package:yummy_go_application/services/auth_router.dart';
// import 'package:yummy_go_application/views/customer_registration.dart';
// import 'package:yummy_go_application/views/splash_screen.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // Initialize Firebase
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   // Your computer's IP address
//   const String emulatorHost = '10.0.2.2';

//   // Firebase Authentication Emulator
//   await FirebaseAuth.instance.useAuthEmulator(
//     emulatorHost,
//     9099,
//   );

//   // Firestore Emulator
//   FirebaseFirestore.instance.useFirestoreEmulator(
//     emulatorHost,
//     8080,
//   );

//   // Firebase Functions Emulator
//   FirebaseFunctions.instance.useFunctionsEmulator(
//     emulatorHost,
//     5001,
//   );

//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         colorScheme: .fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const AuthRouter(),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: Text(widget.title),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: .center,
//           children: [
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
