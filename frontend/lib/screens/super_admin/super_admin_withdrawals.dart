import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/services/super_admin_service.dart';

class SuperAdminWithdrawalsPage extends StatefulWidget {
  const SuperAdminWithdrawalsPage({super.key});

  @override
  State<SuperAdminWithdrawalsPage> createState() =>
      _SuperAdminWithdrawalsPageState();
}

class _SuperAdminWithdrawalsPageState extends State<SuperAdminWithdrawalsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SuperAdminService.fetchWithdrawals();
      if (mounted)
        setState(() {
          _rows = rows;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> row) async {
    await SuperAdminService.approveWithdrawal(row['id'].toString());
    await _load();
  }

  Future<void> _release(Map<String, dynamic> row) async {
    await SuperAdminService.releaseWithdrawal(row['id'].toString());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text('Withdrawal Requests',
              style:
                  GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
              'Review identity, amount, destination, and release status before sending funds.',
              style: GoogleFonts.inter(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_rows.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No pending withdrawal requests.')))
          else
            ..._rows.map((row) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row['user_name']?.toString() ?? 'Unknown user',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                          Text(row['user_email']?.toString() ?? ''),
                          const SizedBox(height: 10),
                          Text('Amount: KSh ${row['amount']}'),
                          Text(
                              'Destination: ${row['destination_account']} (${row['destination_type']})'),
                          Text('Status: ${row['status']}'),
                          const SizedBox(height: 12),
                          Row(children: [
                            if (row['status'] == 'pending')
                              FilledButton(
                                  onPressed: () => _approve(row),
                                  child: const Text('Approve')),
                            if (row['status'] == 'approved')
                              FilledButton(
                                  onPressed: () => _release(row),
                                  child: const Text('Release to M-Pesa')),
                          ]),
                        ]),
                  ),
                )),
        ],
      ),
    );
  }
}
