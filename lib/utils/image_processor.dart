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

  //  Cropping Image sesuai garis CardOverlay
  Future<File?> cropIDCardFromMarkup(File imageFile) async {
    final tempDir = await getTemporaryDirectory();
    final params = CropParams(
      imagePath: imageFile.path,
      qrBoundingBox: Rect.zero,
      tempDirPath: tempDir.path,
    );

    return await compute(_processPerspectiveCrop, params);
  }

  static Future<File?> _processPerspectiveCrop(CropParams params) async {
    final bytes = await File(params.imagePath).readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    int cropWidth = (originalImage.width * 0.85).toInt();
    int cropHeight = (cropWidth / 1.58).toInt();

    int x = (originalImage.width - cropWidth) ~/ 2;
    int y = (originalImage.height - cropHeight) ~/ 2;

    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x + cropWidth > originalImage.width) cropWidth = originalImage.width - x;
    if (y + cropHeight > originalImage.height) cropHeight = originalImage.height - y;

    img.Image cropped = img.copyCrop(
      originalImage,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );

    final path = p.join(
      params.tempDirPath,
      'cropped_full_id_${DateTime.now().millisecondsSinceEpoch}.jpg',
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

  static Future<File?> _processCrop(CropParams params) async {
    final bytes = await File(params.imagePath).readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    final qr = params.qrBoundingBox;

    double qrW = qr.width;
    double qrH = qr.height;

    int cropW = (qrW * 1.1).toInt();
    int cropH = (qrH * 1.05).toInt();
    int gutter = (qrW * 0.05).toInt();

    int x = (qr.right + gutter).toInt();
    int y = (qr.top).toInt();

    x = x.clamp(0, originalImage.width - 1);
    y = y.clamp(0, originalImage.height - 1);

    int finalW = (x + cropW > originalImage.width) ? (originalImage.width - x) : cropW;
    int finalH = (y + cropH > originalImage.height) ? (originalImage.height - y) : cropH;

    if (finalW <= 5 || finalH <= 5) return null;

    img.Image cropped = img.copyCrop(
      originalImage,
      x: x,
      y: y,
      width: finalW,
      height: finalH,
    );

    final path = p.join(
      params.tempDirPath,
      'cropped_id_unique_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final croppedFile = File(path);
    await croppedFile.writeAsBytes(img.encodeJpg(cropped));

    return croppedFile;
  }
}