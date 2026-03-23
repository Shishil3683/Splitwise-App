import 'package:flutter/foundation.dart';
import 'package:splitwise_clone/models/models.dart';

class ExpenseService extends ChangeNotifier {
  final bool useFirestore = false;
  final String currentUserId = 'A';

  List<UserModel> users = [
    UserModel(id: 'A', name: 'Alice'),
    UserModel(id: 'B', name: 'Bob'),
    UserModel(id: 'C', name: 'Charlie'),
  ];

  List<ExpenseModel> expenses = [];
  List<MessageModel> messages = [];
  List<PaymentModel> payments = [];

  // A-perspective balance: positive means user owes A, negative means A owes user
  Map<String, double> netBalanceFromA = {};

  // Pairwise owes: map[from][to] = amount
  Map<String, Map<String, double>> pairwiseOwes = {};

  ExpenseService() {
    _loadInitialData();
  }

  void _loadInitialData() {
    expenses = [
      ExpenseModel(
        id: 'x1',
        total: 300,
        payerId: 'A',
        note: 'Dinner',
        participants: ['A', 'B', 'C'],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    messages = [
      MessageModel(
        id: 'm1',
        senderId: 'A',
        senderName: 'Alice',
        message: '💰 Paid ₹300.00 for "Dinner"',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    _recalcNet();
  }

  /// Add a new user dynamically
  void addUser(String id, String name) {
    if (!users.any((u) => u.id == id)) {
      users.add(UserModel(id: id, name: name));
      _initializePairwiseForUser(id);
      notifyListeners();
    }
  }

  /// Remove a user
  void removeUser(String id) {
    if (id != currentUserId) {
      users.removeWhere((u) => u.id == id);
      pairwiseOwes.remove(id);
      for (final from in pairwiseOwes.values) {
        from.remove(id);
      }
      _recalcNet();
    }
  }

  void _initializePairwiseForUser(String userId) {
    pairwiseOwes[userId] = {};
    for (final user in users) {
      pairwiseOwes[userId]![user.id] = 0;
      pairwiseOwes[user.id]?[userId] = 0;
    }
  }

  void _recalcNet() {
    // Initialize pairwise owes for all users
    pairwiseOwes = {};
    for (final user in users) {
      pairwiseOwes[user.id] = {};
      for (final other in users) {
        pairwiseOwes[user.id]![other.id] = 0;
      }
    }

    // Calculate from expenses
    for (final exp in expenses) {
      final participants = exp.participants.toSet();
      if (!participants.contains(currentUserId)) {
        participants.add(currentUserId);
      }

      final count = participants.length;
      if (count < 2) continue;

      final rawShare = exp.total / count;
      final share = (rawShare * 100).roundToDouble() / 100;

      for (final member in participants) {
        if (member == exp.payerId) continue;
        pairwiseOwes[member]?[exp.payerId] =
            (pairwiseOwes[member]?[exp.payerId] ?? 0) + share;
      }
    }

    // Subtract payments from debts
    for (final payment in payments) {
      final current = pairwiseOwes[payment.fromUserId]?[payment.toUserId] ?? 0;
      pairwiseOwes[payment.fromUserId]?[payment.toUserId] = (current - payment.amount).clamp(0, double.infinity);
    }

    // Calculate A's net balance with each user
    netBalanceFromA = {};
    for (final user in users) {
      if (user.id == currentUserId) continue;
      netBalanceFromA[user.id] =
          (pairwiseOwes[user.id]?[currentUserId] ?? 0) -
              (pairwiseOwes[currentUserId]?[user.id] ?? 0);
    }

    notifyListeners();
  }

  Map<String, double> get pieData {
    return netBalanceFromA.map((k, v) => MapEntry(k, v > 0 ? v : 0));
  }

  void addExpense({
    required double total,
    required String payerId,
    required List<String> participants,
    required String note,
  }) {
    if (total <= 0) throw Exception('Amount must be > 0');
    if (!participants.contains(payerId)) participants.add(payerId);
    if (participants.length < 2) {
      throw Exception('Need at least two participants');
    }

    final newExpense = ExpenseModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      total: total,
      payerId: payerId,
      note: note,
      participants: participants,
      createdAt: DateTime.now(),
    );

    expenses.insert(0, newExpense);
    _recalcNet();

    // Auto-add message
    final payer = users.firstWhere((u) => u.id == payerId, orElse: () => UserModel(id: payerId, name: payerId));
    addMessage(
      senderId: payerId,
      senderName: payer.name,
      message: '💰 Paid ₹${total.toStringAsFixed(2)} for "$note"',
    );
  }

  void deleteExpense(String expenseId) {
    expenses.removeWhere((e) => e.id == expenseId);
    _recalcNet();
  }
  void addExpenseCustom({
    required double total,
    required String payerId,
    required Map<String, double> splits,
    required String note,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    expenses.add(
      ExpenseModel(
        id: id,
        total: total,
        payerId: payerId,
        participants: splits.keys.toList(),
        note: note,
      ),
    );

    splits.forEach((user, amount) {
      if (user == payerId) return;

      pairwiseOwes[user] ??= {};
      pairwiseOwes[user]![payerId] =
          (pairwiseOwes[user]![payerId] ?? 0) + amount;
    });

    notifyListeners();
  }

  void addMessage({required String senderId, required String senderName, required String message}) {
    final newMessage = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      senderName: senderName,
      message: message,
      timestamp: DateTime.now(),
    );
    messages.insert(0, newMessage);
    notifyListeners();
  }

  void recordPayment({required String fromUserId, required String toUserId, required double amount}) {
    if (amount <= 0) throw Exception('Payment amount must be > 0');
    
    final newPayment = PaymentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      timestamp: DateTime.now(),
      note: 'Payment',
    );
    
    payments.add(newPayment);
    _recalcNet();
    
    // Auto-add settlement message
    final fromUser = users.firstWhere((u) => u.id == fromUserId, orElse: () => UserModel(id: fromUserId, name: fromUserId));
    final toUser = users.firstWhere((u) => u.id == toUserId, orElse: () => UserModel(id: toUserId, name: toUserId));
    
    addMessage(
      senderId: fromUserId,
      senderName: fromUser.name,
      message: '✅ Paid ₹${amount.toStringAsFixed(2)} to ${toUser.name}',
    );
  }

  List<ExpenseModel> get allExpenses => List.unmodifiable(expenses);
  List<MessageModel> get allMessages => List.unmodifiable(messages);
}
