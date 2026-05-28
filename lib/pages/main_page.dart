import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/user_service.dart';
import '../theme/mechanical_theme.dart';
import '../widgets/smoke_background.dart';
import 'custom_heat.dart';
import 'userHeat_page.dart';
import 'setting_page.dart';
import 'wifi_page.dart';
import 'cloud_devices_page.dart';
import 'set_side_page.dart';
import 'device_info_page.dart';
import 'heating_page.dart';
import 'session_dashboard_page.dart';

/// Main page - Modern tech style (referencing VOLTA UI)
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  int? _lastSyncedPreset;

  void _onSettingsTap(int index) {
    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomHeatPage()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserHeatPage(optionIndex: index)));
    }
  }

  void _onPresetTap(int index) {
    setState(() => _selectedIndex = index);
    _sendHeatPresetUpdate(index);
  }

  void _onStartHeating() async {
    print('Start Heating button clicked, current: $_selectedIndex');

    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.deviceInfo;

    final lightMode = deviceInfo?['lightMode'] as int? ?? 0;
    final setTemp = deviceInfo?['setTemp'] as int? ?? 60;
    final setTime = deviceInfo?['setTime'] as int? ?? 30;
    final boostCount = deviceInfo?['boostCount'] as int? ?? 0;
    final motorLevel = deviceInfo?['motorLevel'] as int? ?? 0;
    final audioSwitch = deviceInfo?['audioSwitch'] as int? ?? 0;
    final tempUnit = deviceInfo?['tempUnit'] as int? ?? 0;

    try {
      await bluetoothService.sendDeviceParameter(
        lightMode,
        setTemp,
        setTime,
        heatPreset: _selectedIndex,
        startHeating: 1,
        boostCount: boostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
      print('Main Page - Start Heating command sent, heatPreset=$_selectedIndex');

      if (!mounted) return;

      // Get mode name
      String modeName;
      if (_selectedIndex == 0) {
        modeName = '0';
      } else {
        final btIndex = _selectedIndex - 1;
        modeName = bluetoothService.optionNames[btIndex] ?? '$_selectedIndex';
      }

      // Navigate to heating page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SessionDashboardPage(
            heatPreset: _selectedIndex,
            modeName: modeName,
          ),
        ),
      );
    } catch (e) {
      print('Main Page - Failed to send Start Heating command: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start heating: $e'),
          backgroundColor: MechanicalTheme.warningRed,
        ),
      );
    }
  }

  /// Pause heating
  void _onPause() {
    print('Main Page - Pause');
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.deviceInfo;

    final lightMode = deviceInfo?['lightMode'] as int? ?? 0;
    final setTemp = deviceInfo?['setTemp'] as int? ?? 60;
    final setTime = deviceInfo?['setTime'] as int? ?? 30;
    final boostCount = deviceInfo?['boostCount'] as int? ?? 0;
    final motorLevel = deviceInfo?['motorLevel'] as int? ?? 0;
    final audioSwitch = deviceInfo?['audioSwitch'] as int? ?? 0;
    final tempUnit = deviceInfo?['tempUnit'] as int? ?? 0;

    try {
      bluetoothService.sendDeviceParameter(
        lightMode,
        setTemp,
        setTime,
        heatPreset: _selectedIndex,
        startHeating: 0,
        boostCount: boostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
      print('Main Page - Pause command sent');
    } catch (e) {
      print('Main Page - Failed to pause: $e');
    }
  }

  /// Restart heating
  void _onRestart() {
    print('Main Page - Restart');
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.deviceInfo;

    final lightMode = deviceInfo?['lightMode'] as int? ?? 0;
    final setTemp = deviceInfo?['setTemp'] as int? ?? 60;
    final setTime = deviceInfo?['setTime'] as int? ?? 30;
    final boostCount = deviceInfo?['boostCount'] as int? ?? 0;
    final motorLevel = deviceInfo?['motorLevel'] as int? ?? 0;
    final audioSwitch = deviceInfo?['audioSwitch'] as int? ?? 0;
    final tempUnit = deviceInfo?['tempUnit'] as int? ?? 0;

    try {
      bluetoothService.sendDeviceParameter(
        lightMode,
        setTemp,
        setTime,
        heatPreset: _selectedIndex,
        startHeating: 1,
        boostCount: boostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
      print('Main Page - Restart command sent');
    } catch (e) {
      print('Main Page - Failed to restart: $e');
    }
  }

  Future<void> _sendHeatPresetUpdate(int heatPreset) async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.deviceInfo;

    final lightMode = deviceInfo?['lightMode'] as int? ?? 0;
    final setTemp = deviceInfo?['setTemp'] as int? ?? 60;
    final setTime = deviceInfo?['setTime'] as int? ?? 30;
    final startHeating = deviceInfo?['startHeating'] as int? ?? 0;
    final boostCount = deviceInfo?['boostCount'] as int? ?? 0;
    final motorLevel = deviceInfo?['motorLevel'] as int? ?? 0;
    final audioSwitch = deviceInfo?['audioSwitch'] as int? ?? 0;
    final tempUnit = deviceInfo?['tempUnit'] as int? ?? 0;

    try {
      await bluetoothService.sendDeviceParameter(
        lightMode,
        setTemp,
        setTime,
        heatPreset: heatPreset,
        startHeating: startHeating,
        boostCount: boostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
      _lastSyncedPreset = heatPreset;
      print('Main Page - heatPreset update sent: $heatPreset');
    } catch (e) {
      print('Main Page - Failed to send heatPreset update: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SmokeBackground(
      smokeColor: const Color(0xFF1A1A2E),
      particleCount: 5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildPresetList(),
                    ],
                  ),
                ),
              ),
              // Bottom Start Heating + Set Side buttons (same row)
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<BluetoothService>(
      builder: (context, bleService, child) {
        String deviceName = 'Connected Device';
        bool isConnected = bleService.connectedDevice != null;
        if (bleService.connectedDevice != null) {
          if (kIsWeb) {
            deviceName = 'Connected Device';
          } else {
            final name = bleService.connectedDevice.platformName;
            deviceName = name.isNotEmpty ? name : 'Connected Device';
          }
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<UserService>(
                  builder: (context, userService, child) {
                    final username = userService.username;
                    final hasName = username != null && username.isNotEmpty;
                    return RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        children: [
                          const TextSpan(text: 'Hello ', style: TextStyle(color: Colors.white)),
                          if (hasName)
                            TextSpan(
                              text: username,
                              style: const TextStyle(color: Color(0xFFFF9800)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Welcome to ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      'ShishaX',
                      style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    if (isConnected) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: MechanicalTheme.coolGreen,
                          shape: BoxShape.circle,
                          boxShadow: MechanicalTheme.createGlowShadow(
                            MechanicalTheme.coolGreen,
                            intensity: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            // Menu button
            GestureDetector(
              onTap: () {
                _showTopMenu(context, bleService);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 28,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTopMenu(BuildContext context, BluetoothService bleService) {
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Mask layer (tap outside to close menu)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              overlayEntry?.remove();
            },
            child: Container(
              color: Colors.transparent,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),
          // Menu content (placed above mask, can be clicked normally)
          Positioned(
            top: 60,
            right: 10,
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MechanicalTheme.primaryCyan.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // WiFi button
                    _buildMenuItem(
                      icon: Icons.wifi,
                      label: 'WiFi',
                      iconColor: MechanicalTheme.primaryCyan,
                      onTap: () {
                        overlayEntry?.remove();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const WifiPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Cloud Control button
                    _buildMenuItem(
                      icon: Icons.cloud,
                      label: 'Cloud Control',
                      iconColor: MechanicalTheme.primaryCyan,
                      onTap: () {
                        overlayEntry?.remove();
                        final userService = Provider.of<UserService>(context, listen: false);
                        if (!userService.isLoggedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please login first for cloud control'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CloudDevicesPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Info button
                    _buildMenuItem(
                      icon: Icons.info_outline,
                      label: 'Device Info',
                      iconColor: MechanicalTheme.warningYellow,
                      onTap: () {
                        overlayEntry?.remove();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DeviceInfoPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Settings button
                    _buildMenuItem(
                      icon: Icons.settings,
                      label: 'Settings',
                      iconColor: MechanicalTheme.primaryCyan,
                      onTap: () {
                        overlayEntry?.remove();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetList() {
    return Consumer<BluetoothService>(
      builder: (context, bleService, _) {
        // Sync device heatPreset
        final deviceInfo = bleService.deviceInfo;
        if (deviceInfo != null) {
          final devicePreset = deviceInfo['heatPreset'] as int?;
          if (devicePreset != null &&
              devicePreset >= 0 &&
              devicePreset <= 5 &&
              devicePreset != _lastSyncedPreset &&
              devicePreset != _selectedIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedIndex = devicePreset;
                  _lastSyncedPreset = devicePreset;
                });
              }
            });
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Your Setting:',
              style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i <= 5; i++) _buildPresetRow(i, bleService),
          ],
        );
      },
    );
  }

  Widget _buildPresetRow(int index, BluetoothService bleService) {
    final isSelected = _selectedIndex == index;

    String name;
    String subtitle;
    if (index == 0) {
      name = 'Custom';
      subtitle = 'Default Setting';
    } else {
      final btIndex = index - 1;
      name = bleService.optionNames[btIndex] ?? 'Preset $index';
      subtitle = bleService.getOptionDescription(btIndex);
    }

    return GestureDetector(
      onTap: () => _onPresetTap(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    const Color(0xFFFF512F).withOpacity(0.25),
                    const Color(0xFFFF6B35).withOpacity(0.1),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF512F).withOpacity(0.7)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Left color bar
            Container(
              width: 4,
              height: subtitle.isNotEmpty ? 36 : 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF512F)
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            // Settings icon
            GestureDetector(
              onTap: () => _onSettingsTap(index),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.menu,
                  color: Colors.white.withOpacity(0.5),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom buttons (Start Heating + Set Side on same row)
  Widget _buildBottomButtons() {
    return Consumer<BluetoothService>(
      builder: (context, bleService, _) {
        final deviceInfo = bleService.deviceInfo;
        final startHeating = deviceInfo?['startHeating'] as int? ?? 0;
        final bPauseState = deviceInfo?['bPauseState'] as int? ?? 0;

        // Determine button text and colors
        String buttonText;
        List<Color> buttonColors;
        VoidCallback onTap;

        if (startHeating == 1 && bPauseState == 1) {
          // Paused state - show RESTART
          buttonText = 'RESTART';
          buttonColors = [MechanicalTheme.warningYellow, MechanicalTheme.warningRed];
          onTap = _onRestart;
        } else if (startHeating == 1) {
          // Heating state - show PAUSE
          buttonText = 'PAUSE';
          buttonColors = [MechanicalTheme.warningRed, const Color(0xFFFF8E53)];
          onTap = _onPause;
        } else {
          // Not heating - show START HEATING
          buttonText = 'START HEATING';
          buttonColors = [MechanicalTheme.heatOrange, MechanicalTheme.heatRed];
          onTap = _onStartHeating;
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: buttonColors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(27.5),
                      boxShadow: MechanicalTheme.createGlowShadow(
                        buttonColors.first,
                        intensity: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          startHeating == 1
                              ? (bPauseState == 1 ? Icons.replay : Icons.pause)
                              : Icons.local_fire_department,
                          color: Colors.black,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          buttonText,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

