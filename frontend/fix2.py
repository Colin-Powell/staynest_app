with open('lib/services/uploads.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

lines[163] = "               throw Exception('Background processing failed: ');\n"

with open('lib/services/uploads.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)
