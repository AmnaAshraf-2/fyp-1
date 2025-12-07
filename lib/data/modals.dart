import 'package:flutter/material.dart';

class CargoDetails {
  final String loadName;
  final String loadType;
  final double weight;
  final String weightUnit;
  final int quantity;
  final DateTime? pickupDate;
  final TimeOfDay? pickupTime;
  final double offerFare;
  final bool isInsured;
  final String vehicleType;
  final bool isEnterprise;
  final String senderPhone;
  final String receiverPhone;
  final String pickupLocation;
  final String destinationLocation;
  final String? audioNotePath; // Local file path for audio note (deprecated, use audioNoteUrl)
  final String? audioNoteUrl; // Firebase Storage URL for audio note

  CargoDetails({
    required this.loadName,
    required this.loadType,
    required this.weight,
    required this.weightUnit,
    required this.quantity,
    this.pickupDate,
    this.pickupTime,
    required this.offerFare,
    required this.isInsured,
    required this.vehicleType,
    this.isEnterprise = false,
    required this.senderPhone,
    required this.receiverPhone,
    required this.pickupLocation,
    required this.destinationLocation,
    this.audioNotePath,
    this.audioNoteUrl,
  });
}