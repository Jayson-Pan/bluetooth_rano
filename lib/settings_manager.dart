import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const String _carSeriesPrefix = 'car_series_';
  static const String _robotFighterPrefix = 'robot_fighter_';
  
  // 默认按钮命令映射
  static const Map<String, String> _defaultCommands = {
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

  // 机器人格斗模式默认按钮命令映射
  static const Map<String, String> _defaultRobotFighterCommands = {
    // 9个方向控制按钮
    'forward': '1',        // 前进
    'backward': '2',       // 后退
    'left': '3',           // 左转
    'right': '4',          // 右转
    'forward_left': '5',   // 左前
    'forward_right': '6',  // 右前
    'backward_left': '7',  // 左后
    'backward_right': '8', // 右后
    'mode': '0',           // 模式切换（中心按钮）
    
    // 2个舵机功能按钮
    'servo1': '90',        // 舵机1
    'servo2': '90',        // 舵机2
  };

  // 保存小车系列按钮设置
  static Future<void> saveCarSeriesSettings(Map<String, String> commands) async {
    final prefs = await SharedPreferences.getInstance();
    for (String key in commands.keys) {
      await prefs.setString('$_carSeriesPrefix$key', commands[key] ?? '');
    }
  }

  // 读取小车系列按钮设置
  static Future<Map<String, String>> loadCarSeriesSettings() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> commands = {};
    
    for (String key in _defaultCommands.keys) {
      commands[key] = prefs.getString('$_carSeriesPrefix$key') ?? _defaultCommands[key]!;
    }
    
    return commands;
  }

  // 恢复小车系列默认设置
  static Future<void> resetCarSeriesSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (String key in _defaultCommands.keys) {
      await prefs.remove('$_carSeriesPrefix$key');
    }
  }

  // 保存格斗机器人系列按钮设置
  static Future<void> saveRobotFighterSettings(Map<String, String> commands) async {
    final prefs = await SharedPreferences.getInstance();
    for (String key in commands.keys) {
      await prefs.setString('$_robotFighterPrefix$key', commands[key] ?? '');
    }
  }

  // 读取格斗机器人系列按钮设置
  static Future<Map<String, String>> loadRobotFighterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> commands = {};
    
    for (String key in _defaultRobotFighterCommands.keys) {
      commands[key] = prefs.getString('$_robotFighterPrefix$key') ?? _defaultRobotFighterCommands[key]!;
    }
    
    return commands;
  }

  // 恢复格斗机器人系列默认设置
  static Future<void> resetRobotFighterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (String key in _defaultRobotFighterCommands.keys) {
      await prefs.remove('$_robotFighterPrefix$key');
    }
  }

  // 获取默认命令
  static Map<String, String> getDefaultCommands() {
    return Map.from(_defaultCommands);
  }

  // 获取机器人格斗模式默认命令
  static Map<String, String> getDefaultRobotFighterCommands() {
    return Map.from(_defaultRobotFighterCommands);
  }
} 