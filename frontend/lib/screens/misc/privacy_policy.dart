import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/repository/remote_database_repository.dart';

class PrivacyPolicyView extends StatefulWidget {
  const PrivacyPolicyView({super.key});

  @override
  State<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends State<PrivacyPolicyView> {
  String _policy = '';
  bool _loading = true;
  final _repo = RemoteDatabaseRepository();

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    setState(() => _loading = true);
    try {
      final res = await _repo.getPrivacyPolicy();
      if (!mounted) return;
      // The _decodeData method already extracts 'data' if present,
      // so 'res' should directly contain the policy map or an empty map.
      final payload = res;
      setState(() => _policy = payload is Map && payload['policy'] != null
          ? payload['policy'].toString()
          : payload.toString());
    } catch (_) {
      if (mounted) setState(() => _policy = 'Unable to load policy.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _requestDeletion() async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request Data Deletion'),
        content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(hintText: 'Optional reason')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit')),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;
    try {
      final res =
          await _repo.requestDataDeletion(reason: reasonController.text);
      if (!mounted) return;
      final payload = res;
      if (payload is Map && payload['id'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deletion request submitted.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to submit deletion request.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit deletion request.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Data Policy')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: SingleChildScrollView(
                          child: Text(_policy,
                              style: GoogleFonts.poppins(fontSize: 14)))),
                  const SizedBox(height: 12),
                  Text(
                      'Data Retention: We will keep personal data until it is requested to be deleted or for legal/business requirements.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: _requestDeletion,
                          child: const Text('Request Data Deletion'))),
                ],
              ),
            ),
    );
  }
}
