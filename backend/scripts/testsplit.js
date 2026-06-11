const fs = require('fs');
const path = require('path');
const sql = fs.readFileSync(path.join(__dirname, 'init-db.sql'), 'utf8');
function splitSqlStatements(sql) {
  const statements = [];
  let current = '';
  let i = 0;
  while (i < sql.length) {
    const char = sql[i];
    const next = sql[i + 1] || '';
    if (char === '$' && next === '$') {
      const end = sql.indexOf('$$', i + 2);
      if (end === -1) {
        current += sql.slice(i);
        break;
      }
      current += sql.slice(i, end + 2);
      i = end + 2;
      continue;
    }
    if (char === ';') {
      const trimmed = current.trim();
      if (trimmed) statements.push(trimmed);
      current = '';
      i += 1;
      continue;
    }
    current += char;
    i += 1;
  }
  const trailing = current.trim();
  if (trailing) statements.push(trailing);
  return statements;
}
const statements = splitSqlStatements(sql);
console.log('count', statements.length);
const f = statements.find((s) => s.includes('CREATE OR REPLACE FUNCTION update_property_rating'));
console.log('functionLen', f.length);
console.log('contains end', f.includes('END;'));
console.log('first 200', f.slice(0, 200));
console.log('last 200', f.slice(-200));
