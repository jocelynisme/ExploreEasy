import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile_screen.dart';
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
  bool _isUploadingImage = false;
  String? _profileImageUrl;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  // Brand colors matching MyTripsScreen
  final Color _brand = const Color(0xFFD7CCC8);
  final Color _brandDark = const Color(0xFF6D4C41);

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
          _profileImageUrl = userData['profilePicUrl'];
          _isLoading = false;
        });

        // Debug print to check if URL exists
        print('Profile Image URL: $_profileImageUrl');
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
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _profilePic = File(pickedFile.path);
          _isUploadingImage = true;
        });

        await _uploadProfilePicToCloudinary();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _uploadProfilePicToCloudinary() async {
    if (_profilePic == null) return;

    try {
      print('🚀 Starting Cloudinary upload...');

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_profilePic!.path),
      );

      final imageUrl = response.secureUrl;
      print('✅ Image uploaded to Cloudinary: $imageUrl');

      // Save to Firestore with consistent field name
      await _firestore.collection('users').doc(widget.userId).update({
        'profilePicUrl': imageUrl, // Use consistent field name
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Profile image URL saved to Firestore');

      setState(() {
        _profileImageUrl = imageUrl; // Update local state
        _profilePic = null;
        _isUploadingImage = false;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile picture updated!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: _brandDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          content: Text(
            'Upload failed: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isEditing = false;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: _brandDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            shadows: [
              Shadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _brandDark,
        elevation: 0,
        centerTitle: true,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: _brandDark))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Picture Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Color(0xFFE8DDD4), Color(0xFFD7CCC8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundImage:
                                      _profilePic != null
                                          ? FileImage(_profilePic!)
                                          : (_profileImageUrl != null &&
                                                  _profileImageUrl!.isNotEmpty
                                              ? NetworkImage(_profileImageUrl!)
                                              : null),
                                  backgroundColor: Colors.white.withOpacity(
                                    0.8,
                                  ),
                                  child:
                                      (_profilePic == null &&
                                              (_profileImageUrl == null ||
                                                  _profileImageUrl!.isEmpty))
                                          ? Icon(
                                            Icons.person,
                                            size: 60,
                                            color: _brandDark,
                                          )
                                          : null,
                                ),

                                // Camera button
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _brandDark,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
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

                            const SizedBox(height: 16),

                            if (_isUploadingImage)
                              Text(
                                'Uploading image...',
                                style: GoogleFonts.poppins(
                                  color: _brandDark,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Profile Information Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Colors.white, Color(0xFFFAFAFA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Information',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: _brandDark,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildInfoRow(
                              'Username',
                              _usernameController.text,
                              Icons.person_outline,
                            ),
                            _buildInfoRow(
                              'Date of Birth',
                              _dobController.text,
                              Icons.cake_outlined,
                            ),
                            _buildInfoRow(
                              'Gender',
                              _gender ?? 'Not set',
                              Icons.wc_outlined,
                            ),
                            _buildInfoRow(
                              'Phone Number',
                              _phoneNumberController.text,
                              Icons.phone_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
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
                              _fetchUserProfile();
                            },
                            icon: Icon(Icons.edit),
                            label: Text(
                              'Edit Profile',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            onPressed: _logout,
                            icon: Icon(Icons.logout),
                            label: Text(
                              'Logout',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _brandDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: _brandDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
