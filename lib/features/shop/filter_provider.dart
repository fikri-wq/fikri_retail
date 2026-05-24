import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../models/product_model.dart';
import 'product_provider.dart';
import '../../services/supabase_service.dart';

// State for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// State for selected category name (e.g. "Sembako")
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Fetch categories from Supabase
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseService.client.from('categories').select();
  return List<Map<String, dynamic>>.from(response);
});

// A combined provider that returns filtered products
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final categoriesAsync = ref.watch(categoriesProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
  final selectedCategoryName = ref.watch(selectedCategoryProvider);

  return productsAsync.whenData((products) {
    String? selectedCategoryId;
    
    // If a category is selected, try to find its UUID
    if (selectedCategoryName != null && categoriesAsync is AsyncData) {
      final categories = categoriesAsync.value!;
      final match = categories.firstWhere(
        (cat) => cat['name'] == selectedCategoryName,
        orElse: () => <String, dynamic>{},
      );
      selectedCategoryId = match['id'];
    }

    return products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(searchQuery) || 
                            product.description.toLowerCase().contains(searchQuery);
      
      bool matchesCategory = false;
      if (selectedCategoryName == null) {
        matchesCategory = true;
      } else if (product.categoryId != null && product.categoryId == selectedCategoryId) {
        matchesCategory = true;
      } else {
        // Fallback cerdas pencocokan nama produk jika categoryId kosong di database
        final nameLower = product.name.toLowerCase();
        if (selectedCategoryName == 'Produk Online') {
          matchesCategory = true; // Produk online menampilkan semua produk
        } else if (selectedCategoryName == 'Minyak' && (nameLower.contains('bimoli') || nameLower.contains('filma') || nameLower.contains('minyak'))) {
          matchesCategory = true;
        } else if (selectedCategoryName == 'Mie Instan' && (nameLower.contains('indomie') || nameLower.contains('sarimi') || nameLower.contains('pop mie') || nameLower.contains('supermi') || nameLower.contains('ramen'))) {
          matchesCategory = true;
        } else if (selectedCategoryName == 'Bumbu' && (nameLower.contains('bumbu') || nameLower.contains('sambal') || nameLower.contains('kecap'))) {
          matchesCategory = true;
        } else if (selectedCategoryName == 'Susu' && (nameLower.contains('susu') || nameLower.contains('indomilk') || nameLower.contains('kremer') || nameLower.contains('enaak'))) {
          matchesCategory = true;
        } else if (selectedCategoryName == 'Snack' && (nameLower.contains('chitato') || nameLower.contains('lays') || nameLower.contains('qtela') || nameLower.contains('cheetos') || nameLower.contains('trenz') || nameLower.contains('snack') || nameLower.contains('chiki'))) {
          matchesCategory = true;
        } else if (selectedCategoryName == 'Sembako' && (nameLower.contains('beras') || nameLower.contains('gula') || nameLower.contains('tepung'))) {
          matchesCategory = true;
        } else if (selectedCategoryName == 'Minuman' && (nameLower.contains('air') || nameLower.contains('syrup') || nameLower.contains('ocha') || nameLower.contains('tekita') || nameLower.contains('club') || nameLower.contains('mineral') || nameLower.contains('drink') || nameLower.contains('teh'))) {
          matchesCategory = true;
        } else if (selectedCategoryName == 'Kebut. Rumah' && (nameLower.contains('tissue') || nameLower.contains('paseo') || nameLower.contains('sabun') || nameLower.contains('shampoo'))) {
          matchesCategory = true;
        } else if (selectedCategoryName == 'Lainnya') {
          final isKnown = (nameLower.contains('bimoli') || nameLower.contains('filma') || nameLower.contains('minyak')) ||
                          (nameLower.contains('indomie') || nameLower.contains('sarimi') || nameLower.contains('pop mie') || nameLower.contains('supermi') || nameLower.contains('ramen')) ||
                          (nameLower.contains('bumbu') || nameLower.contains('sambal') || nameLower.contains('kecap')) ||
                          (nameLower.contains('susu') || nameLower.contains('indomilk') || nameLower.contains('kremer') || nameLower.contains('enaak')) ||
                          (nameLower.contains('chitato') || nameLower.contains('lays') || nameLower.contains('qtela') || nameLower.contains('cheetos') || nameLower.contains('trenz') || nameLower.contains('snack') || nameLower.contains('chiki')) ||
                          (nameLower.contains('beras') || nameLower.contains('gula') || nameLower.contains('tepung')) ||
                          (nameLower.contains('air') || nameLower.contains('syrup') || nameLower.contains('ocha') || nameLower.contains('tekita') || nameLower.contains('club') || nameLower.contains('mineral') || nameLower.contains('drink') || nameLower.contains('teh')) ||
                          (nameLower.contains('tissue') || nameLower.contains('paseo') || nameLower.contains('sabun') || nameLower.contains('shampoo'));
          if (!isKnown) matchesCategory = true;
        }
      }
      
      return matchesSearch && matchesCategory;
    }).toList();
  });
});
