import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../theme/mechanical_theme.dart';
import '../widgets/smoke_background.dart';
import 'device_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  final String username;
  const HomePage({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    final bt = Provider.of<BluetoothService>(context);
    return SmokeBackground(
      smokeColor: const Color(0xFF3DD6F5),
      particleCount: 10,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Top navigation bar
              SliverToBoxAdapter(
                child: _buildAppBar(context),
              ),

              // Welcome card
              SliverToBoxAdapter(
                child: _buildWelcomeCard(context, bt),
              ),

              // Scan button
              SliverToBoxAdapter(
                child: _buildScanButton(context, bt),
              ),

              // Device list title
              SliverToBoxAdapter(
                child: _buildSectionTitle(),
              ),

              // Device list
              kIsWeb ? _buildWebDeviceView(bt) : _buildMobileDeviceList(bt),

              // Bottom spacing
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [MechanicalTheme.primaryCyan, MechanicalTheme.coolGreen],
                ).createShader(bounds),
                child: const Text(
                  'NIVORA',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DEVICE CONTROL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: MechanicalTheme.textSecondary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MechanicalTheme.bgLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MechanicalTheme.primaryCyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                CupertinoIcons.gear,
                size: 22,
                color: MechanicalTheme.primaryCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, BluetoothService bt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: MechanicalTheme.createMechanicalCardStyle(
          borderRadius: 16,
          borderColor: MechanicalTheme.primaryCyan.withOpacity(0.3),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MechanicalTheme.primaryCyan, MechanicalTheme.coolTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: MechanicalTheme.createGlowShadow(MechanicalTheme.primaryCyan),
              ),
              child: const Icon(
                CupertinoIcons.person_fill,
                color: Colors.black,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $username',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: MechanicalTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: bt.connectedDevice != null
                              ? MechanicalTheme.coolGreen
                              : MechanicalTheme.textDisabled,
                          shape: BoxShape.circle,
                          boxShadow: bt.connectedDevice != null
                              ? MechanicalTheme.createGlowShadow(MechanicalTheme.coolGreen, intensity: 0.8)
                              : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        bt.connectedDevice != null ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          fontSize: 13,
                          color: bt.connectedDevice != null
                              ? MechanicalTheme.coolGreen
                              : MechanicalTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Decorative gear
            CustomPaint(
              size: const Size(40, 40),
              painter: _MiniGearPainter(
                color: MechanicalTheme.primaryCyan.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(BuildContext context, BluetoothService bt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: GestureDetector(
        onTap: () async {
          if (kIsWeb) {
            final res = await bt.requestDeviceWeb();
            if (res['error'] == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Selected: ${res['name'] ?? res['id'] ?? 'device'}"),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: MechanicalTheme.bgLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DevicePage()));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Error: ${res['error']}"),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: MechanicalTheme.warningRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          } else {
            await bt.startScan();
          }
        },
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: bt.scanning
                ? null
                : const LinearGradient(
                    colors: [MechanicalTheme.primaryCyan, MechanicalTheme.coolGreen],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: bt.scanning ? MechanicalTheme.bgLight : null,
            borderRadius: BorderRadius.circular(16),
            border: bt.scanning
                ? Border.all(color: MechanicalTheme.primaryCyan.withOpacity(0.5), width: 1.5)
                : null,
            boxShadow: bt.scanning ? [] : MechanicalTheme.createGlowShadow(MechanicalTheme.primaryCyan),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (bt.scanning)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: const AlwaysStoppedAnimation<Color>(MechanicalTheme.primaryCyan),
                  ),
                )
              else
                Icon(
                  CupertinoIcons.bluetooth,
                  color: Colors.black,
                  size: 24,
                ),
              const SizedBox(width: 12),
              Text(
                kIsWeb
                    ? 'Request Device'
                    : (bt.scanning ? 'Scanning...' : 'Scan Device'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MechanicalTheme.primaryCyan, MechanicalTheme.coolGreen],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              kIsWeb ? 'Web Bluetooth' : 'Discovered Devices',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MechanicalTheme.textPrimary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDeviceList(BluetoothService bt) {
    if (bt.devices.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: MechanicalTheme.createMechanicalCardStyle(
              borderRadius: 16,
              borderColor: MechanicalTheme.primaryCyan.withOpacity(0.2),
            ),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.bluetooth,
                  size: 56,
                  color: MechanicalTheme.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Devices Found',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: MechanicalTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the scan button to discover devices',
                  style: TextStyle(
                    fontSize: 14,
                    color: MechanicalTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, idx) {
            final d = bt.devices[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: MechanicalTheme.createMechanicalCardStyle(
                  borderRadius: 14,
                  borderColor: MechanicalTheme.primaryCyan.withOpacity(0.25),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: MechanicalTheme.bgDark.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: MechanicalTheme.primaryCyan.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.device_phone_portrait,
                        color: MechanicalTheme.primaryCyan,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MechanicalTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d['id'],
                            style: TextStyle(
                              fontSize: 12,
                              color: MechanicalTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await bt.connect(d['device']);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DevicePage()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [MechanicalTheme.primaryCyan, MechanicalTheme.coolTeal],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: MechanicalTheme.createGlowShadow(MechanicalTheme.primaryCyan, intensity: 0.6),
                        ),
                        child: const Text(
                          'Connect',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: bt.devices.length,
        ),
      ),
    );
  }

  Widget _buildWebDeviceView(BluetoothService bt) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: MechanicalTheme.createMechanicalCardStyle(
            borderRadius: 16,
            borderColor: MechanicalTheme.primaryCyan.withOpacity(0.25),
          ),
          child: Column(
            children: [
              Icon(
                CupertinoIcons.globe,
                size: 56,
                color: MechanicalTheme.primaryCyan.withOpacity(0.8),
              ),
              const SizedBox(height: 16),
              const Text(
                'Web Bluetooth',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: MechanicalTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select device from browser prompt',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: MechanicalTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini gear painter
class _MiniGearPainter extends CustomPainter {
  final Color color;

  _MiniGearPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 15.0;

    for (int i = 0; i < 6; i++) {
      final angle = (2 * math.pi / 6) * i;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      canvas.drawCircle(Offset(x, y), 2.5, paint);
    }

    paint.strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.5, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniGearPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
