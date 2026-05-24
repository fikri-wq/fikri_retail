import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static final _picker = ImagePicker();

  /// Fungsi untuk memilih gambar dan langsung mengunggahnya ke Supabase
  static Future<String?> uploadProductImage() async {
    try {
      // 1. Pilih Gambar dari Galeri
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Kompres agar tidak terlalu berat
      );

      if (image == null) return null;

      // 2. Buat nama file unik (Pake Timestamp agar tidak bentrok)
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'product_images/$fileName';

      // 3. Upload ke Supabase
      if (kIsWeb) {
        // Khusus Web
        final bytes = await image.readAsBytes();
        await SupabaseService.client.storage
            .from('product-images')
            .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      } else {
        // Khusus Mobile (Android/iOS)
        final file = File(image.path);
        await SupabaseService.client.storage
            .from('product-images')
            .upload(path, file);
      }

      // 4. Ambil Link Public-nya
      final imageUrl = SupabaseService.client.storage
          .from('product-images')
          .getPublicUrl(path);

      return imageUrl;
    } catch (e) {
      if (e is StorageException) {
        debugPrint('Supabase Storage Error: ${e.message}');
      } else {
        debugPrint('Error upload: $e');
      }
      rethrow; // Biarkan UI menangkap error agar bisa menampilkan SnackBar
    }
  }
}
