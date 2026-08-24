const fs = require('fs');

const pkgFile = 'backend/package.json';
let pkg = JSON.parse(fs.readFileSync(pkgFile, 'utf8'));

pkg.dependencies['redis'] = '^4.6.10';
pkg.dependencies['lru-cache'] = '^10.0.1';

fs.writeFileSync(pkgFile, JSON.stringify(pkg, null, 2), 'utf8');
console.log('Updated package.json');
