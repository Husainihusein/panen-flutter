import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../authentication/landing_page.dart';
import 'edit_profile.dart';
import '../product/view_product.dart';
import '../home_screen.dart';
import '../bottom_nav_controller.dart';
import '../chat/chat_detail.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String name = "User";
  String username = "user";
  String bio = "Hey, this is my profile";
  String? photoUrl;
  List skills = [];
  List links = [];
  List products = [];
  String phoneNumber = "";
  bool isLoading = true;

  // Expansion states
  bool isSkillsExpanded = false;
  bool isLinksExpanded = false;

  late AnimationController _profileAnimController;
  late Animation<double> _profileScaleAnim;

  bool get isCurrentUser {
    final currentUid = supabase.auth.currentUser?.id;
    return widget.userId == null || widget.userId == currentUid;
  }

  @override
  void initState() {
    super.initState();
    _profileAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _profileScaleAnim = CurvedAnimation(
      parent: _profileAnimController,
      curve: Curves.elasticOut,
    );
    _profileAnimController.forward();
    fetchUserInfo();
  }

  @override
  void dispose() {
    _profileAnimController.dispose();
    super.dispose();
  }

  Future<void> fetchUserInfo() async {
    setState(() => isLoading = true);
    final uid = widget.userId ?? supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Fetch user info
      final userResponse = await supabase
          .from('users')
          .select()
          .eq('id', uid)
          .single();

      if (userResponse == null) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User profile not found')));
        return;
      }

      final data = userResponse as Map<String, dynamic>;

      // Fetch user's approved products
      final productsResponse = await supabase
          .from('products')
          .select('*, owner:users!products_owner_fk(id, username, photo_url)')
          .eq('owner_id', uid)
          .eq('status', 'approved')
          .eq('is_deleted', false)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      setState(() {
        name = data['name'] ?? 'User';
        username = data['username'] ?? 'user';
        bio = data['bio'] ?? 'Hey, this is my profile';

        final rawPhoto = data['photo_url'];
        if (rawPhoto != null && rawPhoto.isNotEmpty) {
          if (rawPhoto.startsWith('http')) {
            photoUrl = rawPhoto;
          } else {
            photoUrl = supabase.storage
                .from('profile_photos')
                .getPublicUrl(rawPhoto);
          }
        } else {
          photoUrl = null;
        }

        skills = List.from(data['skills'] ?? []);
        links = List.from(data['links'] ?? []);
        phoneNumber = data['phone_number'] ?? '';
        products = List<Map<String, dynamic>>.from(productsResponse ?? []);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching user info: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<Map<String, dynamic>?> _getOrCreateChat(
    String currentUserId,
    String otherUserId,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      final existingChat = await supabase
          .from('chats')
          .select()
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId')
          .eq('user1_id', otherUserId)
          .or('user2_id.eq.$currentUserId,user1_id.eq.$otherUserId')
          .single()
          .maybeSingle();

      Map<String, dynamic> chat;

      if (existingChat != null) {
        chat = existingChat;
      } else {
        final newChat = await supabase
            .from('chats')
            .insert({
              'user1_id': currentUserId,
              'user2_id': otherUserId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        chat = newChat;
      }

      final otherUserResponse = await supabase
          .from('users')
          .select('photo_url')
          .eq('id', otherUserId)
          .single();

      chat['otherUserPhotoUrl'] = otherUserResponse['photo_url'];

      return chat;
    } catch (e) {
      debugPrint('Error getting or creating chat: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58C1D1)),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => BottomNavController(initialIndex: 0),
          ),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: fetchUserInfo,
            color: const Color(0xFF58C1D1),
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Header with decorative background
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Decorative header background
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF58C1D1).withOpacity(0.15),
                              const Color(0xFF58C1D1).withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Decorative circles
                            Positioned(
                              top: -30,
                              right: -30,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF58C1D1,
                                  ).withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 40,
                              left: -20,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF58C1D1,
                                  ).withOpacity(0.08),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Header buttons
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!isCurrentUser)
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.arrowLeft,
                                  size: 22,
                                ),
                                onPressed: () => Navigator.pop(context),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.all(10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 48),
                            const Spacer(),
                            if (isCurrentUser)
                              PopupMenuButton<String>(
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    LucideIcons.moreVertical,
                                    size: 22,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (value) {
                                  if (value == "logout") {
                                    supabase.auth.signOut();
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const LandingPageScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: "logout",
                                    child: Text("Logout"),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // Profile Picture (positioned to overlap)
                      Positioned(
                        bottom: -50,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ScaleTransition(
                            scale: _profileScaleAnim,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF58C1D1,
                                    ).withOpacity(0.3),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF58C1D1,
                                    ).withOpacity(0.3),
                                    width: 3,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage:
                                      (photoUrl != null && photoUrl!.isNotEmpty)
                                      ? NetworkImage(photoUrl!)
                                      : null,
                                  child: (photoUrl == null || photoUrl!.isEmpty)
                                      ? const Icon(
                                          LucideIcons.user,
                                          size: 45,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // Name and Username
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF58C1D1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "@$username",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF58C1D1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bio
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      bio,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: !isCurrentUser
                        ? _buildActionButton(
                            icon: LucideIcons.messageCircle,
                            label: "Message",
                            onPressed: () async {
                              final currentUserId =
                                  supabase.auth.currentUser?.id;
                              final profileUserId = widget.userId;

                              if (currentUserId == null ||
                                  profileUserId == null ||
                                  currentUserId == profileUserId) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot start chat'),
                                  ),
                                );
                                return;
                              }

                              final chat = await _getOrCreateChat(
                                currentUserId,
                                profileUserId,
                              );
                              if (chat != null && mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatDetailScreen(
                                      chatId: chat['id'],
                                      otherUserName: username,
                                      otherUserPhotoUrl:
                                          chat['otherUserPhotoUrl'],
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open chat'),
                                  ),
                                );
                              }
                            },
                          )
                        : _buildActionButton(
                            icon: LucideIcons.edit3,
                            label: "Edit Profile",
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EditProfileScreen(),
                                ),
                              );
                              fetchUserInfo();
                            },
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Content Sections
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Skills Section - Collapsible
                        if (skills.isNotEmpty)
                          _buildCollapsibleSection(
                            title: "Skills",
                            icon: LucideIcons.award,
                            count: skills.length,
                            isExpanded: isSkillsExpanded,
                            onToggle: () => setState(
                              () => isSkillsExpanded = !isSkillsExpanded,
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: skills.map((skill) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF58C1D1,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF58C1D1,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    skill,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF58C1D1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // Links Section - Collapsible
                        if (links.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildCollapsibleSection(
                            title: "Contact Me",
                            icon: LucideIcons.link2,
                            count: links.length,
                            isExpanded: isLinksExpanded,
                            onToggle: () => setState(
                              () => isLinksExpanded = !isLinksExpanded,
                            ),
                            child: Column(
                              children: links.asMap().entries.map((entry) {
                                final index = entry.key;
                                final link = entry.value;
                                final url = link['url'] ?? '';
                                final label = link['label'] ?? url;

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index < links.length - 1 ? 8 : 0,
                                  ),
                                  child: InkWell(
                                    onTap: () async {
                                      final uri = Uri.tryParse(url);
                                      if (uri != null &&
                                          await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF58C1D1,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              LucideIcons.link,
                                              color: Color(0xFF58C1D1),
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  label,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2D3436),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  url,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            LucideIcons.externalLink,
                                            size: 14,
                                            color: Colors.grey.shade400,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        // Products Section - Carousel
                        if (products.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildProductCarousel(),
                        ] else if (isCurrentUser) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.package,
                                    size: 28,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No products yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF58C1D1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: const Color(0xFF58C1D1).withOpacity(0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required int count,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF58C1D1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: const Color(0xFF58C1D1)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildProductCarousel() {
    final PageController pageController = PageController(
      viewportFraction: 0.88,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF58C1D1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.shoppingBag,
                  size: 18,
                  color: Color(0xFF58C1D1),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Products",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Text(
                products.length.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: pageController,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              if (p['status'] != 'approved') {
                return const SizedBox.shrink();
              }

              final thumbnailUrl = p['thumbnail_url'] ?? '';
              final price = p['price'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewProductPage(
                          productId: p['id'],
                          title: p['title'] ?? '',
                          price: price,
                          creator: p['owner']?['username'] ?? '',
                          ownerId: p['owner']?['id'],
                          photoUrl: p['owner']?['photo_url'],
                          thumbnailUrl: p['thumbnail_url'] ?? '',
                          fileUrl: p['file_url'] ?? '',
                          description: p['description'] ?? '',
                          videoUrl: p['video_url'] ?? '',
                          previewImageUrl: p['preview_image_url'] ?? '',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  thumbnailUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 180,
                                )
                              : Container(
                                  height: 180,
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    LucideIcons.image,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3436),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF58C1D1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'RM ${price.toString()}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if ((p['category'] ?? '').isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        p['category'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
