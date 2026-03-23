import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise_clone/services/expense_service.dart';
import 'package:splitwise_clone/models/models.dart';
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int tabIndex = 0;
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final messageCtrl = TextEditingController();
  final newUserIdCtrl = TextEditingController();
  final newUserNameCtrl = TextEditingController();
  final paymentAmountCtrl = TextEditingController();
  
  final selectedUsers = <String>{};
  final Map<String, TextEditingController> splitControllers = {};
  String payer = 'A';
  String currentUser = 'A';
  String selectedToUser = 'B';
  

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    messageCtrl.dispose();
    newUserIdCtrl.dispose();
    newUserNameCtrl.dispose();
    paymentAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ExpenseService>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Splitwise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.deepPurple.shade700, Colors.purple.shade600], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (index) => setState(() => tabIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple.shade700,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_rounded), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.payment_rounded), label: 'Settle'),
          BottomNavigationBarItem(icon: Icon(Icons.message_rounded), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Users'),
        ],
      ),
      body: [
        _dashboardTab(s),
        _addExpenseTab(s),
        _settlePaymentTab(s),
        _messagesTab(s),
        _usersTab(s),
      ][tabIndex],
    );
  }

  // === DASHBOARD TAB ===
  Widget _dashboardTab(ExpenseService s) {
    // Calculate balances from current user's perspective
    final currentUserBalances = _calculateCurrentUserBalances(s);
    final balanceCards = currentUserBalances.entries.where((e) => e.value.abs() > 0.005).toList();

    final totalOwedToYou = balanceCards.where((e) => e.value > 0).fold<double>(0, (sum, e) => sum + e.value);
    final totalYouOwe = balanceCards.where((e) => e.value < 0).fold<double>(0, (sum, e) => sum + e.value.abs());
    final totalExpenses = s.expenses.fold<double>(0, (sum, e) => sum + e.total);

    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey.shade50, Colors.blue.shade50], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
            const SizedBox(height: 16),

            // === OVERVIEW STATS ===
            GridView.count(crossAxisCount: 3, childAspectRatio: 1.1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12,
              children: [
                _premiumStatCard(icon: Icons.trending_up_rounded, value: '₹${totalExpenses.toStringAsFixed(0)}', label: 'Total', color: Colors.blue),
                _premiumStatCard(icon: Icons.arrow_upward_rounded, value: '₹${totalOwedToYou.toStringAsFixed(0)}', label: 'Owed', color: Colors.green),
                _premiumStatCard(icon: Icons.arrow_downward_rounded, value: '₹${totalYouOwe.toStringAsFixed(0)}', label: 'You Owe', color: Colors.red),
              ],
            ),
            const SizedBox(height: 28),

            // === PIE CHART WITH LEGEND ===
            if (s.expenses.isNotEmpty) _buildPieChartWithLegend(s),
            const SizedBox(height: 24),

            // === BALANCES ===
            Row(children: [
              Icon(Icons.account_balance_wallet_rounded, color: Colors.deepPurple.shade700, size: 28),
              const SizedBox(width: 10),
              Text('Settlement Status', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
            ]),
            const SizedBox(height: 14),
            if (balanceCards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade50, Colors.teal.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 64, color: Colors.green.shade600),
                    const SizedBox(height: 16),
                    Text('All Settled Up! 🎉', textAlign: TextAlign.center, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('No pending balances', style: TextStyle(color: Colors.green.shade600, fontSize: 13)),
                  ],
                ),
              )
            else
              ...balanceCards.map((e) {
                final isOwed = e.value > 0;
                final user = s.users.firstWhere((u) => u.id == e.key, orElse: () => UserModel(id: e.key, name: e.key));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: isOwed ? null : () {
                      // Quick settle action
                      _showQuickSettleDialog(context, s, e.key, e.value.abs());
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isOwed ? LinearGradient(colors: [Colors.red.shade50, Colors.orangeAccent.shade100]) : LinearGradient(colors: [Colors.blue.shade50, Colors.cyan.shade100]),
                        border: Border.all(color: isOwed ? Colors.red.shade300 : Colors.blue.shade300, width: 2),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: (isOwed ? Colors.red : Colors.blue).withOpacity(0.15), blurRadius: 8)],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: isOwed ? [Colors.red.shade400, Colors.orange.shade400] : [Colors.blue.shade400, Colors.cyan.shade400]),
                                ),
                                child: Center(child: Text(user.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white))),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(isOwed ? 'owes you' : 'you owe', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${e.value.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isOwed ? Colors.red.shade700 : Colors.blue.shade700)),
                              Icon(isOwed ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: isOwed ? Colors.red.shade600 : Colors.blue.shade600, size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),

            // === RECENT TRANSACTIONS ===
            Row(children: [
              Icon(Icons.receipt_rounded, color: Colors.deepPurple.shade700, size: 28),
              const SizedBox(width: 10),
              Text('Recent (${s.expenses.length})', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
            ]),
            const SizedBox(height: 12),
            if (s.expenses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No expenses yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                ]),
              )
            else
              ...s.expenses.take(5).map((exp) {
                final payer = s.users.firstWhere((u) => u.id == exp.payerId, orElse: () => UserModel(id: exp.payerId, name: exp.payerId));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                    child: ListTile(
                      leading: Container(
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade100]), borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.receipt_long_rounded, color: Colors.deepPurple, size: 20),
                      ),
                      title: Text('₹${exp.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(exp.note, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), onPressed: () => s.deleteExpense(exp.id)),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // === BUILD PIE CHART WITH LEGEND ===
  Widget _buildPieChartWithLegend(ExpenseService s) {
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.yellow, Colors.purple, Colors.orange, Colors.pink, Colors.teal];
    final chartData = <MapEntry<String, double>>[];
    
    for (var i = 0; i < s.expenses.length && i < 5; i++) {
      chartData.add(MapEntry(s.expenses[i].note, s.expenses[i].total));
    }

    final total = chartData.fold<double>(0, (sum, e) => sum + e.value);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)]),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.pie_chart_rounded, color: Colors.deepPurple.shade700),
            const SizedBox(width: 8),
            Text('Expense Distribution', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.deepPurple.shade700)),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 200,
                width: 120,
                child: PieChart(PieChartData(
                  sections: chartData.asMap().entries.map((entry) {
                    final percentage = (entry.value.value / total) * 100;
                    return PieChartSectionData(
                      value: entry.value.value,
                      color: colors[entry.key % colors.length],
                      radius: 50,
                      titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10),
                    );
                  }).toList(),
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: chartData.asMap().entries.map((entry) {
                      final percentage = (entry.value.value / total) * 100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[entry.key % colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.value.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('₹${entry.value.value.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === SHOW QUICK SETTLE DIALOG ===
  void _showQuickSettleDialog(BuildContext context, ExpenseService s, String toUserId, double amount) {
    final toUser = s.users.firstWhere((u) => u.id == toUserId, orElse: () => UserModel(id: toUserId, name: toUserId));
    final ctrl = TextEditingController(text: amount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay ${toUser.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () {
              try {
                final amt = double.tryParse(ctrl.text) ?? 0;
                if (amt <= 0) throw Exception('Invalid amount');
                s.recordPayment(fromUserId: currentUser, toUserId: toUserId, amount: amt);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('✓ Payment recorded!'), backgroundColor: Colors.green.shade700),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Pay Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // === ADD EXPENSE TAB ===
  Widget _addExpenseTab(ExpenseService s) {
    payer = payer.isEmpty ? 'A' : payer;
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey.shade50, Colors.blue.shade50], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add New Expense', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildTextField(amountCtrl, 'Amount (₹)', Icons.currency_rupee_rounded, TextInputType.number),
            const SizedBox(height: 14),
            _buildTextField(noteCtrl, 'Description', Icons.description_rounded, TextInputType.text),
            const SizedBox(height: 14),
            _buildDropdown('Who paid?', s.users, payer, (v) => setState(() => payer = v ?? 'A')),
            const SizedBox(height: 16),
            Text('Split with:', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: s.users
                  .where((u) => u.id != payer)
                  .map((u) {
                    final selected = selectedUsers.contains(u.id);
                    return FilterChip(
                      label: Text(u.name),
                      selected: selected,
                      selectedColor: Colors.deepPurple.shade200,
                      onSelected: (v) {
                    setState(() {
                      if (v) {
                        selectedUsers.add(u.id);
                        splitControllers[u.id] = TextEditingController();
                      } else {
                        selectedUsers.remove(u.id);
                        splitControllers.remove(u.id);
                      }
                    });
                  },
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 20),

            Text(
              'Enter individual amounts:',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 10),

            Column(
              children: selectedUsers.map((id) {
                final user = s.users.firstWhere((u) => u.id == id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: splitControllers[id],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${user.name} amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  try {
                    final total = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (total <= 0) throw Exception('Amount must be > 0');
                    final participants = <String>{payer, ...selectedUsers};
                    double splitSum = 0;

                    for (var id in selectedUsers) {
                      final value =
                          double.tryParse(splitControllers[id]?.text ?? "0") ??
                          0;
                      splitSum += value;
                    }

                    if (splitSum > total) {
                      throw Exception("Split exceeds total amount");
                    }
                    if (participants.length < 2) throw Exception('Select at least one other person');
                    final splits = <String, double>{};

                    // amounts entered for selected users
                    for (var id in selectedUsers) {
                      final value =
                          double.tryParse(splitControllers[id]?.text ?? "0") ??
                          0;
                      splits[id] = value;
                    }

                    // payer gets the remaining amount
                    splits[payer] = total - splitSum;

                    s.addExpenseCustom(
                      total: total,
                      payerId: payer,
                      splits: splits,
                      note: noteCtrl.text.trim().isEmpty
                          ? 'Expense'
                          : noteCtrl.text.trim(),
                    );
                    amountCtrl.clear();
                    noteCtrl.clear();
                    selectedUsers.clear();
                    setState(() => tabIndex = 0);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✓ Expense added!'), backgroundColor: Colors.deepPurple.shade700));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === SETTLE PAYMENT TAB ===
  Widget _settlePaymentTab(ExpenseService s) {
    // Calculate debts from current user's perspective
    final currentUserDebts = _calculateCurrentUserDebts(s);
    if (selectedToUser.isEmpty || !s.users.any((u) => u.id == selectedToUser)) {
      selectedToUser = s.users.firstWhere((u) => u.id != currentUser, orElse: () => s.users.first).id;
    }

    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey.shade50, Colors.green.shade50], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record Payment', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // === CURRENT USER INDICATOR ===
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: Row(children: [
                Icon(Icons.person_rounded, color: Colors.deepPurple.shade700),
                const SizedBox(width: 8),
                Text('Logged in as:', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                DropdownButton<String>(
                  value: currentUser,
                  items: s.users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (v) => setState(() => currentUser = v ?? 'A'),
                  underline: const SizedBox(),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // === PAY TO ===
            Text('You owe to:', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (currentUserDebts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade300), borderRadius: BorderRadius.circular(10)),
                child: Text('✓ No pending debts!', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
              )
            else
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonFormField<String>(
                  initialValue: currentUserDebts.containsKey(selectedToUser) ? selectedToUser : currentUserDebts.keys.first,
                  items: currentUserDebts.entries
                      .map((e) {
                        final user = s.users.firstWhere((u) => u.id == e.key, orElse: () => UserModel(id: e.key, name: e.key));
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text('${user.name} (₹${e.value.abs().toStringAsFixed(2)})'),
                        );
                      })
                      .toList(),
                  onChanged: (v) => setState(() => selectedToUser = v ?? selectedToUser),
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                ),
              ),
            const SizedBox(height: 16),

            // === AMOUNT ===
            if (currentUserDebts.isNotEmpty) ...[
              _buildTextField(paymentAmountCtrl, 'Payment Amount (₹)', Icons.currency_rupee_rounded, TextInputType.number),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    try {
                      final amount = double.tryParse(paymentAmountCtrl.text.trim()) ?? 0;
                      if (amount <= 0) throw Exception('Amount must be > 0');
                      s.recordPayment(fromUserId: currentUser, toUserId: selectedToUser, amount: amount);
                      paymentAmountCtrl.clear();
                      setState(() => tabIndex = 0);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✓ Payment recorded!'), backgroundColor: Colors.green.shade700));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              const SizedBox(height: 24),

              // === PAYMENT HISTORY ===
              if (s.payments.isNotEmpty) ...[
                Text('Recent Payments', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...s.payments.take(10).map((p) {
                  final from = s.users.firstWhere((u) => u.id == p.fromUserId, orElse: () => UserModel(id: p.fromUserId, name: p.fromUserId));
                  final to = s.users.firstWhere((u) => u.id == p.toUserId, orElse: () => UserModel(id: p.toUserId, name: p.toUserId));
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                      title: Text('${from.name} → ${to.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('₹${p.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 15)),
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // === MESSAGES TAB ===
  Widget _messagesTab(ExpenseService s) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey.shade50, Colors.purple.shade50], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButton<String>(
              isExpanded: true,
              value: currentUser,
              items: s.users.map((u) => DropdownMenuItem(value: u.id, child: Text('Chat as: ${u.name}'))).toList(),
              onChanged: (v) => setState(() => currentUser = v ?? 'A'),
              underline: const SizedBox(),
            ),
          ),
          Expanded(
            child: s.messages.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.message_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No messages yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                  ]))
                : ListView.builder(
                    reverse: true,
                    itemCount: s.messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = s.messages[idx];
                      final isCurrentUser = msg.senderId == currentUser;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Align(
                          alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              gradient: isCurrentUser
                                  ? LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purple.shade300])
                                  : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg.senderName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isCurrentUser ? Colors.white : Colors.grey.shade700)),
                                const SizedBox(height: 4),
                                Text(msg.message, style: TextStyle(fontSize: 14, color: isCurrentUser ? Colors.white : Colors.black)),
                                const SizedBox(height: 4),
                                Text('${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(fontSize: 10, color: isCurrentUser ? Colors.grey.shade200 : Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: () {
                    if (messageCtrl.text.trim().isNotEmpty) {
                      final sender = s.users.firstWhere((u) => u.id == currentUser, orElse: () => UserModel(id: currentUser, name: currentUser));
                      s.addMessage(senderId: currentUser, senderName: sender.name, message: messageCtrl.text.trim());
                      messageCtrl.clear();
                    }
                  },
                  backgroundColor: Colors.deepPurple.shade700,
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === USERS TAB ===
  Widget _usersTab(ExpenseService s) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey.shade50, Colors.amber.shade50], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage Users', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add New User', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildTextField(newUserIdCtrl, 'User ID (e.g., D)', Icons.person_rounded, TextInputType.text),
                  const SizedBox(height: 10),
                  _buildTextField(newUserNameCtrl, 'Name (e.g., David)', Icons.person_outline_rounded, TextInputType.text),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (newUserIdCtrl.text.isNotEmpty && newUserNameCtrl.text.isNotEmpty) {
                          s.addUser(newUserIdCtrl.text.toUpperCase(), newUserNameCtrl.text);
                          newUserIdCtrl.clear();
                          newUserNameCtrl.clear();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✓ User added!'), backgroundColor: Colors.deepPurple.shade700));
                        }
                      },
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Add User'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Users (${s.users.length})', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...s.users.map((user) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purple.shade300]), shape: BoxShape.circle),
                    child: Center(child: Text(user.id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: user.id == 'A' ? const Text('You (primary user)') : null,
                  trailing: user.id != 'A'
                      ? IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), onPressed: () {
                          s.removeUser(user.id);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✓ User removed!'), backgroundColor: Colors.orange.shade700));
                        })
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // === HELPER FUNCTIONS ===
  Map<String, double> _calculateCurrentUserBalances(ExpenseService s) {
    final result = <String, double>{};
    for (final user in s.users) {
      if (user.id == currentUser) continue;
      result[user.id] = (s.pairwiseOwes[user.id]?[currentUser] ?? 0) - (s.pairwiseOwes[currentUser]?[user.id] ?? 0);
    }
    return result;
  }

  Map<String, double> _calculateCurrentUserDebts(ExpenseService s) {
    final result = <String, double>{};
    for (final user in s.users) {
      if (user.id == currentUser) continue;
      final debt = s.pairwiseOwes[currentUser]?[user.id] ?? 0;
      if (debt > 0.01) result[user.id] = debt;
    }
    return result;
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.deepPurple.shade700), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white),
    );
  }

  Widget _buildDropdown(String label, List<UserModel> items, String value, Function(String?) onChanged) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.white),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), prefixIcon: const Icon(Icons.person_rounded)),
      ),
    );
  }

  Widget _premiumStatCard({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.3), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
          const SizedBox(height: 8),
          Text(value, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color.withOpacity(0.9))),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
