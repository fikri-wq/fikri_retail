import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;

import '../shop/product_provider.dart';
import '../order/order_provider.dart';
import '../order/order_chat_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../seed_data.dart'; // IMPORT SEED DATA
import '../../seed_data_new.dart'; // IMPORT SEED DATA BARU (414 produk)
import '../../main.dart' show AppColors, WavePatternPainter;

// Provider untuk mengambil semua user (Hanya untuk Admin)
final allUsersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final response = await SupabaseService.client
      .from('profiles')
      .select()
      .order('full_name', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  bool _isSeeding = false;


  Future<void> _seedDatabase(WidgetRef ref) async {
    setState(() { _isSeeding = true; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mulai memasukkan produk + embedding...')));
    try {
      int success = 0;
      int failed = 0;

      // Seed produk lama (sudah punya embedding)
      for (var product in seedProducts) {
        try {
          await SupabaseService.client.from('products').insert(product);
          success++;
        } catch(e) {
          debugPrint('Gagal insert lama: $e');
          failed++;
        }
      }

      // Seed produk baru (generate embedding via Edge Function)
      for (var product in seedProductsNew) {
        try {
          final textToEmbed = "${product['name']} - ${product['description']}";
          List<dynamic>? embeddingVector;

          // Generate embedding via Edge Function
          try {
            final functionResponse = await SupabaseService.client.functions.invoke(
              'generate-embedding',
              body: {'input': textToEmbed},
            );
            if (functionResponse.status == 200) {
              embeddingVector = functionResponse.data['embedding'];
            }
          } catch (e) {
            debugPrint('⚠️ Embedding gagal untuk ${product['name']}: $e');
          }

          final insertData = Map<String, dynamic>.from(product);
          if (embeddingVector != null) {
            insertData['embedding'] = embeddingVector;
          }

          await SupabaseService.client.from('products').insert(insertData);
          success++;
        } catch(e) {
          debugPrint('Gagal insert new: $e');
          failed++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Selesai! $success berhasil, $failed gagal.')),
        );
      }
      ref.invalidate(productsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error seeding: $e')));
      }
    } finally {
      setState(() { _isSeeding = false; });
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const ProductListTab();
      case 1:
        return const OrderListTab();
      default:
        return const ProductListTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.appBarGradient,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: WavePatternPainter(opacity: 0.12),
              ),
            ),
          ],
        ),
        title: Text(
          _currentIndex == 0 ? 'Kelola Produk' : 'Daftar Pesanan',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          if (_currentIndex == 0) ...[
            Consumer(
              builder: (context, ref, child) {
                return _isSeeding
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Seed Database',
                        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                        onPressed: () => _seedDatabase(ref),
                      );
              },
            ),
          ],
          IconButton(
            onPressed: () => AuthService.signOut(),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade500,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Produk',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Pesanan',
            ),
          ],
        ),
      ),
    );
  }
}

class ProductListTab extends ConsumerWidget {
  const ProductListTab({super.key});

  // Auto-detect kategori berdasarkan nama produk
  static String? _detectCategory(String productName) {
    final name = productName.toLowerCase();
    if (name.contains('bimoli') || name.contains('filma') || name.contains('minyak') || name.contains('sania') || name.contains('tropical')) {
      return 'Minyak';
    } else if (name.contains('indomie') || name.contains('sarimi') || name.contains('pop mie') || name.contains('supermi') || name.contains('ramen') || name.contains('mie ')) {
      return 'Mie Instan';
    } else if (name.contains('bumbu') || name.contains('sambal') || name.contains('kecap') || name.contains('saos') || name.contains('royco') || name.contains('masako')) {
      return 'Bumbu';
    } else if (name.contains('susu') || name.contains('indomilk') || name.contains('kremer') || name.contains('enaak') || name.contains('dancow') || name.contains('frisian')) {
      return 'Susu';
    } else if (name.contains('chitato') || name.contains('lays') || name.contains('qtela') || name.contains('cheetos') || name.contains('trenz') || name.contains('snack') || name.contains('chiki') || name.contains('oreo') || name.contains('wafer')) {
      return 'Snack';
    } else if (name.contains('beras') || name.contains('gula') || name.contains('tepung') || name.contains('garam') || name.contains('telur')) {
      return 'Sembako';
    } else if (name.contains('air') || name.contains('syrup') || name.contains('ocha') || name.contains('tekita') || name.contains('club') || name.contains('mineral') || name.contains('drink') || name.contains('teh') || name.contains('kopi') || name.contains('aqua')) {
      return 'Minuman';
    } else if (name.contains('tissue') || name.contains('paseo') || name.contains('sabun') || name.contains('shampoo') || name.contains('deterjen') || name.contains('rinso') || name.contains('molto')) {
      return 'Kebut. Rumah';
    }
    return null; // Tidak terdeteksi
  }

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    String? uploadedImageUrl;
    bool isUploading = false;
    bool isSaving = false;
    String? selectedCategoryId;
    String? detectedCategoryName;
    List<Map<String, dynamic>> categories = [];

    // Load categories from Supabase
    SupabaseService.client.from('categories').select().then((response) {
      categories = List<Map<String, dynamic>>.from(response);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header dengan gradient
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_box_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tambah Produk Baru',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                if (uploadedImageUrl != null)
                  Container(
                    height: 160,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(uploadedImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ElevatedButton.icon(
                  onPressed: (isUploading || isSaving)
                      ? null
                      : () async {
                          try {
                            setState(() => isUploading = true);
                            final url =
                                await StorageService.uploadProductImage();
                            setState(() {
                              uploadedImageUrl = url;
                              isUploading = false;
                            });
                          } catch (e) {
                            setState(() => isUploading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Upload Gagal: $e')),
                              );
                            }
                          }
                        },
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    isUploading ? 'Mengunggah...' : 'Pilih & Upload Gambar',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Produk',
                    icon: Icon(Icons.shopping_bag),
                  ),
                  onChanged: (value) {
                    // Auto-detect kategori saat nama diketik
                    final detected = _detectCategory(value);
                    if (detected != null && categories.isNotEmpty) {
                      final match = categories.firstWhere(
                        (cat) => cat['name'] == detected,
                        orElse: () => <String, dynamic>{},
                      );
                      if (match.isNotEmpty) {
                        setState(() {
                          selectedCategoryId = match['id'];
                          detectedCategoryName = detected;
                        });
                      }
                    }
                  },
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Singkat',
                    icon: Icon(Icons.description),
                  ),
                ),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga (Rp)',
                    icon: Icon(Icons.monetization_on),
                  ),
                ),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stok Awal',
                    icon: Icon(Icons.inventory),
                  ),
                ),
                const SizedBox(height: 12),
                // Dropdown Kategori
                Row(
                  children: [
                    const Icon(Icons.category, color: Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          helperText: detectedCategoryName != null
                              ? '✨ Auto: $detectedCategoryName'
                              : null,
                          helperStyle: const TextStyle(color: Colors.green, fontSize: 11),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('-- Pilih Kategori --', style: TextStyle(color: Colors.grey)),
                          ),
                          ...categories.map((cat) => DropdownMenuItem<String>(
                            value: cat['id'],
                            child: Text(cat['name']),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCategoryId = value;
                            detectedCategoryName = null; // User override manual
                          });
                        },
                      ),
                    ),
                  ],
                ),
                    ],
                  ),
                ),
                ),
                // Actions section (Cancel + Save)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
            Expanded(
              child: TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: (isUploading || uploadedImageUrl == null || isSaving)
                      ? null
                      : AppColors.primaryGradient,
                  color: (isUploading || uploadedImageUrl == null || isSaving) ? Colors.grey.shade300 : null,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: (isUploading || uploadedImageUrl == null || isSaving) ? null : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              onPressed: (isUploading || uploadedImageUrl == null || isSaving)
                  ? null
                  : () async {
                      setState(() => isSaving = true);
                      try {
                        final textToEmbed = "${nameCtrl.text} - ${descCtrl.text}";
                        List<dynamic>? embeddingVector;

                        // --- MENGGUNAKAN SUPABASE EDGE FUNCTION ---
                        final functionResponse = await SupabaseService
                            .client
                            .functions
                            .invoke(
                              'generate-embedding',
                              body: {'input': textToEmbed},
                            );

                        if (functionResponse.status == 200) {
                          embeddingVector = functionResponse.data['embedding'];
                        } else {
                          throw Exception(
                            "Error Supabase Function: ${functionResponse.data}",
                          );
                        }

                        // 2. Insert ke Supabase beserta vektornya
                        await SupabaseService.client.from('products').insert({
                          'name': nameCtrl.text,
                          'description': descCtrl.text,
                          'price':
                              double.tryParse(
                                priceCtrl.text.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                ),
                              ) ??
                              0,
                          'stock': int.tryParse(stockCtrl.text) ?? 1,
                          'image_url': uploadedImageUrl,
                          'embedding': embeddingVector,
                          'category_id': selectedCategoryId,
                        });

                        if (context.mounted) Navigator.pop(context);
                        ref.invalidate(productsProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '✅ Produk & AI Embedding berhasil ditambahkan!',
                            ),
                          ),
                        );
                      } catch (e) {
                        setState(() => isSaving = false);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Simpan Produk',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
              ),
            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, WidgetRef ref, Product product) {
    final nameCtrl = TextEditingController(text: product.name);
    final descCtrl = TextEditingController(text: product.description);
    final priceCtrl = TextEditingController(text: product.price.toInt().toString());
    final stockCtrl = TextEditingController(text: product.stock.toString());
    String? uploadedImageUrl = product.imageUrl;
    bool isUploading = false;
    bool isSaving = false;
    String? selectedCategoryId = product.categoryId;
    List<Map<String, dynamic>> categories = [];

    // Load categories
    SupabaseService.client.from('categories').select().then((response) {
      categories = List<Map<String, dynamic>>.from(response);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header dengan gradient
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit Produk',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                if (uploadedImageUrl != null)
                  Container(
                    height: 160,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: uploadedImageUrl!.startsWith('assets/')
                            ? AssetImage(uploadedImageUrl!) as ImageProvider
                            : NetworkImage(uploadedImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ElevatedButton.icon(
                  onPressed: (isUploading || isSaving)
                      ? null
                      : () async {
                          try {
                            setState(() => isUploading = true);
                            final url = await StorageService.uploadProductImage();
                            setState(() {
                              uploadedImageUrl = url;
                              isUploading = false;
                            });
                          } catch (e) {
                            setState(() => isUploading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Upload Gagal: $e')),
                              );
                            }
                          }
                        },
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    isUploading ? 'Mengunggah...' : 'Ganti Gambar',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Produk',
                    icon: Icon(Icons.shopping_bag),
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Singkat',
                    icon: Icon(Icons.description),
                  ),
                ),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga (Rp)',
                    icon: Icon(Icons.monetization_on),
                  ),
                ),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stok',
                    icon: Icon(Icons.inventory),
                  ),
                ),
                const SizedBox(height: 12),
                // Dropdown Kategori
                Row(
                  children: [
                    const Icon(Icons.category, color: Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('-- Pilih Kategori --', style: TextStyle(color: Colors.grey)),
                          ),
                          ...categories.map((cat) => DropdownMenuItem<String>(
                            value: cat['id'],
                            child: Text(cat['name']),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCategoryId = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                    ],
                  ),
                ),
                ),
                // Actions section
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
            Expanded(
              child: TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: (isUploading || uploadedImageUrl == null || isSaving)
                      ? null
                      : AppColors.primaryGradient,
                  color: (isUploading || uploadedImageUrl == null || isSaving) ? Colors.grey.shade300 : null,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: (isUploading || uploadedImageUrl == null || isSaving) ? null : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              onPressed: (isUploading || uploadedImageUrl == null || isSaving)
                  ? null
                  : () async {
                      setState(() => isSaving = true);
                      try {
                        final textToEmbed = "${nameCtrl.text} - ${descCtrl.text}";
                        List<dynamic>? embeddingVector;

                        // Generate embedding baru
                        final functionResponse = await SupabaseService
                            .client.functions
                            .invoke('generate-embedding', body: {'input': textToEmbed});

                        if (functionResponse.status == 200) {
                          embeddingVector = functionResponse.data['embedding'];
                        } else {
                          throw Exception("Error AI: ${functionResponse.data}");
                        }

                        // Update ke Supabase
                        await SupabaseService.client.from('products').update({
                          'name': nameCtrl.text,
                          'description': descCtrl.text,
                          'price': double.tryParse(priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                          'stock': int.tryParse(stockCtrl.text) ?? 1,
                          'image_url': uploadedImageUrl,
                          'embedding': embeddingVector,
                          'category_id': selectedCategoryId,
                        }).eq('id', product.id);

                        if (context.mounted) Navigator.pop(context);
                        ref.invalidate(productsProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Produk berhasil di edit!')),
                        );
                      } catch (e) {
                        setState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal: $e')),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Simpan Perubahan',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
              ),
            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

    Widget buildStockBadge(int stock) {
      Color color;
      String text;
      if (stock == 0) {
        color = Colors.red;
        text = 'Stok Habis ❌';
      } else if (stock <= 5) {
        color = Colors.orange;
        text = 'Menipis ($stock) ⚠️';
      } else {
        color = Colors.green;
        text = 'Stok Aman ($stock) ✓';
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddProductDialog(context, ref),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Tambah Produk',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('Belum ada produk terdaftar.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(productsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (p.imageUrl != null && p.imageUrl!.startsWith('assets/'))
                              ? Image.asset(
                                  p.imageUrl!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: AppColors.primaryPale, child: const Icon(Icons.broken_image, color: AppColors.primary)),
                                )
                              : Image.network(
                                  p.imageUrl ?? '',
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(width: 64, height: 64, color: AppColors.primaryPale, child: const Icon(Icons.broken_image, color: AppColors.primary)),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormatter.format(p.price), 
                                style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)
                              ),
                              const SizedBox(height: 8),
                              buildStockBadge(p.stock),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                              onPressed: () => _showEditProductDialog(context, ref, p),
                              tooltip: 'Edit Produk',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Hapus Produk?'),
                                    content: Text('Apakah Anda yakin ingin menghapus ${p.name}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await SupabaseService.client.from('products').delete().eq('id', p.id);
                                          ref.invalidate(productsProvider);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('✅ Produk berhasil dihapus!')),
                                            );
                                          }
                                        },
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              tooltip: 'Hapus Produk',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class UserListTab extends ConsumerWidget {
  const UserListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    Widget buildRoleBadge(String role) {
      final isAdmin = role == 'admin';
      if (isAdmin) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark], // Blue & Green mixture
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent, width: 1.5), // Golden Yellow border
          ),
          child: const Text(
            'ADMIN 👑',
            style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, Color(0xFFFBC02D)], // Green & Yellow mixture
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary, width: 1.5), // Blue border
          ),
          child: const Text(
            'CUSTOMER 👤',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('Belum ada user terdaftar.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(allUsersProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final String role = user['role'];
                final String fullName = user['full_name'] ?? 'No Name';
                final String initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: role == 'admin' 
                                  ? [AppColors.primary, AppColors.accent] // Blue & Yellow mixture
                                  : [AppColors.primaryDark, AppColors.accent], // Green & Yellow mixture
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            child: Text(
                              initial, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              buildRoleBadge(role),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final newRole = role == 'admin' ? 'customer' : 'admin';
                            await SupabaseService.client
                                .from('profiles')
                                .update({'role': newRole})
                                .eq('id', user['id']);
                            ref.invalidate(allUsersProvider);
                          },
                          icon: Icon(
                            role == 'admin' ? Icons.remove_circle_outline : Icons.shield_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: Text(
                            role == 'admin' ? 'Jadikan Customer' : 'Jadikan Admin',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: role == 'admin' ? Colors.red.shade600 : Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class OrderListTab extends ConsumerStatefulWidget {
  const OrderListTab({super.key});

  @override
  ConsumerState<OrderListTab> createState() => _OrderListTabState();
}

class _OrderListTabState extends ConsumerState<OrderListTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color getStatusColor(String s) {
    if (s == 'pending') return Colors.orange;
    if (s == 'delivered') return Colors.green;
    if (s == 'cancelled') return Colors.red;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.today),
                text: 'Hari Ini & Aktif',
              ),
              Tab(
                icon: Icon(Icons.analytics_outlined),
                text: 'Laporan Bulanan',
              ),
            ],
          ),
        ),
        Expanded(
          child: ordersAsync.when(
            data: (orders) {
              // 1. Filter orders: hanya yang BELUM selesai (aktif)
              final todayOrders = orders.where((o) {
                return o.status != 'delivered' && o.status != 'cancelled';
              }).toList();

              // 2. Filter historical delivered/cancelled orders for Monthly Reports
              final pastOrders = orders.where((o) {
                return o.status == 'delivered' || o.status == 'cancelled';
              }).toList();

              // Group historical/past orders by "Month Year" (Indonesian names)
              final Map<String, List<OrderModel>> monthlyGroups = {};
              final months = [
                'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
                'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
              ];
              for (var o in pastOrders) {
                final key = "${months[o.createdAt.month - 1]} ${o.createdAt.year}";
                monthlyGroups.putIfAbsent(key, () => []).add(o);
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Hari Ini & Aktif
                  _buildTodayTab(todayOrders),

                  // Tab 2: Laporan Bulanan
                  _buildMonthlyReportTab(monthlyGroups),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayTab(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Semua pesanan selesai! 🌟', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)
            ),
            SizedBox(height: 8),
            Text(
              'Halaman pesanan hari ini bersih & rapi.', 
              style: TextStyle(fontSize: 13, color: Colors.grey)
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminOrdersProvider);
      },
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final o = orders[index];
          return _buildOrderCard(o);
        },
      ),
    );
  }

  Widget _buildMonthlyReportTab(Map<String, List<OrderModel>> monthlyGroups) {
    if (monthlyGroups.isEmpty) {
      return const Center(
        child: Text('Belum ada riwayat transaksi bulanan.', style: TextStyle(color: Colors.grey)),
      );
    }

    final keys = monthlyGroups.keys.toList();
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminOrdersProvider);
      },
      child: ListView.builder(
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final monthName = keys[index];
          final monthOrders = monthlyGroups[monthName]!;

          // Calculate statistics
          final totalTransactions = monthOrders.length;
          final successfulOrders = monthOrders.where((o) => o.status == 'delivered').toList();
          final cancelledOrders = monthOrders.where((o) => o.status == 'cancelled').toList();
          final totalRevenue = successfulOrders.fold<double>(0, (sum, o) => sum + o.totalAmount);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: const Icon(Icons.summarize, color: AppColors.primary),
              title: Text(
                monthName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                'Omset: Rp ${currencyFormatter.format(totalRevenue).replaceAll('Rp', '')} | $totalTransactions Transaksi',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Total Omset', currencyFormatter.format(totalRevenue), Colors.green),
                        _buildStatItem('Selesai', '${successfulOrders.length}', Colors.blue),
                        _buildStatItem('Batal', '${cancelledOrders.length}', Colors.red),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                // Download button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadReport(monthName, monthOrders),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        'Download Laporan $monthName (CSV)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                // Show order items in this month
                ...monthOrders.map((o) => ListTile(
                  dense: true,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(o.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        currencyFormatter.format(o.totalAmount),
                        style: TextStyle(
                          color: o.status == 'delivered' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Tanggal: ${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year} | Status: ${o.status.toUpperCase()}',
                    style: const TextStyle(fontSize: 11),
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }

  void _downloadReport(String monthName, List<OrderModel> orders) {
    try {
      final successfulOrders = orders.where((o) => o.status == 'delivered').toList();
      final cancelledOrders = orders.where((o) => o.status == 'cancelled').toList();
      final totalRevenue = successfulOrders.fold<double>(0, (sum, o) => sum + o.totalAmount);

      final now = DateTime.now();
      final nowStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

      // Build CSV content
      final buffer = StringBuffer();
      buffer.writeln('LAPORAN PENJUALAN - YETI SMART RETAIL');
      buffer.writeln('Periode:,$monthName');
      buffer.writeln('Tanggal Cetak:,$nowStr');
      buffer.writeln('');
      buffer.writeln('RINGKASAN');
      buffer.writeln('Total Transaksi,${orders.length}');
      buffer.writeln('Pesanan Selesai,${successfulOrders.length}');
      buffer.writeln('Pesanan Batal,${cancelledOrders.length}');
      buffer.writeln('Total Omset,Rp ${totalRevenue.toInt()}');
      buffer.writeln('');
      buffer.writeln('DETAIL TRANSAKSI');
      buffer.writeln('No,Tanggal,Customer,Status,Metode,Items,Total');

      for (var i = 0; i < orders.length; i++) {
        final o = orders[i];
        final d = o.createdAt;
        final date = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
        final customer = (o.customerName ?? 'Customer').replaceAll(',', ' ');
        final status = o.status.toUpperCase();
        final metode = o.address?.contains('Delivery') == true ? 'Delivery' : 'Pick Up';

        String items = '-';
        if (o.items != null && o.items!.isNotEmpty) {
          items = o.items!.map((item) => '${item['name']} x${item['quantity']}').join(' | ');
          items = items.replaceAll(',', ';');
        }

        buffer.writeln('${i + 1},$date,$customer,$status,$metode,"$items",Rp ${o.totalAmount.toInt()}');
      }

      // Download sebagai CSV via Web API
      final bytes = utf8.encode(buffer.toString());
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'Laporan_${monthName.replaceAll(' ', '_')}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Laporan $monthName berhasil didownload!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal download: $e')),
        );
      }
    }
  }

  Widget _buildOrderCard(OrderModel o) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: getStatusColor(o.status)),
                    const SizedBox(width: 8),
                    Text(
                      o.customerName ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getStatusColor(o.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    o.status.toUpperCase(),
                    style: TextStyle(color: getStatusColor(o.status), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const Divider(),
             Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    o.address ?? "-", 
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                if (o.latLocation != null && o.lngLocation != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${o.latLocation},${o.lngLocation}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.green.shade50,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Buka Peta 📍', 
                            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Text('Daftar Barang:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            if (o.items != null)
              ...o.items!.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: (item['image_url'] != null && item['image_url'].toString().startsWith('assets/'))
                            ? Image.asset(
                                item['image_url'],
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48, height: 48, color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                ),
                              )
                            : Image.network(
                                item['image_url'] ?? '',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48, height: 48, color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                ),
                              ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'] ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${item['quantity']}x Rp ${item['price']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Text(
                          'Rp ${item['price'] * item['quantity']}', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)
                        ),
                      ],
                    ),
                  )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pendapatan', style: TextStyle(fontSize: 13, color: Colors.grey)),
                Text(
                  'Rp ${o.totalAmount}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                ),
              ],
            ),
            if (o.paymentReceiptUrl != null) ...[
              const SizedBox(height: 16),
              const Text('Bukti Transaksi (Tap untuk perbesar):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(o.paymentReceiptUrl!),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      o.paymentReceiptUrl!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Chat button
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderChatScreen(orderId: o.id, isAdmin: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_rounded, color: AppColors.primary, size: 20),
                  tooltip: 'Chat Customer',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                if (o.status == 'pending')
                  ElevatedButton(
                    onPressed: () async {
                      await updateOrderStatus(o.id, 'processing');
                      ref.invalidate(adminOrdersProvider);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('Validasi & Proses', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                if (o.status == 'processing')
                  ElevatedButton(
                    onPressed: () async {
                      await updateOrderStatus(o.id, 'shipped');
                      ref.invalidate(adminOrdersProvider);
                      if (o.address?.toLowerCase().contains('delivery') ?? false) {
                        if (o.latLocation != null && o.lngLocation != null) {
                          await openMap(o.latLocation!, o.lngLocation!);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    child: Text(
                      (o.address?.toLowerCase().contains('delivery') ?? false)
                          ? 'Kirim Via GPS'
                          : 'Barang Siap Diambil',
                      style: const TextStyle(color: Colors.white, fontSize: 12)
                    ),
                  ),
                if (o.status == 'shipped')
                  ElevatedButton(
                    onPressed: () async {
                      await updateOrderStatus(o.id, 'delivered');
                      ref.invalidate(adminOrdersProvider);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Selesaikan Pesanan', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                if (o.status == 'delivered' || o.status == 'cancelled')
                  Text(
                    o.status == 'delivered' ? '✅ Selesai' : '❌ Dibatalkan',
                    style: TextStyle(color: getStatusColor(o.status), fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
