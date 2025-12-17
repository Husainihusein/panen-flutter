import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  File? profileImageFile;
  Uint8List? profileImageBytes;
  String? currentPhotoUrl;

  final ImagePicker picker = ImagePicker();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();

  List<String> skills = [];
  List<Map<String, String>> links = [];

  bool isLoading = true;
  bool isSaving = false;
  bool isUploading = false;
  String originalUsername = '';

  final supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> availableSkills = [
    {"name": "Flutter", "icon": FontAwesomeIcons.mobileAlt},
    {"name": "Dart", "icon": FontAwesomeIcons.code},
    {"name": "UI Design", "icon": FontAwesomeIcons.pencilAlt},
    {"name": "Marketing", "icon": FontAwesomeIcons.bullhorn},
    {"name": "Word", "icon": FontAwesomeIcons.fileWord},
    {"name": "Excel", "icon": FontAwesomeIcons.fileExcel},
    {"name": "Canva", "icon": FontAwesomeIcons.paintBrush},
    {"name": "Unity", "icon": FontAwesomeIcons.gamepad},
    {"name": "Photoshop", "icon": FontAwesomeIcons.image},
    {"name": "Python", "icon": FontAwesomeIcons.python},
    {"name": "JavaScript", "icon": FontAwesomeIcons.js},
    {"name": "React", "icon": FontAwesomeIcons.react},
    {"name": "Node.js", "icon": FontAwesomeIcons.node},
    {"name": "Figma", "icon": FontAwesomeIcons.figma},
  ];

  final List<Map<String, dynamic>> availableLinks = [
    {"name": "LinkedIn", "icon": FontAwesomeIcons.linkedin},
    {"name": "Instagram", "icon": FontAwesomeIcons.instagram},
    {"name": "Facebook", "icon": FontAwesomeIcons.facebook},
    {"name": "Twitter", "icon": FontAwesomeIcons.twitter},
    {"name": "GitHub", "icon": FontAwesomeIcons.github},
    {"name": "Email", "icon": FontAwesomeIcons.envelope},
    {"name": "Website", "icon": FontAwesomeIcons.globe},
    {"name": "Portfolio", "icon": FontAwesomeIcons.briefcase},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response =
          await supabase.from('users').select().eq('id', user.id).single()
              as Map<String, dynamic>?;

      if (response != null) {
        setState(() {
          nameController.text = response['name'] ?? '';
          usernameController.text = response['username'] ?? '';
          originalUsername = response['username'] ?? '';
          bioController.text = response['bio'] ?? '';
          skills = List<String>.from(response['skills'] ?? []);
          links = (response['links'] as List<dynamic>? ?? [])
              .map((e) => Map<String, String>.from(e))
              .toList();
          currentPhotoUrl = response['photo_url'];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    if (username.toLowerCase() == originalUsername.toLowerCase()) return true;

    try {
      final res = await supabase
          .from('users')
          .select()
          .eq('username', username.toLowerCase());
      return (res as List).isEmpty;
    } catch (e) {
      debugPrint('Error checking username: $e');
      return false;
    }
  }

  Future<void> _saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    if (usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Username cannot be empty')));
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(usernameController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Username can only contain letters, numbers, and underscores',
          ),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final isUsernameAvailable = await _checkUsernameAvailability(
        usernameController.text.trim(),
      );
      if (!isUsernameAvailable) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken')),
        );
        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => isSaving = false);
        return;
      }

      String? photoUrl;
      if (profileImageFile != null || profileImageBytes != null) {
        setState(() => isUploading = true);

        Uint8List imageData = kIsWeb
            ? profileImageBytes!
            : await profileImageFile!.readAsBytes();

        // Resize & compress
        img.Image? decodedImage = img.decodeImage(imageData);
        if (decodedImage != null) {
          img.Image resized = img.copyResize(
            decodedImage,
            width: 512,
            height: 512,
          );
          imageData = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
        }

        final uid = user.id;
        final filePath = '$uid/profile.jpg';

        await supabase.storage
            .from('profile_photos')
            .uploadBinary(
              filePath,
              imageData,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        photoUrl = supabase.storage
            .from('profile_photos')
            .getPublicUrl(filePath);
      }

      final updateData = {
        'name': nameController.text.trim(),
        'username': usernameController.text.trim().toLowerCase(),
        'bio': bioController.text.trim(),
        'skills': skills,
        'links': links,
      };
      if (photoUrl != null) updateData['photo_url'] = photoUrl;

      await supabase.from('users').update(updateData).eq('id', user.id);

      setState(() => isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        isSaving = false;
        isUploading = false;
      });
      debugPrint('Error saving profile: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() => profileImageBytes = bytes);
      } else {
        setState(() => profileImageFile = File(image.path));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo selected! Click "Save Changes" to upload'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF58C1D1),
              ),
              title: const Text("Choose from Gallery"),
              onTap: () {
                pickImage(ImageSource.gallery);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF58C1D1)),
              title: const Text("Take Photo"),
              onTap: () {
                pickImage(ImageSource.camera);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    ImageProvider? imageProvider;
    if (profileImageFile != null) {
      imageProvider = FileImage(profileImageFile!);
    } else if (profileImageBytes != null) {
      imageProvider = MemoryImage(profileImageBytes!);
    } else if (currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(currentPhotoUrl!);
    }

    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? const Icon(Icons.person, size: 60, color: Colors.white)
          : null,
    );
  }

  // --- Skills & Links Methods ---
  void _addSkill() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedSkill;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Add Skill",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Select Skill",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: availableSkills
                    .where((skill) => !skills.contains(skill["name"]))
                    .map(
                      (skill) => DropdownMenuItem<String>(
                        value: skill["name"] as String,
                        child: Row(
                          children: [
                            FaIcon(skill["icon"], size: 18),
                            const SizedBox(width: 8),
                            Text(skill["name"] as String),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedSkill = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF58C1D1),
                  ),
                  onPressed: () {
                    if (selectedSkill != null) {
                      setState(() {
                        skills.add(selectedSkill!);
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    "Add",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addLink() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedLinkName;
        IconData? selectedIcon;
        final TextEditingController linkController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Add Link",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: InputDecoration(
                      labelText: "Link Type",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: availableLinks
                        .map(
                          (link) => DropdownMenuItem(
                            value: link,
                            child: Row(
                              children: [
                                FaIcon(link["icon"], size: 18),
                                const SizedBox(width: 8),
                                Text(link["name"]),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedLinkName = value?["name"];
                        selectedIcon = value?["icon"];
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: linkController,
                    decoration: InputDecoration(
                      labelText: "URL or Handle",
                      hintText: "e.g., https://linkedin.com/in/yourname",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF58C1D1),
                  ),
                  onPressed: () {
                    if (selectedLinkName != null &&
                        linkController.text.isNotEmpty) {
                      setState(() {
                        links.add({
                          "label": selectedLinkName!,
                          "url": linkController.text.trim(),
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    "Add",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSkillChip(String skillName, int index) {
    IconData icon = FontAwesomeIcons.star; // fallback icon
    for (var skill in availableSkills) {
      if (skill["name"] == skillName) {
        icon = skill["icon"];
      }
    }
    return Chip(
      backgroundColor: Colors.green.shade50,
      label: Text(skillName, style: const TextStyle(color: Colors.green)),
      avatar: FaIcon(icon, size: 16, color: Colors.green),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: () {
        setState(() {
          skills.removeAt(index);
        });
      },
    );
  }

  Widget _buildLinkItem(Map<String, String> link, int index) {
    IconData linkIcon = FontAwesomeIcons.link;
    for (var availableLink in availableLinks) {
      if (availableLink["name"] == link["label"]) {
        linkIcon = availableLink["icon"];
        break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF58C1D1).withOpacity(0.1),
          child: FaIcon(linkIcon, color: const Color(0xFF58C1D1), size: 20),
        ),
        title: Text(
          link["label"] ?? "Link",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          link["url"] ?? "",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () {
            setState(() {
              links.removeAt(index);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          _buildProfileImage(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showImagePicker,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF58C1D1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: "Name",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: usernameController,
                              decoration: InputDecoration(
                                labelText: "Username",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: bioController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: "Bio",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Skills",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextButton(
                                  onPressed: _addSkill,
                                  child: const Text("Add Skill"),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                skills.length,
                                (index) =>
                                    _buildSkillChip(skills[index], index),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Links",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextButton(
                                  onPressed: _addLink,
                                  child: const Text("Add Link"),
                                ),
                              ],
                            ),
                            Column(
                              children: List.generate(
                                links.length,
                                (index) => _buildLinkItem(links[index], index),
                              ),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: isSaving || isUploading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFF58C1D1),
              ),
              child: isSaving || isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Save Changes",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
