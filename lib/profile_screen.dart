import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'edit_profile_screen.dart'; // Adjust the path if needed

import 'dart:io';
import 'main.dart';

// Cloudinary configuration
final cloudinary = CloudinaryPublic(
  'dkcqc2zpd', // Your cloud name
  'travel_app_preset', // Your upload preset
  cache: false,
);

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _gender;
  File? _profilePic;
  String? _errorMessage;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isUploadingImage = false; // Track image upload state
  String? _profileImageUrl;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      var userDoc =
          await _firestore.collection('users').doc(widget.userId).get();
      var userData = userDoc.data();
      if (userData != null) {
        setState(() {
          _usernameController.text = userData['username'] ?? '';
          _dobController.text = userData['dob'] ?? '';
          _phoneNumberController.text = userData['phoneNumber'] ?? '';
          _gender = userData['gender'];
          _profileImageUrl = userData['profileImage'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress image for faster upload
      );

      if (pickedFile != null) {
        setState(() {
          _profilePic = File(pickedFile.path);
          _isUploadingImage = true;
        });

        // Upload immediately when image is picked
        await _uploadProfilePicToCloudinary();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
        _isUploadingImage = false;
      });
    }
  }

  // Upload to Cloudinary instead of Firebase Storage
  Future<void> _uploadProfilePicToCloudinary() async {
    if (_profilePic == null) return;

    try {
      print('🚀 Starting Cloudinary upload...');

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _profilePic!.path,
          folder: 'profiles',
          // Add timestamp to make each upload unique
          publicId:
              'profile_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      final imageUrl = response.secureUrl;
      print('✅ Image uploaded to Cloudinary: $imageUrl');

      // Apply transformations for profile picture (300x300, face-centered)
      final transformedUrl = imageUrl.replaceFirst(
        '/upload/',
        '/upload/w_300,h_300,c_fill,g_face/',
      );

      // Save to Firestore immediately (profileImage field is used)
      await _firestore.collection('users').doc(widget.userId).update({
        'profileImage': transformedUrl, // Use ONLY profileImage field
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Profile image URL saved to Firestore');

      setState(() {
        _profilePic = null; // Clear local file
        _isUploadingImage = false;
        _errorMessage = null;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile picture updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Cloudinary upload failed: $e');
      setState(() {
        _errorMessage = 'Failed to upload profile picture: $e';
        _isUploadingImage = false;
        _profilePic = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_usernameController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _phoneNumberController.text.isEmpty ||
        _gender == null) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'username': _usernameController.text.trim(),
        'dob': _dobController.text.trim(),
        'gender': _gender,
        'phoneNumber': _phoneNumberController.text.trim(),
        // Profile image is already updated via _uploadProfilePicToCloudinary
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isEditing = false;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile: $e';
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightBrown = const Color(0xFFD7CCC8);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: lightBrown,
        foregroundColor: Colors.black,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          // Profile Picture Circle
                          CircleAvatar(
                            radius: 50,
                            backgroundImage:
                                _profilePic != null
                                    ? FileImage(_profilePic!)
                                    : (_profileImageUrl != null
                                        ? NetworkImage(_profileImageUrl!)
                                        : null),
                            backgroundColor: Colors.grey.shade300,
                            child:
                                (_profilePic == null &&
                                        _profileImageUrl == null)
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                          ),

                          // Upload progress indicator
                          if (_isUploadingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Upload status text
                    if (_isUploadingImage)
                      const Text(
                        'Uploading image...',
                        style: TextStyle(
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Text fields or display rows for other user info
                    _isEditing
                        ? Column(
                          children: [
                            _buildTextField('Username', _usernameController),
                            _buildTextField(
                              'Date of Birth (YYYY-MM-DD)',
                              _dobController,
                            ),
                            _buildDropdownField(),
                            _buildTextField(
                              'Phone Number',
                              _phoneNumberController,
                            ),
                          ],
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDisplayRow(
                              'Username',
                              _usernameController.text,
                            ),
                            _buildDisplayRow(
                              'Date of Birth',
                              _dobController.text,
                            ),
                            _buildDisplayRow('Gender', _gender ?? 'Not set'),
                            _buildDisplayRow(
                              'Phone Number',
                              _phoneNumberController.text,
                            ),
                          ],
                        ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightBrown,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => EditProfileScreen(
                                      userId: widget.userId,
                                    ),
                              ),
                            );
                            _fetchUserProfile(); // Refresh profile data
                          },
                          child: const Text('Edit Profile'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _logout,
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _gender,
        decoration: const InputDecoration(
          labelText: 'Gender',
          border: OutlineInputBorder(),
        ),
        items:
            ['Male', 'Female', 'Other'].map((gender) {
              return DropdownMenuItem(value: gender, child: Text(gender));
            }).toList(),
        onChanged: (value) => setState(() => _gender = value),
      ),
    );
  }

  Widget _buildDisplayRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
