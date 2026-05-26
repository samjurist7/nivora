import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/bluetooth_service.dart';
import '../theme/mechanical_theme.dart';

/// Heating page - Display real-time temperature curve
class HeatingPage extends StatefulWidget {
  final int heatPreset; // Current mode index (0-5)
  final String modeName; // Mode name

  const HeatingPage({
    super.key,
    required this.heatPreset,
    required this.modeName,
  });

  @override
  State<HeatingPage> createState() => _HeatingPageState();
}

class _HeatingPageState extends State<HeatingPage> {
  // 温度数据历史
  final List<_TempDataPoint> _realTempHistory = [];
  final List<_TempDataPoint> _topTempHistory = [];
  
  Timer? _dataTimer;
  DateTime? _startTime;

  // Chart display range (seconds)
  double _chartTimeRange = 300; // Default display 5 minutes

  // Timer for refreshing countdown display
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    
    // 每 500ms 更新一次数据
    _dataTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateTempData();
    });
    
    // 每秒刷新一次 countdown 显示
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _dataTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  void _updateTempData() {
    if (!mounted) return;
    
    final bleService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bleService.deviceInfo;
    
    if (deviceInfo == null) return;
    
    final realTemp = deviceInfo['realTemp'] as int? ?? 0;
    final topTemp = deviceInfo['topTemp'] as int? ?? 0;
    final elapsed = DateTime.now().difference(_startTime!);
    
    setState(() {
      _realTempHistory.add(_TempDataPoint(elapsed, realTemp));
      _topTempHistory.add(_TempDataPoint(elapsed, topTemp));
    });
  }
  
  void _onPause() {
    print('Heating Page - Pause');
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
        heatPreset: widget.heatPreset,
        startHeating: 0,
        boostCount: boostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
    } catch (e) {
      print('Heating Page - Failed to pause: $e');
    }
  }
  
  void _onBoost() {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.deviceInfo;
    final currentBoostCount = deviceInfo?['boostCount'] as int? ?? 0;
    final newBoostCount = currentBoostCount + 1;
    print('Heating Page - Boost: $currentBoostCount -> $newBoostCount');
    
    final lightMode = deviceInfo?['lightMode'] as int? ?? 0;
    final setTemp = deviceInfo?['setTemp'] as int? ?? 60;
    final setTime = deviceInfo?['setTime'] as int? ?? 30;
    final motorLevel = deviceInfo?['motorLevel'] as int? ?? 0;
    final audioSwitch = deviceInfo?['audioSwitch'] as int? ?? 0;
    final tempUnit = deviceInfo?['tempUnit'] as int? ?? 0;
    
    try {
      bluetoothService.sendDeviceParameter(
        lightMode,
        setTemp,
        setTime,
        heatPreset: widget.heatPreset,
        startHeating: 1,
        boostCount: newBoostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
    } catch (e) {
      print('Heating Page - Failed to boost: $e');
    }
  }
  
  void _onRestart() {
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
        heatPreset: widget.heatPreset,
        startHeating: 1,
        boostCount: boostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
      // RESTART does not clear data, only updates start time
      setState(() {
        _startTime = DateTime.now();
      });
    } catch (e) {
      print('Heating Page - Failed to restart: $e');
    }
  }
  
  String _formatCountdown(int seconds) {
    if (seconds <= 0) return '0min 0s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}min ${secs}s';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation bar
            _buildAppBar(),

            const SizedBox(height: 20),

            // Mode name and countdown display
            _buildModeNameAndCountdown(),

            const SizedBox(height: 20),

            // Time range control
            _buildTimeRangeControl(),

            const SizedBox(height: 10),

            // Real-time temperature chart
            Expanded(
              child: _buildTempChart(),
            ),

            const SizedBox(height: 20),

            // Current temperature display
            _buildCurrentTemp(),

            const SizedBox(height: 20),

            // Bottom control buttons
            _buildBottomButtons(),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
                Icons.arrow_back,
                color: MechanicalTheme.primaryCyan,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Heating',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModeNameAndCountdown() {
    return Consumer<BluetoothService>(
      builder: (context, bleService, _) {
        final deviceInfo = bleService.deviceInfo;
        final countdownTime = deviceInfo?['countdown_time'] as int? ?? 0;
        final startHeating = deviceInfo?['startHeating'] as int? ?? 0;
        final bPauseState = deviceInfo?['bPauseState'] as int? ?? 0;
        
        String statusText;
        Color statusColor;
        
        if (startHeating == 0) {
          statusText = 'Not Heating';
          statusColor = Colors.grey;
        } else if (bPauseState == 1) {
          statusText = 'Paused';
          statusColor = MechanicalTheme.warningYellow;
        } else {
          statusText = 'Heating';
          statusColor = MechanicalTheme.primaryCyan;
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: MechanicalTheme.bgLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: MechanicalTheme.createGlowShadow(
                        statusColor,
                        intensity: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mode: ${widget.modeName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Countdown: ${_formatCountdown(countdownTime)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildTimeRangeControl() {
    return Column(
      children: [
        const Text(
          'Range',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(width: 8),
              ...[300, 600, 1800, 3600, 7200].map((seconds) {
                final isSelected = _chartTimeRange == seconds;
                return GestureDetector(
                  onTap: () => setState(() => _chartTimeRange = seconds.toDouble()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? MechanicalTheme.primaryCyan.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected 
                            ? MechanicalTheme.primaryCyan
                            : Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _formatTimeRange(seconds),
                      style: TextStyle(
                        color: isSelected 
                            ? MechanicalTheme.primaryCyan
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }
  
  String _formatTimeRange(int seconds) {
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      return '${minutes}min';
    }
    return '${seconds}s';
  }
  
  Widget _buildTempChart() {
    return Consumer<BluetoothService>(
      builder: (context, bleService, _) {
        // 获取当前温度用于显示
        final deviceInfo = bleService.deviceInfo;
        final currentRealTemp = deviceInfo?['realTemp'] as int? ?? 0;
        final currentTopTemp = deviceInfo?['topTemp'] as int? ?? 0;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MechanicalTheme.primaryCyan.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Chart
              CustomPaint(
                size: Size.infinite,
                painter: _TempChartPainter(
                  realTempHistory: _realTempHistory,
                  topTempHistory: _topTempHistory,
                  timeRange: _chartTimeRange,
                ),
              ),

              // Legend
              Positioned(
                top: 12,
                left: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      color: MechanicalTheme.primaryCyan,
                      label: 'Real Temp',
                      value: '$currentRealTemp°C',
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      color: MechanicalTheme.heatOrange,
                      label: 'Top Temp',
                      value: '$currentTopTemp°C',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCurrentTemp() {
    return Consumer<BluetoothService>(
      builder: (context, bleService, _) {
        final deviceInfo = bleService.deviceInfo;
        final realTemp = deviceInfo?['realTemp'] as int? ?? 0;
        final topTemp = deviceInfo?['topTemp'] as int? ?? 0;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTempCard(
              label: 'Real Temp',
              temp: realTemp,
              color: MechanicalTheme.primaryCyan,
            ),
            const SizedBox(width: 30),
            _buildTempCard(
              label: 'Top Temp',
              temp: topTemp,
              color: MechanicalTheme.heatOrange,
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildTempCard({
    required String label,
    required int temp,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$temp°C',
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomButtons() {
    return Consumer<BluetoothService>(
      builder: (context, bleService, _) {
        final deviceInfo = bleService.deviceInfo;
        final startHeating = deviceInfo?['startHeating'] as int? ?? 0;
        final bPauseState = deviceInfo?['bPauseState'] as int? ?? 0;
        
        if (startHeating == 1) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                text: 'PAUSE',
                onTap: _onPause,
                colors: [MechanicalTheme.warningRed, const Color(0xFFFF8E53)],
              ),
              const SizedBox(width: 20),
              _buildActionButton(
                text: 'BOOST',
                onTap: _onBoost,
                colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
              ),
            ],
          );
        }
        
        final buttonText = bPauseState == 1 ? 'RESTART' : 'START HEATING';
        return _buildActionButton(
          text: buttonText,
          onTap: bPauseState == 1 ? _onRestart : _onStartHeating,
          colors: [MechanicalTheme.heatOrange, MechanicalTheme.heatRed],
          width: 220,
        );
      },
    );
  }
  
  void _onStartHeating() {
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
        heatPreset: widget.heatPreset,
        startHeating: 1,
        boostCount: boostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
      // 重置开始时间
      setState(() {
        _startTime = DateTime.now();
        _realTempHistory.clear();
        _topTempHistory.clear();
      });
    } catch (e) {
      print('Heating Page - Failed to start: $e');
    }
  }
  
  Widget _buildActionButton({
    required String text,
    required VoidCallback onTap,
    required List<Color> colors,
    double width = 160,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: MechanicalTheme.createGlowShadow(colors.first),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Temperature data point
class _TempDataPoint {
  final Duration elapsed;
  final int temp;
  
  _TempDataPoint(this.elapsed, this.temp);
}

/// Temperature curve painter
class _TempChartPainter extends CustomPainter {
  final List<_TempDataPoint> realTempHistory;
  final List<_TempDataPoint> topTempHistory;
  final double timeRange; // Display time range (seconds)

  _TempChartPainter({
    required this.realTempHistory,
    required this.topTempHistory,
    required this.timeRange,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (realTempHistory.isEmpty) return;
    
    final padding = 20.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    
    // 找到温度范围
    int minTemp = 0;
    int maxTemp = 300;
    
    for (final point in realTempHistory) {
      if (point.temp > maxTemp) maxTemp = point.temp;
      if (point.temp < minTemp) minTemp = point.temp;
    }
    for (final point in topTempHistory) {
      if (point.temp > maxTemp) maxTemp = point.temp;
      if (point.temp < minTemp) minTemp = point.temp;
    }
    
    // 添加缓冲
    maxTemp = ((maxTemp + 50) / 50).ceil() * 50;
    minTemp = 0;
    final tempRange = maxTemp - minTemp;
    
    // 绘制背景网格
    _drawGrid(canvas, size, padding, chartWidth, chartHeight, minTemp, maxTemp);
    
    // 绘制 Real Temp 曲线
    _drawCurve(
      canvas: canvas,
      history: realTempHistory,
      color: MechanicalTheme.primaryCyan,
      size: size,
      padding: padding,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minTemp: minTemp,
      tempRange: tempRange,
    );
    
    // 绘制 Top Temp 曲线
    _drawCurve(
      canvas: canvas,
      history: topTempHistory,
      color: MechanicalTheme.heatOrange,
      size: size,
      padding: padding,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minTemp: minTemp,
      tempRange: tempRange,
    );
  }
  
  void _drawGrid(
    Canvas canvas,
    Size size,
    double padding,
    double chartWidth,
    double chartHeight,
    int minTemp,
    int maxTemp,
  ) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    // 水平网格线（温度）
    final tempStep = 50;
    for (int temp = minTemp; temp <= maxTemp; temp += tempStep) {
      final y = size.height - padding - ((temp - minTemp) / (maxTemp - minTemp)) * chartHeight;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
      
      // 温度标签
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$temp',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(padding - 25, y - 6));
    }
    
    // 垂直网格线（时间）
    final timeSteps = 6;
    for (int i = 0; i <= timeSteps; i++) {
      final x = padding + (i / timeSteps) * chartWidth;
      canvas.drawLine(
        Offset(x, padding),
        Offset(x, size.height - padding),
        gridPaint,
      );
    }
  }
  
  void _drawCurve({
    required Canvas canvas,
    required List<_TempDataPoint> history,
    required Color color,
    required Size size,
    required double padding,
    required double chartWidth,
    required double chartHeight,
    required int minTemp,
    required int tempRange,
  }) {
    if (history.length < 2) return;
    
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    final path = Path();
    
    // 过滤出在显示时间范围内的数据点
    final maxElapsed = Duration(seconds: timeRange.toInt());
    final visiblePoints = history
        .where((p) => p.elapsed <= maxElapsed)
        .toList();
    
    if (visiblePoints.isEmpty) return;
    
    for (int i = 0; i < visiblePoints.length; i++) {
      final point = visiblePoints[i];
      final x = padding + (point.elapsed.inSeconds / timeRange) * chartWidth;
      final y = size.height - padding - ((point.temp - minTemp) / tempRange) * chartHeight;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // 使用二次贝塞尔曲线平滑连接
        final prevPoint = visiblePoints[i - 1];
        final prevX = padding + (prevPoint.elapsed.inSeconds / timeRange) * chartWidth;
        final prevY = size.height - padding - ((prevPoint.temp - minTemp) / tempRange) * chartHeight;
        
        final cpX = (prevX + x) / 2;
        path.quadraticBezierTo(prevX, prevY, cpX, (prevY + y) / 2);
      }
    }
    
    canvas.drawPath(path, linePaint);
    
    // 绘制渐变填充区域
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    final fillPath = Path.from(path);
    fillPath.lineTo(padding + chartWidth, size.height - padding);
    fillPath.lineTo(padding, size.height - padding);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
  }
  
  @override
  bool shouldRepaint(covariant _TempChartPainter oldDelegate) {
    return oldDelegate.realTempHistory.length != realTempHistory.length ||
        oldDelegate.topTempHistory.length != topTempHistory.length ||
        oldDelegate.timeRange != timeRange;
  }
}
