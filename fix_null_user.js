const fs = require('fs');
const file = 'frontend/lib/screens/super_admin/super_admin_login.dart';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  `final user = await repo.authenticate(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      AppSession.updateCurrentUser(user);`,
  `final user = await repo.authenticate(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (user == null) {
        throw Exception('Invalid credentials');
      }

      AppSession.updateCurrentUser(user);`
);

fs.writeFileSync(file, text, 'utf8');
console.log('Fixed null user check');
