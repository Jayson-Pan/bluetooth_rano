import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bluetooth_service.dart';
import 'dart:async';

class BluetoothCarSeriesPage extends StatefulWidget {
  const BluetoothCarSeriesPage({super.key});

  @override
  State<BluetoothCarSeriesPage> createState() => _BluetoothCarSeriesPageState();
}

class _BluetoothCarSeriesPageState extends State<BluetoothCarSeriesPage> {
  final BluetoothService _bluetoothService = BluetoothService();
  StreamSubscription<bool>? _connectionSubscription;
  
  bool _isConnected = false;
  bool _isCustomizeMode = false; // 按钮自定义模式
  Timer? _sendTimer; // 长按定时器
  Set<String> _pressedButtons = {}; // 记录按下的按钮
  
  // 按钮命令映射
  Map<String, String> _buttonCommands = {
    'up': 'F',
    'down': 'B',
    'left': 'L',
    'right': 'R',
    'f1': '1',
    'f2': '2',
    'f3': '3',
    'f4': '4',
    'f5': '5',
    'f6': '6',
    'f7': '7',
    'f8': '8',
    'f9': '9',
  };

  @override
  void initState() {
    super.initState();
    _setLandscapeOrientation();
    _listenToConnectionState();
    _updateConnectionState();
  }

  @override
  void dispose() {
    _setPortraitOrientation();
    _connectionSubscription?.cancel();
    _sendTimer?.cancel();
    super.dispose();
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
    // 添加按下反馈
    setState(() {
      _pressedButtons.add(buttonKey);
    });
    
    // 震动反馈
    HapticFeedback.lightImpact();
    
    // 延迟移除按下状态
    Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _pressedButtons.remove(buttonKey);
        });
      }
    });
    
    if (_isCustomizeMode) {
      _showCustomizeDialog(buttonKey);
    } else {
      String command = _buttonCommands[buttonKey] ?? '';
      if (command.isNotEmpty) {
        _sendCommand(command);
      }
    }
  }

  // 处理长按开始
  void _onButtonLongPressStart(String buttonKey) {
    if (_isCustomizeMode) return;
    
    // 添加长按反馈
    setState(() {
      _pressedButtons.add(buttonKey);
    });
    
    String command = _buttonCommands[buttonKey] ?? '';
    if (command.isNotEmpty && _isConnected) {
      _sendTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _sendCommand(command);
      });
    }
  }

  // 处理长按结束
  void _onButtonLongPressEnd(String buttonKey) {
    _sendTimer?.cancel();
    _sendTimer = null;
    
    // 移除按下状态
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
        title: Text('自定义按钮: ${buttonKey.toUpperCase()}'),
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
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
              Text('• 点击方向键控制小车移动'),
              Text('• 长按方向键连续发送命令'),
              Text('• F1-F9按钮默认发送1-9字符'),
              SizedBox(height: 12),
              Text('⚙️ 自定义模式：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 开启"按钮自定义"模式'),
              Text('• 点击任意按钮编辑发送命令'),
              Text('• 可以预览每个按钮的命令'),
              SizedBox(height: 12),
              Text('🔗 连接要求：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 需要先在"BLE发现"页面连接设备'),
              Text('• 连接状态会在左上角显示'),
              SizedBox(height: 12),
              Text('⌨️ 默认按键：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 方向键: ↑(F) ↓(B) ←(L) →(R)'),
              Text('• 功能键: F1(1) F2(2) ... F9(9)'),
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
      body: Container(
        decoration: const BoxDecoration(
          // 使用自定义背景图片，如果图片不存在则使用渐变背景
          image: DecorationImage(
            image: AssetImage('assets/images/qt-logo.png'),
            fit: BoxFit.cover,
            onError: null, // 如果图片加载失败，将显示渐变背景
          ),
          // 备用渐变背景
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2563EB), // 蓝色
              Color(0xFF1E40AF), // 深蓝色
              Color(0xFF1E3A8A), // 更深蓝色
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // 顶部状态栏
                _buildTopBar(),
                const SizedBox(height: 12),
                
                // 主控制区域 - 使用对称布局
                Expanded(
                  child: Row(
                    children: [
                      // 左侧区域：上下方向键
                      Expanded(
                        flex: 2,
                        child: _buildDirectionControls(),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // 中间区域：F1-F9按钮
                      Expanded(
                        flex: 4,
                        child: _buildFunctionButtons(),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // 右侧区域：左右方向键
                      Expanded(
                        flex: 2,
                        child: _buildLeftRightControls(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
        
        // 操作指南按钮
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ElevatedButton.icon(
            onPressed: _showGuide,
            icon: const Icon(Icons.help_outline, size: 16),
            label: const Text('操作指南'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // 按钮自定义切换
        Container(
          decoration: BoxDecoration(
            color: _isCustomizeMode 
              ? Colors.orange.withValues(alpha: 0.8)
              : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isCustomizeMode = !_isCustomizeMode;
              });
            },
            icon: Icon(
              _isCustomizeMode ? Icons.edit : Icons.edit_outlined,
              size: 16,
            ),
            label: Text(_isCustomizeMode ? '自定义中' : '按钮自定义'),
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

  // 左侧方向控制
  Widget _buildDirectionControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 上
        _buildControlButton(
          'up',
          Icons.keyboard_arrow_up,
          '↑',
          isDirectional: true,
        ),
        // 下
        _buildControlButton(
          'down',
          Icons.keyboard_arrow_down,
          '↓',
          isDirectional: true,
        ),
      ],
    );
  }

  // 右侧左右控制
  Widget _buildLeftRightControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 左
        _buildControlButton(
          'left',
          Icons.keyboard_arrow_left,
          '←',
          isDirectional: true,
        ),
        // 右
        _buildControlButton(
          'right',
          Icons.keyboard_arrow_right,
          '→',
          isDirectional: true,
        ),
      ],
    );
  }

  // 中间F1-F9按钮
  Widget _buildFunctionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算可用空间，减去间距
        double availableHeight = constraints.maxHeight;
        double availableWidth = constraints.maxWidth;
        
        // 计算按钮大小，确保不溢出
        double buttonHeight = (availableHeight - 40) / 3; // 3行，减去间距
        double buttonWidth = (availableWidth - 40) / 3; // 3列，减去间距
        double buttonSize = buttonHeight < buttonWidth ? buttonHeight : buttonWidth;
        
        // 确保按钮不会太小
        buttonSize = buttonSize < 60 ? 60 : buttonSize;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 第一行：F1, F2, F3
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 1; i <= 3; i++)
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: _buildControlButton(
                      'f$i',
                      Icons.circle,
                      'F$i',
                    ),
                  ),
              ],
            ),
            // 第二行：F4, F5, F6
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 4; i <= 6; i++)
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: _buildControlButton(
                      'f$i',
                      Icons.circle,
                      'F$i',
                    ),
                  ),
              ],
            ),
            // 第三行：F7, F8, F9
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 7; i <= 9; i++)
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: _buildControlButton(
                      'f$i',
                      Icons.circle,
                      'F$i',
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  // 构建控制按钮
  Widget _buildControlButton(
    String buttonKey,
    IconData icon,
    String label, {
    bool isDirectional = false,
  }) {
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
        width: isDirectional ? 100 : null,
        height: isDirectional ? 100 : null,
        transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0), // 按下时缩放
        decoration: BoxDecoration(
          color: isPressed
            ? Colors.white.withValues(alpha: 0.8) // 按下时变白色
            : _isCustomizeMode 
              ? Colors.orange.withValues(alpha: 0.8)
              : (hasCommand && _isConnected 
                ? Colors.blue.withValues(alpha: 0.8) 
                : Colors.black.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPressed 
              ? Colors.blue.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.3),
            width: isPressed ? 3 : 2,
          ),
          boxShadow: isPressed ? [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPressed ? Colors.blue.shade700 : Colors.white,
                size: isDirectional ? 24 : 18,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isPressed ? Colors.blue.shade700 : Colors.white,
                    fontSize: isDirectional ? 14 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (command.isNotEmpty) ...[
                const SizedBox(height: 1),
                Flexible(
                  child: Text(
                    command,
                    style: TextStyle(
                      color: isPressed ? Colors.blue.shade600 : Colors.white70,
                      fontSize: 8,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 