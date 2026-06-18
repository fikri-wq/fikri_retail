import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../main.dart' show AppColors;

// ─── Provider ───────────────────────────────────────────────────────────────

final allUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseService.client
      .from('profiles')
      .select('id, full_name, role, phone, email:id') // id pakai untuk ref
      .order('full_name', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

// ─── Tab Widget ─────────────────────────────────────────────────────────────

class UserManagementTab extends ConsumerStatefulWidget {
  const UserManagementTab({super.key});

  @override
  ConsumerState<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends ConsumerState<UserManagementTab> {
  String _searchQuery = '';
  String _filterRole = 'all'; // 'all', 'admin', 'customer'

  // ─── Toggle Role ──────────────────────────────────────────────────────────
  Future<void> _toggleRole(Map<String, dynamic> user) async {
    final currentRole = user['role'] as String? ?? 'customer';
    final newRole = currentRole == 'admin' ? 'customer' : 'admin';
    final userName = user['full_name'] ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              newRole == 'admin' ? Icons.shield_rounded : Icons.person_rounded,
              color: newRole == 'admin' ? AppColors.primary : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              newRole == 'admin' ? 'Jadikan Admin?' : 'Jadikan Customer?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          newRole == 'admin'
              ? 'User "$userName" akan mendapat akses Admin dan bisa mengelola produk & pesanan.'
              : 'User "$userName" akan dikembalikan menjadi Customer biasa.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newRole == 'admin' ? AppColors.primary : Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Ya, Ubah',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client
          .from('profiles')
          .update({'role': newRole})
          .eq('id', user['id']);

      ref.invalidate(allUsersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newRole == 'admin'
                  ? '✅ $userName sekarang menjadi Admin'
                  : '✅ $userName sekarang menjadi Customer',
            ),
            backgroundColor: newRole == 'admin' ? AppColors.primary : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah role: $e')),
        );
      }
    }
  }

  // ─── Detail Dialog ────────────────────────────────────────────────────────
  void _showUserDetail(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    _buildAvatar(user['full_name'] ?? 'N', size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['full_name'] ?? 'No Name',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          _buildRoleBadge(user['role'] ?? 'customer', small: true),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Detail Info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _detailRow(Icons.badge_rounded, 'User ID', user['id'] ?? '-'),
                    _detailRow(Icons.phone_rounded, 'Telepon', user['phone'] ?? '-'),
                    _detailRow(Icons.location_on_rounded, 'Alamat', user['address'] ?? '-'),
                    _detailRow(Icons.wc_rounded, 'Gender', user['gender'] ?? '-'),
                    _detailRow(Icons.cake_rounded, 'Tgl Lahir', user['dob'] ?? '-'),
                    _detailRow(Icons.calendar_today_rounded, 'Bergabung',
                        user['created_at'] != null
                            ? _formatDate(user['created_at'])
                            : '-'),
                  ],
                ),
              ),
              // Action Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (user['role'] ?? 'customer') == 'admin'
                          ? Colors.red
                          : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _toggleRole(user);
                    },
                    icon: Icon(
                      (user['role'] ?? 'customer') == 'admin'
                          ? Icons.person_rounded
                          : Icons.shield_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      (user['role'] ?? 'customer') == 'admin'
                          ? 'Jadikan Customer'
                          : 'Jadikan Admin',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _buildAvatar(String name, {double size = 44}) {
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFF6A1B9A),
      const Color(0xFFE65100),
      const Color(0xFF00695C),
    ];
    final colorIndex = name.codeUnitAt(0) % colors.length;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors[colorIndex],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role, {bool small = false}) {
    final isAdmin = role == 'admin';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.primary : const Color(0xFFE65100),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.shield_rounded : Icons.person_rounded,
            size: small ? 10 : 12,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            isAdmin ? 'ADMIN' : 'CUSTOMER',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: small ? 9 : 10,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Column(
      children: [
        // ── Search & Filter Bar ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Search Field
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Cari nama user...',
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Filter chips
              Row(
                children: [
                  _filterChip('Semua', 'all'),
                  const SizedBox(width: 8),
                  _filterChip('Admin', 'admin'),
                  const SizedBox(width: 8),
                  _filterChip('Customer', 'customer'),
                ],
              ),
            ],
          ),
        ),

        // ── User List ──
        Expanded(
          child: usersAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text('Gagal memuat data: $err',
                      style: GoogleFonts.poppins(color: Colors.red, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(allUsersProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
            data: (users) {
              // Filter + Search
              final filtered = users.where((u) {
                final name = (u['full_name'] ?? '').toString().toLowerCase();
                final role = (u['role'] ?? 'customer').toString();
                final matchSearch = _searchQuery.isEmpty || name.contains(_searchQuery);
                final matchRole = _filterRole == 'all' || role == _filterRole;
                return matchSearch && matchRole;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_off_rounded, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada user ditemukan',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              // Summary header
              final adminCount = users.where((u) => u['role'] == 'admin').length;
              final customerCount = users.where((u) => u['role'] != 'admin').length;

              return Column(
                children: [
                  // Stats bar
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _statItem(Icons.group_rounded, '${users.length}', 'Total User'),
                        _verticalDivider(),
                        _statItem(Icons.shield_rounded, '$adminCount', 'Admin'),
                        _verticalDivider(),
                        _statItem(Icons.person_rounded, '$customerCount', 'Customer'),
                      ],
                    ),
                  ),
                  // List
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => ref.invalidate(allUsersProvider),
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72, endIndent: 16),
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          final name = user['full_name'] ?? 'No Name';
                          final role = user['role'] ?? 'customer';
                          final isAdmin = role == 'admin';

                          return InkWell(
                            onTap: () => _showUserDetail(user),
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Avatar
                                  _buildAvatar(name),
                                  const SizedBox(width: 12),
                                  // Name + Badge
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildRoleBadge(role),
                                      ],
                                    ),
                                  ),
                                  // Action Button
                                  ElevatedButton.icon(
                                    onPressed: () => _toggleRole(user),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isAdmin
                                          ? Colors.red
                                          : AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    icon: Icon(
                                      isAdmin
                                          ? Icons.person_rounded
                                          : Icons.shield_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      isAdmin ? 'Jadikan Customer' : 'Jadikan Admin',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filterRole == value;
    return GestureDetector(
      onTap: () => setState(() => _filterRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String count, String label) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 32,
      width: 1,
      color: Colors.white.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
