import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String avatar;

  UserModel({required this.id, required this.name, String? avatar})
    : avatar = avatar ?? "https://api.dicebear.com/7.x/personas/png?seed=$name";

  Map<String, dynamic> toMap() => {'name': name, 'avatar': avatar};

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      name: d['name'] ?? '',
      avatar: d['avatar'], // safe because constructor handles null
    );
  }
}

class ExpenseShare {
  final String userId;
  final double due;
  final double paid;
  ExpenseShare({required this.userId, required this.due, required this.paid});

  Map<String, dynamic> toMap() => {'due': due, 'paid': paid};
  factory ExpenseShare.fromMap(String id, Map<String, dynamic> m) =>
      ExpenseShare(
        userId: id,
        due: (m['due'] as num).toDouble(),
        paid: (m['paid'] as num).toDouble(),
      );
}

class ExpenseModel {
  final String id;
  final double total;
  final String payerId;
  final List<String> participants;
  final String note;
  final DateTime createdAt;
  final Map<String, double>? splits;

  ExpenseModel({
    required this.id,
    required this.total,
    required this.payerId,
    required this.participants,
    required this.note,
    DateTime? createdAt,
    this.splits,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total': total,
      'payerId': payerId,
      'note': note,
      'participants': participants,
      'createdAt': createdAt,
      'splits': splits,
    };
  }
}

class ExpenseItem {
  final String category;
  final double amount;
  ExpenseItem({required this.category, required this.amount});
  Map<String, dynamic> toMap() => {'category': category, 'amount': amount};
  factory ExpenseItem.fromMap(Map<String, dynamic> m) => ExpenseItem(
    category: m['category'] as String,
    amount: (m['amount'] as num).toDouble(),
  );
}

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'senderName': senderName,
    'message': message,
    'timestamp': timestamp,
  };

  factory MessageModel.fromMap(String id, Map<String, dynamic> m) =>
      MessageModel(
        id: id,
        senderId: m['senderId'] as String? ?? 'A',
        senderName: m['senderName'] as String? ?? 'Unknown',
        message: m['message'] as String? ?? '',
        timestamp: m['timestamp'] is Timestamp
            ? (m['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

class PaymentModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime timestamp;
  final String note;

  PaymentModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.timestamp,
    this.note = 'Payment',
  });

  Map<String, dynamic> toMap() => {
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'amount': amount,
    'timestamp': timestamp,
    'note': note,
  };

  factory PaymentModel.fromMap(String id, Map<String, dynamic> m) =>
      PaymentModel(
        id: id,
        fromUserId: m['fromUserId'] as String,
        toUserId: m['toUserId'] as String,
        amount: (m['amount'] as num).toDouble(),
        timestamp: m['timestamp'] is Timestamp
            ? (m['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
        note: m['note'] as String? ?? 'Payment',
      );
}
