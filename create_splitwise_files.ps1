$projectRoot = (Get-Location).Path

# files and contents
$files = @{
    "lib/main.dart" = @"
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:splitwise_clone/services/expense_service.dart';
import 'package:splitwise_clone/ui/home_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseService(),
      child: MaterialApp(
        title: 'Splitwise Lite',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const HomePage(),
      ),
    );
  }
}
"@

    "lib/models/models.dart" = @"
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  UserModel({required this.id, required this.name});
  Map<String, dynamic> toMap() => {'name': name};
  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(id: doc.id, name: d['name'] ?? '');
  }
}

class ExpenseShare {
  final String userId;
  final double due;
  final double paid;
  ExpenseShare({required this.userId, required this.due, required this.paid});

  Map<String, dynamic> toMap() => {'due': due, 'paid': paid};
  factory ExpenseShare.fromMap(String id, Map<String, dynamic> m) => ExpenseShare(
      userId: id,
      due: (m['due'] as num).toDouble(),
      paid: (m['paid'] as num).toDouble());
}

class ExpenseModel {
  final String id;
  final double total;
  final String payerId;
  final String note;
  final List<String> participants;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.total,
    required this.payerId,
    required this.note,
    required this.participants,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'total': total,
        'payerId': payerId,
        'note': note,
        'participants': participants,
        'createdAt': createdAt,
      };

  factory ExpenseModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      total: (d['total'] as num).toDouble(),
      payerId: d['payerId'] as String,
      note: d['note'] as String? ?? '',
      participants: List<String>.from(d['participants'] ?? []),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }
}
"@

    "lib/services/expense_service.dart" = @"
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:splitwise_clone/models/models.dart';
import 'package:uuid/uuid.dart';

class ExpenseService extends ChangeNotifier {
  final _fire = FirebaseFirestore.instance;
  final String currentUserId = 'A'; // Replace with auth uid after login
  List<ExpenseModel> expenses = [];
  Map<String, double> netBalance = {};

  ExpenseService() {
    loadUsers();
    loadExpenses();
  }

  List<UserModel> users = [];

  Future<void> loadUsers() async {
    final snap = await _fire.collection('users').get();
    users = snap.docs.map((d) => UserModel.fromDoc(d)).toList();
    if (!users.any((u) => u.id == 'A')) {
      await _fire.collection('users').doc('A').set({'name': 'A'});
      await _fire.collection('users').doc('B').set({'name': 'B'});
      await _fire.collection('users').doc('C').set({'name': 'C'});
      return loadUsers();
    }
    notifyListeners();
  }

  Future<void> loadExpenses() async {
    final snap = await _fire.collection('expenses')
      .where('participants', arrayContains: currentUserId)
      .orderBy('createdAt', descending: true)
      .get();
    expenses = snap.docs.map((d) => ExpenseModel.fromDoc(d)).toList();
    await _recalcNet();
    notifyListeners();
  }

  Future<void> addExpense({
    required double total,
    required String payerId,
    required List<String> participants,
    required String note,
  }) async {
    if (total <= 0) throw Exception('Amount must be > 0');
    if (!participants.contains(payerId)) participants.add(payerId);
    if (participants.length < 2) throw Exception('Need at least two participants');
    final perShare = (total / participants.length);
    final splits = List<double>.filled(participants.length, perShare);
    final roundedTotal = splits.fold<double>(0, (p, e) => p + e);
    final delta = total - roundedTotal;
    splits[splits.length - 1] += delta;

    final docRef = _fire.collection('expenses').doc();
    await docRef.set({
      'total': total,
      'payerId': payerId,
      'note': note,
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (var i = 0; i < participants.length; i++) {
      var userId = participants[i];
      final due = splits[i];
      final paid = (userId == payerId ? due : 0.0);
      await docRef.collection('shares').doc(userId).set({'due': due, 'paid': paid});
    }
    await loadExpenses();
  }

  Future<void> settleShare({
    required String expenseId,
    required String userId,
    required double amount,
  }) async {
    if (amount <= 0) throw Exception('Invalid amount');
    final shareRef = _fire.collection('expenses').doc(expenseId).collection('shares').doc(userId);
    final snap = await shareRef.get();
    if (!snap.exists) throw Exception('No share found');
    final map = snap.data()!;
    final due = (map['due'] as num).toDouble();
    final paid = (map['paid'] as num).toDouble();
    if (paid + amount > due) throw Exception('Paid amount would exceed due');
    await shareRef.update({'paid': paid + amount});
    await loadExpenses();
  }

  Future<void> _recalcNet() async {
    netBalance = {};
    for (var exp in expenses) {
      final sharesSnap = await _fire.collection('expenses').doc(exp.id).collection('shares').get();
      final payer = exp.payerId;
      final shareMap = {
        for (var d in sharesSnap.docs)
          d.id: ExpenseShare.fromMap(d.id, d.data())
      };
      for (var u in exp.participants) {
        final userShare = shareMap[u]!;
        if (u == currentUserId) continue;
        if (payer == currentUserId) {
          netBalance[u] = (netBalance[u] ?? 0) + (userShare.due - userShare.paid);
        } else if (u == currentUserId) {
          netBalance[payer] = (netBalance[payer] ?? 0) - (userShare.due - userShare.paid);
        }
      }
    }
    netBalance.removeWhere((k,v) => v.abs() < 0.005);
  }

  Map<String, double> get pieData {
    return netBalance.map((k, v) => MapEntry(k, v > 0 ? v : 0.0));
  }
}
"@

    "lib/ui/home_page.dart" = @"
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise_clone/services/expense_service.dart';
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tabIndex = 0;
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final selectedUsers = <String>{};
  String payer = 'A';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ExpenseService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Splitwise Lite (Firebase)'),
        actions: [
          TextButton(onPressed: () => setState(() => tabIndex = 0), child: const Text('Dashboard', style: TextStyle(color: Colors.white))),
          TextButton(onPressed: () => setState(() => tabIndex = 1), child: const Text('Add Expense', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: tabIndex == 0 ? _dashboard(s) : _addExpense(s),
    );
  }

  Widget _dashboard(ExpenseService s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Balances', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ...s.netBalance.entries.map((e) {
          final text = e.value > 0 ? '${e.key} owes you ₹${e.value.toStringAsFixed(2)}' : 'You owe ${e.key} ₹${e.value.abs().toStringAsFixed(2)}';
          return Text(text);
        }).toList(),
        const SizedBox(height: 12),
        if (s.pieData.values.any((v) => v > 0))
          SizedBox(height: 250, child: PieChart(PieChartData(
            sections: s.pieData.entries.where((e) => e.value > 0).map((e) {
              final idx = s.pieData.keys.toList().indexOf(e.key);
              return PieChartSectionData(
                color: Colors.primaries[idx % Colors.primaries.length],
                value: e.value,
                title: '${e.key} (${e.value.toStringAsFixed(0)})',
                radius: 56,
              );
            }).toList(),
          ))),
        const SizedBox(height: 20),
        const Text('Expenses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ...s.expenses.map((exp) => Card(
          child: ListTile(
            title: Text('₹${exp.total.toStringAsFixed(2)} — ${exp.note}'),
            subtitle: Text('payer: ${exp.payerId}, participants: ${exp.participants.join(", ")}'),
          ),
        )).toList(),
      ]),
    );
  }

  Widget _addExpense(ExpenseService s) {
    payer = payer.isEmpty ? (s.users.isNotEmpty ? s.users.first.id : 'A') : payer;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
        const SizedBox(height: 10),
        TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note / message')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: payer,
          items: s.users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
          onChanged: (v) { if (v != null) setState(() => payer = v); },
          decoration: const InputDecoration(labelText: 'Payer'),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: s.users.map((u) {
          return FilterChip(
            label: Text(u.name),
            selected: selectedUsers.contains(u.id),
            onSelected: (val) { setState(() { if (val) selectedUsers.add(u.id); else selectedUsers.remove(u.id); }); },
          );
        }).toList()),
        const SizedBox(height: 14),
        ElevatedButton(onPressed: () async {
          try {
            final total = double.tryParse(amountCtrl.text) ?? 0;
            final participants = selectedUsers.toList();
            if (!participants.contains(payer)) participants.add(payer);
            await s.addExpense(total: total, payerId: payer, participants: participants, note: noteCtrl.text);
            amountCtrl.clear(); noteCtrl.clear(); selectedUsers.clear();
            setState(() => tabIndex = 0);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }, child: const Text('Save Expense')),
      ]),
    );
  }
}
"@
}

# create folders and files
$files.Keys | ForEach-Object {
    $path = Join-Path $projectRoot $_
    $dir = Split-Path $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $files[$_] | Out-File -FilePath $path -Encoding utf8
    Write-Host "Created $path"
}

Write-Host "Done. Update pubspec.yaml with firebase + provider + fl_chart + uuid, run flutter pub get."
Write-Host "Then run: flutter run -d chrome"