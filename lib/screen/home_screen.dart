import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product/view_product.dart';
import 'profile/profile_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  String searchText = '';
  String searchType = 'Products'; // Products or Creators
  String selectedCategory = 'All';
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> creators = [];
  bool loading = true;

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
    loadData();
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    try {
      // Fetch approved products
      final productsResponse = await supabase
          .from('products')
          .select('*, owner:users!products_owner_fk(id, username, photo_url)')
          .eq('status', 'approved')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      products = List<Map<String, dynamic>>.from(productsResponse);

      // Fetch all approved creators (from creators table)
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

    setState(() => loading = false);
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

    if (selectedCategory != 'All') {
      filtered = filtered
          .where((p) => (p['category'] ?? '') == selectedCategory)
          .toList();
    }

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.shade200),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (_, index) {
                    final cat = categories[index];
                    final isSelected = selectedCategory == cat;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      title: Text(
                        cat,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF58C1D1)
                              : Colors.black87,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF58C1D1),
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          selectedCategory = cat;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Returning false prevents back navigation
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Column(
            children: [
              // Modern Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF58C1D1), Color(0xFF7DE0E6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discover',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find amazing digital products',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
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
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  searchText = val.trim();
                                });
                              },
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
                                borderRadius: const BorderRadius.horizontal(
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

                    const SizedBox(height: 16),

                    // Toggle Buttons
                    Row(
                      children: [
                        _ToggleButton(
                          label: 'Products',
                          isSelected: searchType == 'Products',
                          onTap: () {
                            setState(() {
                              searchType = 'Products';
                              searchText = '';
                              searchController.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        _ToggleButton(
                          label: 'Creators',
                          isSelected: searchType == 'Creators',
                          onTap: () {
                            setState(() {
                              searchType = 'Creators';
                              searchText = '';
                              searchController.clear();
                              selectedCategory = 'All';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Active Filter Chip
              if (selectedCategory != 'All' && searchType == 'Products')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(selectedCategory),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            selectedCategory = 'All';
                          });
                        },
                        backgroundColor: const Color(
                          0xFF7DE0E6,
                        ).withOpacity(0.2),
                        labelStyle: const TextStyle(
                          color: Color(0xFF58C1D1),
                          fontWeight: FontWeight.w500,
                        ),
                        deleteIconColor: const Color(0xFF58C1D1),
                      ),
                    ],
                  ),
                ),

              // Content List
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF58C1D1),
                        ),
                      )
                    : searchType == 'Products'
                    ? _buildProductsList()
                    : _buildCreatorsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final p = filteredProducts[index];
        final imageUrl = p['thumbnail_url'] ?? '';
        final price = p['price'] ?? 0;
        final owner = p['owner'];

        if (owner == null || owner['id'] == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
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
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
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
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                        ),
                ),

                // Product Details
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
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF58C1D1),
                              borderRadius: BorderRadius.circular(8),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7DE0E6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              p['category'] ?? 'Digital',
                              style: const TextStyle(
                                color: Color(0xFF58C1D1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage:
                                (owner['photo_url'] ?? '').isNotEmpty
                                ? NetworkImage(owner['photo_url'])
                                : null,
                            child: (owner['photo_url'] ?? '').isEmpty
                                ? Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            owner['username'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
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
        );
      },
    );
  }

  Widget _buildCreatorsList() {
    if (filteredCreators.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No creators found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

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

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: c['id'] ?? ''),
              ),
            );
          },
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
        );
      },
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF58C1D1) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF7DE0E6).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF58C1D1),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
