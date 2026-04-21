import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Tambahkan untuk kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'network/network_client.dart';
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
  
  Uint8List? _imageBytes;
  String? _fileName;
  String? _imagePreviewPath; // Simpan path untuk preview cross-platform
  bool _isLoading = false;
  bool _isScanningQR = false;

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> _pickAndScanImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      
      setState(() {
        _imageBytes = bytes;
        _fileName = pickedFile.name;
        _imagePreviewPath = pickedFile.path;
        _isScanningQR = true;
      });

      // CATATAN: ML Kit Barcode Scanning hanya bekerja di Mobile (Android/iOS)
      if (!kIsWeb) {
        try {
          final inputImage = InputImage.fromFilePath(pickedFile.path);
          final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

          if (barcodes.isNotEmpty) {
            final String? qrValue = barcodes.first.displayValue;
            if (qrValue != null) {
              setState(() {
                _qrController.text = qrValue;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR Code berhasil dibaca!'), backgroundColor: Colors.green),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak ada QR Code terdeteksi pada foto ini.'), backgroundColor: Colors.orange),
              );
            }
          }
        } catch (e) {
          debugPrint('Error scanning QR: $e');
        } finally {
          if (mounted) setState(() => _isScanningQR = false);
        }
      } else {
        // Jika di Web, matikan loading scanning karena ML Kit tidak support Web
        setState(() => _isScanningQR = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preview berhasil dimuat. (Catatan: QR Scanner ML Kit hanya tersedia di Mobile)')),
          );
        }
      }
    }
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan upload foto kartu ID'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Validasi QR value (bisa diisi manual di Web)
    if (_qrController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan isi Value QR (bisa manual jika di Web)'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('Attempting registration for: ${_nameController.text}');
      debugPrint('NIP: ${_nipController.text}, QR: ${_qrController.text}');
      debugPrint('File Name: $_fileName, File Size: ${_imageBytes?.length} bytes');

      final response = await _dioClient.adminRegisterId(
        fullname: _nameController.text.trim(),
        nip: _nipController.text.trim(),
        jobTitle: _jobController.text.trim(),
        qrCode: _qrController.text.trim(),
        imageBytes: _imageBytes!,
        fileName: _fileName ?? 'id_card.jpg',
      );

      debugPrint('Registration success: ${response.data}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data ID Card Berhasil Didaftarkan'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      debugPrint('Registration Error (Dio):');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response Data: ${e.response?.data}');
      debugPrint('Error Message: ${e.message}');
      
      String errorMsg = e.response?.data?['message'] ?? "Registrasi Gagal";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('General Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan sistem: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Registrasi Data ID Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Preview Image Section (Replacement for Card Preview)
            _buildImagePickerSection(),
            const SizedBox(height: 32),

            // Registration Form
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Informasi Kartu Identitas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D62ED))),
                    const SizedBox(height: 16),
                    _buildField(
                        controller: _nameController, 
                        label: 'Nama Lengkap (Sesuai ID)', 
                        icon: Icons.person_outline,
                        validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                        controller: _nipController, 
                        label: 'NIP / Nomor Induk', 
                        icon: Icons.badge_outlined,
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
                      label: kIsWeb ? 'Value QR (Isi Manual di Web)' : 'Value QR (Otomatis dari Scan)', 
                      icon: Icons.qr_code_2, 
                      readOnly: false,
                      validator: (v) => v!.isEmpty ? 'QR Value tidak boleh kosong' : null
                    ),
                    const SizedBox(height: 32),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleRegistration,
                      icon: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 20),
                      label: Text(_isLoading ? 'Processing...' : 'SUBMIT KE DATABASE', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return GestureDetector(
      onTap: _pickAndScanImage,
      child: Container(
        height: 250,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Tampilan Preview Gambar
            if (_imagePreviewPath != null)
              kIsWeb
                  ? Image.network(_imagePreviewPath!, fit: BoxFit.contain, width: double.infinity)
                  : Image.file(File(_imagePreviewPath!), fit: BoxFit.contain, width: double.infinity),

            // Placeholder jika belum ada gambar
            if (_imagePreviewPath == null)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Upload Foto ID Card Fisik', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  Text('(QR akan dibaca otomatis di Mobile)', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            
            // Overlay Loading saat Scanning QR
            if (_isScanningQR)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
