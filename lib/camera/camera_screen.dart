import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter/foundation.dart';
import '../camera/card_overlay.dart';
import '../utils/image_processor.dart';
import '../network/network_client.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool isRegistration;

  const CameraScreen({
    super.key,
    required this.cameras,
    this.isRegistration = false,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final ImageProcessor _processor = ImageProcessor();
  final DioClient _network = DioClient();
  bool _isProcessing = false;
  String _processingMessage = "Sistem Sedang Memproses...";

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _processor.dispose();
    super.dispose();
  }

  Future<void> _processCapture() async {
    if (_isProcessing) return;

    try {
      setState(() {
        _isProcessing = true;
        _processingMessage = "Mengambil Gambar...";
      });

      await _initializeControllerFuture;
      final XFile image = await _controller.takePicture();
      final File imageFile = File(image.path);

      if (widget.isRegistration) {
        setState(() => _processingMessage = "Memproses Crop ID Card...");

        // 1. Potong gambar penuh sesuai garis overlay markup
        File? fullIdCardFile = await _processor.cropIDCardFromMarkup(imageFile);

        // 2. deteksi QR code
        setState(() => _processingMessage = "Mendeteksi QR...");
        Barcode? qrBarcode = await _processor.detectQR(imageFile);

        // 3. crop image unik
        File? uniqueCropFile;
        if (qrBarcode != null && qrBarcode.rawValue != null) {
          setState(() => _processingMessage = "Memotong Area Unik...");
          uniqueCropFile = await _processor.cropUniqueImageArea(imageFile, qrBarcode.boundingBox);
        }

        if (mounted) {
          Navigator.pop(context, {
            'full_id_file': fullIdCardFile ?? imageFile,
            'qr_value': qrBarcode?.rawValue,
            'unique_crop_file': uniqueCropFile,
          });
        }
        return;
      }

      setState(() => _processingMessage = "Mendeteksi QR...");
      Barcode? qrBarcode = await _processor.detectQR(imageFile);

      if (qrBarcode == null || qrBarcode.rawValue == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR tidak terdeteksi, silakan coba lagi.')),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      setState(() => _processingMessage = "Memotong Gambar...");
      File? croppedFile = await _processor.cropUniqueImageArea(
          imageFile,
          qrBarcode.boundingBox
      );

      if (croppedFile == null) {
        throw Exception("Gagal memotong gambar");
      }

      setState(() => _processingMessage = "Mengunggah Data...");
      final Uint8List croppedBytes = await croppedFile.readAsBytes();
      final String croppedName = croppedFile.path.split(kIsWeb ? '/' : Platform.pathSeparator).last;

      final response = await _network.verifyScan(
        qrBarcode.rawValue!,
        croppedBytes,
        croppedName,
      );

      if (mounted) {
        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          _showResultDialog(
              "Hasil Verifikasi",
              "Verifikasi Selesai",
              details: response.data as Map<String, dynamic>
          );
        } else if (response.statusCode == 404) {
          _showResultDialog(
            "Tidak Ditemukan",
            response.data['msg'] ?? "ID Card tidak terdaftar di sistem kami.",
          );
        } else {
          String resultMsg = response.data is Map
              ? (response.data['message'] ?? response.data['msg'] ?? 'Verifikasi Selesai')
              : 'Berhasil';
          _showResultDialog("Hasil Verifikasi", resultMsg);
        }
      }

    } on DioException catch (e) {
      if (mounted) {
        if (e.response?.statusCode == 404) {
          _showResultDialog(
            "Tidak Ditemukan",
            e.response?.data['msg'] ?? "Data ID Card tidak ditemukan di database.",
          );
        } else {
          _showResultDialog("Error", e.response?.data['msg'] ?? e.message ?? "Terjadi kesalahan koneksi");
        }
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog("Error", e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showResultDialog(String title, String message, {Map<String, dynamic>? details}) {
    showDialog(
      context: context,
      builder: (context) {
        bool isFake = details?['status'] == 'fake';
        Color statusColor = isFake ? Colors.red : Colors.green;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isFake ? Icons.error_outline : Icons.check_circle_outline,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              Text(title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details != null) ...[
                _buildResultRow("Status", details['status'].toString().toUpperCase(), color: statusColor, bold: true),
                const Divider(),
                _buildResultRow("Nama", details['fullname'] ?? "-"),
                _buildResultRow("NIP", details['nip'] ?? "-"),
                _buildResultRow("Match Score", "${((details['match_score'] ?? 0) * 100).toStringAsFixed(1)}%"),
                _buildResultRow("Liveness", "${((details['liveness_score'] ?? 0) * 100).toStringAsFixed(1)}%"),
              ] else ...[
                Text(message),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("TUTUP"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No camera available', style: TextStyle(color: Colors.white))),
        backgroundColor: Colors.black,
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('Camera Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }

            // AspectRatio
            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 1 / _controller.value.aspectRatio,
                    child: CameraPreview(_controller),
                  ),
                ),
                const CardOverlay(),
                
                // Toolbar Atas (Close button)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // Overlay Loading / Processing
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFF2D62ED),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _processingMessage,
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 16, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Tombol Capture Bawah
                if (!_isProcessing)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _processCapture,
                        child: Container(
                          height: 80,
                          width: 80,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 32,
                              color: Color(0xFF2D62ED),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
