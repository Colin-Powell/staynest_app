const fs = require('fs');

function applyChanges(filePath, changes) {
  let text = fs.readFileSync(filePath, 'utf8');
  let updated = false;
  
  for (const {search, replace} of changes) {
    if (text.includes(search)) {
      text = text.replace(search, replace);
      updated = true;
    } else {
      console.log(`Could not find target in ${filePath}`);
    }
  }
  
  if (updated) {
    fs.writeFileSync(filePath, text, 'utf8');
    console.log(`Updated ${filePath}`);
  }
}

// Ensure the imports are used by replacing the whole files using a simpler regex approach for the bodies
