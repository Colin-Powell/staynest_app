import os

file = "frontend/lib/screens/property/property_details.dart"
with open(file, "r", encoding="utf-8") as f:
    lines = f.readlines()

with open(file, "w", encoding="utf-8") as f:
    for line in lines:
        if "package:google_maps_flutter/google_maps_flutter.dart" not in line:
            f.write(line)

print("Removed google_maps_flutter import from property_details.dart")
