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
  int touchedIndex = -1;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animationController.forward();
  }

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
        title: const Text(
          'Splitwise',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),

            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentUser,

                icon: const Icon(Icons.arrow_drop_down),

                items: s.users.map((u) {
                  return DropdownMenuItem(
                    value: u.id,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage(
                            "https://api.dicebear.com/7.x/personas/png?seed=${u.name}",
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          u.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      currentUser = v;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (index) => setState(() => tabIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_rounded),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment_rounded),
            label: 'Settle',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_rounded),
            label: 'Chat',
          ),
        ],
      ),
      floatingActionButton: tabIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(body: _usersTab(s)),
                  ),
                );
              },
              backgroundColor: const Color(0xFF4F46E5),
              child: const Icon(Icons.group_add_rounded, size: 28),
            )
          : null,
      body: [
        _dashboardTab(s),
        _addExpenseTab(s),
        _settlePaymentTab(s),
        _messagesTab(s),
      ][tabIndex],
    );
  }

  void _showQuickSettleDialog(
    BuildContext context,
    ExpenseService s,
    String toUserId,
    double amount,
  ) {
    final toUser = s.users.firstWhere(
      (u) => u.id == toUserId,
      orElse: () => UserModel(id: toUserId, name: toUserId),
    );

    final ctrl = TextEditingController(text: amount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay ${toUser.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(ctrl.text) ?? 0;

              s.recordPayment(
                fromUserId: currentUser,
                toUserId: toUserId,
                amount: amt,
              );

              Navigator.pop(ctx);
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  // === DASHBOARD TAB ===
  Widget _dashboardTab(ExpenseService s) {
    // Calculate balances from current user's perspective
    final currentUserBalances = _calculateCurrentUserBalances(s);
    final balanceCards = currentUserBalances.entries
        .where((e) => e.value.abs() > 0.005)
        .toList();

    final totalOwedToYou = balanceCards
        .where((e) => e.value > 0)
        .fold<double>(0, (sum, e) => sum + e.value);
    final totalYouOwe = balanceCards
        .where((e) => e.value < 0)
        .fold<double>(0, (sum, e) => sum + e.value.abs());
    final totalExpenses = s.expenses.fold<double>(0, (sum, e) => sum + e.total);

    return Container(
      color: const Color(0xFFF8F8F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // === OVERVIEW STATS ===
            GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _animatedStatCard(
                  0,
                  icon: Icons.trending_up_rounded,
                  value: '₹${totalExpenses.toStringAsFixed(0)}',
                  label: 'Total',
                  color: Colors.blue,
                ),
                _animatedStatCard(
                  1,
                  icon: Icons.arrow_upward_rounded,
                  value: '₹${totalOwedToYou.toStringAsFixed(0)}',
                  label: 'Owed',
                  color: Colors.green,
                ),
                _animatedStatCard(
                  2,
                  icon: Icons.arrow_downward_rounded,
                  value: '₹${totalYouOwe.toStringAsFixed(0)}',
                  label: 'You Owe',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // === PIE CHART WITH LEGEND ===
            if (s.expenses.isNotEmpty) _buildPieChartWithLegend(s),
            const SizedBox(height: 24),

            // === BALANCES ===
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.black87,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'Settlement Status',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (balanceCards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.teal.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 64,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All Settled Up! 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No pending balances',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...balanceCards.map((e) {
                final isOwed = e.value > 0;
                final user = s.users.firstWhere(
                  (u) => u.id == e.key,
                  orElse: () => UserModel(id: e.key, name: e.key),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: isOwed
                        ? null
                        : () {
                            // Quick settle action
                            _showQuickSettleDialog(
                              context,
                              s,
                              e.key,
                              e.value.abs(),
                            );
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: NetworkImage(user.avatar),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    isOwed ? 'owes you' : 'you owe',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${e.value.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isOwed
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),

                              const SizedBox(height: 6),

                              if (!isOwed)
                                ElevatedButton(
                                  onPressed: () {
                                    _showQuickSettleDialog(
                                      context,
                                      s,
                                      e.key,
                                      e.value.abs(),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: const Text(
                                    "Pay",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                )
                              else
                                OutlinedButton(
                                  onPressed: () {
                                    final user = s.users.firstWhere(
                                      (u) => u.id == e.key,
                                      orElse: () =>
                                          UserModel(id: e.key, name: e.key),
                                    );

                                    s.addMessage(
                                      senderId: currentUser,
                                      senderName: "Reminder",
                                      message:
                                          "🔔 Reminder: ${user.name}, please pay ₹${e.value.toStringAsFixed(2)}",
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Reminder sent in chat"),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: const Text(
                                    "Remind",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
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
            Row(
              children: [
                Icon(Icons.receipt_rounded, color: Colors.black87, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Recent (${s.expenses.length})',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (s.expenses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No expenses yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...s.expenses.take(5).map((exp) {
                final payer = s.users.firstWhere(
                  (u) => u.id == exp.payerId,
                  orElse: () => UserModel(id: exp.payerId, name: exp.payerId),
                );
                final participantNames = exp.participants
                    .map((id) {
                      final user = s.users.firstWhere(
                        (u) => u.id == id,
                        orElse: () => UserModel(id: id, name: id),
                      );
                      return user.name;
                    })
                    .join(', ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade300,
                                Colors.purple.shade200,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${exp.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              exp.note,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 14,
                                color: Colors.deepPurple.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${payer.name} paid • Split: $participantNames',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => s.deleteExpense(exp.id),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
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
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    final chartExpenses = s.expenses.take(5).toList();

    final chartData = chartExpenses
        .map((e) => MapEntry(e.note, e.total))
        .toList();

    final total = chartData.fold<double>(0, (sum, e) => sum + e.value);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: Colors.deepPurple.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Expense Distribution',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.deepPurple.shade700,
                  fontSize: 15,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),

            child: Column(
              children: [
                /// PIE CHART
                SizedBox(
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              touchedIndex = -1;
                            } else {
                              touchedIndex =
                                  response.touchedSection!.touchedSectionIndex;
                            }
                          });
                        },
                      ),

                      sections: chartData.asMap().entries.map((entry) {
                        final isTouched = entry.key == touchedIndex;
                        final percentage = (entry.value.value / total) * 100;

                        final radius = isTouched ? 70.0 : 55.0;
                        final fontSize = isTouched ? 14.0 : 11.0;

                        return PieChartSectionData(
                          value: entry.value.value,
                          title: '${percentage.toStringAsFixed(0)}%',
                          color: colors[entry.key % colors.length],
                          radius: radius,
                          titleStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: fontSize,
                          ),
                        );
                      }).toList(),

                      centerSpaceRadius: 35,
                      sectionsSpace: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// SHOW DETAILS WHEN SLICE IS TOUCHED
                if (touchedIndex != -1 && touchedIndex < chartExpenses.length)
                  _buildExpenseDetails(s, chartExpenses[touchedIndex]),

                const SizedBox(height: 16),

                /// LEGEND
                ...chartData.asMap().entries.map((entry) {
                  final percentage = (entry.value.value / total) * 100;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),

                    child: Container(
                      padding: const EdgeInsets.all(10),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors[entry.key % colors.length].withOpacity(
                            0.3,
                          ),
                          width: 1.5,
                        ),
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: colors[entry.key % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  entry.value.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                Text(
                                  '₹${entry.value.value.toStringAsFixed(2)} '
                                  '(${percentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === ADD EXPENSE TAB ===
  Widget _addExpenseTab(ExpenseService s) {
    payer = payer.isEmpty ? 'A' : payer;
    return Container(
      color: const Color(0xFFF8F8F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Expense',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              amountCtrl,
              'Amount (₹)',
              Icons.currency_rupee_rounded,
              TextInputType.number,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              noteCtrl,
              'Description',
              Icons.description_rounded,
              TextInputType.text,
            ),
            const SizedBox(height: 14),
            _buildDropdown(
              'Who paid?',
              s.users,
              payer,
              (v) => setState(() => payer = v ?? 'A'),
            ),
            const SizedBox(height: 16),
            Text(
              'Split with:',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                for (final u in s.users.where((u) => u.id != payer))
                  Builder(
                    builder: (context) {
                      if (!splitControllers.containsKey(u.id)) {
                        splitControllers[u.id] = TextEditingController();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(
                                "https://api.dicebear.com/7.x/personas/png?seed=${u.name}",
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                u.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: splitControllers[u.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: "Amount",
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  try {
                    final total = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (total <= 0) throw Exception('Amount must be > 0');

                    final splits = <String, double>{};
                    double enteredTotal = 0;

                    for (final user in s.users) {
                      if (user.id == payer) continue;

                      final ctrl = splitControllers[user.id];
                      if (ctrl == null) continue;

                      final amount = double.tryParse(ctrl.text) ?? 0;
                      if (amount > 0) {
                        splits[user.id] = amount;
                        enteredTotal += amount;
                      }
                    }

                    final payerShare = total - enteredTotal;

                    if (payerShare < 0) {
                      throw Exception("Split exceeds total amount");
                    }

                    splits[payer] = payerShare;

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

                    for (var c in splitControllers.values) {
                      c.clear();
                    }

                    setState(() => tabIndex = 0);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✓ Expense added!'),
                        backgroundColor: Colors.deepPurple.shade700,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'Save Expense',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
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

    // Ensure selectedToUser is valid and not yourself
    if (selectedToUser.isEmpty ||
        selectedToUser == currentUser ||
        !currentUserDebts.containsKey(selectedToUser)) {
      if (currentUserDebts.isNotEmpty) {
        selectedToUser = currentUserDebts.keys.first;
      } else {
        selectedToUser = '';
      }
    }

    return Container(
      color: const Color(0xFFF8F8F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record Payment',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // === CURRENT USER INDICATOR ===
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, color: Colors.deepPurple.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Logged in as:',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: currentUser,
                    items: s.users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              u.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != currentUser) {
                        setState(() {
                          currentUser = v;
                          selectedToUser =
                              ''; // Reset to force selection of valid user
                        });
                      }
                    },
                    underline: const SizedBox(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // === PAY TO ===
            Text(
              'You owe to:',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (currentUserDebts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '✓ No pending debts!',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: currentUserDebts.containsKey(selectedToUser)
                      ? selectedToUser
                      : currentUserDebts.keys.first,
                  items: currentUserDebts.entries.map((e) {
                    final user = s.users.firstWhere(
                      (u) => u.id == e.key,
                      orElse: () => UserModel(id: e.key, name: e.key),
                    );
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        '${user.name} (₹${e.value.abs().toStringAsFixed(2)})',
                      ),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setState(() => selectedToUser = v ?? selectedToUser),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // === AMOUNT ===
            if (currentUserDebts.isNotEmpty) ...[
              _buildTextField(
                paymentAmountCtrl,
                'Payment Amount (₹)',
                Icons.currency_rupee_rounded,
                TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    try {
                      if (currentUser == selectedToUser) {
                        throw Exception('❌ Cannot pay yourself!');
                      }
                      final amount =
                          double.tryParse(paymentAmountCtrl.text.trim()) ?? 0;
                      if (amount <= 0) throw Exception('Amount must be > 0');
                      s.recordPayment(
                        fromUserId: currentUser,
                        toUserId: selectedToUser,
                        amount: amount,
                      );
                      paymentAmountCtrl.clear();
                      setState(() => tabIndex = 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('✓ Payment recorded!'),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Record Payment',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // === PAYMENT HISTORY ===
              if (s.payments.isNotEmpty) ...[
                Text(
                  'Recent Payments',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...s.payments.take(10).map((p) {
                  final from = s.users.firstWhere(
                    (u) => u.id == p.fromUserId,
                    orElse: () =>
                        UserModel(id: p.fromUserId, name: p.fromUserId),
                  );
                  final to = s.users.firstWhere(
                    (u) => u.id == p.toUserId,
                    orElse: () => UserModel(id: p.toUserId, name: p.toUserId),
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 24,
                      ),
                      title: Text(
                        '${from.name} → ${to.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        '₹${p.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 15,
                        ),
                      ),
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
      color: const Color(0xFFF8F8F8),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(
              top: 100,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: currentUser,
              items: s.users
                  .map(
                    (u) => DropdownMenuItem(
                      value: u.id,
                      child: Text('Chat as: ${u.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => currentUser = v ?? 'A'),
              underline: const SizedBox(),
            ),
          ),
          Expanded(
            child: s.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: s.messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = s.messages[idx];
                      final isCurrentUser = msg.senderId == currentUser;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Align(
                          alignment: isCurrentUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? const Color(0xFF4F46E5)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: isCurrentUser
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg.message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isCurrentUser
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isCurrentUser
                                        ? Colors.grey.shade200
                                        : Colors.grey.shade600,
                                  ),
                                ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: () {
                    if (messageCtrl.text.trim().isNotEmpty) {
                      final sender = s.users.firstWhere(
                        (u) => u.id == currentUser,
                        orElse: () =>
                            UserModel(id: currentUser, name: currentUser),
                      );
                      s.addMessage(
                        senderId: currentUser,
                        senderName: sender.name,
                        message: messageCtrl.text.trim(),
                      );
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
      color: const Color(0xFFF8F8F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Users',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New User',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    newUserIdCtrl,
                    'User ID (e.g., D)',
                    Icons.person_rounded,
                    TextInputType.text,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    newUserNameCtrl,
                    'Name (e.g., David)',
                    Icons.person_outline_rounded,
                    TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (newUserIdCtrl.text.isNotEmpty &&
                            newUserNameCtrl.text.isNotEmpty) {
                          s.addUser(
                            newUserIdCtrl.text.toUpperCase(),
                            newUserNameCtrl.text,
                          );
                          newUserIdCtrl.clear();
                          newUserNameCtrl.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('✓ User added!'),
                              backgroundColor: Colors.deepPurple.shade700,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Add User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Users (${s.users.length})',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...s.users.map((user) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(
                      "https://api.dicebear.com/7.x/personas/png?seed=${user.name}",
                    ),
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: user.id == 'A'
                      ? const Text('You (primary user)')
                      : null,
                  trailing: user.id != 'A'
                      ? IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            s.removeUser(user.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('✓ User removed!'),
                                backgroundColor: Colors.orange.shade700,
                              ),
                            );
                          },
                        )
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
      result[user.id] =
          (s.pairwiseOwes[user.id]?[currentUser] ?? 0) -
          (s.pairwiseOwes[currentUser]?[user.id] ?? 0);
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

  Widget _buildExpenseDetails(ExpenseService s, ExpenseModel exp) {
    final payer = s.users.firstWhere(
      (u) => u.id == exp.payerId,
      orElse: () => UserModel(id: exp.payerId, name: exp.payerId),
    );

    Map<String, double> splits = exp.splits ?? {};

    if (splits.isEmpty && exp.participants.isNotEmpty) {
      final equalShare = exp.total / exp.participants.length;

      splits = {for (var id in exp.participants) id: equalShare};
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Expense: ${exp.note}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text("Paid by: ${payer.name}"),

          const SizedBox(height: 6),

          Text("Total: ₹${exp.total.toStringAsFixed(2)}"),

          const SizedBox(height: 10),

          const Text("Split:", style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 6),

          ...splits.entries.map((entry) {
            final user = s.users.firstWhere(
              (u) => u.id == entry.key,
              orElse: () => UserModel(id: entry.key, name: entry.key),
            );

            if (entry.key == exp.payerId) {
              return Text(
                "${user.name} paid ₹${entry.value.toStringAsFixed(2)}",
              );
            }

            return Text("${user.name} owes ₹${entry.value.toStringAsFixed(2)}");
          }),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    TextInputType type,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<UserModel> items,
    String value,
    Function(String?) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items
            .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          prefixIcon: const Icon(Icons.person_rounded),
        ),
      ),
    );
  }

  Widget _animatedStatCard(
    int index, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final animationValue = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(index * 0.1, index * 0.1 + 0.6, curve: Curves.easeOut),
      ),
    );

    return ScaleTransition(
      scale: animationValue,
      child: FadeTransition(
        opacity: animationValue,
        child: _premiumStatCard(
          icon: icon,
          value: value,
          label: label,
          color: color,
        ),
      ),
    );
  }

  Widget _premiumStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
