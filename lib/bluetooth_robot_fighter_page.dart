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
  bool _isCustomizeMode = false; // 按钮自定义模式
  Timer? _sendTimer; // 长按定时器
  Set<String> _pressedButtons = {}; // 记录按下的按钮
  
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
              final defaultCommands = SettingsManager.getDefaultCommands();
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
    _sendTimer?.cancel();
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
              _saveSettings(); // 保存到本地存储
              Navigator.pop(context);
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('按钮 ${buttonKey.toUpperCase()} 的命令已保存'),
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
    
    // 确保返回时是横屏
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    
    if (result != null && result is Map<String, String>) {
      // 延迟更新状态，等待屏幕方向稳定
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
              Text('🤖 格斗模式：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 点击方向键控制机器人移动'),
              Text('• 长按方向键连续发送命令'),
              Text('• F1-F9按钮默认发送1-9字符'),
              SizedBox(height: 12),
              Text('⚙️ 自定义模式：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 点击"按钮自定义"进入竖屏编辑模式'),
              Text('• 在竖屏模式下编辑每个按钮的命令'),
              Text('• 完成后自动返回横屏操作界面'),
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
      resizeToAvoidBottomInset: false, // 避免键盘影响布局
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
            color: Colors.amber.withValues(alpha: 0.9), // 金黄色作为红色主题的反差色
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

  // 构建控制按钮 - 红色主题
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
            ? Colors.yellow.withValues(alpha: 0.9) // 按下时变亮黄色
            : _isCustomizeMode 
              ? Colors.amber.withValues(alpha: 0.8) // 自定义模式用金黄色
              : (hasCommand && _isConnected 
                ? Colors.red.withValues(alpha: 0.8) // 红色主题
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
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPressed ? Colors.red.shade700 : Colors.white,
                size: isDirectional ? 24 : 18,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isPressed ? Colors.red.shade700 : Colors.white,
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
                      color: isPressed ? Colors.red.shade600 : Colors.white70,
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
    'up': {'label': '上 ↑', 'icon': Icons.keyboard_arrow_up, 'description': '向上移动'},
    'down': {'label': '下 ↓', 'icon': Icons.keyboard_arrow_down, 'description': '向下移动'},
    'left': {'label': '左 ←', 'icon': Icons.keyboard_arrow_left, 'description': '向左移动'},
    'right': {'label': '右 →', 'icon': Icons.keyboard_arrow_right, 'description': '向右移动'},
    'f1': {'label': 'F1', 'icon': Icons.looks_one, 'description': '功能键1'},
    'f2': {'label': 'F2', 'icon': Icons.looks_two, 'description': '功能键2'},
    'f3': {'label': 'F3', 'icon': Icons.looks_3, 'description': '功能键3'},
    'f4': {'label': 'F4', 'icon': Icons.looks_4, 'description': '功能键4'},
    'f5': {'label': 'F5', 'icon': Icons.looks_5, 'description': '功能键5'},
    'f6': {'label': 'F6', 'icon': Icons.looks_6, 'description': '功能键6'},
    'f7': {'label': 'F7', 'icon': Icons.filter_7, 'description': '功能键7'},
    'f8': {'label': 'F8', 'icon': Icons.filter_8, 'description': '功能键8'},
    'f9': {'label': 'F9', 'icon': Icons.filter_9, 'description': '功能键9'},
  };

  @override
  void initState() {
    super.initState();
    _buttonCommands = Map.from(widget.buttonCommands);
    // 设置竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    // 立即恢复横屏，但使用Future.microtask避免在dispose过程中的冲突
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
              // 保存到本地存储
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
        // 在返回前确保屏幕方向设置正确
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        // 短暂延迟确保方向变化开始
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('按钮自定义'),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        actions: [
          // 连接状态指示
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
              Color(0xFFDC2626), // 红色
              Color(0xFFB91C1C), // 深红色
              Color(0xFF991B1B), // 更深红色
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 说明文字
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
                        '• 点击下方按钮可编辑发送的命令\n• 支持单个字符或字符串\n• 编辑完成后点击返回按钮保存',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 按钮列表
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
                                  // 按钮图标
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
                                  
                                  // 按钮信息
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
                                  
                                  // 编辑图标
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