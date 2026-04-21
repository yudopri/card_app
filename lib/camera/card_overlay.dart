import 'package:flutter/material.dart';

class CardOverlay extends StatelessWidget {
  const CardOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Menghitung dimensi overlay (biasanya aspek rasio KTP adalah 1.58:1)
      final width = constraints.maxWidth * 0.85;
      final height = width / 1.58;

      return Stack(
        children: [
          // Background gelap transparan di luar area fokus
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Garis border dan instruksi
          Align(
            alignment: Alignment.center,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Siku-siku di pojok (Corner markers)
                  _buildCorner(0, 0, 25, true, true),
                  _buildCorner(0, 0, 25, false, true),
                  _buildCorner(0, 0, 25, true, false),
                  _buildCorner(0, 0, 25, false, false),
                ],
              ),
            ),
          ),
          Positioned(
            top: constraints.maxHeight * 0.2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'Siapkan Kartu Identitas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: constraints.maxHeight * 0.25,
            left: 40,
            right: 40,
            child: const Text(
              'Pastikan QR terlihat jelas dan cahaya cukup',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCorner(double offset, double size, double length, bool isLeft, bool isTop) {
    const color = Color(0xFF2D62ED);
    const thickness = 4.0;
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: Container(
        width: length,
        height: length,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            bottom: isTop ? BorderSide.none : const BorderSide(color: color, width: thickness),
            left: isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            right: isLeft ? BorderSide.none : const BorderSide(color: color, width: thickness),
          ),
        ),
      ),
    );
  }
}
