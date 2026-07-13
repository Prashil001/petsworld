import 'package:flutter/foundation.dart';

@immutable
class DeliverySettingsModel {
  const DeliverySettingsModel({
    this.freeDeliveryThreshold = 999,
    this.deliveryFee = 49,
    this.supportWhatsAppNumber = '',
  });

  final double freeDeliveryThreshold;
  final double deliveryFee;
  final String supportWhatsAppNumber;

  DeliverySettingsModel copyWith({
    double? freeDeliveryThreshold,
    double? deliveryFee,
    String? supportWhatsAppNumber,
  }) {
    return DeliverySettingsModel(
      freeDeliveryThreshold:
          freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      supportWhatsAppNumber:
          supportWhatsAppNumber ?? this.supportWhatsAppNumber,
    );
  }

  factory DeliverySettingsModel.fromMap(Map<String, dynamic> data) {
    final parsedThreshold = (data['freeDeliveryThreshold'] as num?)?.toDouble();
    final parsedFee = (data['deliveryFee'] as num?)?.toDouble();
    return DeliverySettingsModel(
      freeDeliveryThreshold: parsedThreshold == null || parsedThreshold <= 0
          ? 999
          : parsedThreshold,
      deliveryFee: parsedFee == null || parsedFee <= 0 ? 49 : parsedFee,
      supportWhatsAppNumber: (data['supportWhatsAppNumber'] as String? ?? '')
          .trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'freeDeliveryThreshold': freeDeliveryThreshold,
      'deliveryFee': deliveryFee,
      'supportWhatsAppNumber': supportWhatsAppNumber.trim(),
    };
  }
}
