import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class ProductInsightScreen extends StatefulWidget {
  final String productId;
  final String productTitle;
  final double price;

  const ProductInsightScreen({
    super.key,
    required this.productId,
    required this.productTitle,
    this.price = 0.0,
  });

  @override
  State<ProductInsightScreen> createState() => _ProductInsightScreenState();
}

class _ProductInsightScreenState extends State<ProductInsightScreen> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  bool error = false;

  // Totals
  int totalSold = 0;
  int totalViews = 0;
  double totalEarnings = 0.0;

  // Weekly data (last 7 days)
  List<int> weeklySales = List<int>.filled(7, 0);
  List<double> weeklyEarnings = List<double>.filled(7, 0.0);
  List<String> weekLabels = [];

  // Add these to your state class
  String _buyerDateFilter =
      'all'; // 'today', 'yesterday', 'week', 'month', 'all'
  int _reviewsToShow = 5;

  // Recent buyers
  List<Map<String, dynamic>> recentBuyers = [];

  List<Map<String, dynamic>> productReviews = [];

  @override
  void initState() {
    super.initState();
    _prepareWeekLabels();
    _loadInsights();
  }

  void _prepareWeekLabels() {
    final now = DateTime.now();
    weekLabels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.weekday % 7];
    });
  }

  Future<void> _loadInsights() async {
    setState(() {
      loading = true;
      error = false;
    });

    try {
      debugPrint(
        '📱 Starting to load insights for product: ${widget.productId}',
      );

      // 1) Fetch product data (only views exist in products table)
      debugPrint('🔍 Step 1: Fetching product data...');
      final productResp = await supabase
          .from('products')
          .select('id, price, views, title')
          .eq('id', widget.productId)
          .maybeSingle();

      debugPrint('✅ Product data: $productResp');

      if (productResp != null) {
        totalViews = (productResp['views'] as int?) ?? 0;
        debugPrint('📊 Total Views from product table: $totalViews');
      }

      // 2) Fetch ALL purchases for this product to count sales
      debugPrint('🔍 Step 2: Fetching ALL purchases (any status)...');

      final allPurchasesResp = await supabase
          .from('purchases')
          .select('id, status')
          .eq('product_id', widget.productId);

      final List<dynamic> allPurchases =
          allPurchasesResp as List<dynamic>? ?? [];
      debugPrint('📦 Total purchases (all statuses): ${allPurchases.length}');

      if (allPurchases.isNotEmpty) {
        final statuses = allPurchases.map((p) => p['status']).toSet();
        debugPrint('💡 Statuses found: $statuses');
      }

      // 3) Fetch PAID purchases with user details
      debugPrint('🔍 Step 3: Fetching PAID purchases with user data...');

      final purchasesResp = await supabase
          .from('purchases')
          .select(
            'id, user_id, amount, status, created_at, users!inner(username, email, photo_url)',
          )
          .eq('product_id', widget.productId)
          .eq('status', 'paid')
          .order('created_at', ascending: false);

      final List<dynamic> purchasesList = purchasesResp as List<dynamic>? ?? [];

      debugPrint('💰 Found ${purchasesList.length} PAID purchases');
      debugPrint(
        '📋 First purchase (if any): ${purchasesList.isNotEmpty ? purchasesList.first : "none"}',
      );

      // Calculate totals from paid purchases
      totalSold = purchasesList.length;
      double earningsSum = 0.0;

      for (final p in purchasesList) {
        final amount = p['amount'];
        if (amount != null) {
          final amountValue = (amount is num)
              ? amount.toDouble()
              : double.tryParse(amount.toString()) ?? widget.price;
          earningsSum += amountValue;
        } else {
          earningsSum += widget.price;
        }
      }

      totalEarnings = earningsSum;
      debugPrint('💵 Total Sold: $totalSold');
      debugPrint('💵 Total Earnings: RM ${totalEarnings.toStringAsFixed(2)}');

      // 4) Build weekly data (last 7 days)
      debugPrint('🔍 Step 4: Building weekly data...');
      final now = DateTime.now().toUtc();
      final startOfPeriod = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));

      // Weekly purchases
      final weekPurchasesResp = await supabase
          .from('purchases')
          .select('id, amount, created_at')
          .eq('product_id', widget.productId)
          .eq('status', 'paid')
          .gte('created_at', startOfPeriod.toIso8601String())
          .order('created_at', ascending: true);

      final List<dynamic> weekPurchases =
          weekPurchasesResp as List<dynamic>? ?? [];
      debugPrint('📅 Weekly purchases: ${weekPurchases.length}');

      // Aggregate weekly sales and earnings
      List<int> sales = List<int>.filled(7, 0);
      List<double> earnings = List<double>.filled(7, 0.0);

      for (final p in weekPurchases) {
        try {
          final createdAtRaw = p['created_at'];
          DateTime? createdAt;
          if (createdAtRaw is String) {
            createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
          } else if (createdAtRaw is DateTime) {
            createdAt = createdAtRaw.toUtc();
          }

          if (createdAt != null) {
            final daysFromStart = createdAt.difference(startOfPeriod).inDays;
            final index = daysFromStart.clamp(0, 6);
            sales[index]++;

            final amount = p['amount'];
            final amt = (amount is num)
                ? amount.toDouble()
                : double.tryParse(amount?.toString() ?? '') ?? widget.price;
            earnings[index] += amt;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing purchase: $e');
        }
      }

      debugPrint('📊 Weekly sales: $sales');
      debugPrint('📊 Weekly earnings: $earnings');

      // 5) Get recent buyers (top 10)
      debugPrint('🔍 Step 5: Preparing recent buyers list...');
      final List<Map<String, dynamic>> buyers = [];
      for (final p in purchasesList.take(10)) {
        final userData = p['users'];
        buyers.add({
          'id': p['id'],
          'user_id': p['user_id'],
          'amount': p['amount'],
          'created_at': p['created_at'],
          'username': userData != null ? userData['username'] : null,
          'photo_url': userData != null ? userData['photo_url'] : null,
        });
      }

      debugPrint('✅ Recent buyers prepared: ${buyers.length}');
      debugPrint('🎉 All data loaded successfully!');

      // 6) Fetch product reviews with user info
      debugPrint('🔍 Step 6: Fetching product reviews...');
      final reviewsResp = await supabase
          .from('product_reviews')
          .select(
            'id, rating, comment, created_at, users!inner(username, photo_url)',
          )
          .eq('product_id', widget.productId)
          .order('created_at', ascending: false);

      final List<dynamic> reviewsList = reviewsResp as List<dynamic>? ?? [];
      debugPrint('⭐ Reviews fetched: ${reviewsList.length}');

      setState(() {
        productReviews = List<Map<String, dynamic>>.from(reviewsList);
      });

      setState(() {
        weeklySales = sales;
        weeklyEarnings = earnings;
        recentBuyers = buyers;
      });
    } catch (e, st) {
      debugPrint('❌ ERROR loading insights: $e');
      debugPrint('📍 Stack trace: $st');
      setState(() {
        error = true;
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  double _calcConversionRate() {
    if (totalViews == 0) return 0.0;
    return (totalSold / totalViews) * 100.0;
  }

  Widget _buildReviewsTab() {
    final reviewsToDisplay = productReviews.take(_reviewsToShow).toList();
    final hasMore = productReviews.length > _reviewsToShow;

    return Column(
      children: [
        Expanded(
          child: productReviews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No reviews yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviewsToDisplay.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    return _buildReviewTile(reviewsToDisplay[index]);
                  },
                ),
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _reviewsToShow += 5;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF58C1D1),
                side: const BorderSide(color: Color(0xFF58C1D1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Load More Reviews'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          widget.productTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadInsights,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewSection(),
                    const SizedBox(height: 16),
                    _buildChartsSection(),
                    const SizedBox(height: 16),
                    _buildBuyersAndReviewsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInsights,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58C1D1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  label: 'Total Sales',
                  value: totalSold.toString(),
                  icon: Icons.shopping_cart_rounded,
                  color: const Color(0xFF58C1D1),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF58C1D1), Color(0xFF45A0B8)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  label: 'Total Views',
                  value: totalViews.toString(),
                  icon: Icons.visibility_rounded,
                  color: const Color(0xFF7C6FDC),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C6FDC), Color(0xFF6A5EC9)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEarningsCard(),
          const SizedBox(height: 12),
          _buildConversionCard(),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RM ${totalEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Total Earnings',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionCard() {
    final conversionRate = _calcConversionRate();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: Colors.orange.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${conversionRate.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Text(
                  'Conversion Rate',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'All Time',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Performance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'Last 7 days',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildChartCard(
            title: 'Sales',
            spots: _generateSpots(
              weeklySales.map((e) => e.toDouble()).toList(),
            ),
            color: const Color(0xFF58C1D1),
            isEmpty: weeklySales.every((v) => v == 0),
          ),
          const SizedBox(height: 16),
          _buildChartCard(
            title: 'Earnings',
            spots: _generateSpots(weeklyEarnings),
            color: const Color(0xFF4CAF50),
            isEmpty: weeklyEarnings.every((v) => v == 0.0),
            prefix: 'RM',
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required List<FlSpot> spots,
    required Color color,
    required bool isEmpty,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No $title in the last 7 days',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ModernLineChart(
                  spots: spots,
                  labels: weekLabels,
                  color: color,
                  prefix: prefix,
                ),
        ),
      ],
    );
  }

  List<FlSpot> _generateSpots(List<double> values) {
    return List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
  }

  Widget _buildBuyersAndReviewsSection() {
    return DefaultTabController(
      length: 2,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            TabBar(
              labelColor: const Color(0xFF58C1D1),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF58C1D1),
              tabs: const [
                Tab(text: 'Recent Buyers'),
                Tab(text: 'Customer Reviews'),
              ],
            ),
            SizedBox(
              height: 500, // Adjust based on your needs
              child: TabBarView(
                children: [_buildBuyersTab(), _buildReviewsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyersTab() {
    final filteredBuyers = _filterBuyersByDate();

    return Column(
      children: [
        // Date filter dropdown
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Filter:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _buyerDateFilter,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(
                        value: 'yesterday',
                        child: Text('Yesterday'),
                      ),
                      DropdownMenuItem(
                        value: 'week',
                        child: Text('Last 7 Days'),
                      ),
                      DropdownMenuItem(
                        value: 'month',
                        child: Text('Last 30 Days'),
                      ),
                      DropdownMenuItem(value: 'all', child: Text('All Time')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _buyerDateFilter = value!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        // Buyers list
        Expanded(
          child: filteredBuyers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No buyers in this period',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredBuyers.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    return _buildBuyerTile(filteredBuyers[index]);
                  },
                ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filterBuyersByDate() {
    if (_buyerDateFilter == 'all') return recentBuyers;

    final now = DateTime.now();
    DateTime filterDate;

    switch (_buyerDateFilter) {
      case 'today':
        filterDate = DateTime(now.year, now.month, now.day);
        break;
      case 'yesterday':
        filterDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1));
        break;
      case 'week':
        filterDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        filterDate = now.subtract(const Duration(days: 30));
        break;
      default:
        return recentBuyers;
    }

    return recentBuyers.where((buyer) {
      try {
        final createdAtRaw = buyer['created_at'];
        if (createdAtRaw is String) {
          final dt = DateTime.parse(createdAtRaw);
          if (_buyerDateFilter == 'yesterday') {
            return dt.year == filterDate.year &&
                dt.month == filterDate.month &&
                dt.day == filterDate.day;
          }
          return dt.isAfter(filterDate);
        }
      } catch (_) {}
      return false;
    }).toList();
  }

  Widget _buildBuyerTile(Map<String, dynamic> buyer) {
    final username = buyer['username'] ?? 'Anonymous';
    final photo = buyer['photo_url'];
    final amount = buyer['amount'];
    final createdAtRaw = buyer['created_at'];

    String dateStr = '';
    String timeStr = '';
    try {
      if (createdAtRaw is String) {
        final dt = DateTime.parse(createdAtRaw).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    final amountValue = (amount is num)
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? widget.price;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF58C1D1).withOpacity(0.1),
            backgroundImage:
                (photo != null && photo is String && photo.isNotEmpty)
                ? NetworkImage(photo)
                : null,
            child: (photo == null || (photo is String && photo.isEmpty))
                ? const Icon(Icons.person, color: Color(0xFF58C1D1))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateStr • $timeStr',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+RM ${amountValue.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildReviewTile(Map<String, dynamic> review) {
  final username = review['users']?['username'] ?? 'Anonymous';
  final photo = review['users']?['photo_url'];
  final rating = review['rating'] ?? 0;
  final comment = review['comment'] ?? '';
  final createdAtRaw = review['created_at'];

  String dateStr = '';
  try {
    if (createdAtRaw is String) {
      final dt = DateTime.parse(createdAtRaw).toLocal();
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }
  } catch (_) {}

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blue.shade50,
          backgroundImage:
              (photo != null && photo is String && photo.isNotEmpty)
              ? NetworkImage(photo)
              : null,
          child: (photo == null || (photo is String && photo.isEmpty))
              ? const Icon(Icons.person, color: Colors.blue)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                comment,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Modern line chart widget
class ModernLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<String> labels;
  final Color color;
  final String? prefix;

  const ModernLineChart({
    super.key,
    required this.spots,
    required this.labels,
    required this.color,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = (spots.map((s) => s.y).fold(0.0, (a, b) => max(a, b)) * 1.3)
        .clamp(1.0, double.infinity);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[idx],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: prefix != null ? 50 : 35,
              interval: max(1, maxY / 4),
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  prefix != null
                      ? '$prefix${value.toInt()}'
                      : value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: max(0, (spots.length - 1).toDouble()),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: color,
                );
              },
            ),
            color: color,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.05)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => color.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final value = prefix != null
                    ? '$prefix${spot.y.toStringAsFixed(0)}'
                    : spot.y.toStringAsFixed(0);
                return LineTooltipItem(
                  value,
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
