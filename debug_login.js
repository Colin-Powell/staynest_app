const fs = require('fs');
const file = 'frontend/lib/screens/super_admin/super_admin_login.dart';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  `} catch (e) {
      setState(() {
        _errorMessage = 'Invalid credentials or network error.';`,
  `} catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');`
);

fs.writeFileSync(file, text, 'utf8');
