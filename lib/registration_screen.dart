import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:camera/camera.dart'; // PASTI KAN INI DI-IMPORT
import 'network/network_client.dart';
import 'camera/camera_screen.dart';
import 'utils/image_processor.dart';
import 'package:dio/dio.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nipController = TextEditingController();
  final _jobController = TextEditingController();
  final _qrController = TextEditingController();
  final DioClient _dioClient = DioClient();
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final ImageProcessor _imageProcessor = ImageProcessor();

  Uint8List? _imageBytes;
  Uint8List? _uniqueCropBytes;
  String? _fileName;
  String? _uniqueCropFileName;
  String? _imagePreviewPath;
  bool _isLoading = false;
  bool _isScanningQR = false;
  String? _processingMessage;

  @override
  void dispose() {
    _barcodeScanner.close();
    _imageProcessor.dispose();
    _nameController.dispose();
    _nipController.dispose();
    _jobController.dispose();
    _qrController.dispose();
    super.dispose();
  }
// CameraScreen Custom
  Future<void> _processCameraScreenResult(Map<String, dynamic> result) async {
    final File idCardFile = result['full_id_file'];
    final String? qrValue = result['qr_value'];
    final File? uniqueCropFile = result['unique_crop_file'];

    final bytes = await idCardFile.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      _fileName = idCardFile.path.split(Platform.pathSeparator).last;
      _imagePreviewPath = idCardFile.path; // Preview sekarang akan menampilkan gambar yang sudah terpotong rapi!

      if (qrValue != null) {
        _qrController.text = qrValue;
      }
    });

    if (uniqueCropFile != null) {
      _uniqueCropBytes = await uniqueCropFile.readAsBytes();
      _uniqueCropFileName = uniqueCropFile.path.split(Platform.pathSeparator).last;
    }

    if (qrValue != null) {
      _showSnackBar('Gambar KTP berhasil dipotong & QR Code terdeteksi otomatis!', Colors.green);
    } else {
      _showSnackBar('Gambar KTP berhasil dipotong, tapi QR tidak ditemukan. Isi data manual.', const Color(0xFFF59E0B));
    }
  }
  Future<void> _pickAndScanImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 85);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final File imageFile = File(pickedFile.path);

      setState(() {
        _imageBytes = bytes;
        _fileName = pickedFile.name;
        _imagePreviewPath = pickedFile.path;
        _isScanningQR = true;
      });

      if (!kIsWeb) {
        try {
          // 1. Deteksi QR
          final inputImage = InputImage.fromFilePath(pickedFile.path);
          final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

          if (barcodes.isNotEmpty) {
            final Barcode firstBarcode = barcodes.first;
            final String? qrValue = firstBarcode.displayValue;

            if (qrValue != null) {
              setState(() {
                _qrController.text = qrValue;
              });

              // 2. Cropping Otomatis
              setState(() => _processingMessage = "Memproses Cropping...");
              final File? croppedFile = await _imageProcessor.cropUniqueImageArea(
                  imageFile,
                  firstBarcode.boundingBox
              );

              if (croppedFile != null) {
                _uniqueCropBytes = await croppedFile.readAsBytes();
                _uniqueCropFileName = "crop_${pickedFile.name}";
                debugPrint("Auto-cropping success. Size: ${_uniqueCropBytes?.length} bytes");
              }

              _showSnackBar('QR Code & Area Foto terdeteksi otomatis!', Colors.green);
            }
          } else {
            _showSnackBar('QR Code tidak ditemukan. Isilah data secara manual.', const Color(0xFFF59E0B));
          }
        } catch (e) {
          debugPrint('Error scanning/cropping: $e');
        } finally {
          if (mounted) setState(() => _isScanningQR = false);
        }
      } else {
        setState(() => _isScanningQR = false);
        _showSnackBar('Preview dimuat. (Catatan: Scanner otomatis hanya untuk Mobile)', const Color(0xFF1E40AF));
      }
    }
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      _showSnackBar('Silakan upload foto kartu ID terlebih dahulu', const Color(0xFFF59E0B));
      return;
    }

    if (!kIsWeb && _uniqueCropBytes == null) {
      _showSnackBar('Gagal memproses area foto unik. Coba foto dengan QR yang lebih jelas.', const Color(0xFFEF4444));
      return;
    }

    final Uint8List finalUniqueBytes = _uniqueCropBytes ?? _imageBytes!;
    final String finalUniqueFileName = _uniqueCropFileName ?? "web_crop_$_fileName";

    setState(() => _isLoading = true);
    try {
      final response = await _dioClient.adminRegisterId(
        fullname: _nameController.text.trim(),
        nip: _nipController.text.trim(),
        jobTitle: _jobController.text.trim(),
        qrCode: _qrController.text.trim(),
        imageBytes: _imageBytes!,
        fileName: _fileName ?? 'id_card.jpg',
        uniqueCropBytes: finalUniqueBytes,
        uniqueCropFileName: finalUniqueFileName,
      );

      _showSnackBar('Data ID Card Berhasil Didaftarkan', Colors.green);
      if (mounted) Navigator.pop(context);

    } on DioException catch (e) {
      String errorMsg = e.response?.data?['message'] ?? "Registrasi Gagal, periksa koneksi jaringan.";
      _showSnackBar(errorMsg, const Color(0xFFEF4444));
    } catch (e) {
      _showSnackBar('Terjadi kesalahan sistem: $e', const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dimensi layar
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? screenWidth * 0.15 : 24.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Background enterprise
      appBar: AppBar(
        title: const Text(
            'Registrasi ID Card',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.5)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: const Color(0xFF1E40AF),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
        child: Column(
          children: [
            // Upload Area
            _buildImagePickerSection(),
            const SizedBox(height: 32),

            // Form Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 15,
                      offset: const Offset(0, 8)
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E40AF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.badge_rounded, color: Color(0xFF1E40AF), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                            'Informasi Karyawan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Color(0xFFF3F4F6), thickness: 1.5),
                    ),

                    _buildField(
                        controller: _nameController,
                        label: 'Nama Lengkap (Sesuai ID)',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                        controller: _nipController,
                        label: 'NIP / Nomor Induk',
                        icon: Icons.pin_outlined,
                        validator: (v) => v!.isEmpty ? 'NIP tidak boleh kosong' : null
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                        controller: _jobController,
                        label: 'Jabatan / Divisi',
                        icon: Icons.work_outline_rounded,
                        validator: (v) => v!.isEmpty ? 'Jabatan tidak boleh kosong' : null
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _qrController,
                      label: kIsWeb ? 'Value QR (Isi Manual)' : 'Value QR (Terisi Otomatis)',
                      icon: Icons.qr_code_2_rounded,
                      readOnly: !kIsWeb, // Jika mobile, biarkan readonly agar mengandalkan scan
                      validator: (v) => v!.isEmpty ? 'QR Value tidak boleh kosong' : null,
                      fillColor: !kIsWeb ? const Color(0xFFF3F4F6) : null,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleRegistration,
                        icon: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_rounded, size: 22),
                        label: Text(
                            _isLoading ? 'Memproses Data...' : 'Simpan Data Identitas',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF9CA3AF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
    Color? fillColor,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none
        ),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))
        ),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5)
        ),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1)
        ),
        filled: true,
        fillColor: fillColor ?? const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return GestureDetector(
      onTap: () {
        _showImageSourceActionSheet();
      },
      child: Container(
        height: 220,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _imagePreviewPath == null ? const Color(0xFF1E40AF).withOpacity(0.3) : Colors.transparent,
              style: BorderStyle.solid,
              width: 1.5
          ),
          boxShadow: _imagePreviewPath != null ? [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            // Preview Gambar
            if (_imagePreviewPath != null)
              kIsWeb
                  ? Image.network(_imagePreviewPath!, fit: BoxFit.cover)
                  : Image.file(File(_imagePreviewPath!), fit: BoxFit.cover),

            // Gradient Overlay
            if (_imagePreviewPath != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.5)],
                  ),
                ),
              ),

            // Tombol Ganti Gambar
            if (_imagePreviewPath != null)
              Positioned(
                bottom: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Efek blur kaca
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                        // backdropFilter
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                              'Ganti Foto',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Placeholder jika belum ada gambar
            if (_imagePreviewPath == null)
              Container(
                color: const Color(0xFFF3F6FF), // Soft blue tint
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.document_scanner_rounded, size: 40, color: Color(0xFF1E40AF)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Upload Foto ID Card Fisik', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                        kIsWeb ? '(Format JPG/PNG)' : '(QR akan dibaca otomatis)',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)
                    ),
                  ],
                ),
              ),

            // Overlay Loading saat Scanning QR
            if (_isScanningQR)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                        _processingMessage ?? 'Memindai ID...',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper untuk Bottom Sheet modern
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Sumber Gambar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 16),

              // Opsi Galeri
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1E40AF).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF1E40AF)),
                ),
                title: const Text('Galeri Perangkat', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndScanImage(ImageSource.gallery);
                },
              ),

              // Opsi Kamera
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1E40AF).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1E40AF)),
                ),
                title: const Text('Kamera Langsung (Scanner Mode)', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);

                  if (kIsWeb) {
                    // Web tidak support CameraScreen + ML Kit secara native, fallback ke file picker camera
                    _pickAndScanImage(ImageSource.camera);
                  } else {
                    // Buka custom Camera Screen dengan flag isRegistration = true
                    final cameras = await availableCameras();
                    if (mounted) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CameraScreen(
                            cameras: cameras,
                            isRegistration: true, // Beritahu kamera bahwa ini bukan mode Verify!
                          ),
                        ),
                      );

                      // Tangkap Map result dari Navigator.pop
                      if (result != null && result is Map<String, dynamic>) {
                        _processCameraScreenResult(result);
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}