import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import '../chat/chat_detail.dart';
import '../product/edit_product.dart';
import '../profile/profile_page.dart';

class ViewProductPage extends StatefulWidget {
  final String productId;
  final String title;
  final num price;
  final String creator;
  final String? photoUrl;
  final String thumbnailUrl;
  final String fileUrl;
  final String description;
  final String videoUrl;
  final String? previewImageUrl;
  final String? ownerId;

  const ViewProductPage({
    super.key,
    required this.productId,
    required this.title,
    required this.price,
    required this.creator,
    this.ownerId,
    this.photoUrl,
    required this.thumbnailUrl,
    required this.fileUrl,
    required this.description,
    required this.videoUrl,
    this.previewImageUrl,
  });

  @override
  State<ViewProductPage> createState() => _ViewProductPageState();
}

class _ViewProductPageState extends State<ViewProductPage> {
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoController;
  bool _isVideoReady = false;

  bool _hasPurchased = false;
  String? _currentPurchaseId;
  bool _canDownload = false;
  bool _isCheckingPurchase = true;
  RealtimeChannel? _purchaseChannel;

  bool _isBookmarked = false;

  int _userRating = 0;
  final TextEditingController _reviewController = TextEditingController();

  bool _isReviewLoading = true;
  List<dynamic> _reviews = [];

  String? _editingReviewId; // null = not editing

  // Deep link handling
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _checkPurchaseStatus();
    _subscribePurchaseUpdates();
    _initDeepLinks();
    _incrementViews();
    _checkIfBookmarked();
    _checkPurchase();
    _fetchReviews();
  }

  Future<void> _checkIfBookmarked() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final saved = await supabase
        .from('product_saves')
        .select()
        .eq('user_id', user.id)
        .eq('product_id', widget.productId)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _isBookmarked = saved != null;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (_isBookmarked) {
        // Remove from library
        await supabase
            .from('product_saves')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', widget.productId);
        if (mounted) {
          setState(() {
            _isBookmarked = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Removed from library')));
        }
      } else {
        // Save to library
        await supabase.from('product_saves').insert({
          'user_id': user.id,
          'product_id': widget.productId,
        });
        if (mounted) {
          setState(() {
            _isBookmarked = true;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved to library')));
        }
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _checkPurchase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('purchases')
          .select('id, status')
          .eq('user_id', userId)
          .eq('product_id', widget.productId)
          .eq('status', 'paid')
          .maybeSingle();

      setState(() {
        _hasPurchased = response != null;
        _currentPurchaseId = response?['id']; // store purchase id
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error checking purchase: $e')));
      }
    }
  }

  void _handleDownloadNow() async {
    await _handleDownload(); // your existing download logic
    if (!mounted) return;

    // Show the "Did you get your product?" popup
    final gotFile = await showDialog<bool>(
      context: context,
      builder: (_) => GotFileDialog(),
    );

    if (gotFile == true) {
      setState(() {
        _canDownload = false; // reset button to Buy Now
      });
    }
  }

  Future<void> _fetchReviews() async {
    setState(() => _isReviewLoading = true);

    final res = await Supabase.instance.client
        .from('product_reviews')
        .select(
          'id, rating, comment, user_id, created_at, user:users(username, photo_url)',
        )
        .eq('product_id', widget.productId)
        .order('created_at', ascending: false);

    setState(() {
      _reviews = res;
      _isReviewLoading = false;
    });
  }

  Future<void> _submitReview() async {
    final user = Supabase.instance.client.auth.currentUser;

    // Don't proceed if no user, no rating, or no comment
    if (user == null ||
        _userRating == 0 ||
        _reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating and comment')),
      );
      return;
    }

    final reviewsTable = Supabase.instance.client.from('product_reviews');
    final reviewData = {
      'product_id': widget.productId,
      'user_id': user.id,
      'rating': _userRating,
      'comment': _reviewController.text.trim(),
    };

    try {
      if (_editingReviewId == null) {
        // Insert new review
        await reviewsTable.insert(reviewData);
      } else {
        // Update existing review
        await reviewsTable
            .update({
              'rating': _userRating,
              'comment': _reviewController.text.trim(),
            })
            .eq(
              'id',
              _editingReviewId!,
            ); // Safe because we checked it's not null
      }

      // Reset form
      setState(() {
        _editingReviewId = null;
        _userRating = 0;
        _reviewController.clear();
      });

      // Reload reviews
      await _fetchReviews();
    } catch (e) {
      debugPrint('Error submitting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
      }
    }
  }

  void _startEditingReview(dynamic review) {
    setState(() {
      _editingReviewId = review['id'].toString();
      _userRating = review['rating'];
      _reviewController.text = review['comment'];
    });
  }

  Future<void> _deleteReview(String id) async {
    await Supabase.instance.client
        .from('product_reviews')
        .delete()
        .eq('id', id);
    await _fetchReviews();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Review deleted")));
  }

  void _showDeleteConfirmation(String reviewId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Review',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to delete this review? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteReview(reviewId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _incrementViews() async {
    try {
      await Supabase.instance.client.rpc(
        'increment_product_views',
        params: {'p_id': widget.productId},
      );
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  Future<void> _incrementSold() async {
    try {
      await Supabase.instance.client.rpc(
        'increment_product_sold',
        params: {'p_id': widget.productId},
      );
    } catch (e) {
      debugPrint('Error incrementing sold: $e');
    }
  }

  void _initVideo() {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) return;

    if (YoutubePlayer.convertUrlToId(url) != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: YoutubePlayer.convertUrlToId(url)!,
        flags: const YoutubePlayerFlags(autoPlay: false),
      );
      _isVideoReady = true;
    } else if (url.endsWith(".mp4")) {
      _videoController = VideoPlayerController.network(url)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoReady = true;
            });
          }
        });
    } else {
      _isVideoReady = true;
    }
  }

  Future<void> _checkPurchaseStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isCheckingPurchase = false;
        });
      }
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('purchases')
          .select()
          .eq('user_id', user.id)
          .eq('product_id', widget.productId)
          .eq('status', 'paid')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _hasPurchased = response != null;
          _isCheckingPurchase = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking purchase status: $e');
      if (mounted) {
        setState(() {
          _isCheckingPurchase = false;
        });
      }
    }
  }

  void _subscribePurchaseUpdates() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _purchaseChannel = Supabase.instance.client
        .channel('purchases_${widget.productId}_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchases',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final productId = payload.newRecord['product_id'];
            final status = payload.newRecord['status'];

            if (productId == widget.productId && status == 'paid') {
              if (mounted) {
                setState(() {
                  _hasPurchased = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment confirmed! You can now download.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          },
        )
        .subscribe();
  }

  // Initialize deep links
  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Handle links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Handle links when app is launched from deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Deep link received: $uri');

    if (uri.host == 'payment' && uri.pathSegments.contains('success')) {
      final productId = uri.queryParameters['product_id'];

      if (productId == widget.productId) {
        if (mounted) {
          setState(() {
            _isCheckingPurchase = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Verifying purchase...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Manually update the purchase status
        try {
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;

          if (user != null) {
            debugPrint(
              'Updating purchase for user: ${user.id}, product: $productId',
            );

            // Find the most recent pending purchase for this product
            final response = await supabase
                .from('purchases')
                .select()
                .eq('user_id', user.id)
                .eq('product_id', widget.productId)
                .eq('status', 'pending')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            debugPrint('Found pending purchase: $response');

            if (response != null) {
              // Update it to paid
              final updateResult = await supabase
                  .from('purchases')
                  .update({
                    'status': 'paid',
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', response['id'])
                  .select();

              await _incrementSold();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Purchase confirmed! You can now download.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              debugPrint('No pending purchase found');
            }
          }
        } catch (e) {
          debugPrint('Error updating purchase: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error verifying purchase: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        // Wait a bit then check purchase status
        await Future.delayed(const Duration(milliseconds: 500));
        _checkPurchaseStatus();

        // Check again after a delay to ensure UI updates
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _checkPurchaseStatus();
        });
      }
    }
  }

  Future<void> _handleBuyNow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to purchase')),
        );
      }
      return;
    }

    final session = supabase.auth.currentSession;
    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please sign in again.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Creating payment link...')));
    }

    try {
      debugPrint('DEBUG: Calling edge function with user: ${user.id}');

      final response = await supabase.functions.invoke(
        'createBillplzBill',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {
          'user_id': user.id,
          'product_id': widget.productId,
          'amount': widget.price,
          'email': user.email,
        },
      );

      debugPrint('DEBUG: Response status: ${response.status}');
      debugPrint('DEBUG: Response data: ${response.data}');

      if (response.data == null) {
        throw Exception('No response from payment service');
      }

      final data = response.data as Map<String, dynamic>;
      final billUrl = data['billUrl'] as String?;

      if (billUrl == null || billUrl.isEmpty) {
        throw Exception('Payment URL not found in response');
      }

      // Open Billplz payment page externally
      final uri = Uri.parse(billUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // After payment page opens, set _canDownload = true
        // So the button now shows "Download Now"
        setState(() {
          _canDownload = true;
        });

        // Optional: show a fun toast/snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment initiated! You can now download your product.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDownload() async {
    if (widget.fileUrl.isEmpty) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to download')),
      );
      return;
    }

    try {
      // 1️⃣ Check if this is a Supabase file
      final isSupabaseFile =
          widget.fileUrl.contains('.supabase.co/storage/') &&
          widget.fileUrl.contains('product-files');

      if (!isSupabaseFile) {
        // External link (Google Drive, Dropbox, etc.)
        final uri = Uri.tryParse(widget.fileUrl);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        } else {
          throw Exception('Invalid URL or cannot open link');
        }
      }

      // 2️⃣ Request storage permission (Android)
      if (Platform.isAndroid) {
        if (!await Permission.manageExternalStorage.isGranted) {
          final result = await Permission.manageExternalStorage.request();
          if (!result.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission is required to download files',
                ),
              ),
            );
            return;
          }
        }
      }

      // 3️⃣ Get storage directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists())
          directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null)
        throw Exception('Could not access storage directory');

      // 4️⃣ Determine file name
      final fileName =
          _getFileNameFromUrl(widget.fileUrl) ??
          '${widget.title}_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${directory.path}/$fileName';
      debugPrint('Downloading to: $filePath');

      // 5️⃣ Generate signed URL for Supabase
      final uri = Uri.parse(widget.fileUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('product-files');
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        throw Exception('Invalid product-files URL format');
      }
      final filePathInBucket = pathSegments.sublist(bucketIndex + 1).join('/');
      final downloadUrl = await supabase.storage
          .from('product-files')
          .createSignedUrl(filePathInBucket, 3600);

      if (downloadUrl.isEmpty)
        throw Exception('Failed to generate download link');

      // 6️⃣ Download using Dio
      final dio = Dio();
      await dio.download(downloadUrl, filePath);

      // 7️⃣ Open file with correct MIME type
      final fileExtension = filePath.split('.').last.toLowerCase();
      String? mimeType;
      if (fileExtension == 'pdf') mimeType = 'application/pdf';
      if (fileExtension == 'jpg' || fileExtension == 'jpeg')
        mimeType = 'image/jpeg';
      if (fileExtension == 'png') mimeType = 'image/png';

      await OpenFile.open(filePath, type: mimeType);

      // 8️⃣ Record download in Supabase (optional: link to purchase)
      final lastPurchase = await supabase
          .from('purchases')
          .select()
          .eq('user_id', user.id)
          .eq('product_id', widget.productId)
          .eq('status', 'paid')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      await supabase.from('product_downloads').insert({
        'user_id': user.id,
        'product_id': widget.productId,
        'purchase_id': lastPurchase != null ? lastPurchase['id'] : null,
      });

      // 9️⃣ Interactive popup after download
      if (!mounted) return;

      final gotFile = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF58C1D1), Color(0xFF7DE0E6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Download Complete!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Did you successfully get your digital product?',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF58C1D1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF58C1D1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (gotFile == true) {
        setState(() {
          _hasPurchased = false; // Reset button to Buy Now
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded to ${directory.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String? _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        String fileName = Uri.decodeComponent(segments.last);
        if (fileName.contains('?')) {
          fileName = fileName.split('?').first;
        }
        return fileName;
      }
    } catch (e) {
      debugPrint('Error extracting filename: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getOrCreateChat(
    String currentUserId,
    String otherUserId,
  ) async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('chats')
        .select()
        .or(
          'and(user1_id.eq.$currentUserId,user2_id.eq.$otherUserId),'
          'and(user1_id.eq.$otherUserId,user2_id.eq.$currentUserId)',
        )
        .maybeSingle();

    if (response != null) return response;

    final insertResponse = await supabase
        .from('chats')
        .insert({'user1_id': currentUserId, 'user2_id': otherUserId})
        .select()
        .single();

    return insertResponse;
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoController?.dispose();
    _purchaseChannel?.unsubscribe();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final ownerId = widget.ownerId ?? '';
    final isOwner = currentUserId != null && currentUserId == ownerId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                image: widget.thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(widget.thumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: widget.thumbnailUrl.isEmpty
                  ? const Text(
                      '[ Product Image ]',
                      style: TextStyle(color: Colors.black54),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (isOwner)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditProductScreen(productId: widget.productId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF58C1D1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        LucideIcons.messageCircle,
                        color: Color(0xFF58C1D1),
                      ),
                      tooltip: 'Chat with creator',
                      onPressed: () async {
                        if (currentUserId == null || ownerId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not open chat: owner ID missing',
                              ),
                            ),
                          );
                          return;
                        }
                        try {
                          final chat = await _getOrCreateChat(
                            currentUserId,
                            ownerId,
                          );
                          if (chat != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                  chatId: chat['id'],
                                  otherUserName: widget.creator,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not open chat: $e'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      _isBookmarked
                          ? LucideIcons.bookmark
                          : LucideIcons.bookmarkPlus,
                      color: _isBookmarked ? Colors.red : Colors.black54,
                    ),
                    tooltip: _isBookmarked
                        ? 'Remove from library'
                        : 'Save to library',
                    onPressed: _toggleBookmark,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {
                  if (widget.ownerId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: widget.ownerId),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          (widget.photoUrl != null &&
                              widget.photoUrl!.isNotEmpty)
                          ? NetworkImage(widget.photoUrl!)
                          : null,
                      child:
                          (widget.photoUrl == null || widget.photoUrl!.isEmpty)
                          ? Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey.shade600,
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'by ${widget.creator}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RM ${widget.price.toString()}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 8,
                    children: [
                      _TagChip(label: '#UI'),
                      _TagChip(label: '#Template'),
                      _TagChip(label: '#Flutter'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    'About this digital product',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      color: Colors.black87,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // ================= PREVIEW VIDEO =================
                  if (widget.videoUrl.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    const Text(
                      'Preview Video',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _launchExternalURL(widget.videoUrl),
                      child: _buildVideoWidget(),
                    ),
                  ],

                  // ================= PREVIEW IMAGE =================
                  if (widget.previewImageUrl != null &&
                      widget.previewImageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    const Text(
                      'Preview Image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _showPreviewDialog(),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(widget.previewImageUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Buy / Download Button
                  SizedBox(
                    width: double.infinity,
                    child: _isCheckingPurchase
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF58C1D1),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _canDownload
                                ? _handleDownloadNow
                                : _handleBuyNow,
                            icon: Icon(
                              _canDownload ? Icons.lock_open : Icons.lock,
                              color: Colors.white,
                            ),
                            label: Text(
                              _canDownload ? 'Download Now' : 'Buy Now',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF58C1D1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // ⭐ REVIEWS SECTION ⭐
                  const Divider(),
                  const SizedBox(height: 10),

                  const Text(
                    "Customer Reviews",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Reviews List ---
                  _isReviewLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFF58C1D1),
                            ),
                          ),
                        )
                      : _reviews.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              "No reviews yet. Be the first to review!",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: _reviews.map((review) {
                            final rating = review['rating'];
                            final comment = review['comment'];
                            final username = review['user']['username'];
                            final profileImage =
                                review['user']['photo_url'] ?? '';
                            final userId = review['user_id'];
                            final currentUser =
                                Supabase.instance.client.auth.currentUser?.id;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(
                                            0xFF58C1D1,
                                          ),
                                          backgroundImage:
                                              profileImage.isNotEmpty
                                              ? NetworkImage(profileImage)
                                              : null,
                                          child: profileImage.isEmpty
                                              ? Text(
                                                  username
                                                          ?.substring(0, 1)
                                                          .toUpperCase() ??
                                                      "U",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                username ?? "User",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (index) => Icon(
                                                    Icons.star,
                                                    size: 14,
                                                    color: index < rating
                                                        ? Colors.amber
                                                        : Colors.grey.shade300,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // --- Three Dots Menu (only for own reviews) ---
                                        if (currentUser == userId)
                                          PopupMenuButton<String>(
                                            icon: const Icon(
                                              Icons.more_vert,
                                              color: Colors.black54,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _startEditingReview(review);
                                              } else if (value == 'delete') {
                                                _showDeleteConfirmation(
                                                  review['id'],
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (BuildContext context) => [
                                                  const PopupMenuItem<String>(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.edit,
                                                          size: 18,
                                                          color: Color(
                                                            0xFF58C1D1,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('Edit Review'),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem<String>(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          size: 18,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('Delete Review'),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      comment ?? "",
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 24),

                  // --- Write / Edit Review Section ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _editingReviewId == null
                                  ? "Write a Review"
                                  : "Edit Your Review",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            if (_editingReviewId != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _editingReviewId = null;
                                    _userRating = 0;
                                    _reviewController.clear();
                                  });
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Star rating selector
                        Row(
                          children: [
                            const Text(
                              'Rating: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            ...List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _userRating = index + 1);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Icon(
                                    Icons.star,
                                    color: index < _userRating
                                        ? Colors.amber
                                        : Colors.grey.shade300,
                                    size: 28,
                                  ),
                                ),
                              );
                            }),
                            if (_userRating > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  '$_userRating/5',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Comment input
                        TextField(
                          controller: _reviewController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText:
                                "Share your thoughts about this product...",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF58C1D1),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Submit / Update button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitReview,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF58C1D1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: Text(
                              _editingReviewId == null
                                  ? "Submit Review"
                                  : "Update Review",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Secure digital delivery • No refunds on downloadable files',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoWidget() {
    if (_youtubeController != null) {
      return YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
      );
    } else if (_videoController != null &&
        _videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Tap to open video externally',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
  }

  void _showPreviewDialog() {
    if (widget.previewImageUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.network(widget.previewImageUrl!)),
      ),
    );
  }

  Future<void> _launchExternalURL(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
      }
    }
  }
}

class GotFileDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF58C1D1), Color(0xFF7DE0E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_done, size: 50, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Did you get your digital product?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Yes',
                    style: TextStyle(color: Color(0xFF58C1D1)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'No',
                    style: TextStyle(color: Color(0xFF58C1D1)),
                  ),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
