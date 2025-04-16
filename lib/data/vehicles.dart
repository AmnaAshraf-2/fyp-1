// lib/data/vehicle_list.dart

class Vehicle {
  final String name;
  final String capacity;
  //final String image;

  Vehicle({
    required this.name,
    required this.capacity,
  }); //required this.image});
}

final List<Vehicle> vehicleList = [
  Vehicle(
    name: 'Suzuki Pickup',
    capacity: 'Up to 800kg',
    //image: 'assets/images/suzuki.png',
  ),
  Vehicle(
    name: 'Shehzore',
    capacity: 'Up to 1200kg',
    //image: 'assets/images/shehzore.png',
  ),
  Vehicle(
    name: 'Mazda Truck',
    capacity: 'Up to 2000kg',
    //image: 'assets/images/mazda.png',
  ),
  Vehicle(
    name: 'Trailer',
    capacity: 'Up to 20,000kg',
    //image: 'assets/images/trailer.png',
  ),
];
