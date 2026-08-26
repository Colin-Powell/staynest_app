import re

with open('lib/services/uploads.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace uploadFile logic
old_upload = r'''    static Future<String> uploadFile\(File file, \{String\? token, String\? idempotencyKey\}\) async \{
      final base = AppSession.apiBaseUrl;
      final uri = Uri.parse\('\/uploads'\);
      final request = http.MultipartRequest\('POST', uri\);
      if \(\(token \?\? AppSession.apiToken\) != null\) \{
        request.headers\['Authorization'\] = 'Bearer \$\{token \?\? AppSession.apiToken\}';
      \}
      if \(idempotencyKey != null\) \{
        request.headers\['Idempotency-Key'\] = idempotencyKey;
      \}
      final multipart = await http.MultipartFile.fromPath\('file', file.path\);
      request.files.add\(multipart\);

      final streamed = await request.send\(\);
      final response = await http.Response.fromStream\(streamed\);
      if \(response.statusCode < 200 \|\| response.statusCode >= 300\) \{
        throw Exception\('Upload failed: \$\{response.statusCode\} \$\{response.body\}'\);
      \}'''

new_upload = '''    static Future<String> uploadFile(File file, {String? token, String? idempotencyKey}) async {
      final base = AppSession.apiBaseUrl;
      final uri = Uri.parse('\/uploads');
      bool tokenRefreshed = false;
      
      while (true) {
        final request = http.MultipartRequest('POST', uri);
        if ((token ?? AppSession.apiToken) != null) {
          request.headers['Authorization'] = 'Bearer \';
        }
        if (idempotencyKey != null) {
          request.headers['Idempotency-Key'] = idempotencyKey;
        }
        final multipart = await http.MultipartFile.fromPath('file', file.path);
        request.files.add(multipart);

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);
        
        if (response.statusCode == 401 && !tokenRefreshed) {
          tokenRefreshed = true;
          try {
            await HttpJsonClient().refreshAccessTokenIfPossible();
            continue;
          } catch (_) {}
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Upload failed: \ \');
        }'''
content = re.sub(old_upload, new_upload, content, flags=re.MULTILINE)

with open('lib/services/uploads.dart', 'w', encoding='utf-8') as f:
    f.write(content)
