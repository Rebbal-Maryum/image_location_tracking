import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_location_tracking/config/colors.dart';
import 'package:image_location_tracking/config/strings.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../../config/styles.dart';

class ImageLocation extends StatefulWidget {
  @override
  _ImageLocationState createState() => _ImageLocationState();
}

class _ImageLocationState extends State<ImageLocation> {
  File? _image;
  bool _uploading = false;
  String uniqueFileName = DateTime.now().millisecondsSinceEpoch.toString();
  LatLng? _selectedLocation;
  ImagePicker picker = ImagePicker();
  Location location = Location();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return; // Location service is still not enabled, return
        }
      }

      // Check if permission to access location is granted
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          return; // Permission not granted, return
        }
      }

      // Get the current location
      LocationData currentLocation = await location.getLocation();

      // Update _selectedLocation with the current latitude and longitude
      setState(() {
        _selectedLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
      });
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _selectImage(ImageSource source) async {
    XFile? pickedFile = await picker.pickImage(source: source);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future<void> _uploadImage() async {
    setState(() {
      _uploading = true;
    });

    try {
      if (_image != null) {
        String? fileExtension = _image!.path.split('.').last;
        String fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

        firebase_storage.Reference ref =
        firebase_storage.FirebaseStorage.instance.ref(fileName);

        firebase_storage.UploadTask uploadTask = ref.putFile(
          _image!,
          firebase_storage.SettableMetadata(
            contentType: 'image/$fileExtension',
            customMetadata: <String, String>{
              'uploaded_by': 'user_id',
              'timestamp': DateTime.now().toString(),
              'latitude': _selectedLocation!.latitude.toString(),
              'longitude': _selectedLocation!.longitude.toString(),
            },
          ),
        );

        await uploadTask.whenComplete(() => null);

        // Get the download URL
        String downloadURL = await ref.getDownloadURL();

        setState(() {
          _uploading = false;
          _image = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.imageUploaded),
          ),
        );

        // Show image on map
        _getCurrentLocation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.selectImage),
          ),
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.errorUploading),
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.title,
          style: h1,
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryColor,
      ),
      backgroundColor:AppColors.primaryColor ,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploading ? null : () async {
                // Select Image from Gallery
                await _selectImage(ImageSource.gallery);
                // Upload Image to Firebase
                if (_image != null) {
                  await _uploadImage();
                }
              },
              child: _uploading
                  ? CircularProgressIndicator()
                  : Text(AppStrings.select,style:h2,),
              style: ElevatedButton.styleFrom(
                backgroundColor:AppColors.buttonColor,
              ),
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploading ? null : () async {
                // Capture Image from Camera
                await _selectImage(ImageSource.camera);
                // Upload Image to Firebase
                if (_image != null) {
                  await _uploadImage();
                }
              },
              child: _uploading
                  ? CircularProgressIndicator()
                  : Text(AppStrings.capture,style:h2,),
              style: ElevatedButton.styleFrom(
                backgroundColor:AppColors.buttonColor,
            ),
            ),

            SizedBox(height: 20),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? LatLng(0, 0),
                  zoom: 10,
                ),
                markers: _selectedLocation != null
                    ? {
                  Marker(
                    markerId: MarkerId('selected_location'),
                    position: _selectedLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed),
                  ),
                }
                    : {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}