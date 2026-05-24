import 'dart:convert';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String? categoryId;
  final String? imageUrl;
  final List<double>? embedding;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.categoryId,
    this.imageUrl,
    this.embedding,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    // Membaca data embedding cerdas (Bisa handle String maupun List asli)
    List<double>? parsedEmbedding;
    if (map['embedding'] != null) {
      if (map['embedding'] is String) {
        // Parse JSON String "[0.0, 0.0...]" jadi List betulan
        parsedEmbedding = (jsonDecode(map['embedding']) as List).map((e) => (e as num).toDouble()).toList();
      } else if (map['embedding'] is List) {
        parsedEmbedding = (map['embedding'] as List).map((e) => (e as num).toDouble()).toList();
      }
    }

    return Product(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      price: (map['price'] as num).toDouble(),
      stock: map['stock'] ?? 0,
      categoryId: map['category_id'],
      imageUrl: map['image_url'],
      embedding: parsedEmbedding,
    );
  }
}
