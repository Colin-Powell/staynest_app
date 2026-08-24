const fs = require('fs');

const pkgFile = 'backend/package.json';
let pkg = JSON.parse(fs.readFileSync(pkgFile, 'utf8'));

pkg.dependencies['bullmq'] = '^5.7.8';
pkg.dependencies['sharp'] = '^0.33.4';
pkg.dependencies['fluent-ffmpeg'] = '^2.1.3';
pkg.devDependencies['@types/fluent-ffmpeg'] = '^2.1.24';

fs.writeFileSync(pkgFile, JSON.stringify(pkg, null, 2), 'utf8');
console.log('Updated package.json for workers');
