import re

with open('lib/screens/setting_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:flutter_svg/flutter_svg.dart';", "")

with open('lib/screens/setting_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
