import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../services/midtrans_service.dart';
import '../../models/product_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'order_provider.dart';
import 'payment_success_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  /// Untuk checkout single product (dari tombol "Beli Sekarang")
  final Product? product;

  /// Untuk checkout dari keranjang (list item dari carts table)
  final List<Map<String, dynamic>>? cartItems;

  const CheckoutScreen({super.key, this.product, this.cartItems})
      : assert(product != null || cartItems != null,
            'Harus menyediakan product atau cartItems');

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoadingLocation = false;
  String _deliveryMethod = 'Delivery';
  String? _selectedPayment;
  final TextEditingController _notesController = TextEditingController();
  
  XFile? _receiptImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // Requirement 2.5: Simpan order_id di state lokal sesi checkout
  // Digunakan untuk polling atau pengecekan status pasca-pembayaran.
  // ignore: unused_field
  String? _currentOrderId;

  // MidtransService instance
  final MidtransService _midtransService = MidtransService();

  /// Menghasilkan UUID v4 secara lokal menggunakan dart:math.
  /// Digunakan untuk pre-generate order_id sebelum memanggil Midtrans.
  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _receiptImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  // Requirement 6.4: Dua pilihan metode pembayaran
  // Midtrans: satu tombol, user memilih metode spesifik di halaman Midtrans
  // COD: bayar di tempat
  final List<Map<String, dynamic>> _midtransPaymentMethods = [
    {'id': 'midtrans', 'name': 'Bayar via Midtrans', 'icon': Icons.payment},
  ];

  final List<Map<String, dynamic>> _codPaymentMethods = [
    {'id': 'COD', 'name': 'Bayar di Tempat (COD)', 'icon': Icons.payments},
  ];

  // Requirement 6.2, 6.3: Helper untuk menentukan tipe pembayaran yang dipilih
  bool get _isMidtransPayment => _selectedPayment != null && _selectedPayment != 'COD';
  bool get _isCOD => _selectedPayment == 'COD';

  bool get _isCartCheckout =>
      widget.cartItems != null && widget.cartItems!.isNotEmpty;

  /// Hitung total harga semua item
  double get _subtotal {
    if (_isCartCheckout) {
      double total = 0;
      for (var item in widget.cartItems!) {
        total += (item['products']['price'] * item['quantity']);
      }
      return total;
    }
    return widget.product!.price;
  }

  int get _totalItems {
    if (_isCartCheckout) {
      return widget.cartItems!.length;
    }
    return 1;
  }

  double get _deliveryFee => _deliveryMethod == 'Delivery' ? 10000 : 0;

  double get _totalPayment => _subtotal + 1000 + _deliveryFee;

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      String? address;

      // 1. Coba Nominatim (OpenStreetMap) - bisa cari nama tempat (POI) seperti "Kosan Pak Agus"
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=${position.latitude}'
          '&lon=${position.longitude}'
          '&zoom=18'
          '&addressdetails=1'
          '&accept-language=id',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'YetiSmartRetail/1.0'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          // Prioritas: nama tempat (POI) > display_name > alamat
          final name = data['name']?.toString();
          final displayName = data['display_name']?.toString();
          final addr = data['address'] as Map<String, dynamic>?;

          if (name != null && name.isNotEmpty) {
            // Ada nama tempat spesifik (mis. "Kosan Pak Agus", "Warung Bu Tini")
            // Tambahkan konteks jalan/area untuk informasi yang lebih lengkap
            final road = addr?['road'] ?? addr?['pedestrian'] ?? '';
            final suburb = addr?['suburb'] ?? addr?['village'] ?? addr?['neighbourhood'] ?? '';
            final parts = <String>[name];
            if (road.toString().isNotEmpty) parts.add(road.toString());
            if (suburb.toString().isNotEmpty) parts.add(suburb.toString());
            address = parts.join(', ');
          } else if (displayName != null && displayName.isNotEmpty) {
            // Pakai display_name (alamat lengkap dari OSM)
            // Ambil 3-4 segmen pertama agar tidak terlalu panjang
            final segments = displayName.split(', ');
            address = segments.take(4).join(', ');
          }
        }
      } catch (e) {
        debugPrint('Nominatim gagal: $e');
      }

      // 2. Fallback ke geocoding package (untuk mobile saja, tidak jalan di web)
      if (address == null && !kIsWeb) {
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = <String>[
              if (p.name != null && p.name!.isNotEmpty && p.name != p.street) p.name!,
              if (p.street != null && p.street!.isNotEmpty) p.street!,
              if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
              if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            ];
            address = parts.join(', ');
          }
        } catch (e) {
          debugPrint('placemarkFromCoordinates gagal: $e');
        }
      }

      // 3. Fallback terakhir: koordinat
      address ??= 'Lokasi GPS terekam (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';

      setState(() {
        _currentPosition = position;
        _currentAddress = address;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Widget gambar yang support local asset & network
  Widget _buildProductImage(String? imageUrl,
      {double width = 70, double height = 70}) {
    if (imageUrl != null && imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Container(width: width, height: height, color: Colors.grey[300]),
      );
    }
    return Image.network(
      imageUrl ?? 'https://via.placeholder.com/150',
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(width: width, height: height, color: Colors.grey[300]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Checkout',
            style: TextStyle(color: Colors.black87, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metode Pengiriman
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping, color: Theme.of(context).colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          const Text('Metode Pengiriman',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Delivery', style: TextStyle(fontSize: 13)),
                              value: 'Delivery',
                              groupValue: _deliveryMethod,
                              activeColor: Theme.of(context).colorScheme.primary,
                              onChanged: (val) => setState(() => _deliveryMethod = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Pick Up', style: TextStyle(fontSize: 13)),
                              value: 'Pick Up',
                              groupValue: _deliveryMethod,
                              activeColor: Theme.of(context).colorScheme.primary,
                              onChanged: (val) => setState(() => _deliveryMethod = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Alamat Pengiriman
                if (_deliveryMethod == 'Delivery')
                  Container(
                    color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        height: 3,
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Colors.redAccent, Colors.blueAccent])),
                      ),
                      InkWell(
                        onTap: _getLocation,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Titik Jemput Pengiriman',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 4),
                                    _isLoadingLocation
                                        ? const Text('Mencari lokasi...',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey))
                                        : _currentPosition == null
                                            ? const Text(
                                                'Ketuk untuk pilih lokasi GPS',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey))
                                            : Text(
                                                _currentAddress ?? 'Lokasi jemput Anda sudah terekam.',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87,
                                                    height: 1.4)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Catatan Tambahan (Opsional)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.note_alt_outlined, color: Colors.grey),
                      border: InputBorder.none,
                      hintText: 'Pesan: Silakan tinggalkan pesan...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Produk Detail
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storefront, color: Colors.grey, size: 20),
                          SizedBox(width: 8),
                          Text('Fikri Retail Store',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // === Tampilkan item-item yang dipesan ===
                      if (_isCartCheckout)
                        ...widget.cartItems!.map((item) {
                          final product = item['products'];
                          final qty = item['quantity'] ?? 1;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProductImage(product['image_url']),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(product['name'],
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              currencyFormatter
                                                  .format(product['price']),
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold)),
                                          Text('x$qty',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProductImage(widget.product!.imageUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.product!.name,
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          currencyFormatter
                                              .format(widget.product!.price),
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold)),
                                      const Text('x1',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Pesanan ($_totalItems Produk):',
                              style: const TextStyle(fontSize: 12)),
                          Text(currencyFormatter.format(_subtotal),
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Metode Pembayaran — Requirement 6.4: dua grup terpisah
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Metode Pembayaran',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 16),

                      // --- Grup 1: Bayar dengan Midtrans ---
                      Row(
                        children: [
                          Icon(Icons.payment, color: Theme.of(context).colorScheme.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Bayar dengan Midtrans',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ..._midtransPaymentMethods.map((method) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              method['icon'] as IconData,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            title: Text(
                              method['name'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Radio<String>(
                              value: method['id'] as String,
                              groupValue: _selectedPayment,
                              activeColor: Theme.of(context).colorScheme.primary,
                              onChanged: (val) {
                                setState(() {
                                  _selectedPayment = val;
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                _selectedPayment = method['id'] as String;
                              });
                            },
                          )),

                      const Divider(height: 24),

                      // --- Grup 2: Bayar di Tempat ---
                      Row(
                        children: [
                          Icon(Icons.store, color: Colors.orange.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Bayar di Tempat',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ..._codPaymentMethods.map((method) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              method['icon'] as IconData,
                              color: Colors.orange.shade700,
                              size: 28,
                            ),
                            title: Text(
                              method['name'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Radio<String>(
                              value: method['id'] as String,
                              groupValue: _selectedPayment,
                              activeColor: Colors.orange.shade700,
                              onChanged: (val) {
                                setState(() {
                                  _selectedPayment = val;
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                _selectedPayment = method['id'] as String;
                              });
                            },
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Upload Bukti Pembayaran
                // Requirement 6.2: Sembunyikan saat Midtrans dipilih
                // Requirement 6.3: Tampilkan kembali saat berpindah ke COD
                if (!_isMidtransPayment)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.upload_file, color: Theme.of(context).colorScheme.primary, size: 18),
                            const SizedBox(width: 8),
                            const Text('Bukti Pembayaran (Opsional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Silakan upload screenshot struk transfer atau pembayaran QRIS.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _pickReceiptImage,
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: _receiptImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: kIsWeb 
                                        ? Image.network(_receiptImage!.path, fit: BoxFit.cover)
                                        : Image.file(File(_receiptImage!.path), fit: BoxFit.cover),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                                      SizedBox(height: 8),
                                      Text('Tap untuk upload struk', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_isMidtransPayment) const SizedBox(height: 8),

                // Rincian Pembayaran
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long,
                              color: Theme.of(context).colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          const Text('Rincian Pembayaran',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildReceiptRow('Subtotal Produk',
                          currencyFormatter.format(_subtotal)),
                      _buildReceiptRow('Subtotal Pengiriman', currencyFormatter.format(_deliveryFee)),
                      _buildReceiptRow('Biaya Layanan', 'Rp1.000'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pembayaran',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(currencyFormatter.format(_totalPayment),
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 80,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, -2))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Pembayaran',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              currencyFormatter.format(_totalPayment),
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: (_deliveryMethod == 'Delivery' && _currentPosition == null) ||
                                _selectedPayment == null
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          _deliveryMethod == 'Delivery' && _currentPosition == null
                                              ? 'Pilih titik jemput dan metode pembayaran'
                                              : 'Pilih metode pembayaran')),
                                );
                              }
                            : _showPaymentDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          color: (_deliveryMethod == 'Delivery' && _currentPosition == null) ||
                                  _selectedPayment == null
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                          child: const Center(
                            child: Text('Buat Pesanan',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Text(value,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pesanan'),
        content: Text(
            _isCOD
                ? 'Pesanan Anda akan diproses dengan pembayaran di tempat (COD).'
                : _isMidtransPayment
                    ? 'Pesanan Anda akan diproses via Midtrans. Anda akan diarahkan ke halaman pembayaran untuk menyelesaikan transaksi.'
                    : 'Konfirmasi pesanan Anda.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              // Requirement 6.1: COD branch — jangan panggil MidtransService sama sekali
              if (_isCOD) {
                await _submitCODOrder(dialogContext: context);
                return;
              }

              // Requirement 7.2: Alur checkout Midtrans
              if (_isMidtransPayment) {
                await _submitMidtransOrder(dialogContext: context);
                return;
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary),
            child: _isUploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Buat Pesanan',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Requirement 7.2: Alur checkout Midtrans
  /// 1. Panggil MidtransService.createTransaction() → dapatkan snap_token
  /// 2. INSERT order ke tabel orders dengan snap_token, payment_method='midtrans', payment_status='unpaid'
  /// 3. Simpan order_id di state lokal (Requirement 2.5)
  /// 4. Panggil MidtransService.openPaymentPage(snapToken) → buka browser
  /// 5. Setelah kembali: invalidate providers, navigasi ke riwayat pesanan
  Future<void> _submitMidtransOrder({required BuildContext dialogContext}) async {
    setState(() => _isUploading = true);

    try {
      final user = SupabaseService.client.auth.currentUser!;
      final userId = user.id;
      final userEmail = user.email ?? '';

      // Ambil nama customer dari session metadata atau gunakan fallback
      final userMeta = user.userMetadata;
      final customerName = (userMeta?['full_name'] as String?)
          ?? (userMeta?['name'] as String?)
          ?? 'Customer';
      const customerPhone = '08000000000'; // Nomor placeholder; bisa diperluas via profil

      // Format list item
      final List<Map<String, dynamic>> orderItems = [];
      if (_isCartCheckout) {
        for (var item in widget.cartItems!) {
          orderItems.add({
            'product_id': item['products']['id'],
            'name': item['products']['name'],
            'price': (item['products']['price'] as num).toInt(),
            'image_url': item['products']['image_url'],
            'quantity': item['quantity'],
          });
        }
      } else {
        orderItems.add({
          'product_id': widget.product!.id,
          'name': widget.product!.name,
          'price': widget.product!.price.toInt(),
          'image_url': widget.product!.imageUrl,
          'quantity': 1,
        });
      }

      // Pre-generate order_id (dibutuhkan Midtrans sebelum INSERT)
      final orderId = _generateUuid();

      // Tambahkan biaya layanan dan ongkir ke items agar gross_amount == sum(item_details)
      final List<Map<String, dynamic>> midtransItems = List.from(orderItems);
      midtransItems.add({
        'product_id': 'service-fee',
        'name': 'Biaya Layanan',
        'price': 1000,
        'image_url': null,
        'quantity': 1,
      });
      if (_deliveryFee > 0) {
        midtransItems.add({
          'product_id': 'delivery-fee',
          'name': 'Biaya Pengiriman',
          'price': _deliveryFee.toInt(),
          'image_url': null,
          'quantity': 1,
        });
      }

      // Requirement 1.1: Panggil Edge Function untuk mendapatkan snap_token
      MidtransTokenResult tokenResult;
      try {
        tokenResult = await _midtransService.createTransaction(
          orderId: orderId,
          customerId: userId,
          customerEmail: userEmail,
          customerName: customerName,
          customerPhone: customerPhone,
          totalAmount: _totalPayment.toInt(),
          items: midtransItems,
        );
      } catch (e) {
        // Requirement 1.5: Tampilkan pesan error, hentikan proses
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal membuat sesi pembayaran: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Requirement 2.1: INSERT order ke tabel orders dengan snap_token
      try {
        await SupabaseService.client.from('orders').insert({
          'id': orderId,
          'customer_id': userId,
          'total_amount': _totalPayment,
          'status': 'pending',
          'payment_method': 'midtrans',
          'payment_status': 'unpaid',
          'snap_token': tokenResult.snapToken,
          'lat_location': _currentPosition?.latitude,
          'lng_location': _currentPosition?.longitude,
          'address': '$_deliveryMethod${_notesController.text.isNotEmpty ? ' | Catatan: ${_notesController.text}' : ''}',
          'items': orderItems,
        });
      } catch (e) {
        // Requirement 2.4: Tampilkan error spesifik, jangan buka browser
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan pesanan. Periksa koneksi internet. ($e)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Requirement 2.5: Simpan order_id di state lokal sesi checkout
      setState(() => _currentOrderId = orderId);

      // Tutup dialog konfirmasi sebelum membuka browser
      if (dialogContext.mounted) Navigator.pop(dialogContext);

      // Requirement 3.1–3.3: Buka halaman Midtrans di browser eksternal
      try {
        await _midtransService.openPaymentPage(tokenResult.snapToken);
      } catch (e) {
        // Requirement 3.6: Tampilkan error jika browser tidak tersedia
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Requirement 3.4: Setelah user kembali dari browser, segarkan data dan navigasi ke halaman sukses
      ref.invalidate(customerOrdersProvider);
      ref.invalidate(adminOrdersProvider);

      if (mounted) {
        // Kembali ke main screen dulu, lalu push PaymentSuccessScreen
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Requirement 6.1, 6.5: Alur checkout COD
  /// INSERT langsung ke tabel `orders` tanpa memanggil MidtransService sama sekali.
  /// Jika gagal, tampilkan error via SnackBar — jangan tutup layar checkout.
  Future<void> _submitCODOrder({required BuildContext dialogContext}) async {
    setState(() => _isUploading = true);

    try {
      final userId = SupabaseService.client.auth.currentUser!.id;

      // Format list item yang dipesan ke JSON
      final List<Map<String, dynamic>> orderItems = [];
      if (_isCartCheckout) {
        for (var item in widget.cartItems!) {
          orderItems.add({
            'product_id': item['products']['id'],
            'name': item['products']['name'],
            'price': (item['products']['price'] as num).toDouble(),
            'image_url': item['products']['image_url'],
            'quantity': item['quantity'],
          });
        }
      } else {
        orderItems.add({
          'product_id': widget.product!.id,
          'name': widget.product!.name,
          'price': widget.product!.price,
          'image_url': widget.product!.imageUrl,
          'quantity': 1,
        });
      }

      // Requirement 6.1: INSERT dengan payment_method='COD', payment_status='unpaid',
      // status='pending', tanpa snap_token — MidtransService tidak dipanggil sama sekali.
      await SupabaseService.client.from('orders').insert({
        'customer_id': userId,
        'total_amount': _totalPayment,
        'status': 'pending',
        'payment_method': 'COD',
        'payment_status': 'unpaid',
        'lat_location': _currentPosition?.latitude,
        'lng_location': _currentPosition?.longitude,
        'address': '$_deliveryMethod${_notesController.text.isNotEmpty ? ' | Catatan: ${_notesController.text}' : ''}',
        'items': orderItems,
      });

      // Kurangi stok produk sesuai quantity yang dibeli
      for (final item in orderItems) {
        final productId = item['product_id']?.toString();
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        if (productId != null) {
          try {
            await SupabaseService.client.rpc(
              'decrement_product_stock',
              params: {
                'p_product_id': productId,
                'p_quantity': qty,
              },
            );
          } catch (e) {
            debugPrint('Gagal kurangi stok $productId: $e');
          }
        }
      }

      // Jika checkout dari keranjang, hapus semua item cart
      if (_isCartCheckout) {
        await SupabaseService.client
            .from('carts')
            .delete()
            .eq('user_id', userId);
      }

      // Segarkan data pesanan
      ref.invalidate(customerOrdersProvider);
      ref.invalidate(adminOrdersProvider);

      if (dialogContext.mounted) {
        Navigator.pop(dialogContext); // Tutup dialog konfirmasi
      }
      if (mounted) {
        Navigator.pop(context); // Kembali ke halaman sebelumnya
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Pesanan COD berhasil! Bayar saat barang tiba.')),
        );
      }
    } catch (e) {
      // Requirement 6.5: Tampilkan error spesifik — jangan tutup layar checkout
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext); // Tutup dialog konfirmasi
      }
      if (mounted) {
        // Layar checkout tetap terbuka, hanya tampilkan SnackBar error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pesanan COD: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}
