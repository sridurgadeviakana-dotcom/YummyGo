import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemModel {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String image;
  final bool isVeg;

  const OrderItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.image = '',
    this.isVeg = true,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> data) {
    return OrderItemModel(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      image: data['image']?.toString() ?? '',
      isVeg: data['isVeg'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'image': image,
      'isVeg': isVeg,
    };
  }
}

class OrderModel {
  final String id;
  final String userId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String restaurantId;
  final String restaurantName;
  final List<OrderItemModel> items;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String? deliveryPartnerId;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;
  final bool deliveryAccepted;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? deliveryInstructions;
  final String? groupId;
  final String? orderType;
  final String? groupName;
  final List<String> memberUids;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isGroupOrder =>
      orderType == 'group' || (groupId != null && groupId!.isNotEmpty);

  String get deliveryArea => deliveryAddress;

  bool get isActive {
    final s = orderStatus.trim().toLowerCase();
    return s != 'delivered' && s != 'completed' && s != 'cancelled';
  }

  bool get isDelivered {
    final s = orderStatus.trim().toLowerCase();
    return s == 'delivered' || s == 'completed';
  }

  bool isUserInOrder(String uid) {
    if (uid.isEmpty) return false;
    if (userId == uid) return true;
    return memberUids.contains(uid);
  }

  const OrderModel({
    required this.id,
    required this.userId,
    required this.customerName,
    this.customerPhone = '',
    this.deliveryAddress = '',
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.totalAmount,
    this.paymentMethod = 'Online',
    this.paymentStatus = 'paid',
    this.orderStatus = 'placed',
    this.deliveryPartnerId,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
    this.deliveryAccepted = false,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryInstructions,
    this.groupId,
    this.orderType,
    this.groupName,
    this.memberUids = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OrderModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    final rawItems = data['items'];
    final items = <OrderItemModel>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(OrderItemModel.fromMap(item));
        } else if (item is Map) {
          items.add(OrderItemModel.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    }
    DateTime? updated;
    if (data['updatedAt'] is Timestamp) {
      updated = (data['updatedAt'] as Timestamp).toDate();
    }

    final total = (data['totalAmount'] as num?)?.toDouble() ??
        (data['total'] as num?)?.toDouble() ??
        (data['amount'] as num?)?.toDouble() ??
        0.0;

    final rawMembers = data['memberUids'];
    final memberUids = <String>[];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m != null && m.toString().isNotEmpty) {
          memberUids.add(m.toString());
        }
      }
    }

    return OrderModel(
      id: id,
      userId: data['userId']?.toString() ??
          data['customerId']?.toString() ??
          '',
      customerName: data['customerName']?.toString() ?? 'Customer',
      customerPhone: data['customerPhone']?.toString() ?? '',
      deliveryAddress: data['deliveryAddress']?.toString() ??
          data['address']?.toString() ??
          (data['receiverDetails'] is Map
              ? (data['receiverDetails']['formattedAddress']?.toString() ?? '')
              : ''),
      restaurantId: data['restaurantId']?.toString() ?? '',
      restaurantName: data['restaurantName']?.toString() ?? 'Restaurant',
      items: items,
      totalAmount: total,
      paymentMethod: data['paymentMethod']?.toString() ?? 'Online',
      paymentStatus: data['paymentStatus']?.toString() ?? 'paid',
      orderStatus: data['orderStatus']?.toString() ?? data['status']?.toString() ?? 'placed',
      deliveryPartnerId: data['deliveryPartnerId']?.toString(),
      deliveryPartnerName: data['deliveryPartnerName']?.toString(),
      deliveryPartnerPhone: data['deliveryPartnerPhone']?.toString(),
      deliveryAccepted: data['deliveryAccepted'] == true,
      deliveryLatitude: (data['deliveryLatitude'] as num?)?.toDouble() ??
          (data['customerLatitude'] as num?)?.toDouble() ??
          (data['receiverDetails'] is Map
              ? (data['receiverDetails']['latitude'] as num?)?.toDouble()
              : null) ??
          (data['latitude'] as num?)?.toDouble(),
      deliveryLongitude: (data['deliveryLongitude'] as num?)?.toDouble() ??
          (data['customerLongitude'] as num?)?.toDouble() ??
          (data['receiverDetails'] is Map
              ? (data['receiverDetails']['longitude'] as num?)?.toDouble()
              : null) ??
          (data['longitude'] as num?)?.toDouble(),
      deliveryInstructions: data['deliveryInstructions']?.toString(),
      groupId: data['groupId']?.toString(),
      orderType: data['orderType']?.toString(),
      groupName: data['groupName']?.toString(),
      memberUids: memberUids,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'orderStatus': orderStatus,
      'status': orderStatus,
      'deliveryAccepted': deliveryAccepted,
      if (groupId != null) 'groupId': groupId,
      if (orderType != null) 'orderType': orderType,
      if (groupName != null) 'groupName': groupName,
      if (memberUids.isNotEmpty) 'memberUids': memberUids,
      if (deliveryPartnerId != null) 'deliveryPartnerId': deliveryPartnerId,
      if (deliveryPartnerName != null) 'deliveryPartnerName': deliveryPartnerName,
      if (deliveryPartnerPhone != null) 'deliveryPartnerPhone': deliveryPartnerPhone,
      if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
      if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
      if (deliveryInstructions != null) 'deliveryInstructions': deliveryInstructions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get statusDisplay {
    switch (orderStatus.toLowerCase()) {
      case 'placed':
        return 'Order Placed';
      case 'confirmed':
        return 'Confirmed by Restaurant';
      case 'preparing':
        return 'Cooking in Kitchen';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'on_the_way':
      case 'out_for_delivery':
      case 'picked_up':
        return 'On The Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return orderStatus;
    }
  }
}

