const fs = require('fs');
['frontend/lib/main.dart', 'frontend/lib/main_superadmin.dart'].forEach(file => {
  if (fs.existsSync(file)) {
    let text = fs.readFileSync(file, 'utf8');
    text = text.replace(/GoogleFonts\.config\.allowRuntimeFetching\s*=\s*false;/g, '// GoogleFonts.config.allowRuntimeFetching = false;');
    fs.writeFileSync(file, text, 'utf8');
    console.log('Fixed', file);
  }
});
