import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise_clone/services/expense_service.dart';
import 'package:splitwise_clone/models/models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:splitwise_clone/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int tabIndex = 0;
  bool showSuccess = false;
  bool equalSplit = false;
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

  // IMPROVEMENT 5: category filter for expenses
  static const _categories = [
    'All',
    'Food',
    'Travel',
    'Grocery',
    'Fun',
    'Others',
  ];
  String _selectedCategory = _categories[0];

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

  void _playSuccessAnimation() {
    setState(() => showSuccess = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => showSuccess = false);
    });
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    messageCtrl.dispose();
    newUserIdCtrl.dispose();
    newUserNameCtrl.dispose();
    paymentAmountCtrl.dispose();
    for (final c in splitControllers.values) c.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ─── IMPROVEMENT 6: Category detection ─────────────────────────────────────
  String _getCategoryForNote(String? note) {
    // Guard against both Dart null AND JS undefined (DDC web quirk)
    final n = (note == null ? '' : note.toString()).toLowerCase();
    if (n.contains("food") ||
        n.contains("lunch") ||
        n.contains("dinner") ||
        n.contains("pizza") ||
        n.contains("burger") ||
        n.contains("restaurant") ||
        n.contains("coffee") ||
        n.contains("tea") ||
        n.contains("cafe") ||
        n.contains("swiggy") ||
        n.contains("zomato") ||
        n.contains("breakfast") ||
        n.contains("snack"))
      return 'Food';
    if (n.contains("uber") ||
        n.contains("cab") ||
        n.contains("taxi") ||
        n.contains("travel") ||
        n.contains("petrol") ||
        n.contains("fuel") ||
        n.contains("flight") ||
        n.contains("train") ||
        n.contains("bus") ||
        n.contains("ola") ||
        n.contains("diesel"))
      return 'Travel';
    if (n.contains("grocery") ||
        n.contains("vegetable") ||
        n.contains("mart") ||
        n.contains("supermarket") ||
        n.contains("milk") ||
        n.contains("bread") ||
        n.contains("fruits"))
      return 'Grocery';
    if (n.contains("movie") ||
        n.contains("netflix") ||
        n.contains("concert") ||
        n.contains("party") ||
        n.contains("club") ||
        n.contains("spotify") ||
        n.contains("game"))
      return 'Fun';
    return 'Others';
  }

  Map<String, dynamic> _getExpenseVisual(String? note) {
    switch (_getCategoryForNote(note)) {
      case 'Food':
        return {
          "icon": Icons.restaurant,
          "color": Colors.orange,
          "bg": const Color(0xFFFFF3E0),
        };
      case 'Travel':
        return {
          "icon": Icons.directions_car,
          "color": Colors.blue,
          "bg": const Color(0xFFE3F2FD),
        };
      case 'Grocery':
        return {
          "icon": Icons.shopping_cart,
          "color": Colors.green,
          "bg": const Color(0xFFE8F5E9),
        };
      case 'Fun':
        return {
          "icon": Icons.movie,
          "color": Colors.purple,
          "bg": const Color(0xFFF3E5F5),
        };
      default:
        return {
          "icon": Icons.widgets,
          "color": Colors.grey,
          "bg": const Color(0xFFF5F5F5),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ExpenseService>();
    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          drawer: _groupDrawer(s),
          // ─── IMPROVEMENT 1: Refined AppBar ──────────────────────────────
          appBar: _buildAppBar(s),
          // ─── IMPROVEMENT 6: Persistent centered FAB (no tab-switch) ────
          bottomNavigationBar: _buildBottomNav(),
          floatingActionButton: _buildFAB(s),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: [
            _dashboardTab(s),
            _addExpenseTab(s),
            _messagesTab(s),
          ][tabIndex],
        ),
        _successOverlay(),
      ],
    );
  }

  // ─── IMPROVEMENT 1: Cleaner AppBar ─────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ExpenseService s) {
    final group = s.groups.firstWhere((g) => g.id == s.currentGroupId);
    final user = s.currentGroupUsers.firstWhere(
      (u) => u.id == currentUser,
      orElse: () => UserModel(id: currentUser, name: currentUser),
    );

    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            group.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.text,
            ),
          ),
          Text(
            '${s.currentGroupUsers.length} members',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.subtext,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      // ─── User pill (IMPROVEMENT 1) ───────────────────────────────────
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => _showUserSwitcher(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundImage: NetworkImage(
                      "https://api.dicebear.com/7.x/personas/png?seed=${user.name}",
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showUserSwitcher(ExpenseService s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch user',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 14),
            ...s.currentGroupUsers.map(
              (u) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(
                    "https://api.dicebear.com/7.x/personas/png?seed=${u.name}",
                  ),
                ),
                title: Text(
                  u.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: currentUser == u.id
                    ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => currentUser = u.id);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── IMPROVEMENT 6: Persistent bottom nav with docked FAB slot ────────────
  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              0,
              Icons.dashboard_rounded,
              Icons.dashboard_outlined,
              'Dashboard',
            ),
            _navItem(
              1,
              Icons.add_circle_rounded,
              Icons.add_circle_outline_rounded,
              'Add',
            ),
            _navItem(2, Icons.message_rounded, Icons.message_outlined, 'Chat'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isActive = tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => tabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                key: ValueKey(isActive),
                color: isActive ? AppColors.primary : AppColors.subtext,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.subtext,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── IMPROVEMENT 6: Centered persistent FAB ───────────────────────────────
  Widget _buildFAB(ExpenseService s) {
    // Dashboard → Add User
    if (tabIndex == 0) {
      return FloatingActionButton(
        heroTag: 'add_user',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text("Manage Users"),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                body: _usersTab(s),
              ),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      );
    }

    // Other tabs → No FAB
    return const SizedBox.shrink();
  }

  void _showQuickSettleDialog(
    BuildContext context,
    ExpenseService s,
    String toUserId,
    double amount,
  ) {
    final toUser = s.currentGroupUsers.firstWhere(
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
              _playSuccessAnimation();
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  // ─── DASHBOARD TAB ─────────────────────────────────────────────────────────
  Widget _dashboardTab(ExpenseService s) {
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
    final groupExpenses = s.expenses
        .where((e) => e.groupId == s.currentGroupId)
        .toList();
    final totalExpenses = groupExpenses.fold<double>(
      0.0,
      (sum, e) => sum + e.total,
    );
    double myExpense = groupExpenses.fold(0.0, (sum, e) {
      double share = 0;
      if (e.splits != null && e.splits!.containsKey(currentUser)) {
        share = e.splits![currentUser]!;
      } else if (e.participants.contains(currentUser)) {
        share = e.total / e.participants.length;
      }
      return sum + share;
    });

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),

            // ─── IMPROVEMENT 2: 2×2 grid stats ────────────────────────
            _buildStatsGrid(
              myExpense,
              totalYouOwe,
              totalOwedToYou,
              totalExpenses,
            ),
            const SizedBox(height: 20),

            // ─── IMPROVEMENT 3: Spending personality bar ───────────────
            _buildSpendingPersonality(s),
            const SizedBox(height: 20),

            if (s.expenses
                .where((e) => e.groupId == s.currentGroupId)
                .isNotEmpty)
              _buildPieChartWithLegend(s),
            const SizedBox(height: 24),

            // ─── Settlement status ─────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.text,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  'Settlement Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ─── IMPROVEMENT 4: Compact settlement card ────────────────
            if (balanceCards.isEmpty)
              _buildAllSettledCard()
            else
              _buildSettlementCard(s, balanceCards),

            const SizedBox(height: 24),

            // ─── Recent transactions ───────────────────────────────────
            _buildRecentHeader(s),
            const SizedBox(height: 12),

            // ─── IMPROVEMENT 5: Category chips ────────────────────────
            _buildCategoryChips(),
            const SizedBox(height: 12),

            // ─── Expense list with personal share ─────────────────────
            _buildExpenseList(s),
          ],
        ),
      ),
    );
  }

  // ─── Stat cards: fixed-height horizontal scroll, immune to screen width ─────
  Widget _buildStatsGrid(
    double myExpense,
    double youOwe,
    double toReceive,
    double total,
  ) {
    return SizedBox(
      height: 115,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _statGridCard(
            title: 'My Expense',
            amount: myExpense,
            icon: Icons.account_balance_wallet,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _statGridCard(
            title: 'You Owe',
            amount: youOwe,
            icon: Icons.arrow_upward_rounded,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          _statGridCard(
            title: 'To Receive',
            amount: toReceive,
            icon: Icons.arrow_downward_rounded,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          _statGridCard(
            title: 'Total Expenses',
            amount: total,
            icon: Icons.receipt_long_rounded,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _statGridCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 13),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.subtext,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── IMPROVEMENT 3: Spending personality with segmented bar ───────────────
  Widget _buildSpendingPersonality(ExpenseService s) {
    final userExpenses = s.expenses
        .where(
          (e) =>
              e.groupId == s.currentGroupId &&
              e.participants.contains(currentUser),
        )
        .toList();
    if (userExpenses.isEmpty) return const SizedBox();

    final categories = <String, double>{
      'Food': 0,
      'Travel': 0,
      'Grocery': 0,
      'Fun': 0,
      'Others': 0,
    };
    final categoryColors = <String, Color>{
      'Food': Colors.orange,
      'Travel': Colors.blue,
      'Grocery': Colors.green,
      'Fun': Colors.purple,
      'Others': Colors.grey,
    };

    for (final exp in userExpenses) {
      final share =
          exp.splits?[currentUser] ?? (exp.total / exp.participants.length);
      final cat = _getCategoryForNote(exp.note == null ? '' : exp.note);
      categories[cat] = (categories[cat] ?? 0) + share;
    }

    final total = categories.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox();

    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    final topPct = ((top.value / total) * 100).round();

    final emojiMap = {
      'Food': '🍔',
      'Travel': '✈️',
      'Grocery': '🛒',
      'Fun': '🎬',
      'Others': '💳',
    };
    final titleMap = {
      'Food': 'The Foodie',
      'Travel': 'The Traveller',
      'Grocery': 'The Home Manager',
      'Fun': 'The Fun Lover',
      'Others': 'The Explorer',
    };

    final user = s.currentGroupUsers.firstWhere(
      (u) => u.id == currentUser,
      orElse: () => UserModel(id: currentUser, name: currentUser),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(user.avatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.name}: ${titleMap[top.key]} ${emojiMap[top.key]}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$topPct% on ${top.key.toLowerCase()}',
                      style: TextStyle(fontSize: 12, color: AppColors.subtext),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: sorted.where((e) => e.value > 0).map((e) {
                  final flex = ((e.value / total) * 100).round();
                  return Expanded(
                    flex: flex < 1 ? 1 : flex,
                    child: Container(
                      color: categoryColors[e.key],
                      margin: const EdgeInsets.only(right: 1),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: sorted.where((e) => e.value > 0).map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: categoryColors[e.key],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${e.key} ${((e.value / total) * 100).round()}%',
                    style: TextStyle(fontSize: 10, color: AppColors.subtext),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── IMPROVEMENT 4: Compact settlement card (grouped, not separate cards) ──
  Widget _buildAllSettledCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
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
            size: 56,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            'All Settled Up! 🎉',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No pending balances',
            style: TextStyle(color: Colors.green.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(
    ExpenseService s,
    List<MapEntry<String, double>> balanceCards,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: balanceCards.asMap().entries.map((entry) {
          final idx = entry.key;
          final e = entry.value;
          final isOwed = e.value > 0;
          final user = s.currentGroupUsers.firstWhere(
            (u) => u.id == e.key,
            orElse: () => UserModel(id: e.key, name: e.key),
          );

          return Column(
            children: [
              if (idx != 0) const Divider(height: 1, indent: 16, endIndent: 16),
              // ─── IMPROVEMENT 4: Swipe to settle ────────────────────
              isOwed
                  ? _settlementRow(user, e.value, isOwed, s, e.key)
                  : Dismissible(
                      key: Key('settle_${e.key}'),
                      direction: DismissDirection.startToEnd,
                      confirmDismiss: (_) async {
                        _showQuickSettleDialog(
                          context,
                          s,
                          e.key,
                          e.value.abs(),
                        );
                        return false;
                      },
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: idx == 0
                              ? const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                )
                              : (idx == balanceCards.length - 1
                                    ? const BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      )
                                    : BorderRadius.zero),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swipe_right_alt_rounded,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Swipe to pay',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: _settlementRow(user, e.value, isOwed, s, e.key),
                    ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _settlementRow(
    UserModel user,
    double value,
    bool isOwed,
    ExpenseService s,
    String userId,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundImage: NetworkImage(user.avatar)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isOwed ? 'owes you' : 'you owe',
                  style: TextStyle(
                    color: isOwed ? AppColors.success : AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${value.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isOwed ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 6),
              if (!isOwed)
                GestureDetector(
                  onTap: () =>
                      _showQuickSettleDialog(context, s, userId, value.abs()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    s.addMessage(
                      senderId: currentUser,
                      senderName: "Reminder",
                      message:
                          "🔔 Reminder: ${user.name}, please pay ₹${value.toStringAsFixed(2)}",
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Reminder sent in chat")),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Remind',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtext,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Recent header ──────────────────────────────────────────────────────────
  Widget _buildRecentHeader(ExpenseService s) {
    final count = s.expenses.where((e) => e.groupId == s.currentGroupId).length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_rounded, color: AppColors.text, size: 24),
            const SizedBox(width: 8),
            Text(
              'Recent ($count)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── IMPROVEMENT 5: Category filter chips ─────────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.subtext,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── IMPROVEMENT 5: Expense list with personal share + swipe to delete ─────
  Widget _buildExpenseList(ExpenseService s) {
    var expenses = s.expenses
        .where(
          (e) =>
              e.groupId == s.currentGroupId &&
              e.participants.contains(currentUser),
        )
        .toList();

    if (_selectedCategory != 'All') {
      expenses = expenses
          .where(
            (e) =>
                _getCategoryForNote(e.note == null ? '' : e.note) ==
                _selectedCategory,
          )
          .toList();
    }

    if (expenses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              (_selectedCategory == 'All')
                  ? 'No expenses yet'
                  : 'No ${(_selectedCategory).toLowerCase()} expenses',
              style: TextStyle(color: AppColors.subtext, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: expenses.take(10).map((exp) {
        final payerUser = s.currentGroupUsers.firstWhere(
          (u) => u.id == exp.payerId,
          orElse: () => UserModel(id: exp.payerId, name: exp.payerId),
        );

        // Personal share for this user
        double myShare = 0;
        if (exp.splits != null && exp.splits!.containsKey(currentUser)) {
          myShare = exp.splits![currentUser]!;
        } else if (exp.participants.contains(currentUser)) {
          myShare = exp.total / exp.participants.length;
        }
        final iPaid = exp.payerId == currentUser;
        final iGetBack = iPaid && myShare < exp.total;
        final iOwe = !iPaid && myShare > 0;

        final visual = _getExpenseVisual(exp.note);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          // ─── IMPROVEMENT 5: Swipe to delete ─────────────────────────
          child: Dismissible(
            key: Key(exp.id ?? UniqueKey().toString()),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              bool confirm = false;
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete expense?'),
                  content: Text(
                    'Remove "${exp.note ?? 'Expense'}" from the group?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      onPressed: () {
                        confirm = true;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              return confirm;
            },
            onDismissed: (_) => s.deleteExpense(exp.id),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  Text(
                    'Delete',
                    style: TextStyle(color: AppColors.danger, fontSize: 11),
                  ),
                ],
              ),
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: visual["bg"],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          visual["icon"],
                          color: visual["color"],
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exp.note ?? 'Expense',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${payerUser.name} paid · ${exp.participants.length} people',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.subtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${exp.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // ─── Personal share badge ──────────────────────────────
                        if (iGetBack)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'you get ₹${(exp.total - myShare).toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (iOwe)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'you owe ₹${myShare.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'settled',
                              style: TextStyle(
                                color: AppColors.subtext,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── PIE CHART (unchanged) ─────────────────────────────────────────────────
  Widget _buildPieChartWithLegend(ExpenseService s) {
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      Colors.pink,
      Colors.teal,
    ];
    final chartExpenses = s.expenses
        .where(
          (e) =>
              e.groupId == s.currentGroupId &&
              e.participants.contains(currentUser),
        )
        .take(5)
        .toList();
    final chartData = chartExpenses
        .map((e) => MapEntry(e.note ?? 'Expense', e.total))
        .toList();
    final total = chartData.fold<double>(0, (sum, e) => sum + e.value);
    if (total == 0) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Expense Distribution',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                  final pct = (entry.value.value / total) * 100;
                  return PieChartSectionData(
                    value: entry.value.value,
                    title: '${pct.toStringAsFixed(0)}%',
                    color: colors[entry.key % colors.length],
                    radius: isTouched ? 82.0 : 50.0,
                    titleStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: isTouched ? 14.0 : 11.0,
                    ),
                  );
                }).toList(),
                centerSpaceRadius: 35,
                sectionsSpace: 2,
              ),
            ),
          ),
          if (touchedIndex != -1 && touchedIndex < chartExpenses.length) ...[
            const SizedBox(height: 12),
            _buildExpenseDetails(s, chartExpenses[touchedIndex]),
          ],
          const SizedBox(height: 14),
          ...chartData.asMap().entries.map((entry) {
            final pct = (entry.value.value / total) * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[entry.key % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${entry.value.value.toStringAsFixed(0)} (${pct.toStringAsFixed(1)}%)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _successOverlay() {
    if (!showSuccess) return const SizedBox();
    return Positioned.fill(
      child: Container(
        color: AppColors.text.withOpacity(0.25),
        child: Center(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
            ),
            child: const _AnimatedCheck(),
          ),
        ),
      ),
    );
  }

  // ─── ADD EXPENSE TAB (unchanged logic, minor polish) ──────────────────────
  Widget _addExpenseTab(ExpenseService s) {
    payer = payer.isEmpty ? 'A' : payer;
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 100),
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
              s.currentGroupUsers,
              payer,
              (v) => setState(() => payer = v ?? 'A'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  equalSplit ? "Equal Split" : "Custom Split",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Switch(
                  value: equalSplit,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => equalSplit = v),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Select participants', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Column(
              children: s.currentGroupUsers.where((u) => u.id != payer).map((
                u,
              ) {
                if (!splitControllers.containsKey(u.id)) {
                  splitControllers[u.id] = TextEditingController();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectedUsers.contains(u.id),
                        onChanged: (v) => setState(() {
                          if (v == true)
                            selectedUsers.add(u.id);
                          else
                            selectedUsers.remove(u.id);
                        }),
                      ),
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
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!equalSplit)
                        SizedBox(
                          width: 110,
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
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  try {
                    if (selectedUsers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Add at least one other participant"),
                        ),
                      );
                      return;
                    }
                    final total = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (total <= 0) throw Exception('Amount must be > 0');
                    final splits = <String, double>{};
                    if (equalSplit) {
                      if (selectedUsers.isEmpty)
                        throw Exception("Select at least one user");
                      final participants = [...selectedUsers, payer];
                      final count = participants.length;
                      final baseShare = (total / count);
                      double remaining = total;
                      for (int i = 0; i < count; i++) {
                        double share;
                        if (i == count - 1) {
                          share = remaining;
                        } else {
                          share = double.parse(baseShare.toStringAsFixed(2));
                          remaining -= share;
                        }
                        splits[participants[i]] = share;
                      }
                    } else {
                      double enteredTotal = 0;
                      for (final id in selectedUsers) {
                        final ctrl = splitControllers[id];
                        if (ctrl == null) continue;
                        final amount = double.tryParse(ctrl.text) ?? 0;
                        if (amount > 0) {
                          splits[id] = amount;
                          enteredTotal += amount;
                        }
                      }
                      final payerShare = total - enteredTotal;
                      if (payerShare < 0)
                        throw Exception("Split exceeds total amount");
                      splits[payer] = payerShare;
                    }
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
                    for (var c in splitControllers.values) c.clear();
                    setState(() => tabIndex = 0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✓ Expense added!'),
                        backgroundColor: AppColors.primary,
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
                  backgroundColor: AppColors.primary,
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

  Color _getMessageColor(String message, bool isCurrentUser) {
    // Reminder
    if (message.contains("🔔") || message.toLowerCase().contains("reminder")) {
      return const Color.fromARGB(255, 230, 143, 13);
    }

    // Payment
    if (message.contains("✅") || message.toLowerCase().contains("paid")) {
      return const Color.fromARGB(255, 63, 214, 68);
    }

    // Normal messages
    return isCurrentUser ? AppColors.primary : Colors.grey.shade200;
  }

  Color _getMessageTextColor(String message, bool isCurrentUser) {
    if (message.contains("🔔") || message.toLowerCase().contains("reminder")) {
      return const Color.fromARGB(255, 218, 8, 124);
    }

    if (message.contains("✅") || message.toLowerCase().contains("paid")) {
      return Colors.green.shade900;
    }

    return isCurrentUser ? Colors.white : Colors.black;
  }

  // ─── MESSAGES TAB (unchanged) ─────────────────────────────────────────────
  Widget _messagesTab(ExpenseService s) {
    final groupMessages = s.messages
        .where((m) => m.groupId == s.currentGroupId)
        .toList();
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(
              top: 100,
              left: 16,
              right: 16,
              bottom: 8,
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
              items: s.currentGroupUsers
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
            child: groupMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message_outlined,
                          size: 52,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: AppColors.subtext,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: groupMessages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = groupMessages[idx];
                      final isCurrentUser = msg.senderId == currentUser;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
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
                              color: _getMessageColor(
                                msg.message,
                                isCurrentUser,
                              ),
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
                                    color: _getMessageTextColor(
                                      msg.message,
                                      isCurrentUser,
                                    ),
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                  heroTag: 'chat_send',
                  mini: true,
                  onPressed: () {
                    if (messageCtrl.text.trim().isNotEmpty) {
                      final sender = s.currentGroupUsers.firstWhere(
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
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── USERS TAB (unchanged) ────────────────────────────────────────────────
  Widget _usersTab(ExpenseService s) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.text.withOpacity(0.05),
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
                        if (newUserNameCtrl.text.isNotEmpty) {
                          s.addUserToGroup(newUserNameCtrl.text.trim());
                          newUserIdCtrl.clear();
                          newUserNameCtrl.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('✓ User added to group!'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Add User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF60A5FA),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Users (${s.currentGroupUsers.length})',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...s.currentGroupUsers.map(
              (user) => Card(
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
                            color: AppColors.danger,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  Map<String, double> _calculateCurrentUserBalances(ExpenseService s) {
    final result = <String, double>{};
    for (final user in s.currentGroupUsers) {
      if (user.id == currentUser) continue;
      result[user.id] =
          (s.pairwiseOwes[user.id]?[currentUser] ?? 0) -
          (s.pairwiseOwes[currentUser]?[user.id] ?? 0);
    }
    return result;
  }

  Map<String, double> _calculateCurrentUserDebts(ExpenseService s) {
    final result = <String, double>{};
    for (final user in s.currentGroupUsers) {
      if (user.id == currentUser) continue;
      final debt = s.pairwiseOwes[currentUser]?[user.id] ?? 0;
      if (debt > 0.01) result[user.id] = debt;
    }
    return result;
  }

  Widget _buildExpenseDetails(ExpenseService s, ExpenseModel exp) {
    Map<String, double> splits = exp.splits ?? {};
    if (splits.isEmpty && exp.participants.isNotEmpty) {
      final equalShare = exp.total / exp.participants.length;
      splits = {for (var id in exp.participants) id: equalShare};
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exp.note ?? 'Expense',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${exp.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFF4338CA),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...splits.entries.map((entry) {
            final user = s.currentGroupUsers.firstWhere(
              (u) => u.id == entry.key,
              orElse: () => UserModel(id: entry.key, name: entry.key),
            );
            final isPayer = entry.key == exp.payerId;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Text(
                    isPayer
                        ? "paid ₹${entry.value.toStringAsFixed(0)}"
                        : "owes ₹${entry.value.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPayer
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _groupDrawer(ExpenseService s) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, const Color(0xFF1D4ED8)],
              ),
            ),
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                "Groups",
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ...s.groups.map((g) {
            final selected = g.id == s.currentGroupId;
            return ListTile(
              leading: Icon(
                Icons.group,
                color: selected ? AppColors.primary : Colors.grey,
              ),
              title: Text(g.name),
              selected: selected,
              selectedTileColor: AppColors.primary.withOpacity(0.08),

              trailing: s.groups.length > 1
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        bool confirm = false;

                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Group"),
                            content: Text("Delete '${g.name}' group?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () {
                                  confirm = true;
                                  Navigator.pop(ctx);
                                },
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        );

                        if (confirm) {
                          s.deleteGroup(g.id);
                        }
                      },
                    )
                  : null,

              onTap: () {
                s.switchGroup(g.id);
                Navigator.pop(context);
              },
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text("Create Group"),
            onTap: () {
              Navigator.pop(context);
              final ctrl = TextEditingController();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Create Group"),
                  content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(labelText: "Group name"),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (ctrl.text.isNotEmpty) {
                          s.addGroup(
                            ctrl.text,
                            s.baseUsers.map((u) => u.id).toList(),
                          );
                        }
                        Navigator.pop(context);
                      },
                      child: const Text("Create"),
                    ),
                  ],
                ),
              );
            },
          ),
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
        prefixIcon: Icon(icon, color: AppColors.primary),
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
}

// ─── Animated check ─────────────────────────────────────────────────────────
class _AnimatedCheck extends StatefulWidget {
  const _AnimatedCheck();
  @override
  State<_AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<_AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CheckPainter(controller));
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _CheckPainter extends CustomPainter {
  final Animation<double> animation;
  _CheckPainter(this.animation) : super(repaint: animation);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(size.width * 0.28, size.height * 0.52);
    path.lineTo(size.width * 0.45, size.height * 0.68);
    path.lineTo(size.width * 0.72, size.height * 0.38);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * animation.value),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Stat card (kept for backward compat, now replaced by grid) ─────────────
Widget _statCard({
  required String title,
  required String amount,
  required IconData icon,
  required Color color,
}) {
  return Container(
    width: 140,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    ),
  );
}
