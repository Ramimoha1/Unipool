import 'package:flutter/material.dart';
import 'package:unipool/features/carpool/screens/map_screen.dart';
import 'package:unipool/features/delivery/screens/delivery_home_screen.dart';
import 'package:unipool/features/profile/presentation/profile_screen.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});
  
  final int currentIndex;

  static const Color _teal = Color(0xFF1A9B8A);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: _teal,
      unselectedItemColor: const Color(0xFF8A96A3),
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
      unselectedLabelStyle: const TextStyle(fontSize: 11.5),
      backgroundColor: Colors.white,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Carpool'),
        BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Delivery'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile'),
      ],
      onTap: (index) {
        if (index == currentIndex) {
          return;
        }

        if (index == 0) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MapScreen()),
          );
          return;
        }

        if (index == 1) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DeliveryHomeScreen()),
          );
          return;
        }

        if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
          return;
        }
      },
    );
  }
}
