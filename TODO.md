- [ ] Add missing _HttpJsonClient implementation (or correct client usage) in frontend/lib/repository/remote_database_repository.dart
- [ ] Fix duplicate authenticate definitions by removing positional overload or merging call sites
- [ ] Fix auth/otp/register call-site parameter mismatches to match repository method signatures
- [ ] Fix repository authenticate/register/verifyPhoneCode overloads so call sites compile
- [ ] Resolve remaining void-return misuse errors
- [ ] Run `flutter analyze` (or `flutter test`) and iterate until clean build

