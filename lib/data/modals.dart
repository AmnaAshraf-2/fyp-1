import 'package:flutter/material.dart';

class CargoDetails {
  final String loadName;
  final String loadType;
  final double weight;
  final String weightUnit;
  final int quantity;
  final TimeOfDay? pickupTime;
  final double offerFare;
  final bool isInsured;
  final String vehicleType;
  final bool isEnterprise;
  final String senderPhone;
  final String receiverPhone;
  final String pickupLocation;
  final String destinationLocation;

  CargoDetails({
    required this.loadName,
    required this.loadType,
    required this.weight,
    required this.weightUnit,
    required this.quantity,
    this.pickupTime,
    required this.offerFare,
    required this.isInsured,
    required this.vehicleType,
    this.isEnterprise = false,
    required this.senderPhone,
    required this.receiverPhone,
    required this.pickupLocation,
    required this.destinationLocation,
  });
}