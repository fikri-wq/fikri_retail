import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _client = Supabase.instance.client;
  
  bool _isEditing = false;
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _dobController;
  String _gender = 'Laki-laki';

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final user = _client.auth.currentUser;
    final metadata = user?.userMetadata;

    _nameController = TextEditingController(text: metadata?['full_name'] as String? ?? '');
    _phoneController = TextEditingController(text: metadata?['phone'] as String? ?? '');
    _addressController = TextEditingController(text: metadata?['address'] as String? ?? '');
    _dobController = TextEditingController(text: metadata?['dob'] as String? ?? '');
    _gender = metadata?['gender'] as String? ?? 'Laki-laki';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (image == null) return;

      setState(() => _isLoading = true);

      final user = _client.auth.currentUser;
      if (user == null) return;

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // 1. Upload ke storage bucket "avatars"
      await _client.storage
          .from('avatars')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));

      final String publicUrl = _client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // 2. Simpan URL foto ke Auth Metadata User
      await _client.auth.updateUser(
        UserAttributes(
          data: {
            ...user.userMetadata ?? {},
            'avatar_url': publicUrl,
          },
        ),
      );

      // 3. Sinkronisasi ke DB profiles jika kolomnya ada
      try {
        await _client.from('profiles').update({
          'avatar_url': publicUrl,
        }).eq('id', user.id);
      } catch (dbError) {
        debugPrint('DB Profile Photo Sync skipped: $dbError');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Foto profil berhasil diperbarui!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Konfigurasi Supabase'),
              ],
            ),
            content: Text(
              'Gagal mengunggah foto profil:\n\n$e\n\n'
              'Penyebab umum: Anda belum membuat Bucket bernama "avatars" di Supabase Storage Anda, atau bucket tersebut belum diset ke Public.\n\n'
              'Silakan login ke Dashboard Supabase Anda, masuk ke menu Storage, buat bucket baru bernama "avatars", lalu centang pilihan "Public".'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Lengkap tidak boleh kosong!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi.');

      // 1. Simpan ke Auth User Metadata (Source of Truth teraman di Supabase)
      await _client.auth.updateUser(
        UserAttributes(
          data: {
            ...user.userMetadata ?? {},
            'full_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'gender': _gender,
            'dob': _dobController.text.trim(),
          },
        ),
      );

      // 2. Coba sinkronisasi ke tabel profiles jika kolomnya ada
      try {
        await _client.from('profiles').update({
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'gender': _gender,
          'dob': _dobController.text.trim(),
        }).eq('id', user.id);
      } catch (dbError) {
        // Soft fail jika kolom di tabel profiles belum ada (user metadata tetap aman & tersimpan)
        debugPrint('DB Profile Sync skipped/failed: $dbError');
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profil berhasil diperbarui!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal memperbarui profil: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (_dobController.text.isNotEmpty) {
      try {
        List<String> parts = _dobController.text.split('/');
        if (parts.length == 3) {
          initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final email = user?.email ?? 'Member';
    
    // Mengambil state terbaru
    final metadata = user?.userMetadata;
    final String fullName = metadata?['full_name'] as String? ?? _nameController.text;
    final String displayName = fullName.isNotEmpty ? fullName : (email.contains('@') ? email.split('@')[0] : email);
    final String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M';

    final String phone = metadata?['phone'] as String? ?? 'Belum diisi';
    final String address = metadata?['address'] as String? ?? 'Belum diisi';
    final String dob = metadata?['dob'] as String? ?? 'Belum diisi';
    final String gender = metadata?['gender'] as String? ?? 'Laki-laki';
    final String? avatarUrl = metadata?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profil Saya', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Info Widget
            Container(
              color: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 28.0, top: 8.0),
              child: Row(
                children: [
                  // Avatar Bulat Interaktif
                  GestureDetector(
                    onTap: _isLoading ? null : _uploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.white,
                            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? Text(
                                    initial, 
                                    style: TextStyle(
                                      fontSize: 26, 
                                      fontWeight: FontWeight.bold, 
                                      color: Theme.of(context).colorScheme.primary
                                    )
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: const Color(0xFFFFBC00), // Gold Ring Accent dari logo
                            child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName, 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Member Silver', 
                                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => AuthService.signOut(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Keluar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            // Koin & Poin
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileMetric(Icons.monetization_on, 'Koin Fikri', 'Rp 0', Colors.orange),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  _buildProfileMetric(Icons.star, 'Poin Belanja', '1.500 Poin', Colors.amber),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Form atau Tampilan Informasi Customer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isEditing ? _buildEditForm() : _buildInfoView(email, phone, address, dob, gender),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // TAMPILAN VIEW INFO
  Widget _buildInfoView(String email, String phone, String address, String dob, String gender) {
    return Column(
      key: const ValueKey('InfoView'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Informasi Pribadi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Ubah', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          ],
        ),
        const Divider(height: 24),
        _buildInfoItem(Icons.person_outline, 'Nama Lengkap', _nameController.text.isNotEmpty ? _nameController.text : 'Belum diisi'),
        _buildInfoItem(Icons.email_outlined, 'Email', email, subtitle: 'Akun utama (Tidak dapat diubah)'),
        _buildInfoItem(Icons.phone_outlined, 'No. Handphone', phone),
        _buildInfoItem(Icons.location_on_outlined, 'Alamat Lengkap', address),
        _buildInfoItem(Icons.wc_outlined, 'Jenis Kelamin', gender),
        _buildInfoItem(Icons.calendar_today_outlined, 'Tanggal Lahir', dob),
      ],
    );
  }

  // TAMPILAN FORM EDIT
  Widget _buildEditForm() {
    return Column(
      key: const ValueKey('EditForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Edit Profil Anda',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        
        _buildEditField(
          controller: _nameController,
          label: 'Nama Lengkap',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 14),

        _buildEditField(
          controller: _phoneController,
          label: 'No. Handphone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),

        _buildEditField(
          controller: _addressController,
          label: 'Alamat Lengkap',
          icon: Icons.location_on_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: 14),

        // Jenis Kelamin
        Row(
          children: [
            Icon(Icons.wc_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            const Text('Jenis Kelamin', style: TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Laki-laki')),
                selected: _gender == 'Laki-laki',
                onSelected: (selected) {
                  if (selected) setState(() => _gender = 'Laki-laki');
                },
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                checkmarkColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: _gender == 'Laki-laki' ? Theme.of(context).colorScheme.primary : Colors.black87,
                  fontWeight: _gender == 'Laki-laki' ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Perempuan')),
                selected: _gender == 'Perempuan',
                onSelected: (selected) {
                  if (selected) setState(() => _gender = 'Perempuan');
                },
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                checkmarkColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: _gender == 'Perempuan' ? Theme.of(context).colorScheme.primary : Colors.black87,
                  fontWeight: _gender == 'Perempuan' ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tanggal Lahir
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: _buildEditField(
              controller: _dobController,
              label: 'Tanggal Lahir',
              icon: Icons.calendar_today_outlined,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Tombol Aksi
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _initControllers(); // Reset form ke data semula
                    _isEditing = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Batal', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: _isLoading ? null : LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.secondary,
                      Theme.of(context).colorScheme.primary,
                    ],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfileChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  // WIDGET HELPER INFO ITEM
  Widget _buildInfoItem(IconData icon, String label, String value, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET HELPER TEXTFIELD EDIT
  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildProfileMetric(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
      ],
    );
  }
}
