class FinancialTransaction {
  final String id;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String audioFileName;
  final int quantity;
  final double unitPrice;

  FinancialTransaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    required this.audioFileName,
    this.quantity = 1,
    double? unitPrice,
  }) : unitPrice = unitPrice ?? amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category,
    'description': description,
    'date': date.toIso8601String(),
    'audioFileName': audioFileName,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) => FinancialTransaction(
    id: json['id'],
    amount: json['amount'].toDouble(),
    category: json['category'],
    description: json['description'],
    date: DateTime.parse(json['date']),
    audioFileName: json['audioFileName'],
    quantity: json['quantity'] ?? 1,
    unitPrice: json['unitPrice']?.toDouble(),
  );

  String get formattedQuantity => quantity > 1 ? '${quantity}x ' : '';
  String get displayText => '${formattedQuantity}${description}';
  String get priceBreakdown => quantity > 1 ? '${quantity}x ₹${unitPrice.toInt()}' : '₹${amount.toInt()}';
}