import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'
    as dp;

// Cloudinary configuration
final cloudinary = CloudinaryPublic(
  'dkcqc2zpd', // Your cloud name
  'travel_app_preset', // Your upload preset
  cache: false,
);

class EditProfileScreen extends StatefulWidget {
  final String userId;

  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _gender;
  File? _profilePic; // Selected image file (not uploaded yet)
  String? _currentImageUrl; // Current image URL from Firestore
  String? _errorMessage;
  bool _isLoading = true;

  final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,}$');
  final RegExp _dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  final RegExp _phoneRegex = RegExp(r'^\d{9,11}$');

  String? _usernameError, _dobError, _phoneError, _genderError;

  bool _validateInputs() {
    bool isValid = true;
    setState(() {
      _usernameError = _dobError = _phoneError = _genderError = null;
      final username = _usernameController.text.trim();
      final dob = _dobController.text.trim();
      final phone = _phoneNumberController.text.trim();

      if (username.isEmpty || !_usernameRegex.hasMatch(username)) {
        _usernameError = 'At least 3 characters, alphanumeric only.';
        isValid = false;
      }

      if (!_dobRegex.hasMatch(dob)) {
        _dobError = 'Use YYYY-MM-DD format.';
        isValid = false;
      } else {
        try {
          final date = DateTime.parse(dob);
          int age = DateTime.now().year - date.year;
          if (date.month > DateTime.now().month ||
              (date.month == DateTime.now().month &&
                  date.day > DateTime.now().day)) {
            age--;
          }
          if (age < 13) {
            _dobError = 'You must be at least 13 years old.';
            isValid = false;
          }
        } catch (_) {
          _dobError = 'Invalid date.';
          isValid = false;
        }
      }

      if (!_phoneRegex.hasMatch(phone)) {
        _phoneError = 'Must be 9–11 digits.';
        isValid = false;
      }

      if (_gender == null) {
        _genderError = 'Select gender.';
        isValid = false;
      }
    });
    return isValid;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    print('🔍 Loading user data for ${widget.userId}');
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
      final data = doc.data();

      if (data != null) {
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _dobController.text = data['dob'] ?? '';
          _phoneNumberController.text = data['phoneNumber'] ?? '';
          _gender = data['gender'];
          // Load current image URL
          _currentImageUrl = data['profileImage'];
        });

        print('✅ Loaded current image URL: $_currentImageUrl');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Just pick image - don't upload yet
  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (picked != null) {
        setState(() {
          _profilePic = File(picked.path);
        });

        print('📷 Image selected: ${picked.path}');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📷 Image selected! Click "Save Profile" to upload.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to pick image: $e');
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  // Upload to Cloudinary (only called from _updateProfile)
  Future<String?> _uploadImageToCloudinary() async {
    if (_profilePic == null) return _currentImageUrl;

    try {
      print('🚀 Starting Cloudinary upload...');

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _profilePic!.path,
          resourceType: CloudinaryResourceType.Image,
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

      // Add cache-busting parameter to force image refresh
      final finalUrl =
          '$transformedUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      print('✅ Final image URL: $finalUrl');
      return finalUrl;
    } catch (e) {
      print('❌ Cloudinary upload failed: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Save profile - uploads image if selected, then saves all data
  Future<void> _updateProfile() async {
    if (!_validateInputs()) return;

    try {
      setState(() => _isLoading = true);

      String? finalImageUrl = _currentImageUrl; // Start with current URL

      // Upload new image if user selected one
      if (_profilePic != null) {
        print('🔄 User selected new image, uploading...');
        finalImageUrl = await _uploadImageToCloudinary();
      } else {
        print('ℹ️ No new image selected, keeping current image');
      }

      // Save all profile data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'username': _usernameController.text.trim(),
            'dob': _dobController.text.trim(),
            'gender': _gender,
            'phoneNumber': _phoneNumberController.text.trim(),
            'profileImage': finalImageUrl, // Save final image URL
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      print('✅ Profile data saved to Firestore with image: $finalImageUrl');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to update profile: $e');
      setState(() {
        _errorMessage = 'Failed to update profile: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightBrown = const Color(0xFFD7CCC8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile'),
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
                            key: ValueKey(
                              _profilePic?.path ?? _currentImageUrl,
                            ), // Force rebuild
                            backgroundImage:
                                _profilePic != null
                                    ? FileImage(
                                      _profilePic!,
                                    ) // Show selected image preview
                                    : (_currentImageUrl != null
                                            ? NetworkImage(_currentImageUrl!)
                                            : null)
                                        as ImageProvider?,
                            backgroundColor: Colors.grey.shade300,
                            child:
                                (_profilePic == null &&
                                        _currentImageUrl == null)
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                          ),

                          // Camera button
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: lightBrown,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.black,
                                  size: 20,
                                ),
                                onPressed:
                                    _pickImage, // Just pick, don't upload
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Show status when new image is selected
                    if (_profilePic != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'New image selected - Click "Save Profile" to upload',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    _buildTextField(
                      'Username',
                      _usernameController,
                      _usernameError,
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth field with date picker
                    TextField(
                      controller: _dobController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth (YYYY-MM-DD)',
                        hintText: 'e.g. 2002-08-30',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                        errorText: _dobError,
                      ),
                      onTap: () {
                        dp.DatePicker.showDatePicker(
                          context,
                          showTitleActions: true,
                          minTime: DateTime(1900),
                          maxTime: DateTime.now(),
                          currentTime: DateTime(2005, 1, 1),
                          locale: dp.LocaleType.en,
                          theme: dp.DatePickerTheme(
                            headerColor: const Color(0xFFD7CCC8),
                            backgroundColor: Colors.white,
                            itemStyle: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            doneStyle: const TextStyle(color: Colors.blue),
                          ),
                          onConfirm: (date) {
                            _dobController.text = date
                                .toIso8601String()
                                .substring(0, 10);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField(),

                    _buildTextField(
                      'Phone Number',
                      _phoneNumberController,
                      _phoneError,
                      hintText: 'e.g. 0123456789',
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _isLoading ? null : _updateProfile,
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Save Profile'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),

                    // Debug info (remove in production)
                    if (_currentImageUrl != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const Text(
                        'Debug Info (Current Image URL):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _currentImageUrl!,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? errorText, {
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          errorText: errorText,
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _gender,
        decoration: InputDecoration(
          labelText: 'Gender',
          border: const OutlineInputBorder(),
          errorText: _genderError,
        ),
        items:
            [
              'Male',
              'Female',
              'Other',
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (val) => setState(() => _gender = val),
      ),
    );
  }
}
