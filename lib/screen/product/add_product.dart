import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final supabase = Supabase.instance.client;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController videoUrlController = TextEditingController();
  final TextEditingController fileLinkController = TextEditingController();

  String? selectedCategory;
  String? selectedNiche;

  File? productImage;
  File? previewImage;
  File? uploadedFile;

  final ImagePicker picker = ImagePicker();
  bool useExternalLink = false;

  bool isLicensed = false;

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case 'txt':
        return 'text/plain';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String> uploadFile(File file, String bucketName) async {
    final user = supabase.auth.currentUser!;
    final fileName =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    await supabase.storage
        .from(bucketName)
        .upload(fileName, file, fileOptions: const FileOptions(upsert: true));
    return supabase.storage.from(bucketName).getPublicUrl(fileName);
  }

  // Categories
  final List<Map<String, dynamic>> categories = [
    {'label': 'E-book', 'icon': FontAwesomeIcons.book},
    {'label': 'Template', 'icon': FontAwesomeIcons.fileLines},
    {'label': 'Audio', 'icon': FontAwesomeIcons.music},
    {'label': 'Video', 'icon': FontAwesomeIcons.video},
    {'label': 'Graphic Design', 'icon': FontAwesomeIcons.penFancy},
    {'label': 'Software', 'icon': FontAwesomeIcons.code},
    {'label': 'Others', 'icon': FontAwesomeIcons.box},
  ];

  final List<String> niches = [
    'Marketing',
    'Education',
    'Finance',
    'Tech',
    'Design',
    'Lifestyle',
    'Fitness',
    'Health',
    'Other',
  ];

  // Pick product image
  Future<void> pickProductImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => productImage = File(image.path));
  }

  // Pick preview image
  Future<void> pickPreviewImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => previewImage = File(image.path));
  }

  // Pick digital file
  Future<void> pickDigitalFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xlsx',
        'pptx',
        'zip',
        'rar',
        'txt',
        'mp3',
        'wav',
        'mp4',
        'mov',
        'jpg',
        'png',
        'gif',
      ],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => uploadedFile = File(result.files.single.path!));
    }
  }

  // Add Product
  Future<void> addProduct() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }

    // Validate required fields
    if (titleController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        priceController.text.isEmpty ||
        selectedCategory == null ||
        selectedNiche == null ||
        productImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields.")),
      );
      return;
    }

    try {
      // ------------------ Upload Thumbnail ------------------
      final thumbPath =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${productImage!.path.split('/').last}';
      print('Uploading thumbnail to: $thumbPath');
      await supabase.storage
          .from('product-thumbnails')
          .upload(
            thumbPath,
            productImage!,
            fileOptions: const FileOptions(upsert: true),
          );
      final thumbnailUrl = supabase.storage
          .from('product-thumbnails')
          .getPublicUrl(thumbPath);

      // ------------------ Upload Preview ------------------
      String previewUrl = '';
      if (previewImage != null) {
        final previewPath =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${previewImage!.path.split('/').last}';
        print('Uploading preview to: $previewPath');
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

      // ------------------ Upload Product File ------------------
      String finalFileUrl = fileLinkController.text.trim();
      if (!useExternalLink && uploadedFile != null) {
        final filePath =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${uploadedFile!.path.split('/').last}';
        print('Uploading file to: $filePath');

        // ✅ Get the correct MIME type
        final fileName = uploadedFile!.path.split('/').last;
        final mimeType = _getMimeType(fileName);

        await supabase.storage
            .from('product-files')
            .upload(
              filePath,
              uploadedFile!,
              fileOptions: FileOptions(upsert: true, contentType: mimeType),
            );
        finalFileUrl = supabase.storage
            .from('product-files')
            .getPublicUrl(filePath);
      }

      // ------------------ Insert Product ------------------
      final insertedRows = await supabase.from('products').insert({
        'owner_id': user.id,
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'price': double.tryParse(priceController.text) ?? 0.0,
        'category': selectedCategory,
        'niche': selectedNiche,
        'thumbnail_url': thumbnailUrl,
        'preview_image_url': previewUrl,
        'video_url': videoUrlController.text.trim(),
        'file_url': finalFileUrl,
        'views': 0,
        'status': 'review',
        'is_active': true,
      }).select(); // optional: returns inserted rows

      print('Product inserted successfully! Rows: $insertedRows');

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Success"),
          content: const Text("Product added successfully!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Add product failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add product failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Add Product",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Product Title",
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
                  child: productImage == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Colors.grey,
                        )
                      : Image.file(productImage!, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Preview Image
            const Text(
              "Preview Image",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: pickPreviewImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: previewImage == null
                      ? const Text(
                          "Add Preview Image",
                          style: TextStyle(color: Colors.grey),
                        )
                      : Image.file(previewImage!, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category dropdown
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat['label'],
                  child: Row(
                    children: [
                      FaIcon(cat['icon'], size: 16),
                      const SizedBox(width: 8),
                      Text(cat['label']),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedCategory = val),
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Niche dropdown
            DropdownButtonFormField<String>(
              value: selectedNiche,
              items: niches
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (val) => setState(() => selectedNiche = val),
              decoration: const InputDecoration(
                labelText: "Niche",
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
                border: OutlineInputBorder(),
                prefixText: "RM ",
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Video URL
            TextField(
              controller: videoUrlController,
              decoration: const InputDecoration(
                labelText: "Preview Video URL",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // File or Link
            // ------------------ File / External Link Section ------------------
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => useExternalLink = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !useExternalLink
                            ? Colors.blue
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !useExternalLink
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          "Upload File",
                          style: TextStyle(
                            color: !useExternalLink
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => useExternalLink = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: useExternalLink
                            ? Colors.blue
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: useExternalLink
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          "External Link",
                          style: TextStyle(
                            color: useExternalLink
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ------------------ Conditional Box Below ------------------
            useExternalLink
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade300, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: fileLinkController,
                      decoration: const InputDecoration(
                        labelText: "External File URL",
                        border: InputBorder.none,
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: pickDigitalFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade100.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.attach_file, color: Colors.blue),
                          const SizedBox(width: 10),
                          Text(
                            uploadedFile == null
                                ? "Choose File"
                                : uploadedFile!.path.split('/').last,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isLicensed,
                  onChanged: (val) => setState(() => isLicensed = val ?? false),
                ),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black),
                      children: [
                        TextSpan(
                          text:
                              "I confirm that this product is my original work and I have full rights to upload it. "
                              "I understand that I am fully responsible for any copyright or licensing issues. "
                              "The app/company is not liable for any disputes arising from this product.",
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLicensed ? addProduct : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLicensed
                      ? const Color(0xFF58C1D1)
                      : Colors.grey,
                ),
                child: const Text(
                  "Add Product",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
