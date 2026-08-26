import os

file = "frontend/pubspec.yaml"
with open(file, "r", encoding="utf-8") as f:
    lines = f.readlines()

with open(file, "w", encoding="utf-8") as f:
    for line in lines:
        if "google_maps_flutter:" not in line:
            f.write(line)

print("Removed google_maps_flutter from pubspec.yaml")
