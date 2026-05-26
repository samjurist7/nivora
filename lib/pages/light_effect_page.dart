import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';

/// Light effect control page
class LightEffectPage extends StatefulWidget {
  final String mode; // 'classic' or 'herbal'

  const LightEffectPage({super.key, required this.mode});

  @override
  State<LightEffectPage> createState() => _LightEffectPageState();
}

class _LightEffectPageState extends State<LightEffectPage> {
  int _selectedLightMode = 0; // 0-5 corresponds to 1-6.png

  // Light effect name list
  final List<String> _lightEffectNames = [
    'Normal',
    'Normal',
    'Normal',
    'Normal',
    'Normal',
    'Normal',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLightMode();
  }

  /// Load current light mode
  void _loadCurrentLightMode() async {
    await StorageService.init();
    setState(() {
      _selectedLightMode = StorageService.getLightMode();
    });
  }

  /// Switch light effect
  Future<void> _switchLightEffect(int lightMode) async {
    if (_selectedLightMode == lightMode) return;

    setState(() {
      _selectedLightMode = lightMode;
    });

    // Save to local storage
    await StorageService.setLightMode(lightMode);

    // Send command to device
    final bt = Provider.of<BluetoothService>(context, listen: false);
    if (bt.connectedDevice != null) {
      try {
        // Get current temperature and time settings
        final setTemp = StorageService.getSetTemp();
        final setTime = StorageService.getSetTime();
        print(
            '🎛 Switch light effect -> lightMode=$lightMode, setTemp=$setTemp, setTime=$setTime | Sending device_parameter (0xA9) refer to @蓝牙命令.xlsx');

        // Send device parameter setting command (including light mode)
        await bt.sendDeviceParameter(lightMode, setTemp, setTime);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Light effect switched'),
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        print('❌ Failed to switch light effect: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switch failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device not connected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_main.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Navigation bar: back button + title
              _buildAppBar(),

              // Top: currently selected light effect large image
              _buildSelectedEffect(),

              const SizedBox(height: 30),

              // Light effect grid list
              Expanded(
                child: _buildEffectGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build navigation bar
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          // Title (show Classic or Herbal based on mode)
          Text(
            widget.mode.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build top selected light effect large image
  Widget _buildSelectedEffect() {
    final imageIndex = _selectedLightMode + 1; // 0-5 corresponds to 1-6.png

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/$imageIndex.png',
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 220,
              alignment: Alignment.center,
              child: Text(
                'Effect $_selectedLightMode',
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build light effect grid list
  Widget _buildEffectGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 per row
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1, // Keep square
        ),
        itemCount: 6, // 6 light effects
        itemBuilder: (context, index) {
          return _buildEffectCell(index);
        },
      ),
    );
  }

  /// Build single light effect cell
  Widget _buildEffectCell(int lightMode) {
    final isSelected = _selectedLightMode == lightMode;
    final imageIndex = lightMode + 1; // 0-5 corresponds to 1-6.png

    final backgroundAsset = 'assets/images/bg_$imageIndex.png';

    return GestureDetector(
      onTap: () => _switchLightEffect(lightMode),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tileSize = constraints.maxWidth;
          final double backgroundSize = tileSize * 1.15;
          final double imageSize = tileSize * 0.85;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Background glow when selected
              if (isSelected)
                SizedBox(
                  width: backgroundSize,
                  height: backgroundSize,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Image.asset(
                      backgroundAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              // Main image scaling display
              SizedBox(
                width: imageSize,
                height: imageSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(imageSize * 0.18),
                  child: Image.asset(
                    'assets/images/$imageIndex.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.lightbulb,
                          color: Colors.white.withOpacity(0.5),
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Bottom title (inside image)
              Positioned(
                bottom: tileSize * 0.06,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _lightEffectNames[lightMode],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

