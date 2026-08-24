const fs = require('fs');
const file = 'backend/src/routes/admin.ts';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  /SELECT v.id, v.status, v.created_at, u.name, u.email\s+FROM verifications v/g,
  `SELECT v.id, v.status, v.created_at, v.documents, v.property_data, u.name, u.email\n         FROM verifications v`
);

fs.writeFileSync(file, text, 'utf8');
console.log('Fixed GET /kyc query in admin.ts');
