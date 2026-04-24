import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'camera/camera_screen.dart';
import 'registration_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'ID Scanner Pro',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: const Color(0xFF1E40AF),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifikasi',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? screenWidth * 0.1 : 24, // Padding dinamis untuk tablet vs HP
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Role: Administrator',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Dashboard Overview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 32),

              // Menu Grid Section
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isTablet ? 3 : 2, // Scaling jumlah kolom
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1, // Menjaga proporsi kartu
                children: [
                  _buildModernCard(
                    title: 'Registrasi',
                    subtitle: 'ID Card Baru',
                    icon: Icons.person_add_alt_1_rounded,
                    color: const Color(0xFF10B981), // Emerald green
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationScreen()));
                    },
                  ),
                  _buildModernCard(
                    title: 'Riwayat',
                    subtitle: 'Log Aktivitas',
                    icon: Icons.history_edu_rounded,
                    color: const Color(0xFFF59E0B), // Amber
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                    },
                  ),
                  _buildModernCard(
                    title: 'Laporan',
                    subtitle: 'Statistik Data',
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFF8B5CF6), // Violet
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Security Banner Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gpp_good_rounded, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keamanan Sistem Aktif',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Semua data yang dikumpulkan dan ditransmisikan telah terenkripsi secara end-to-end.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32), // Ekstra padding di bawah agar tidak tertutup BottomAppBar
            ],
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(cameras: widget.cameras)));
        },
        backgroundColor: const Color(0xFF2D62ED),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom Navigation
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                index: 0,
              ),
              const SizedBox(width: 48), // Ruang kosong untuk tombol Scan di tengah
              _buildBottomNavItem(
                icon: Icons.settings_outlined,
                label: 'Pengaturan',
                index: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget helper Bottom Navigation Item
  Widget _buildBottomNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF1E40AF) : Colors.grey.shade400;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper
  Widget _buildModernCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.04),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}