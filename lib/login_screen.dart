import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'network/network_client.dart';
import 'package:dio/dio.dart';

class LoginScreen extends StatefulWidget {
  final dynamic cameras;
  const LoginScreen({super.key, required this.cameras});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final DioClient _dioClient = DioClient();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        print("LOGIN_DEBUG: Starting login process...");
        final response = await _dioClient.login(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        print("LOGIN_DEBUG: Response status: ${response.statusCode}");
        if (response.statusCode == 200) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen(cameras: widget.cameras)),
            );
          }
        } else {
          String errorMsg = response.data?['message'] ?? "Login Gagal (${response.statusCode})";
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
            );
          }
        }
      } on DioException catch (e) {
        print("LOGIN_DEBUG: DioException occurred: ${e.type} - ${e.message}");
        String errorMsg = "Terjadi kesalahan koneksi ke server";
        
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMsg = "Koneksi timeout (Server lama merespon)";
        } else if (e.type == DioExceptionType.connectionError) {
          errorMsg = "Gagal terhubung ke Server (Cek apakah Backend sudah jalan di 127.0.0.1:5000)";
        } else if (e.response?.statusCode == 401) {
          errorMsg = "Username atau Password salah";
        } else if (e.response?.statusCode != null) {
          errorMsg = "Server error: ${e.response?.statusCode}";
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        print("LOGIN_DEBUG: General exception: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo & Title
                const Icon(Icons.security_rounded, size: 80, color: Color(0xFF2D62ED)),
                const SizedBox(height: 24),
                const Text(
                  'ID Scanner Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                ),
                const Text(
                  'Corporate Access Management',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey, letterSpacing: 1.2),
                ),
                const SizedBox(height: 60),

                // Email Field
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Masukkan username';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) return 'Minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('SIGN IN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {},
                  child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF2D62ED))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
