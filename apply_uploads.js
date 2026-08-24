const fs = require('fs');

const file = 'frontend/lib/services/uploads.dart';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  `final uri = Uri.parse('$base/uploads');`,
  `final uri = Uri.parse('$base/uploads/async');` // Change both occurrences! Wait, regex is better.
);

fs.writeFileSync(file, text, 'utf8');
console.log('Done');
