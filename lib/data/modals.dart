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

  CargoDetails({
    required this.loadName,
    required this.loadType,
    required this.weight,
    required this.weightUnit,
    required this.quantity,
    this.pickupTime,
    required this.offerFare,
    required this.isInsured,
  });
}