const fs = require('fs');

const file = 'frontend/lib/screens/super_admin/super_admin_login.dart';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  `import 'package:property_app/services/auth_service.dart';`,
  `import 'package:property_app/repository/remote_database_repository.dart';`
);

const oldLogin = `await AuthService.instance.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (AppSession.currentRole.toLowerCase() != 'admin') {`;

const newLogin = `final repo = RemoteDatabaseRepository();
      final user = await repo.authenticate(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      AppSession.updateCurrentUser(user);
      AppSession.apiToken = user['token']?.toString() ?? user['accessToken']?.toString() ?? AppSession.apiToken;
      AppSession.refreshToken = user['refreshToken']?.toString() ?? AppSession.refreshToken;
      await AppSession.persistSession();

      if (AppSession.currentRole.toLowerCase() != 'admin') {`;

text = text.replace(oldLogin, newLogin);
fs.writeFileSync(file, text, 'utf8');
console.log('Fixed super_admin_login.dart');
