import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;

class EditProductScreen extends StatefulWidget {
  final String productId;

  const EditProductScreen({super.key, required this.productId});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final supabase = Supabase.instance.client;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController fileLinkController = TextEditingController();
  final TextEditingController videoUrlController = TextEditingController();

  String? selectedCategory;
  File? productImage;
  File? previewImage;

  String? existingThumbnailUrl;
  String? existingPreviewUrl;

  final ImagePicker picker = ImagePicker();

  final Map<String, IconData> categoryIcons = {
    "E-book": Icons.book,
    "Template": Icons.description,
    "Audio": Icons.audiotrack,
    "Video": Icons.video_library,
    "Graphic Design": Icons.brush,
    "Software": Icons.computer,
    "Others": Icons.widgets,
  };

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    try {
      final data = await supabase
          .from('products')
          .select()
          .eq('id', widget.productId)
          .single();

      if (data == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product not found')));
        return;
      }
      titleController.text = data['title'] ?? '';
      priceController.text = (data['price'] ?? 0.0).toString();
      descriptionController.text = data['description'] ?? '';
      fileLinkController.text = data['file_url'] ?? '';
      videoUrlController.text = data['video_url'] ?? '';
      selectedCategory = data['category'];
      existingThumbnailUrl = data['thumbnail_url'];
      existingPreviewUrl = data['preview_image_url'];

      setState(() {});
    } catch (e) {
      debugPrint('Error loading product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load product data')),
      );
    }
  }

  Future<void> pickProductImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => productImage = File(image.path));
  }

  Future<void> pickPreviewImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => previewImage = File(image.path));
  }

  Future<String> compressImageToBase64(
    File file, {
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 80,
  }) async {
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception("Cannot decode image");

    img.Image resized = img.copyResize(
      image,
      width: maxWidth,
      height: maxHeight,
    );
    final compressedBytes = img.encodeJpg(resized, quality: quality);
    return base64Encode(compressedBytes);
  }

  Future<void> updateProduct() async {
    if (titleController.text.isEmpty ||
        priceController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields.")),
      );
      return;
    }

    try {
      final user = supabase.auth.currentUser!;
      String thumbnailUrl = existingThumbnailUrl ?? '';
      String previewUrl = existingPreviewUrl ?? '';
      String finalFileUrl = fileLinkController.text.trim(); // keep file as-is

      // ------------------ Upload Thumbnail ------------------
      if (productImage != null) {
        final path =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${productImage!.path.split('/').last}';
        await supabase.storage
            .from('product-thumbnails')
            .upload(
              path,
              productImage!,
              fileOptions: const FileOptions(upsert: true),
            );
        thumbnailUrl = supabase.storage
            .from('product-thumbnails')
            .getPublicUrl(path);
      }

      // ------------------ Upload Preview ------------------
      if (previewImage != null) {
        final previewPath =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${previewImage!.path.split('/').last}';
        await supabase.storage
            .from('product-previews')
            .upload(
              previewPath,
              previewImage!,
              fileOptions: const FileOptions(upsert: true),
            );
        previewUrl = supabase.storage
            .from('product-previews')
            .getPublicUrl(previewPath);
      }

      // ------------------ Update Product ------------------
      final updatedRows = await supabase
          .from('products')
          .update({
            'title': titleController.text.trim(),
            'description': descriptionController.text.trim(),
            'price': double.tryParse(priceController.text) ?? 0.0,
            'category': selectedCategory,
            'thumbnail_url': thumbnailUrl,
            'preview_image_url': previewUrl,
            'video_url': videoUrlController.text.trim(),
            'file_url': finalFileUrl, // remain unchanged
          })
          .eq('id', widget.productId)
          .select();

      if (updatedRows == null || updatedRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update product')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Product updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error updating product: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating product: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Edit Product",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Product Title
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Product Title",
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Product Image
            const Text(
              "Product Image",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: pickProductImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: productImage != null
                      ? Image.file(productImage!, fit: BoxFit.cover)
                      : (existingThumbnailUrl != null &&
                            existingThumbnailUrl!.isNotEmpty)
                      ? Image.network(existingThumbnailUrl!, fit: BoxFit.cover)
                      : const Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Colors.grey,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categoryIcons.keys
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(categoryIcons[cat], color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(cat),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => selectedCategory = value),
              decoration: const InputDecoration(
                labelText: "Category",
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Price
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Price",
                prefixText: "RM ",
                prefixStyle: TextStyle(fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Description",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Preview Image
            const Text(
              "Preview",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: pickPreviewImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: previewImage != null
                      ? Image.file(previewImage!, fit: BoxFit.cover)
                      : (existingPreviewUrl != null &&
                            existingPreviewUrl!.isNotEmpty)
                      ? Image.network(existingPreviewUrl!, fit: BoxFit.cover)
                      : const Text(
                          "Add Preview Image",
                          style: TextStyle(color: Colors.grey),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Video URL
            TextField(
              controller: videoUrlController,
              decoration: const InputDecoration(
                labelText: "Preview Video URL",
                prefixIcon: Icon(Icons.video_library),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ------------------ File info only ------------------
            const Text(
              "Digital Product (File cannot be changed)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileLinkController.text.isNotEmpty
                          ? fileLinkController.text.split('/').last
                          : "No file available",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Update Product button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF58C1D1),
                ),
                onPressed: updateProduct,
                child: const Text(
                  "Update Product",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
