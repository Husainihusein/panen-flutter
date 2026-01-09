import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_product.dart';
import 'edit_product.dart';
import 'product_insight.dart';
import '../bottom_nav_controller.dart';
import '../home_screen.dart';
import 'withdrawal.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> products = [];
  double totalWithdrawn = 0.0;
  AnimationController? _headerController;
  AnimationController? _fabController;
  Animation<double>? _headerAnimation;
  Animation<double>? _fabAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _headerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fabController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerController!,
      curve: Curves.easeOutCubic,
    );

    _fabAnimation = CurvedAnimation(
      parent: _fabController!,
      curve: Curves.elasticOut,
    );

    _fetchProducts();
    _fetchWithdrawals();

    // Start animations
    _headerController!.forward();
    Future.delayed(Duration(milliseconds: 400), () {
      if (mounted) _fabController!.forward();
    });
  }

  @override
  void dispose() {
    _headerController?.dispose();
    _fabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      debugPrint('Current user: ${user?.id}');

      final salesData = await supabase
          .from('product_sales')
          .select('*')
          .eq('owner_id', user.id)
          .eq('is_deleted', false);

      final productData = await supabase
          .from('products')
          .select('id, rejection_reason, rejection_remark')
          .eq('owner_id', user.id)
          .eq('is_deleted', false);

      final Map<String, Map<String, dynamic>> rejectionMap = {
        for (var item in productData) item['id']: item,
      };

      setState(() {
        products = salesData.map((item) {
          final rejection = rejectionMap[item['product_id']] ?? {};
          return {
            'id': item['product_id'],
            'title': item['title'] ?? 'Untitled',
            'price': (item['price'] as num?)?.toDouble() ?? 0.0,
            'thumbnail_url': item['thumbnail_url'] ?? '',
            'status': item['product_status'] ?? 'review',
            'is_active': item['is_active'] ?? true,
            'views': (item['views'] as num?)?.toInt() ?? 0,
            'sold': (item['sold'] as num?)?.toInt() ?? 0,
            'earnings': (item['earnings'] as num?)?.toDouble() ?? 0.0,
            'rejection_reason': rejection['rejection_reason'] ?? '',
            'rejection_remark': rejection['rejection_remark'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching products: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load products')));
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await supabase
          .from('products')
          .update({'is_deleted': true})
          .eq('id', productId);

      setState(() {
        products.removeWhere((p) => p['id'] == productId);
      });
    } catch (e) {
      debugPrint('Error deleting product: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete product')));
    }
  }

  Future<void> _fetchWithdrawals() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('withdrawals')
          .select('amount, status')
          .eq('creator_id', user.id)
          .eq('status', 'paid');

      final List<dynamic> fetched = data as List<dynamic>;

      setState(() {
        totalWithdrawn = fetched.fold<double>(
          0.0,
          (sum, w) => sum + ((w['amount'] as num?)?.toDouble() ?? 0.0),
        );
      });
    } catch (e) {
      debugPrint('Error fetching withdrawals: $e');
    }
  }

  Future<void> _toggleActive(String productId, bool value) async {
    try {
      await supabase
          .from('products')
          .update({'is_active': value})
          .eq('id', productId);
      setState(() {
        final index = products.indexWhere((p) => p['id'] == productId);
        if (index != -1) products[index]['is_active'] = value;
      });
    } catch (e) {
      debugPrint('Error toggling active: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  void _showDeleteDialog(String title, String productId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              SizedBox(height: 16),

              // Title
              Text(
                "Delete Product?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 12),

              // Subtitle
              Text(
                'Are you sure you want to delete "$title"?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _deleteProduct(productId);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectionDialog(String reason, String remark) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              SizedBox(height: 16),

              // Title
              Text(
                "Rejection Details",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 16),

              // Reason & Remark
              if (reason.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Reason:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  reason,
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                ),
                SizedBox(height: 12),
              ],
              if (remark.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Remark:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  remark,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 12),
              ],

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    int totalProducts = products.length;
    int totalSold = products.fold(
      0,
      (sum, p) => sum + (p['sold'] as int? ?? 0),
    );
    int totalViews = products.fold(
      0,
      (sum, p) => sum + (p['views'] as int? ?? 0),
    );
    double totalEarnings = products.fold(
      0.0,
      (sum, p) => sum + (p['earnings'] as double? ?? 0.0),
    );
    double availableEarnings = totalEarnings - totalWithdrawn;
    if (availableEarnings < 0) availableEarnings = 0.0;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BottomNavController(initialIndex: 0),
          ),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              // Animated Header with gradient
              FadeTransition(
                opacity: _headerAnimation ?? AlwaysStoppedAnimation(1.0),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(_headerAnimation ?? AlwaysStoppedAnimation(1.0)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF58C1D1), Color(0xFF45A5B5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF58C1D1).withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Row(
                            children: [
                              Text(
                                "My Products",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "$totalProducts items",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Earnings Card
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xFF58C1D1,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.account_balance_wallet,
                                        color: Color(0xFF58C1D1),
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Earnings Overview",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),

                                // Earnings breakdown
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Total",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          "RM ${totalEarnings.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Withdrawn",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          "RM ${totalWithdrawn.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Available",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          "RM ${availableEarnings.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12),

                                // Withdraw Button with animation
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => WithdrawalScreen(),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          color: Color(
                                            0xFF58C1D1,
                                          ).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.arrow_circle_up,
                                                color: Color(0xFF58C1D1),
                                                size: 20,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                "Withdraw",
                                                style: TextStyle(
                                                  color: Color(0xFF58C1D1),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 16),

                          // Stats Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernStatCard(
                                  "Sold",
                                  totalSold.toString(),
                                  Icons.shopping_bag_outlined,
                                  Colors.green,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildModernStatCard(
                                  "Views",
                                  totalViews.toString(),
                                  Icons.visibility_outlined,
                                  Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Products List
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No products yet",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Add your first product to get started",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final String title = product['title'];
                          final double price = product['price'];
                          final String thumbnail = product['thumbnail_url'];
                          final String productId = product['id'];
                          final String status = product['status'];
                          final bool isActive = product['is_active'];
                          final int sold = product['sold'];
                          final int views = product['views'];
                          final String rejectionReason =
                              product['rejection_reason'] ?? '';
                          final String rejectionRemark =
                              product['rejection_remark'] ?? '';

                          return TweenAnimationBuilder<double>(
                            duration: Duration(
                              milliseconds: 400 + (index * 100),
                            ),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: Opacity(opacity: value, child: child),
                              );
                            },
                            child: Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: status == 'rejected'
                                    ? Colors
                                          .grey[100] // lighten card if rejected
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Thumbnail
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[200],
                                            child: thumbnail.isNotEmpty
                                                ? Image.network(
                                                    thumbnail,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) => Icon(
                                                          Icons.image_outlined,
                                                          color:
                                                              Colors.grey[400],
                                                        ),
                                                  )
                                                : Icon(
                                                    Icons.image_outlined,
                                                    color: Colors.grey[400],
                                                  ),
                                          ),
                                        ),
                                        SizedBox(width: 12),

                                        // Product Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            status == 'rejected'
                                                            ? Colors
                                                                  .grey // dim title
                                                            : Color(0xFF2C3E50),
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // Rejection Badge stays bright
                                                  _buildStatusBadge(
                                                    status,
                                                    rejectionReason,
                                                    rejectionRemark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                "RM ${price.toStringAsFixed(2)}",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: status == 'rejected'
                                                      ? Colors
                                                            .grey // dim price
                                                      : Color(0xFF58C1D1),
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  _buildInfoChip(
                                                    Icons
                                                        .shopping_cart_outlined,
                                                    "$sold sold",
                                                    Colors.green,
                                                  ),
                                                  SizedBox(width: 8),
                                                  _buildInfoChip(
                                                    Icons.visibility_outlined,
                                                    "$views views",
                                                    Colors.blue,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action Buttons
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        // Active/Inactive Switch (hide if rejected)
                                        if (status != 'rejected')
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? Colors.green.withOpacity(
                                                      0.1,
                                                    )
                                                  : Colors.grey.withOpacity(
                                                      0.1,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isActive
                                                      ? "Active"
                                                      : "Inactive",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isActive
                                                        ? Colors.green[700]
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Transform.scale(
                                                  scale: 0.8,
                                                  child: Switch(
                                                    value: isActive,
                                                    onChanged: (value) =>
                                                        _toggleActive(
                                                          productId,
                                                          value,
                                                        ),
                                                    activeColor: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Spacer(),

                                        // Insight Button (disabled if rejected)
                                        Opacity(
                                          opacity: status == 'rejected'
                                              ? 0.4
                                              : 1.0,
                                          child: IgnorePointer(
                                            ignoring: status == 'rejected',
                                            child: _buildActionButton(
                                              Icons.insights_outlined,
                                              Colors.purple,
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ProductInsightScreen(
                                                          productId: productId,
                                                          productTitle: title,
                                                          price: price,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),

                                        // Edit Button (disabled if rejected)
                                        Opacity(
                                          opacity: status == 'rejected'
                                              ? 0.4
                                              : 1.0,
                                          child: IgnorePointer(
                                            ignoring: status == 'rejected',
                                            child: _buildActionButton(
                                              Icons.edit_outlined,
                                              Colors.blue,
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        EditProductScreen(
                                                          productId: productId,
                                                        ),
                                                  ),
                                                ).then((_) => _fetchProducts());
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),

                                        // Delete Button always works and stays bright
                                        _buildActionButton(
                                          Icons.delete_outline,
                                          Colors.red,
                                          () => _showDeleteDialog(
                                            title,
                                            productId,
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
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: ScaleTransition(
          scale: _fabAnimation ?? AlwaysStoppedAnimation(1.0),
          child: FloatingActionButton.extended(
            backgroundColor: Color(0xFF58C1D1),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddProductScreen()),
              ).then((_) => _fetchProducts());
            },
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Add Product',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    String status,
    String rejectionReason,
    String rejectionRemark,
  ) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case 'approved':
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green[700]!;
        text = 'APPROVED';
        break;
      case 'rejected':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red[700]!;
        text = 'REJECTED';
        break;
      default:
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange[700]!;
        text = 'REVIEW';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        if (status == 'rejected' &&
            (rejectionReason.isNotEmpty || rejectionRemark.isNotEmpty))
          Padding(
            padding: EdgeInsets.only(left: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    _showRejectionDialog(rejectionReason, rejectionRemark),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, MaterialColor color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            padding: EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
