import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'camera/camera_screen.dart';
import 'registration_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('ID Scanner Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF2D62ED),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Role: Administrator', style: TextStyle(color: Color(0xFF2D62ED), fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Dashboard Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 24),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildModernCard(
                  title: 'Scanner',
                  subtitle: 'Verifikasi ID',
                  icon: Icons.qr_code_scanner_rounded,
                  color: const Color(0xFF2D62ED),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(cameras: cameras)));
                  },
                ),
                _buildModernCard(
                  title: 'Registrasi',
                  subtitle: 'ID Card Baru',
                  icon: Icons.person_add_alt_1_rounded,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationScreen()));
                  },
                ),
                _buildModernCard(
                  title: 'Riwayat',
                  subtitle: 'Log Aktivitas',
                  icon: Icons.history_edu_rounded,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                  },
                ),
                _buildModernCard(
                  title: 'Laporan',
                  subtitle: 'Statistik Data',
                  icon: Icons.bar_chart_rounded,
                  color: Colors.purple,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2D62ED), Color(0xFF537FF1)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.white, size: 40),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Semua data yang dikumpulkan telah terenkripsi secara end-to-end.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 10,
        selectedItemColor: const Color(0xFF2D62ED),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Setting'),
        ],
      ),
    );
  }

  Widget _buildModernCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
