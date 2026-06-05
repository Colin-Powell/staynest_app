import 'package:flutter/material.dart';

class AmenityChip extends StatelessWidget {
  final String name;

  const AmenityChip({super.key, required this.name});

  IconData get icon {
    switch (name.toLowerCase()) {
      case 'wifi':
        return Icons.wifi;
      case 'water':
        return Icons.opacity;
      case 'parking':
        return Icons.local_parking;
      case 'security':
        return Icons.shield;
      default:
        return Icons.star_border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }
}
