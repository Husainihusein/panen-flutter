import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product/view_product.dart';
import 'bottom_nav_controller.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _savedProducts = [];
  List<dynamic> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  AnimationController? _headerAnimController;
  AnimationController? _fabAnimController;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fetchSavedProducts();
    _headerAnimController?.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerAnimController?.dispose();
    _fabAnimController?.dispose();
    super.dispose();
  }

  Future<void> _fetchSavedProducts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('product_saves')
          .select('''
            *,
            product:products(
              id,
              title,
              price,
              owner_id,
              thumbnail_url,
              file_url,
              description,
              video_url,
              preview_image_url,
              owner:users(username, photo_url)
            )
          ''')
          .eq('user_id', user.id);

      if (!mounted) return;

      setState(() {
        _savedProducts = response as List<dynamic>;
        _filteredProducts = _savedProducts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching saved products: $e');
      if (!mounted) return;

      setState(() {
        _savedProducts = [];
        _filteredProducts = [];
        _isLoading = false;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _savedProducts;
      } else {
        _filteredProducts = _savedProducts.where((item) {
          final product = item['product'];
          if (product == null) return false;

          final title = (product['title'] ?? '').toLowerCase();
          final creator = (product['owner']?['username'] ?? '').toLowerCase();
          final searchLower = query.toLowerCase();

          return title.contains(searchLower) || creator.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _removeBookmark(String productId, int index) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('product_saves')
          .delete()
          .eq('user_id', user.id)
          .eq('product_id', productId);

      if (!mounted) return;

      setState(() {
        _savedProducts.removeAt(index);
        _filterProducts(_searchController.text);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(LucideIcons.check, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Removed from saved'),
            ],
          ),
          backgroundColor: const Color(0xFF2D3436),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error removing bookmark: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to remove bookmark'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              _buildAnimatedHeader(),
              if (_showSearch) _buildSearchBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF58C1D1),
                          ),
                        ),
                      )
                    : _buildProductGrid(),
              ),
            ],
          ),
        ),
        floatingActionButton:
            _savedProducts.isNotEmpty && _fabAnimController != null
            ? ScaleTransition(
                scale: CurvedAnimation(
                  parent: _fabAnimController!,
                  curve: Curves.elasticOut,
                ),
                child: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchController.clear();
                        _filterProducts('');
                      }
                    });
                  },
                  backgroundColor: const Color(0xFF58C1D1),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _showSearch ? LucideIcons.x : LucideIcons.search,
                      key: ValueKey(_showSearch),
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    final controller = _headerAnimController;
    if (controller == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF58C1D1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF58C1D1).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.bookmark,
                color: Color(0xFF58C1D1),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Saved',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            if (_savedProducts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF58C1D1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filteredProducts.length} item${_filteredProducts.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF58C1D1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: controller,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF58C1D1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF58C1D1).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.bookmark,
                  color: Color(0xFF58C1D1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Saved',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              if (_savedProducts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58C1D1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredProducts.length} item${_filteredProducts.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF58C1D1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: TextField(
          controller: _searchController,
          onChanged: _filterProducts,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search saved products...',
            prefixIcon: const Icon(
              LucideIcons.search,
              color: Color(0xFF58C1D1),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _filterProducts('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF58C1D1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _searchController.text.isNotEmpty
                      ? LucideIcons.searchX
                      : LucideIcons.bookmark,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No products found'
                  : 'No saved products',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Try a different search term',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      );
    }

    _fabAnimController?.forward();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final item = _filteredProducts[index];
        final product = item['product'];
        if (product == null) return const SizedBox();

        return _ProductCard(
          product: product,
          index: index,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewProductPage(
                  productId: product['id'],
                  title: product['title'] ?? 'Untitled',
                  price: product['price'] ?? 0,
                  creator: product['owner']?['username'] ?? 'Unknown',
                  ownerId: product['owner_id'],
                  photoUrl: product['owner']?['photo_url'],
                  thumbnailUrl: product['thumbnail_url'] ?? '',
                  fileUrl: product['file_url'] ?? '',
                  description: product['description'] ?? '',
                  videoUrl: product['video_url'] ?? '',
                  previewImageUrl: product['preview_image_url'] ?? '',
                ),
              ),
            );
          },
          onRemove: () => _removeBookmark(product['id'], index),
        );
      },
    );
  }
}

class _ProductCard extends StatefulWidget {
  final dynamic product;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.product,
    required this.index,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.product['title'] ?? 'Untitled';
    final thumbnail = widget.product['thumbnail_url'] ?? '';
    final price = widget.product['price'] ?? 0;
    final creator = widget.product['owner']?['username'] ?? 'Unknown';

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: _controller,
        child: GestureDetector(
          onTap: widget.onTap,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.identity()
                ..translate(0.0, _isHovered ? -4.0 : 0.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovered
                      ? const Color(0xFF58C1D1).withOpacity(0.3)
                      : Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? const Color(0xFF58C1D1).withOpacity(0.15)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: _isHovered ? 12 : 6,
                    offset: Offset(0, _isHovered ? 6 : 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: thumbnail.isNotEmpty
                              ? Image.network(
                                  thumbnail,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      LucideIcons.image,
                                      size: 40,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onRemove,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  LucideIcons.bookmarkMinus,
                                  size: 18,
                                  color: Color(0xFF58C1D1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'by $creator',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF58C1D1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RM ${price.toString()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
