import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bluetooth_service.dart';
import 'settings_manager.dart';
import 'dart:async';

class BluetoothRobotFighterPage extends StatefulWidget {
  const BluetoothRobotFighterPage({super.key});

  @override
  State<BluetoothRobotFighterPage> createState() => _BluetoothRobotFighterPageState();
}

class _BluetoothRobotFighterPageState extends State<BluetoothRobotFighterPage> {
  final BluetoothService _bluetoothService = BluetoothService();
  StreamSubscription<bool>? _connectionSubscription;
  
  bool _isConnected = false;
  Map<String, Timer> _sendTimers = {};
  Set<String> _pressedButtons = {};
  
  // 轮播背景相关
  late PageController _pageController;
  Timer? _backgroundTimer;
  int _currentBackgroundIndex = 0;
  
  // 背景图片列表
  final List<String> _backgroundImages = [
    'assets/images/bg1.jpg',
    'assets/images/bg2.jpg',
  ];
  
  // 按钮命令映射
  Map<String, String> _buttonCommands = {};
  
  // 舵机角度
  double _servo1Angle = 90.0;
  double _servo2Angle = 90.0;

  @override
  void initState() {
    super.initState();
    _setLandscapeOrientation();
    _listenToConnectionState();
    _updateConnectionState();
    _initBackgroundCarousel();
    _loadSettings();
  }

  // 加载保存的设置
  void _loadSettings() async {
    final commands = await SettingsManager.loadRobotFighterSettings();
    if (mounted) {
      setState(() {
        _buttonCommands = commands;
      });
    }
  }

  // 保存设置
  void _saveSettings() async {
    await SettingsManager.saveRobotFighterSettings(_buttonCommands);
  }

  // 恢复默认设置
  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('确定要将所有按钮恢复为默认设置吗？\n\n此操作将清除您的所有自定义按钮命令。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await SettingsManager.resetRobotFighterSettings();
              final defaultCommands = SettingsManager.getDefaultRobotFighterCommands();
              setState(() {
                _buttonCommands = defaultCommands;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已恢复默认设置'),
                  duration: Duration(milliseconds: 1500),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定恢复'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _setPortraitOrientation();
    _connectionSubscription?.cancel();
    _sendTimers.values.forEach((timer) => timer.cancel());
    _sendTimers.clear();
    _backgroundTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // 初始化背景轮播
  void _initBackgroundCarousel() {
    _pageController = PageController();
    _startBackgroundTimer();
  }

  // 开始背景轮播定时器
  void _startBackgroundTimer() {
    _backgroundTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        _currentBackgroundIndex = (_currentBackgroundIndex + 1) % _backgroundImages.length;
        _pageController.animateToPage(
          _currentBackgroundIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // 设置横屏
  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // 恢复竖屏
  void _setPortraitOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _listenToConnectionState() {
    _connectionSubscription = _bluetoothService.connectionStateStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });
  }

  void _updateConnectionState() {
    setState(() {
      _isConnected = _bluetoothService.isConnected;
    });
  }

  // 发送命令
  Future<void> _sendCommand(String command) async {
    if (!_isConnected) return;
    await _bluetoothService.sendMessage(command);
  }

  // 处理按钮按下
  void _onButtonPressed(String buttonKey) {
    setState(() {
      _pressedButtons.add(buttonKey);
    });
    
    HapticFeedback.lightImpact();
    
    Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _pressedButtons.remove(buttonKey);
        });
      }
    });
    
    String command = _buttonCommands[buttonKey] ?? '';
    if (command.isNotEmpty) {
      _sendCommand(command);
    }
  }

  // 处理长按开始
  void _onButtonLongPressStart(String buttonKey) {
    setState(() {
      _pressedButtons.add(buttonKey);
    });
    
    String command = _buttonCommands[buttonKey] ?? '';
    if (command.isNotEmpty && _isConnected) {
      _sendTimers[buttonKey] = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _sendCommand(command);
      });
    }
  }

  // 处理长按结束
  void _onButtonLongPressEnd(String buttonKey) {
    _sendTimers[buttonKey]?.cancel();
    _sendTimers.remove(buttonKey);
    
    setState(() {
      _pressedButtons.remove(buttonKey);
    });
  }

  // 显示按钮自定义对话框
  void _showCustomizeDialog(String buttonKey) {
    TextEditingController controller = TextEditingController(
      text: _buttonCommands[buttonKey] ?? '',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('自定义按钮: ${_getButtonDisplayName(buttonKey)}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '发送命令',
            hintText: '输入要发送的字符串',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _buttonCommands[buttonKey] = controller.text;
              });
              _saveSettings();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('按钮 ${_getButtonDisplayName(buttonKey)} 的命令已保存'),
                  duration: const Duration(milliseconds: 1500),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 获取按钮显示名称
  String _getButtonDisplayName(String buttonKey) {
    switch (buttonKey) {
      case 'forward': return '前进';
      case 'backward': return '后退';
      case 'left': return '左转';
      case 'right': return '右转';
      case 'forward_left': return '左前';
      case 'forward_right': return '右前';
      case 'backward_left': return '左后';
      case 'backward_right': return '右后';
      case 'mode': return 'MODE';
      case 'servo1': return '舵机1';
      case 'servo2': return '舵机2';
      default: return buttonKey.toUpperCase();
    }
  }

  // 跳转到竖屏自定义界面
  void _openCustomizeScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomizeButtonsScreen(
          buttonCommands: Map.from(_buttonCommands),
          isConnected: _isConnected,
        ),
      ),
    );
    
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    
    if (result != null && result is Map<String, String>) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _buttonCommands = result;
        });
      }
    }
  }

  // 显示操作指南
  void _showGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('操作指南'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎮 遥控模式：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 左侧9个按钮控制机器人移动方向'),
              Text('• 长按方向键连续发送命令'),
              Text('• 中心MODE按钮切换运动模式'),
              SizedBox(height: 12),
              Text('🎛️ 舵机控制：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 右上方滑条调节舵机角度(0-180°)'),
              Text('• 点击发送按钮执行舵机命令'),
              Text('• 右下方按钮快速设置舵机到90°'),
              SizedBox(height: 12),
              Text('⚙️ 自定义模式：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 点击"按钮自定义"进入竖屏编辑模式'),
              Text('• 在竖屏模式下编辑每个按钮的命令'),
              Text('• 完成后自动返回横屏操作界面'),
              SizedBox(height: 12),
              Text('🔗 连接要求：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 需要先在"BLE发现"页面连接设备'),
              Text('• 连接状态会在左上角显示'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 轮播背景
          PageView.builder(
            controller: _pageController,
            itemCount: _backgroundImages.length,
            onPageChanged: (index) {
              setState(() {
                _currentBackgroundIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_backgroundImages[index]),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      // 图片加载失败时显示红色渐变背景
                    },
                  ),
                  // 备用红色渐变背景
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFDC2626), // 红色
                      Color(0xFFB91C1C), // 深红色
                      Color(0xFF991B1B), // 更深红色
                    ],
                  ),
                ),
              );
            },
          ),
          
          // 前景内容
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // 顶部状态栏
                  _buildTopBar(),
                  const SizedBox(height: 12),
                  
                  // 主控制区域
                  Expanded(
                    child: Row(
                      children: [
                        // 左侧区域：9个方向控制按钮
                        Expanded(
                          flex: 1,
                          child: _buildDirectionControlGrid(),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // 右侧区域
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              // 右上：舵机角度控制
                              Expanded(
                                flex: 4,
                                child: _buildServoControls(),
                              ),
                              
                              const SizedBox(height: 4),
                              
                              // 右下：舵机功能按钮
                              SizedBox(
                                height: 55,
                                child: _buildServoButtons(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 顶部状态栏
  Widget _buildTopBar() {
    return Row(
      children: [
        // 返回按钮
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // 连接状态
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isConnected 
              ? Colors.green.withValues(alpha: 0.9) 
              : Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _isConnected ? '已连接' : '未连接',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // 恢复默认按钮
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restore, size: 16),
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 操作指南按钮
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            onPressed: _showGuide,
            icon: const Icon(Icons.help_outline, size: 16),
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 按钮自定义切换
        Container(
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ElevatedButton.icon(
            onPressed: _openCustomizeScreen,
            icon: const Icon(
              Icons.edit,
              size: 16,
            ),
            label: const Text('按钮自定义'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  // 左侧9个方向控制按钮网格
  Widget _buildDirectionControlGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double size = (constraints.maxHeight - 40) / 3; // 3x3网格
        size = size > 80 ? 80 : size; // 限制最大尺寸
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 第一行：左前、前进、右前
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDirectionButton('forward_left', Icons.north_west, '', size),
                _buildDirectionButton('forward', Icons.keyboard_arrow_up, '', size),
                _buildDirectionButton('forward_right', Icons.north_east, '', size),
              ],
            ),
            // 第二行：左转、MODE、右转
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDirectionButton('left', Icons.keyboard_arrow_left, '', size),
                _buildDirectionButton('mode', Icons.autorenew, 'MODE', size, isMode: true),
                _buildDirectionButton('right', Icons.keyboard_arrow_right, '', size),
              ],
            ),
            // 第三行：左后、后退、右后
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDirectionButton('backward_left', Icons.south_west, '', size),
                _buildDirectionButton('backward', Icons.keyboard_arrow_down, '', size),
                _buildDirectionButton('backward_right', Icons.south_east, '', size),
              ],
            ),
          ],
        );
      },
    );
  }

  // 方向控制按钮
  Widget _buildDirectionButton(String buttonKey, IconData? icon, String label, double size, {bool isMode = false}) {
    String command = _buttonCommands[buttonKey] ?? '';
    bool hasCommand = command.isNotEmpty;
    bool isPressed = _pressedButtons.contains(buttonKey);
    
    return GestureDetector(
      onTap: () => _onButtonPressed(buttonKey),
      onLongPressStart: (_) => _onButtonLongPressStart(buttonKey),
      onLongPressEnd: (_) => _onButtonLongPressEnd(buttonKey),
      onLongPressCancel: () => _onButtonLongPressEnd(buttonKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: size,
        height: size,
        transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          color: isPressed
            ? Colors.yellow.withValues(alpha: 0.9)
            : isMode
              ? Colors.orange.withValues(alpha: 0.8) // MODE按钮特殊颜色
              : (hasCommand && _isConnected 
                ? Colors.red.withValues(alpha: 0.8)
                : Colors.black.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPressed 
              ? Colors.red.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.3),
            width: isPressed ? 3 : 2,
          ),
          boxShadow: isPressed ? [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isPressed ? Colors.red.shade700 : Colors.white,
                size: isMode ? 20 : 24,
              ),
              if (label.isNotEmpty) const SizedBox(height: 4),
            ],
            if (label.isNotEmpty) ...[
              Text(
                label,
                style: TextStyle(
                  color: isPressed ? Colors.red.shade700 : Colors.white,
                  fontSize: isMode ? 10 : (icon != null ? 12 : 14),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (command.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                command,
                style: TextStyle(
                  color: isPressed ? Colors.red.shade600 : Colors.white70,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 右上舵机控制组件
  Widget _buildServoControls() {
    return Column(
      children: [
        // 舵机1控制
        Expanded(
          child: _buildServoControl(
            title: '舵机角度 1',
            angle: _servo1Angle,
            onChanged: (value) {
              setState(() {
                _servo1Angle = value;
              });
            },
            onSend: () {
              _sendCommand('servo${_servo1Angle.round()}');
            },
          ),
        ),
        
        const SizedBox(height: 2),
        
        // 舵机2控制
        Expanded(
          child: _buildServoControl(
            title: '舵机角度 2',
            angle: _servo2Angle,
            onChanged: (value) {
              setState(() {
                _servo2Angle = value;
              });
            },
            onSend: () {
              _sendCommand('servo${_servo2Angle.round()}');
            },
          ),
        ),
      ],
    );
  }

  // 单个舵机控制组件
  Widget _buildServoControl({
    required String title,
    required double angle,
    required ValueChanged<double> onChanged,
    required VoidCallback onSend,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${angle.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.red.withValues(alpha: 0.8),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                      thumbColor: Colors.red,
                      overlayColor: Colors.red.withValues(alpha: 0.2),
                      trackHeight: 1.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: angle,
                      min: 0,
                      max: 180,
                      divisions: 180,
                      onChanged: onChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 28,
                  width: 48,
                  child: ElevatedButton(
                    onPressed: _isConnected ? onSend : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                    child: const Text('发送', style: TextStyle(fontSize: 9)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 右下舵机功能按钮
  Widget _buildServoButtons() {
    return Row(
      children: [
        // 舵机1按钮
        Expanded(
          child: _buildServoFunctionButton('servo1', '舵机1'),
        ),
        const SizedBox(width: 12),
        // 舵机2按钮
        Expanded(
          child: _buildServoFunctionButton('servo2', '舵机2'),
        ),
      ],
    );
  }

  // 舵机功能按钮
  Widget _buildServoFunctionButton(String buttonKey, String label) {
    String command = _buttonCommands[buttonKey] ?? '';
    bool hasCommand = command.isNotEmpty;
    bool isPressed = _pressedButtons.contains(buttonKey);
    
    return GestureDetector(
      onTap: () => _onButtonPressed(buttonKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 55,
        transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          color: isPressed
            ? Colors.yellow.withValues(alpha: 0.9)
            : (hasCommand && _isConnected 
              ? Colors.red.withValues(alpha: 0.8)
              : Colors.black.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPressed 
              ? Colors.red.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.3),
            width: isPressed ? 3 : 2,
          ),
          boxShadow: isPressed ? [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_input_antenna,
              color: isPressed ? Colors.red.shade700 : Colors.white,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isPressed ? Colors.red.shade700 : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (command.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                command,
                style: TextStyle(
                  color: isPressed ? Colors.red.shade600 : Colors.white70,
                  fontSize: 7,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 竖屏按钮自定义界面
class CustomizeButtonsScreen extends StatefulWidget {
  final Map<String, String> buttonCommands;
  final bool isConnected;

  const CustomizeButtonsScreen({
    super.key,
    required this.buttonCommands,
    required this.isConnected,
  });

  @override
  State<CustomizeButtonsScreen> createState() => _CustomizeButtonsScreenState();
}

class _CustomizeButtonsScreenState extends State<CustomizeButtonsScreen> {
  late Map<String, String> _buttonCommands;

  // 按钮信息映射
  final Map<String, Map<String, dynamic>> _buttonInfo = {
    'forward': {'label': '前进 ↑', 'icon': Icons.keyboard_arrow_up, 'description': '机器人前进'},
    'backward': {'label': '后退 ↓', 'icon': Icons.keyboard_arrow_down, 'description': '机器人后退'},
    'left': {'label': '左转 ←', 'icon': Icons.keyboard_arrow_left, 'description': '机器人左转'},
    'right': {'label': '右转 →', 'icon': Icons.keyboard_arrow_right, 'description': '机器人右转'},
    'forward_left': {'label': '左前 ↖', 'icon': Icons.north_west, 'description': '机器人左前移动'},
    'forward_right': {'label': '右前 ↗', 'icon': Icons.north_east, 'description': '机器人右前移动'},
    'backward_left': {'label': '左后 ↙', 'icon': Icons.south_west, 'description': '机器人左后移动'},
    'backward_right': {'label': '右后 ↘', 'icon': Icons.south_east, 'description': '机器人右后移动'},
    'mode': {'label': 'MODE', 'icon': Icons.autorenew, 'description': '切换运动模式'},
    'servo1': {'label': '舵机1', 'icon': Icons.settings_input_antenna, 'description': '舵机1控制'},
    'servo2': {'label': '舵机2', 'icon': Icons.settings_input_antenna, 'description': '舵机2控制'},
  };

  @override
  void initState() {
    super.initState();
    _buttonCommands = Map.from(widget.buttonCommands);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    Future.microtask(() {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
    super.dispose();
  }

  void _editButton(String buttonKey) {
    TextEditingController controller = TextEditingController(
      text: _buttonCommands[buttonKey] ?? '',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑 ${_buttonInfo[buttonKey]?['label'] ?? buttonKey}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '功能：${_buttonInfo[buttonKey]?['description'] ?? '自定义功能'}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '发送命令',
                hintText: '输入要发送的字符串',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _buttonCommands[buttonKey] = controller.text;
              });
              SettingsManager.saveRobotFighterSettings(_buttonCommands);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('按钮 ${_buttonInfo[buttonKey]?['label'] ?? buttonKey} 的命令已保存'),
                  duration: const Duration(milliseconds: 1500),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('按钮自定义'),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isConnected 
                ? Colors.green.withValues(alpha: 0.2) 
                : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isConnected ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  size: 14,
                  color: widget.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context, _buttonCommands);
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFDC2626),
              Color(0xFFB91C1C),
              Color(0xFF991B1B),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎮 按钮自定义说明',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• 点击下方按钮可编辑发送的命令\n• 支持单个字符或字符串\n• 舵机角度控制发送"servo+角度"\n• 编辑完成后点击返回按钮保存',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: _buttonInfo.length,
                    itemBuilder: (context, index) {
                      String buttonKey = _buttonInfo.keys.elementAt(index);
                      Map<String, dynamic> info = _buttonInfo[buttonKey]!;
                      String command = _buttonCommands[buttonKey] ?? '';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _editButton(buttonKey),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      info['icon'],
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 16),
                                  
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          info['label'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          info['description'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (command.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.blue.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              '命令: $command',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  Icon(
                                    Icons.edit,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}