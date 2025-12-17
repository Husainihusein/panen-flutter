import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'profile/profile_page.dart';
import 'content_creator/creator_registration.dart';
import 'product/product_dashboard.dart';
import 'notification_screen.dart';
import 'chat/chat_list.dart';
import 'library.dart';

class BottomNavController extends StatefulWidget {
  final int initialIndex;
  const BottomNavController({super.key, this.initialIndex = 0});

  @override
  State<BottomNavController> createState() => _BottomNavControllerState();
}

class _BottomNavControllerState extends State<BottomNavController> {
  late int _currentIndex;
  bool _isCreatorLoading = true;
  bool _isCreator = false;
  bool _isPending = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkCreatorStatus();
  }

  Future<void> _checkCreatorStatus() async {
    setState(() => _isCreatorLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('creators')
          .select()
          .eq('user_id', user.id)
          .single();

      setState(() {
        if (data == null) {
          _isCreator = false;
          _isPending = false;
        } else {
          _isCreator = data['status'] == 'approved';
          _isPending = data['status'] == 'pending';
        }
        _isCreatorLoading = false;
      });
    } catch (e) {
      setState(() {
        _isCreator = false;
        _isPending = false;
        _isCreatorLoading = false;
      });
    }
  }

  Widget _getMyShopScreen() {
    if (_isCreatorLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isCreator) {
      if (_isPending) {
        // Show a simple Pending Approval screen
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
                  const SizedBox(height: 24),
                  const Text(
                    "Your creator application is under review.\nPlease wait for admin approval.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // User not yet applied → show registration
        return const CreatorRegistrationScreen();
      }
    }

    // Approved → show dashboard
    return const MyProductsScreen();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      _getMyShopScreen(), // My Shop tab
      const LibraryScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF58C1D1),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) async {
          setState(() {
            _currentIndex = index;
          });

          // Refresh creator status when tapping My Shop
          if (index == 1) await _checkCreatorStatus();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'My Shop'),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_outlined),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
