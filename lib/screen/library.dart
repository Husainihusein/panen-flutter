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

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isLoading = true;
  List<dynamic> _downloads = [];
  List<dynamic> _savedProducts = [];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _fetchDownloads();
    _fetchSavedProducts();
  }

  Future<void> _fetchDownloads() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('product_downloads')
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
              owner:users(username)
            )
          ''')
          .eq('user_id', user.id);

      if (!mounted) return;

      debugPrint('Downloads response: $response');
      debugPrint('Downloads count: ${(response as List).length}');

      setState(() {
        _downloads = response as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching downloads: $e');
      if (!mounted) return;

      setState(() {
        _downloads = [];
        _isLoading = false;
      });
    }
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
              owner:users(username)
            )
          ''')
          .eq('user_id', user.id);

      if (!mounted) return;

      debugPrint('Saved products response: $response');
      debugPrint('Saved products count: ${(response as List).length}');

      setState(() {
        _savedProducts = response as List<dynamic>;
      });
    } catch (e) {
      debugPrint('Error fetching saved products: $e');
      if (!mounted) return;

      setState(() {
        _savedProducts = [];
      });
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
              // Custom Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF58C1D1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.library,
                            color: Color(0xFF58C1D1),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Library',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Custom Tab Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              label: 'Downloads',
                              icon: LucideIcons.download,
                              index: 0,
                              count: _downloads.length,
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              label: 'Saved',
                              icon: LucideIcons.bookmark,
                              index: 1,
                              count: _savedProducts.length,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF58C1D1),
                          ),
                        ),
                      )
                    : _selectedTab == 0
                    ? _buildProductGrid(
                        _downloads,
                        emptyMessage: 'No downloads yet',
                        emptyIcon: LucideIcons.download,
                      )
                    : _buildProductGrid(
                        _savedProducts,
                        emptyMessage: 'No saved products',
                        emptyIcon: LucideIcons.bookmark,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required int index,
    required int count,
  }) {
    final isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF58C1D1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(
    List<dynamic> products, {
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        final product = item['product'];

        if (product == null) return const SizedBox();

        final title = product['title'] ?? 'Untitled';
        final thumbnail = product['thumbnail_url'] ?? '';
        final preview = product['preview_image_url'] ?? '';
        final fileUrl = product['file_url'] ?? '';
        final videoUrl = product['video_url'] ?? '';
        final price = product['price'] ?? 0;
        final ownerId = product['owner_id'];
        final photoUrl = product['owner']?['photo_url'];
        final creator = product['owner'] != null
            ? product['owner']['username'] ?? 'Unknown'
            : 'Unknown';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewProductPage(
                  productId: product['id'],
                  title: title,
                  price: price,
                  creator: creator,
                  ownerId: ownerId,
                  photoUrl: photoUrl,
                  thumbnailUrl: thumbnail,
                  fileUrl: fileUrl,
                  description: product['description'] ?? '',
                  videoUrl: videoUrl,
                  previewImageUrl: preview,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
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
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.grey.shade200,
                                child: Icon(
                                  LucideIcons.image,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                      ),
                      // Badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF58C1D1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedTab == 0
                                    ? LucideIcons.download
                                    : LucideIcons.bookmark,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'by $creator',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }
}
