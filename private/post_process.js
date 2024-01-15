const fs = require('fs');

process.argv.slice(2).forEach((file) => {
  file = file.replace('../', 'external/');
  if (!fs.existsSync(file)) {
    fs.writeFileSync(file, '', 'utf8');
    fs.writeFileSync(file.replace('.js', '.d.ts'), '', 'utf8');
  }
});
