import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String id;
  final String userId;
  final String receiverName;
  final String receiverPhone;
  final String houseFlatNo;
  final String street;
  final String area;
  final String pincode;
  final String landmark;
  final String deliveryInstructions;
  final String label; // 'Home', 'Work', 'Other'
  final double latitude;
  final double longitude;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AddressModel({
    required this.id,
    required this.userId,
    required this.receiverName,
    required this.receiverPhone,
    required this.houseFlatNo,
    required this.street,
    required this.area,
    this.pincode = '',
    this.landmark = '',
    this.deliveryInstructions = '',
    this.label = 'Home',
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Complete human-readable formatted address
  String get formattedAddress {
    final parts = <String>[];
    if (houseFlatNo.trim().isNotEmpty) parts.add(houseFlatNo.trim());
    if (street.trim().isNotEmpty) parts.add(street.trim());
    if (area.trim().isNotEmpty) parts.add(area.trim());
    if (landmark.trim().isNotEmpty) parts.add('Near ${landmark.trim()}');
    final base = parts.join(', ');
    if (pincode.trim().isNotEmpty) {
      return base.isEmpty ? pincode.trim() : '$base - ${pincode.trim()}';
    }
    return base;
  }

  factory AddressModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AddressModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory AddressModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    }
    DateTime? updated;
    if (data['updatedAt'] is Timestamp) {
      updated = (data['updatedAt'] as Timestamp).toDate();
    }

    return AddressModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      receiverName: data['receiverName']?.toString() ??
          data['customerName']?.toString() ??
          data['name']?.toString() ??
          '',
      receiverPhone: data['receiverPhone']?.toString() ??
          data['customerPhone']?.toString() ??
          data['phone']?.toString() ??
          '',
      houseFlatNo: data['houseFlatNo']?.toString() ??
          data['flatNo']?.toString() ??
          data['houseNo']?.toString() ??
          data['addressLine']?.toString() ??
          '',
      street: data['street']?.toString() ?? '',
      area: data['area']?.toString() ?? data['city']?.toString() ?? '',
      pincode: (data['pincode'] ?? data['pinCode'] ?? data['postalCode'] ?? '')
          .toString()
          .trim(),
      landmark: data['landmark']?.toString() ?? '',
      deliveryInstructions: data['deliveryInstructions']?.toString() ??
          data['instructions']?.toString() ??
          '',
      label: data['label']?.toString() ?? 'Home',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 17.4442,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 78.3845,
      isDefault: data['isDefault'] == true,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'houseFlatNo': houseFlatNo,
      'street': street,
      'area': area,
      'pincode': pincode,
      'postalCode': pincode,
      'landmark': landmark,
      'deliveryInstructions': deliveryInstructions,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'formattedAddress': formattedAddress,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AddressModel copyWith({
    String? id,
    String? userId,
    String? receiverName,
    String? receiverPhone,
    String? houseFlatNo,
    String? street,
    String? area,
    String? pincode,
    String? landmark,
    String? deliveryInstructions,
    String? label,
    double? latitude,
    double? longitude,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      houseFlatNo: houseFlatNo ?? this.houseFlatNo,
      street: street ?? this.street,
      area: area ?? this.area,
      pincode: pincode ?? this.pincode,
      landmark: landmark ?? this.landmark,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

