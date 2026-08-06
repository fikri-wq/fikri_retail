import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'home_screen.dart';
import '../order/customer_orders_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/supabase_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  final List<Widget> _pages = [
    const HomeScreen(),
    const CustomerOrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: _PesananBadgeIcon(isActive: false),
            activeIcon: _PesananBadgeIcon(isActive: true),
            label: 'Pesanan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// Widget icon Pesanan dengan badge merah realtime
class _PesananBadgeIcon extends StatelessWidget {
  final bool isActive;
  const _PesananBadgeIcon({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      return Icon(isActive ? Icons.receipt_long : Icons.receipt_long_outlined);
    }

    // Stream pesanan milik user ini, lalu cek chat terbaru
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('customer_id', userId),
      builder: (context, ordersSnapshot) {
        if (!ordersSnapshot.hasData || ordersSnapshot.data!.isEmpty) {
          return Icon(isActive ? Icons.receipt_long : Icons.receipt_long_outlined);
        }

        final orderIds = ordersSnapshot.data!.map((o) => o['id'].toString()).toList();

        // Cek chat terbaru dari semua order milik user (realtime stream)
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.client
              .from('order_chats')
              .stream(primaryKey: ['id'])
              .inFilter('order_id', orderIds)
              .order('created_at', ascending: false),
          builder: (context, chatSnapshot) {
            // Badge merah hanya kalau pesan TERBARU adalah dari admin (bukan dari customer sendiri)
            bool hasUnread = false;
            if (chatSnapshot.hasData && chatSnapshot.data!.isNotEmpty) {
              final latestMsg = chatSnapshot.data!.first;
              hasUnread = latestMsg['sender_id'] != userId && latestMsg['is_admin'] == true;
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isActive ? Icons.receipt_long : Icons.receipt_long_outlined),
                if (hasUnread)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
