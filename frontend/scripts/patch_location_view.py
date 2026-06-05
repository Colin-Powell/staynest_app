from pathlib import Path

path = Path(r'c:\Users\koder\Desktop\staynest\flutter_frontend\lib\screens\property\location_view.dart')
text = path.read_text(encoding='utf-8')

replacements = [
    (
        "  @override\n  Widget build(BuildContext context) {\n    final location = _currentLocation ?? _fallbackLocation;\n\n    return Scaffold(\n      backgroundColor: Colors.white,\n",
        "  @override\n  Widget build(BuildContext context) {\n    final currentLocation = _currentLocation;\n    final propertyLocation = selectedProperty != null\n        ? LatLng(selectedProperty!.lat, selectedProperty!.lng)\n        : null;\n    final location = currentLocation ?? propertyLocation ?? _fallbackLocation;\n\n    return Scaffold(\n      backgroundColor: Colors.white,\n",
    ),
    (
        "                            TileLayer(\n                              urlTemplate:\n                                  'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png',\n                              userAgentPackageName: 'com.example.rental_app',\n                            ),\n",
        "                            TileLayer(\n                              urlTemplate:\n                                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',\n                              subdomains: const ['a', 'b', 'c'],\n                              userAgentPackageName: 'com.example.property_app',\n                            ),\n",
    ),
    (
        "                                                            Text(\n                                                                'Ksh.\x00\"+prop.price.toString()+\"/month',\n                                                                style: const TextStyle(\n                                                                    fontWeight:\n                                                                        FontWeight\n                                                                            .w900)),\n",
        "                                                            Text(\n                                                                'Ksh. ${prop.price}/month',\n                                                                style: const TextStyle(\n                                                                    fontWeight:\n                                                                        FontWeight\n                                                                            .w900)),\n",
    ),
    (
        "                                                            final originParam =\n                                                                origin != null\n                                                                    ? '\\${origin.latitude},\\\\${origin.longitude}'\n                                                                    : '';\n                                                            final destParam =\n                                                                '\\$destLat,\\$destLng';\n                                                            final url = Uri.parse(\n                                                                'https://www.google.com/maps/dir/?api=1&origin=\\$originParam&destination=\\$destParam&travelmode=driving');\n",
        "                                                            final originParam =\n                                                                origin != null\n                                                                    ? '${origin.latitude},${origin.longitude}'\n                                                                    : '';\n                                                            final destParam =\n                                                                '$destLat,$destLng';\n                                                            final url = Uri.parse(\n                                                                'https://www.google.com/maps/dir/?api=1&origin=$originParam&destination=$destParam&travelmode=driving');\n",
    ),
    (
        "                              Text(\n                                _currentLocation != null\n                                    ? 'Current location'\n                                    : 'Location',\n                                style: const TextStyle(\n                                  fontSize: 22,\n                                  fontWeight: FontWeight.w800,\n                                  color: Colors.black,\n                                ),\n                              ),\n                              const SizedBox(height: 6),\n                              Text(\n                                _currentLocation != null\n                                    ? (_currentAddress ??\n                                        'Fetching current address...')\n                                    : '1.2 km From Kilifi Town',\n                                style: const TextStyle(\n                                  fontSize: 15,\n                                  color: Color(0xFF6B7280),\n                                  fontWeight: FontWeight.w500,\n                                ),\n                              ),\n",
        "                              Text(\n                                _locationTitle,\n                                style: const TextStyle(\n                                  fontSize: 22,\n                                  fontWeight: FontWeight.w800,\n                                  color: Colors.black,\n                                ),\n                              ),\n                              const SizedBox(height: 6),\n                              Text(\n                                _locationSubtitle,\n                                style: const TextStyle(\n                                  fontSize: 15,\n                                  color: Color(0xFF6B7280),\n                                  fontWeight: FontWeight.w500,\n                                ),\n                              ),\n",
    ),
]

for old, new in replacements:
    if old not in text:
        print('MISSING_PATTERN:')
        print(old)
        raise SystemExit('Missing expected pattern')
    text = text.replace(old, new)

# Now replace markers block maybe by a simpler pattern around property markers and current location marker.
old_markers = """                              markers: [\n                                // Property markers from dataset\n                                ...properties.map((prop) {\n                                  return Marker(\n                                    point: LatLng(prop.lat, prop.lng),\n                                    width: 160,\n                                    height: 48,\n                                    child: GestureDetector(\n                                      onTap: () {\n"""
# We'll not replace entire block yet to avoid mismatch. Instead fix smaller issues above.

path.write_text(text, encoding='utf-8')
print('patched parts')
