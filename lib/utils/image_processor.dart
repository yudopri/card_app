import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CropParams {
  final String imagePath;
  final Rect qrBoundingBox;
  final String tempDirPath;

  CropParams({
    required this.imagePath,
    required this.qrBoundingBox,
    required this.tempDirPath,
  });
}

class ImageProcessor {
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );

  // 1. Deteksi Barcode/QR Code
  Future<Barcode?> detectQR(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final barcodes = await _barcodeScanner.processImage(inputImage);
    if (barcodes.isNotEmpty) {
      return barcodes.first;
    }
    return null;
  }

  static Future<File?> _processCrop(CropParams params) async {
    final bytes = await File(params.imagePath).readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    // Define crop area: 400x400 square to the right of the QR code
    // Assuming the ID card is held horizontally.
    // We can adjust the offset based on common ID card layouts.
    int cropWidth = 400;
    int cropHeight = 400;
    int offsetX = 50; // space between QR and the unique image area

    int x = (params.qrBoundingBox.right + offsetX).toInt();
    int y = (params.qrBoundingBox.top).toInt();

    // Ensure we are within image bounds
    x = x.clamp(0, originalImage.width - cropWidth);
    y = y.clamp(0, originalImage.height - cropHeight);

    img.Image cropped = img.copyCrop(
      originalImage,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );

    final path = p.join(
      params.tempDirPath,
      'cropped_id_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final croppedFile = File(path);
    await croppedFile.writeAsBytes(img.encodeJpg(cropped));
    
    return croppedFile;
  }

  // 2. Potong Gambar Berdasarkan Bounding Box Barcode
  Future<File?> cropUniqueImageArea(File imageFile, Rect qrBoundingBox) async {
    final tempDir = await getTemporaryDirectory();
    final params = CropParams(
      imagePath: imageFile.path,
      qrBoundingBox: qrBoundingBox,
      tempDirPath: tempDir.path,
    );

    return await compute(_processCrop, params);
  }

  void dispose() {
    _barcodeScanner.close();
  }

  // ...existing code...
}
