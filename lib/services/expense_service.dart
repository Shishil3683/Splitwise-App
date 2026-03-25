import 'package:flutter/foundation.dart';
import 'package:splitwise_clone/models/models.dart';

class ExpenseService extends ChangeNotifier {
  final bool useFirestore = false;
  final String currentUserId = 'A';

  List<UserModel> baseUsers = [
    UserModel(id: 'A', name: 'Alice'),
    UserModel(id: 'B', name: 'Bob'),
    UserModel(id: 'C', name: 'Charlie'),
    UserModel(id:'D', name:'David'),
    UserModel(id:'E', name:'Emma'),
  ];
  List<UserModel> groupUsers=[];

  List<ExpenseModel> expenses = [];
  List<MessageModel> messages = [];
  List<PaymentModel> payments = [];
  List<GroupModel> groups = [];

  String currentGroupId = "g1";
  List<UserModel> get currentGroupUsers {
    final group = groups.firstWhere(
      (g) => g.id == currentGroupId,
      orElse: () => groups.first,
    );

    final allUsers = [...baseUsers, ...groupUsers];

    return allUsers.where((u) => group.members.contains(u.id)).toList();
  }
  

  // A-perspective balance: positive means user owes A, negative means A owes user
  Map<String, double> netBalanceFromA = {};

  // Pairwise owes: map[from][to] = amount
  Map<String, Map<String, double>> pairwiseOwes = {};

  ExpenseService() {
    groups.add(
      GroupModel(
        id: "g1",
        name: "Main Group",
        members: baseUsers.map((u) => u.id).toList(),
      ),
    );

    _loadInitialData();
  }
  //ADD GROUP
  void addGroup(String name, List<String> members) {
    final id = "g${groups.length + 1}";

    groups.add(GroupModel(id: id, name: name, members: members));

    currentGroupId = id;

    _recalcNet(); 

    notifyListeners();
  }

  void switchGroup(String groupId) {
    currentGroupId = groupId;
    _recalcNet();
    notifyListeners();
  }

  void _loadInitialData() {
    expenses = [
      ExpenseModel( 
        id: 'x1',
        groupId: currentGroupId,
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
  groupId: currentGroupId,
)
    ];
    _recalcNet();
  }

  /// Add a new user dynamically
  void addUserToGroup(String name) {
    final id = "U${DateTime.now().millisecondsSinceEpoch}";

    final newUser = UserModel(id: id, name: name);

    groupUsers.add(newUser);

    final group = groups.firstWhere((g) => g.id == currentGroupId);
    group.members.add(id);

    notifyListeners();
  }

  /// Remove a user
  void removeUser(String id) {
  if (id != currentUserId) {
    groupUsers.removeWhere((u) => u.id == id);

    final group = groups.firstWhere((g) => g.id == currentGroupId);
    group.members.remove(id);

    pairwiseOwes.remove(id);

    for (final from in pairwiseOwes.values) {
      from.remove(id);
    }

    _recalcNet();
  }
}
  

  void _initializePairwiseForUser(String userId) {
  final allUsers = [...baseUsers, ...groupUsers];

  pairwiseOwes[userId] = {};

  for (final user in allUsers) {
    pairwiseOwes[userId]![user.id] = 0;
    pairwiseOwes[user.id]?[userId] = 0;
  }
}

  void _recalcNet() {
    // Initialize pairwise owes for all users
    pairwiseOwes = {};

    for (final user in currentGroupUsers) {
      pairwiseOwes[user.id] = {};

      for (final other in currentGroupUsers) {
        pairwiseOwes[user.id]![other.id] = 0;
      }
    }

    // Calculate from expenses
    for (final exp in expenses.where((e) => e.groupId == currentGroupId)) {
      final participants = exp.participants.toSet();
      

      // Use custom splits if available
      if (exp.splits != null && exp.splits!.isNotEmpty) {
        exp.splits!.forEach((user, amount) {
          if (user == exp.payerId) return;

          pairwiseOwes[user]?[exp.payerId] =
              (pairwiseOwes[user]?[exp.payerId] ?? 0) + amount;
        });
      } else {
        final count = participants.length;
        final share = count > 0
            ? double.parse((exp.total / count).toStringAsFixed(2))
            : 0;

        for (final member in participants) {
          if (member == exp.payerId) continue;

          pairwiseOwes[member]?[exp.payerId] =
              (pairwiseOwes[member]?[exp.payerId] ?? 0) + share;
        }
      }
    }

    // Subtract payments from debts
    // Subtract payments from debts
    for (final payment in payments.where((p) => p.groupId == currentGroupId)) {
      final current = pairwiseOwes[payment.fromUserId]?[payment.toUserId] ?? 0;

      pairwiseOwes[payment.fromUserId]?[payment.toUserId] =
          (current - payment.amount).clamp(0, double.infinity);
    }

    // Calculate A's net balance with each user
    netBalanceFromA = {};
    for (final user in currentGroupUsers) {
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
    if (!splits.containsKey(payerId)) {
      splits[payerId] = 0;
    }

    final splitTotal = splits.values.fold(0.0, (sum, a) => sum + a);

    if ((splitTotal - total).abs() > 0.05) {
      throw Exception("Split amounts must equal total");
    }

    final expenseId = DateTime.now().millisecondsSinceEpoch.toString();

    expenses.insert(
      0,
      ExpenseModel(
        id: expenseId,
        groupId: currentGroupId,
        total: total,
        payerId: payerId,
        participants: splits.keys.toList(),
        splits: splits,
        note: note,
        createdAt: DateTime.now(),
      ),
    );

    // 🔥 RECALCULATE BALANCES
    _recalcNet();

    // 🔥 GET PAYER USER
    final payer = currentGroupUsers.firstWhere(
      (u) => u.id == payerId,
      orElse: () => UserModel(id: payerId, name: payerId),
    );

    // 🔥 ADD CHAT MESSAGE
    messages.insert(
      0,
      MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: payerId,
        senderName: payer.name,
        message:
            '💰 Paid ₹${total.toStringAsFixed(2)} for "$note"',
        groupId: currentGroupId,
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

void deleteGroup(String groupId) {
    if (groups.length <= 1) return; // prevent deleting last group

    groups.removeWhere((g) => g.id == groupId);

    // switch to first remaining group
    currentGroupId = groups.first.id;

    // remove expenses, messages, payments of that group
    expenses.removeWhere((e) => e.groupId == groupId);
    messages.removeWhere((m) => m.groupId == groupId);
    payments.removeWhere((p) => p.groupId == groupId);

    _recalcNet();
    notifyListeners();
  }

  void addMessage({
    required String senderId,
    required String senderName,
    required String message,
  }) {
    final newMessage = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      senderName: senderName,
      message: message,
      timestamp: DateTime.now(),
      groupId: currentGroupId,
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
      groupId: currentGroupId,
    );
    
    payments.add(newPayment);
    _recalcNet();
    
    // Auto-add settlement message
    final fromUser = [...baseUsers, ...groupUsers].firstWhere(
      (u) => u.id == fromUserId,
      orElse: () => UserModel(id: fromUserId, name: fromUserId),
    );

    final toUser = [...baseUsers, ...groupUsers].firstWhere(
      (u) => u.id == toUserId,
      orElse: () => UserModel(id: toUserId, name: toUserId),
    );
    addMessage(
      senderId: fromUserId,
      senderName: fromUser.name,
      message: '✅ Paid ₹${amount.toStringAsFixed(2)} to ${toUser.name}',
    );
  }

  List<ExpenseModel> get allExpenses => List.unmodifiable(expenses);
  List<MessageModel> get allMessages => List.unmodifiable(messages);
}
