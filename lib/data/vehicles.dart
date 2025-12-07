// lib/data/vehicle_list.dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Vehicle {
  final String nameKey;
  final String capacityKey;
  //final String image;

  Vehicle({
    required this.nameKey,
    required this.capacityKey,
  }); // required this.image});
  
  String getName(AppLocalizations loc) {
    switch (nameKey) {
      case 'pickupCarry': return loc.pickupCarry;
      case 'shehzore': return loc.shehzore;
      case 'mazdaTruckOpenBody': return loc.mazdaTruckOpenBody;
      case 'mazdaTruckCloseBody': return loc.mazdaTruckCloseBody;
      case 'vehicleCarrier': return loc.vehicleCarrier;
      case 'containerTruck20ft': return loc.containerTruck20ft;
      case 'containerTruck40ft': return loc.containerTruck40ft;
      //case 'oilTanker': return loc.oilTanker;
      case 'reeferCarrier': return loc.reeferCarrier;
      case 'reeferCarrierLarge': return loc.reeferCarrierLarge;
      case 'miniLoaderRickshaw': return loc.miniLoaderRickshaw;
      case 'flatbedTruck': return loc.flatbedTruck;
      case 'dumper': return loc.dumper;
      default: return nameKey;
    }
  }
  
  String getCapacity(AppLocalizations loc) {
    switch (capacityKey) {
      case 'pickupCarryCapacity': return loc.pickupCarryCapacity;
      case 'shehzoreCapacity': return loc.shehzoreCapacity;
      case 'mazdaTruckOpenBodyCapacity': return loc.mazdaTruckOpenBodyCapacity;
      case 'mazdaTruckCloseBodyCapacity': return loc.mazdaTruckCloseBodyCapacity;
      case 'vehicleCarrierCapacity': return loc.vehicleCarrierCapacity;
      case 'containerTruck20ftCapacity': return loc.containerTruck20ftCapacity;
      case 'containerTruck40ftCapacity': return loc.containerTruck40ftCapacity;
      //case 'oilTankerCapacity': return loc.oilTankerCapacity;
      case 'reeferCarrierCapacity': return loc.reeferCarrierCapacity;
      case 'reeferCarrierLargeCapacity': return loc.reeferCarrierLargeCapacity;
      case 'miniLoaderRickshawCapacity': return loc.miniLoaderRickshawCapacity;
      case 'flatbedTruckCapacity1': return loc.flatbedTruckCapacity1;
      case 'flatbedTruckCapacity2': return loc.flatbedTruckCapacity2;
      case 'flatbedTruckCapacity3': return loc.flatbedTruckCapacity3;
      case 'flatbedTruckCapacity4': return loc.flatbedTruckCapacity4;
      case 'dumperCapacity': return loc.dumperCapacity;
      default: return capacityKey;
    }
  }
}

final List<Vehicle> vehicleList = [
  Vehicle(
    nameKey: 'pickupCarry',
    capacityKey: 'pickupCarryCapacity',
    //image: 'assets/images/suzuki.png',
  ),
  Vehicle(
    nameKey: 'shehzore',
    capacityKey: 'shehzoreCapacity',
    //image: 'assets/images/shehzore.png',
  ),
  Vehicle(
    nameKey: 'mazdaTruckOpenBody',
    capacityKey: 'mazdaTruckOpenBodyCapacity',
    //image: 'assets/images/mazda.png',
  ),
  Vehicle(
    nameKey: 'mazdaTruckCloseBody',
    capacityKey: 'mazdaTruckCloseBodyCapacity',
    //image: 'assets/images/mazda.png',
  ),
 
  Vehicle(
    nameKey: 'vehicleCarrier',
    capacityKey: 'vehicleCarrierCapacity',
    //image: 'assets/images/daewoo_truck.png',
  ),
  Vehicle(
    nameKey: 'containerTruck20ft',
    capacityKey: 'containerTruck20ftCapacity',
    //image: 'assets/images/container_20ft.png',
  ),
  Vehicle(
    nameKey: 'containerTruck40ft',
    capacityKey: 'containerTruck40ftCapacity',
    //image: 'assets/images/container_40ft.png',
  ),
  // Vehicle(
  //   nameKey: 'oilTanker',
  //   capacityKey: 'oilTankerCapacity',
  //   //image: 'assets/images/oil_tanker.png',
  // ),
  
  Vehicle(
    nameKey: 'reeferCarrier',
    capacityKey: 'reeferCarrierCapacity',
    //image: 'assets/images/refrigerated_truck.png',
  ),
   Vehicle(
    nameKey: 'reeferCarrierLarge',
    capacityKey: 'reeferCarrierLargeCapacity',
    //image: 'assets/images/refrigerated_truck.png',
  ),
  Vehicle(
    nameKey: 'miniLoaderRickshaw',
    capacityKey: 'miniLoaderRickshawCapacity',
    //image: 'assets/images/loader_rickshaw.png',
  ),
  
  Vehicle(
    nameKey: 'flatbedTruck',
    capacityKey: 'flatbedTruckCapacity1',
    //image: 'assets/images/flatbed.png',
  ),
  Vehicle(
    nameKey: 'flatbedTruck',
    capacityKey: 'flatbedTruckCapacity2',
    //image: 'assets/images/flatbed.png',
  ),
  Vehicle(
    nameKey: 'flatbedTruck',
    capacityKey: 'flatbedTruckCapacity3',
    //image: 'assets/images/flatbed.png',
  ),
  Vehicle(
    nameKey: 'flatbedTruck',
    capacityKey: 'flatbedTruckCapacity4',
    //image: 'assets/images/flatbed.png',
  ),
  Vehicle(
    nameKey: 'dumper',
    capacityKey: 'dumperCapacity',
    //image: 'assets/images/flatbed.png',
  ),
  Vehicle(
    nameKey: 'Bulan',
    capacityKey: 'trailerCapacity',
    //image: 'assets/images/trailer.png',
  ),
];
