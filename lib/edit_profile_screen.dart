import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Brand colors matching MyTripsScreen
  final Color _brand = const Color(0xFFD7CCC8);
  final Color _brandDark = const Color(0xFF6D4C41);

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
    print('Loading user data for ${widget.userId}');
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
          _currentImageUrl = data['profilePicUrl'];
        });

        print('Loaded current image URL: $_currentImageUrl');
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

        print('Image selected: ${picked.path}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Image selected! Click "Save Profile" to upload.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: _brandDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('Failed to pick image: $e');
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Future<String?> _uploadImageToCloudinary() async {
    if (_profilePic == null) return _currentImageUrl;

    try {
      print('Starting Cloudinary upload...');

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_profilePic!.path),
      );

      final imageUrl = response.secureUrl;
      print('Image uploaded to Cloudinary: $imageUrl');

      return imageUrl;
    } catch (e) {
      print('Cloudinary upload failed: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (!_validateInputs()) return;

    try {
      setState(() => _isLoading = true);

      String? finalImageUrl = _currentImageUrl;

      if (_profilePic != null) {
        print('User selected new image, uploading...');
        finalImageUrl = await _uploadImageToCloudinary();
      } else {
        print('No new image selected, keeping current image');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'username': _usernameController.text.trim(),
            'dob': _dobController.text.trim(),
            'gender': _gender,
            'phoneNumber': _phoneNumberController.text.trim(),
            'profilePicUrl': finalImageUrl,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      print('Profile data saved to Firestore with image: $finalImageUrl');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: _brandDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('Failed to update profile: $e');
      setState(() {
        _errorMessage = 'Failed to update profile: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          'Edit Profile',
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
                                  key: ValueKey(
                                    _profilePic?.path ?? _currentImageUrl,
                                  ),
                                  backgroundImage:
                                      _profilePic != null
                                          ? FileImage(_profilePic!)
                                          : (_currentImageUrl != null &&
                                                  _currentImageUrl!.isNotEmpty
                                              ? NetworkImage(_currentImageUrl!)
                                              : null),
                                  backgroundColor: Colors.white.withOpacity(
                                    0.8,
                                  ),
                                  child:
                                      (_profilePic == null &&
                                              (_currentImageUrl == null ||
                                                  _currentImageUrl!.isEmpty))
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
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Status when new image is selected
                            if (_profilePic != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _brandDark.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: _brandDark,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'New image selected - Click "Save Profile" to upload',
                                        style: GoogleFonts.poppins(
                                          color: _brandDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Edit Form Card
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
                              'Edit Information',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: _brandDark,
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildTextField(
                              'Username',
                              _usernameController,
                              _usernameError,
                              Icons.person_outline,
                            ),

                            // Date of Birth field with date picker
                            _buildDateField(),

                            _buildDropdownField(),

                            _buildTextField(
                              'Phone Number',
                              _phoneNumberController,
                              _phoneError,
                              Icons.phone_outlined,
                              hintText: 'e.g. 0123456789',
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
                            onPressed: _isLoading ? null : _updateProfile,
                            icon:
                                _isLoading
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Icon(Icons.save),
                            label: Text(
                              _isLoading ? 'Saving...' : 'Save Profile',
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
                              backgroundColor: Colors.grey.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                            icon: Icon(Icons.cancel),
                            label: Text(
                              'Cancel',
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? errorText,
    IconData icon, {
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.poppins(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: GoogleFonts.poppins(color: _brandDark.withOpacity(0.7)),
          errorText: errorText,
          errorStyle: GoogleFonts.poppins(color: Colors.red),
          prefixIcon: Icon(icon, color: _brandDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _brand),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _brandDark, width: 2),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: _dobController,
        readOnly: true,
        style: GoogleFonts.poppins(fontSize: 16),
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          hintText: 'YYYY-MM-DD',
          labelStyle: GoogleFonts.poppins(color: _brandDark.withOpacity(0.7)),
          errorText: _dobError,
          errorStyle: GoogleFonts.poppins(color: Colors.red),
          prefixIcon: Icon(Icons.cake_outlined, color: _brandDark),
          suffixIcon: Icon(Icons.calendar_today, color: _brandDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _brand),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _brandDark, width: 2),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
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
              headerColor: _brand,
              backgroundColor: Colors.white,
              itemStyle: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              doneStyle: GoogleFonts.poppins(color: _brandDark),
            ),
            onConfirm: (date) {
              _dobController.text = date.toIso8601String().substring(0, 10);
            },
          );
        },
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        value: _gender,
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          labelText: 'Gender',
          labelStyle: GoogleFonts.poppins(color: _brandDark.withOpacity(0.7)),
          errorText: _genderError,
          errorStyle: GoogleFonts.poppins(color: Colors.red),
          prefixIcon: Icon(Icons.wc_outlined, color: _brandDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _brand),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _brandDark, width: 2),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
        ),
        items:
            ['Male', 'Female', 'Other']
                .map(
                  (g) => DropdownMenuItem(
                    value: g,
                    child: Text(g, style: GoogleFonts.poppins()),
                  ),
                )
                .toList(),
        onChanged: (val) => setState(() => _gender = val),
      ),
    );
  }
}
