import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryPartnerModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String email;
  final String vehicleType;
  final String vehicleNumber;
  final bool isAvailable;
  final String? activeOrderId;
  final double rating;
  final int totalDeliveries;
  final double earnings;
  final String status;

  const DeliveryPartnerModel({
    required this.id,
    required this.userId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.vehicleType = 'Bike',
    this.vehicleNumber = '',
    this.isAvailable = true,
    this.activeOrderId,
    this.rating = 4.8,
    this.totalDeliveries = 0,
    this.earnings = 0.0,
    this.status = 'approved',
  });

  factory DeliveryPartnerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DeliveryPartnerModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory DeliveryPartnerModel.fromMap(String id, Map<String, dynamic> data) {
    return DeliveryPartnerModel(
      id: id,
      userId: data['userId']?.toString() ?? id,
      name: data['name']?.toString() ?? 'Delivery Partner',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      vehicleType: data['vehicleType']?.toString() ?? 'Bike',
      vehicleNumber: data['vehicleNumber']?.toString() ?? '',
      isAvailable: data['isAvailable'] == true || data['isOnline'] == true,
      activeOrderId: data['activeOrderId']?.toString(),
      rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
      totalDeliveries: (data['totalDeliveries'] as num?)?.toInt() ?? 0,
      earnings: (data['earnings'] as num?)?.toDouble() ?? 0.0,
      status: data['status']?.toString() ?? 'approved',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'isAvailable': isAvailable,
      'isOnline': isAvailable,
      if (activeOrderId != null) 'activeOrderId': activeOrderId,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'earnings': earnings,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

