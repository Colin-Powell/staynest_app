import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_app/services/wallet_api.dart';

class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  late Future<List<Object>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<List<Object>> _load() async {
    final wallet = await WalletApi.getWallet();
    final transactions = await WalletApi.getTransactions();
    return [wallet, transactions];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: FutureBuilder<List<Object>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load wallet: ${snapshot.error}'));
          }
          final wallet = snapshot.data![0] as Map<String, dynamic>;
          final transactions = snapshot.data![1] as List<Map<String, dynamic>>;
          final balance =
              double.tryParse(wallet['wallet_balance'].toString()) ?? 0;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _loadFuture = _load()),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available balance'),
                        const SizedBox(height: 8),
                        Text('KES ${balance.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Transactions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('No wallet transactions yet.'),
                  ),
                ...transactions.map((transaction) => ListTile(
                      title: Text(transaction['description']?.toString() ??
                          transaction['type'].toString()),
                      subtitle: Text(DateFormat.yMMMd().add_jm().format(
                          DateTime.parse(transaction['created_at'].toString())
                              .toLocal())),
                      trailing: Text('+ KES ${transaction['amount']}'),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}
