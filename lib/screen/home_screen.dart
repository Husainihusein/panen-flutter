import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product/view_product.dart';
import 'profile/profile_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String searchText = '';
  String searchType = 'Products';
  String selectedCategory = 'All';
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> creators = [];
  bool loading = true;

  late AnimationController _headerController;
  late AnimationController _listController;
  late Animation<double> _headerAnimation;
  late Animation<double> _listAnimation;

  final List<String> categories = [
    'All',
    'E-book',
    'Template',
    'Audio',
    'Video',
    'Graphic Design',
    'Software',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOut,
    );
    _headerController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    try {
      final productsResponse = await supabase
          .from('products')
          .select('*, owner:users!products_owner_fk(id, username, photo_url)')
          .eq('status', 'approved')
          .eq('is_active', true)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      products = List<Map<String, dynamic>>.from(productsResponse);

      final creatorsResponse = await supabase
          .from('creators')
          .select('user_id, users(id, username, photo_url, name)')
          .eq('status', 'approved');

      creators = List<Map<String, dynamic>>.from(creatorsResponse).map((c) {
        final user = c['users'];
        return {
          'id': user['id'],
          'username': user['username'],
          'photo_url': user['photo_url'],
          'name': user['name'],
        };
      }).toList();
    } catch (e) {
      print('Error loading data: $e');
      products = [];
      creators = [];
    }

    if (mounted) {
      setState(() => loading = false);
      _listController.forward();
    }
  }

  List<Map<String, dynamic>> get filteredProducts {
    List<Map<String, dynamic>> filtered = products;
    if (searchText.isNotEmpty) {
      filtered = filtered.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final owner = (p['username'] ?? '').toString().toLowerCase();
        final category = (p['category'] ?? '').toString().toLowerCase();
        return title.contains(searchText.toLowerCase()) ||
            category.contains(searchText.toLowerCase()) ||
            owner.contains(searchText.toLowerCase());
      }).toList();
    }
    if (selectedCategory != 'All')
      filtered = filtered
          .where((p) => (p['category'] ?? '') == selectedCategory)
          .toList();
    return filtered;
  }

  List<Map<String, dynamic>> get filteredCreators {
    List<Map<String, dynamic>> filtered = creators;
    if (searchText.isNotEmpty) {
      filtered = filtered.where((c) {
        final name = (c['username'] ?? '').toString().toLowerCase();
        final fullName = (c['name'] ?? '').toString().toLowerCase();
        return name.contains(searchText.toLowerCase()) ||
            fullName.contains(searchText.toLowerCase());
      }).toList();
    }
    return filtered;
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 450,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Category',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade200, thickness: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final sel = selectedCategory == cat;
                  return TweenAnimationBuilder(
                    duration: Duration(milliseconds: 300 + (i * 50)),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (c, double v, ch) => Transform.translate(
                      offset: Offset(20 * (1 - v), 0),
                      child: Opacity(opacity: v, child: ch),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF58C1D1).withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        title: Text(
                          cat,
                          style: TextStyle(
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel
                                ? const Color(0xFF58C1D1)
                                : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                        trailing: sel
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF58C1D1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              )
                            : null,
                        onTap: () {
                          setState(() => selectedCategory = cat);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Column(
            children: [
              FadeTransition(
                opacity: _headerAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.5),
                    end: Offset.zero,
                  ).animate(_headerAnimation),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF58C1D1), Color(0xFF7DE0E6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF58C1D1).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            TweenAnimationBuilder(
                              duration: const Duration(milliseconds: 600),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (c, double v, ch) => Transform.scale(
                                scale: v,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.store_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Digital Marketplace',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Discover amazing creations',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 800),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (c, double v, ch) => Transform.scale(
                            scale: 0.9 + (0.1 * v),
                            child: Opacity(opacity: v, child: ch),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: searchController,
                                    decoration: InputDecoration(
                                      hintText: searchType == 'Products'
                                          ? 'Search products...'
                                          : 'Search creators...',
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade400,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.grey.shade400,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                    onChanged: (v) =>
                                        setState(() => searchText = v.trim()),
                                  ),
                                ),
                                if (searchType == 'Products')
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                if (searchType == 'Products')
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                            right: Radius.circular(16),
                                          ),
                                      onTap: _showCategoryFilter,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.tune,
                                              color: Colors.grey.shade600,
                                              size: 20,
                                            ),
                                            if (selectedCategory != 'All') ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF58C1D1),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _ToggleButton(
                              label: 'Products',
                              icon: Icons.shopping_bag_outlined,
                              isSelected: searchType == 'Products',
                              onTap: () => setState(() {
                                searchType = 'Products';
                                searchText = '';
                                searchController.clear();
                              }),
                            ),
                            const SizedBox(width: 12),
                            _ToggleButton(
                              label: 'Creators',
                              icon: Icons.people_outline,
                              isSelected: searchType == 'Creators',
                              onTap: () => setState(() {
                                searchType = 'Creators';
                                searchText = '';
                                searchController.clear();
                                selectedCategory = 'All';
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (selectedCategory != 'All' && searchType == 'Products')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (c, double v, ch) =>
                        Transform.scale(scale: v, child: ch),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(
                            Icons.filter_alt,
                            size: 18,
                            color: Color(0xFF58C1D1),
                          ),
                          label: Text(selectedCategory),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () =>
                              setState(() => selectedCategory = 'All'),
                          backgroundColor: const Color(
                            0xFF7DE0E6,
                          ).withOpacity(0.2),
                          labelStyle: const TextStyle(
                            color: Color(0xFF58C1D1),
                            fontWeight: FontWeight.w600,
                          ),
                          deleteIconColor: const Color(0xFF58C1D1),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: loading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TweenAnimationBuilder(
                              duration: const Duration(milliseconds: 1000),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (c, double v, ch) => Transform.scale(
                                scale: 0.8 + (0.2 * v),
                                child: Opacity(opacity: v, child: ch),
                              ),
                              child: const CircularProgressIndicator(
                                color: Color(0xFF58C1D1),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FadeTransition(
                        opacity: _listAnimation,
                        child: searchType == 'Products'
                            ? _buildProductsList()
                            : _buildCreatorsList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    if (filteredProducts.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 600),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (c, double v, ch) => Transform.scale(
                scale: v,
                child: Opacity(opacity: v, child: ch),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting filters',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final p = filteredProducts[index];
        final imageUrl = p['thumbnail_url'] ?? '';
        final price = p['price'] ?? 0;
        final owner = p['owner'];
        if (owner == null || owner['id'] == null)
          return const SizedBox.shrink();

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (c, double v, ch) => Transform.translate(
            offset: Offset(0, 30 * (1 - v)),
            child: Opacity(opacity: v, child: ch),
          ),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewProductPage(
                  productId: p['id'],
                  title: p['title'] ?? '',
                  price: price,
                  creator: owner['username'] ?? '',
                  ownerId: p['owner']?['id'],
                  photoUrl: owner['photo_url'],
                  thumbnailUrl: p['thumbnail_url'] ?? '',
                  fileUrl: p['file_url'] ?? '',
                  description: p['description'] ?? '',
                  videoUrl: p['video_url'] ?? '',
                  previewImageUrl: p['preview_image_url'] ?? '',
                ),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                              )
                            : Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey.shade100,
                                      Colors.grey.shade200,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(p['category'] ?? 'Digital'),
                                size: 14,
                                color: const Color(0xFF58C1D1),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                p['category'] ?? 'Digital',
                                style: const TextStyle(
                                  color: Color(0xFF58C1D1),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF58C1D1),
                                    Color(0xFF7DE0E6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF58C1D1,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'RM ${price.toString()}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage:
                                      (owner['photo_url'] ?? '').isNotEmpty
                                      ? NetworkImage(owner['photo_url'])
                                      : null,
                                  child: (owner['photo_url'] ?? '').isEmpty
                                      ? Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      owner['username'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Creator',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'E-book':
        return Icons.menu_book;
      case 'Template':
        return Icons.description;
      case 'Audio':
        return Icons.audio_file;
      case 'Video':
        return Icons.video_library;
      case 'Graphic Design':
        return Icons.palette;
      case 'Software':
        return Icons.code;
      default:
        return Icons.category;
    }
  }

  Widget _buildCreatorsList() {
    if (filteredCreators.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 600),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (c, double v, ch) => Transform.scale(
                scale: v,
                child: Opacity(opacity: v, child: ch),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No creators found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredCreators.length,
      itemBuilder: (context, index) {
        final c = filteredCreators[index];
        final photoUrl = c['photo_url'] ?? '';
        final name = c['name'] ?? '';
        final username = c['username'] ?? '';

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (ctx, double v, ch) => Transform.scale(
            scale: v,
            child: Opacity(opacity: v, child: ch),
          ),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: c['id'] ?? ''),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 45,
                            color: Colors.grey.shade400,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      name.isNotEmpty ? name : username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$username',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF58C1D1) : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF58C1D1) : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
