import 'dart:io';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

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

  void dispose() {
    _barcodeScanner.close();
  }
}