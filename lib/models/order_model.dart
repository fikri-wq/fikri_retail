class OrderModel {
  final String id;
  final String userId;
  final double totalAmount;
  final String status;
  final double? latLocation;
  final double? lngLocation;
  final String? address;
  final DateTime createdAt;
  final String? customerName;
  final List<Map<String, dynamic>>? items;
  final String? paymentReceiptUrl;

  OrderModel({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.status,
    this.latLocation,
    this.lngLocation,
    this.address,
    required this.createdAt,
    this.customerName,
    this.items,
    this.paymentReceiptUrl,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>>? parsedItems;
    if (map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return OrderModel(
      id: map['id'].toString(),
      userId: map['customer_id'] ?? '',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      latLocation: map['lat_location'] != null ? (map['lat_location'] as num).toDouble() : null,
      lngLocation: map['lng_location'] != null ? (map['lng_location'] as num).toDouble() : null,
      address: map['address'],
      createdAt: DateTime.parse(map['created_at']),
      customerName: map['_customer_name'] 
          ?? (map['profiles'] != null ? map['profiles']['full_name'] : null)
          ?? 'Unknown',
      items: parsedItems,
      paymentReceiptUrl: map['payment_receipt_url'],
    );
  }
}
