import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class DeliveryJobModel {
  const DeliveryJobModel({
    required this.id,
    required this.createdBy,
    required this.sellerId,
    required this.title,
    required this.pickupLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryStops,
    required this.deliveryTime,
    required this.items,
    required this.quantity,
    required this.price,
    required this.allowedDrivers,
    required this.jobStatus,
    required this.assignedDriverId,
    required this.sellerApprovedDriverId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String createdBy;
  final String sellerId;
  final String title;
  final String pickupLabel;
  final double pickupLat;
  final double pickupLng;
  final List<Map<String, dynamic>> deliveryStops;
  final DateTime deliveryTime;
  final List<Map<String, dynamic>> items;
  final int quantity;
  final double price;
  final String allowedDrivers;
  final String jobStatus;
  final String assignedDriverId;
  final String sellerApprovedDriverId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DeliveryJobModel.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryJobModel(
      id: id,
      createdBy: map[AppFields.creatorId] as String? ?? '',
      sellerId: map[AppFields.sellerId] as String? ?? '',
      title: map[AppFields.title] as String? ?? '',
      pickupLabel: map[AppFields.pickupLabel] as String? ?? '',
      pickupLat: (map[AppFields.pickupLat] as num?)?.toDouble() ?? 0,
      pickupLng: (map[AppFields.pickupLng] as num?)?.toDouble() ?? 0,
      deliveryStops: (map[AppFields.deliveryStops] as List<dynamic>? ?? const [])
          .map((stop) => Map<String, dynamic>.from(stop as Map))
          .toList(),
      deliveryTime:
          (map[AppFields.deliveryTime] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (map[AppFields.items] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      quantity: (map[AppFields.quantity] as num?)?.toInt() ?? 0,
      price: (map[AppFields.price] as num?)?.toDouble() ?? 0,
      allowedDrivers: map[AppFields.allowedDrivers] as String? ??
          DeliveryAllowedDrivers.verifiedOnly,
      jobStatus:
          map[AppFields.jobStatus] as String? ?? DeliveryJobStatuses.open,
      assignedDriverId: map[AppFields.assignedDriverId] as String? ?? '',
      sellerApprovedDriverId:
          map[AppFields.sellerApprovedDriverId] as String? ?? '',
      createdAt:
          (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (map[AppFields.updatedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.creatorId: createdBy,
      AppFields.sellerId: sellerId,
      AppFields.title: title,
      AppFields.pickupLabel: pickupLabel,
      AppFields.pickupLat: pickupLat,
      AppFields.pickupLng: pickupLng,
      AppFields.deliveryStops: deliveryStops,
      AppFields.deliveryTime: Timestamp.fromDate(deliveryTime),
      AppFields.items: items,
      AppFields.quantity: quantity,
      AppFields.price: price,
      AppFields.allowedDrivers: allowedDrivers,
      AppFields.jobStatus: jobStatus,
      AppFields.assignedDriverId: assignedDriverId,
      AppFields.sellerApprovedDriverId: sellerApprovedDriverId,
      AppFields.createdAt: Timestamp.fromDate(createdAt),
      AppFields.updatedAt: Timestamp.fromDate(updatedAt),
    };
  }

  DeliveryJobModel copyWith({
    String? id,
    String? createdBy,
    String? sellerId,
    String? title,
    String? pickupLabel,
    double? pickupLat,
    double? pickupLng,
    List<Map<String, dynamic>>? deliveryStops,
    DateTime? deliveryTime,
    List<Map<String, dynamic>>? items,
    int? quantity,
    double? price,
    String? allowedDrivers,
    String? jobStatus,
    String? assignedDriverId,
    String? sellerApprovedDriverId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryJobModel(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      pickupLabel: pickupLabel ?? this.pickupLabel,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      deliveryStops: deliveryStops ?? this.deliveryStops,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      items: items ?? this.items,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      allowedDrivers: allowedDrivers ?? this.allowedDrivers,
      jobStatus: jobStatus ?? this.jobStatus,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      sellerApprovedDriverId:
          sellerApprovedDriverId ?? this.sellerApprovedDriverId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
