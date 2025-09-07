import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final cloudinary = CloudinaryPublic(
  'dkcqc2zpd',
  'travel_app_preset',
  cache: false,
);

Future<void> pickAndUploadImage(String userId) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    try {
      // Upload to Cloudinary
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          pickedFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      final imageUrl = response.secureUrl;

      // Store image URL in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profileImage': imageUrl,
      });

      print('Image uploaded and URL saved: $imageUrl');
    } catch (e) {
      print('Upload failed: $e');
    }
  } else {
    print('No image selected.');
  }
}
