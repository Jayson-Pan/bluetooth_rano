import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

// 统一的设备模型
class UnifiedBluetoothDevice {
  final String address;
  final String? name;
  final fbp.BluetoothDevice? device;
  
  UnifiedBluetoothDevice({
    required this.address,
    this.name,
    this.device,
  });

  // 从BLE device创建
  factory UnifiedBluetoothDevice.fromBle(fbp.BluetoothDevice device) {
    return UnifiedBluetoothDevice(
      address: device.remoteId.str,
      name: device.platformName.isNotEmpty ? device.platformName : null,
      device: device,
    );
  }
}

// 数据接收模式
enum ReceiveMode {
  ascii,  // ASCII字符串模式
  hex,    // 十六进制模式
}

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _writeCharacteristic;
  fbp.BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _dataStreamSubscription;
  StreamSubscription<fbp.BluetoothConnectionState>? _connectionSubscription;
  
  final StreamController<String> _messageStreamController = StreamController<String>.broadcast();
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();

  Stream<String> get messageStream => _messageStreamController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  UnifiedBluetoothDevice? connectedDevice;
  
  // 数据接收模式
  ReceiveMode _receiveMode = ReceiveMode.ascii;
  ReceiveMode get receiveMode => _receiveMode;
  
  // 回环过滤相关
  final List<String> _recentSentMessages = [];
  static const int _maxRecentMessages = 5;
  static const int _echoTimeoutMs = 2000; // 2秒内的回传被认为是回环
  bool _enableEchoFilter = true; // 默认启用回环过滤
  
  // 切换接收模式
  void setReceiveMode(ReceiveMode mode) {
    _receiveMode = mode;
    print('接收模式切换为: ${mode == ReceiveMode.ascii ? "ASCII" : "HEX"}');
  }
  
  // 切换回环过滤
  void setEchoFilter(bool enabled) {
    _enableEchoFilter = enabled;
    print('回环过滤${enabled ? "已启用" : "已禁用"}');
  }
  
  bool get isEchoFilterEnabled => _enableEchoFilter;
  
  // 处理接收到的数据
  String _processReceivedData(List<int> data) {
    switch (_receiveMode) {
      case ReceiveMode.ascii:
        // 尝试多种ASCII解码方式
        String message = _decodeAsciData(data);
        print('接收到ASCII数据: $message');
        return message;
      case ReceiveMode.hex:
        String hexString = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        print('接收到HEX数据: $hexString');
        return hexString;
    }
  }
  
     // 智能ASCII解码
   String _decodeAsciData(List<int> data) {
     print('原始数据: ${data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
     print('原始数据字节: $data');
     
     // 方法1: 直接UTF-8解码（处理完整的UTF-8序列）
     try {
       String message = utf8.decode(data, allowMalformed: false);
       print('UTF-8解码成功: $message');
       return message;
     } catch (e) {
       print('UTF-8解码失败: $e');
     }
     
     // 方法1.5: 尝试UTF-8解码，允许畸形字符，但清理替换字符
     try {
       String message = utf8.decode(data, allowMalformed: true);
       
       // 计算替换字符的数量
       int replacementCount = message.split('�').length - 1;
       print('UTF-8解码（允许畸形）原始结果: $message (替换字符数: $replacementCount)');
       
       if (replacementCount == 0) {
         // 没有替换字符，完美解码
         print('UTF-8解码完全成功: $message');
         return message;
       } else if (replacementCount < data.length * 0.3) {
         // 有少量替换字符，尝试清理
         String cleanedMessage = _cleanReplacementCharacters(message);
         if (cleanedMessage.isNotEmpty) {
           print('UTF-8解码成功（已清理）: $cleanedMessage');
           return cleanedMessage;
         }
       }
     } catch (e) {
       print('UTF-8解码（允许畸形）失败: $e');
     }
    
         // 方法2: 智能协议解析和ASCII解码
     String result = _parseProtocolData(data);
     if (result.isNotEmpty) {
       print('协议解析成功: "$result"');
       return result;
     }
     
     // 方法2.5: 检查是否为简单的协议头+ASCII数据格式
     if (data.length > 1 && (data[0] < 32 || data[0] > 126)) {
       // 跳过第一个字节，直接解码剩余部分
       List<int> remainingData = data.skip(1).toList();
       try {
         String message = String.fromCharCodes(remainingData.where((byte) => 
             (byte >= 32 && byte <= 126) || byte == 10 || byte == 13 || byte == 9
         ));
         message = message.trim();
         if (message.isNotEmpty) {
           print('跳过协议头解码成功: "$message"');
           return message;
         }
       } catch (e) {
         print('跳过协议头解码失败: $e');
       }
     }
     
     // 方法3: 过滤非ASCII字符，只保留可打印字符
     List<int> filteredData = data.where((byte) => 
         (byte >= 32 && byte <= 126) ||  // 可打印ASCII字符
         byte == 9 || byte == 10 || byte == 13  // 制表符、换行符、回车符
     ).toList();
     
     print('过滤后的数据: $filteredData');
     
     if (filteredData.isNotEmpty) {
       try {
         String message = String.fromCharCodes(filteredData);
         // 清理字符串，移除前后的空白字符和控制字符
         message = message.trim();
         print('过滤方法解码成功: "$message"');
         return message;
       } catch (e) {
         print('过滤方法解码失败: $e');
         // 继续下一种方法
       }
     }
    
         // 方法4: 逐字节尝试转换，跳过无效字符
     StringBuffer buffer = StringBuffer();
    bool hasValidChars = false;
    
    for (int byte in data) {
      if (byte >= 32 && byte <= 126) {  // 可打印ASCII字符
        buffer.writeCharCode(byte);
        hasValidChars = true;
      } else if (byte == 9) {  // 制表符
        buffer.write('\\t');
        hasValidChars = true;
      } else if (byte == 10) {  // 换行符
        buffer.write('\\n');
        hasValidChars = true;
      } else if (byte == 13) {  // 回车符
        buffer.write('\\r');
        hasValidChars = true;
      } else {
        // 跳过无效字符，但记录位置
        buffer.write('[${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}]');
      }
    }
    
         if (hasValidChars) {
       String result = buffer.toString();
       print('逐字节方法解码成功: $result');
       return result;
     }
     
     // 方法5: 如果所有方法都失败，返回十六进制格式
     String hexString = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          print('所有ASCII解码方法失败，返回HEX格式');
     return '[无法解码] HEX: $hexString';
   }
   
   // 解析特定协议格式的数据
   String _parseProtocolData(List<int> data) {
     if (data.isEmpty) return '';
     
     // 针对观察到的数据格式 [129, 58, 32, 111, 110, 13, 10] 进行解析
     // 格式似乎是：[协议头, 数据...]
     
     // 检查是否是以非ASCII字符开头的协议数据
     if (data.length > 1 && (data[0] < 32 || data[0] > 126)) {
       // 跳过第一个字节（协议头），尝试解码剩余部分
       List<int> payloadData = data.skip(1).toList();
       print('检测到协议头: ${data[0]} (0x${data[0].toRadixString(16).toUpperCase()})');
       print('有效载荷数据: $payloadData');
       
       // 过滤出有效的ASCII字符
       List<int> validChars = payloadData.where((byte) => 
           (byte >= 32 && byte <= 126) ||  // 可打印ASCII字符
           byte == 9 || byte == 10 || byte == 13  // 制表符、换行符、回车符
       ).toList();
       
       if (validChars.isNotEmpty) {
         try {
           String message = String.fromCharCodes(validChars);
           message = message.trim();
           if (message.isNotEmpty) {
             return message;
           }
         } catch (e) {
           print('协议解析中的字符转换失败: $e');
         }
       }
     }
     
     // 检查是否是多个连续的协议数据包
     if (data.length > 3) {
       // 尝试查找ASCII字符序列
       List<int> asciiSequence = [];
       for (int i = 0; i < data.length; i++) {
         int byte = data[i];
         if (byte >= 32 && byte <= 126) {
           asciiSequence.add(byte);
         } else if (byte == 10 || byte == 13) {
           // 遇到换行符，处理当前序列
           if (asciiSequence.isNotEmpty) {
             try {
               String message = String.fromCharCodes(asciiSequence).trim();
               if (message.isNotEmpty) {
                 return message;
               }
             } catch (e) {
               // 继续处理
             }
             asciiSequence.clear();
           }
         }
       }
       
       // 处理最后的序列
       if (asciiSequence.isNotEmpty) {
         try {
           String message = String.fromCharCodes(asciiSequence).trim();
           if (message.isNotEmpty) {
             return message;
           }
         } catch (e) {
           // 继续处理
         }
       }
     }
     
           return '';
    }
    
    // 清理字符串中的替换字符
    String _cleanReplacementCharacters(String message) {
      if (!message.contains('�')) return message;
      
      // 移除开头和结尾的替换字符
      String cleaned = message;
      
      // 移除开头的替换字符和紧跟的标点符号
      cleaned = cleaned.replaceAll(RegExp(r'^�+[:：\s]*'), '');
      
      // 移除结尾的替换字符
      cleaned = cleaned.replaceAll(RegExp(r'�+$'), '');
      
      // 移除单独的替换字符（前后都是空格或标点）
      cleaned = cleaned.replaceAll(RegExp(r'\s*�+\s*'), ' ');
      
      // 清理多余的空格
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      
             return cleaned;
     }
     
     // 记录发送的消息
     void _recordSentMessage(String message) {
       String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
       _recentSentMessages.add('$timestamp:$message');
       
       // 保持列表大小
       while (_recentSentMessages.length > _maxRecentMessages) {
         _recentSentMessages.removeAt(0);
       }
       
       print('记录发送消息: $message');
     }
     
     // 检查是否为回环消息
     bool _isEchoMessage(String receivedMessage) {
       if (_recentSentMessages.isEmpty) return false;
       
       int currentTime = DateTime.now().millisecondsSinceEpoch;
       String cleanReceived = receivedMessage.trim();
       
       // 检查最近发送的消息
       for (String entry in _recentSentMessages.reversed) {
         List<String> parts = entry.split(':');
         if (parts.length >= 2) {
           int sentTime = int.tryParse(parts[0]) ?? 0;
           String sentMessage = parts.sublist(1).join(':').trim();
           
           // 在时间窗口内且内容匹配
           if (currentTime - sentTime < _echoTimeoutMs && 
               (cleanReceived == sentMessage || 
                cleanReceived.startsWith(sentMessage) ||
                sentMessage.startsWith(cleanReceived))) {
             print('检测到回环消息: "$cleanReceived" 匹配发送的 "$sentMessage"');
             return true;
           }
         }
       }
       
       return false;
     }
 
    // 多种UART服务UUID（支持更多设备）
  static const List<String> _uartServiceUuids = [
    "6e400001-b5a3-f393-e0a9-e50e24dcca9e", // Nordic UART Service
    "0000ffe0-0000-1000-8000-00805f9b34fb", // HM-10/HC-05等常用服务
    "49535343-fe7d-4ae5-8fa9-9fafd205e455", // Microchip RN4020
  ];
  
  static const List<String> _uartTxCharacteristicUuids = [
    "6e400002-b5a3-f393-e0a9-e50e24dcca9e", // Nordic TX
    "0000ffe1-0000-1000-8000-00805f9b34fb", // HM-10 TX
    "49535343-1e4d-4bd9-ba61-23c647249616", // Microchip TX
  ];
  
  static const List<String> _uartRxCharacteristicUuids = [
    "6e400003-b5a3-f393-e0a9-e50e24dcca9e", // Nordic RX
    "0000ffe1-0000-1000-8000-00805f9b34fb", // HM-10 RX (同一个特征)
    "49535343-8841-43f4-a8d4-ecbe34729bb3", // Microchip RX
  ];

  // 开始设备发现 - 扫描BLE设备
  Future<List<UnifiedBluetoothDevice>> startDiscovery() async {
    try {
      List<UnifiedBluetoothDevice> allDevices = [];
      
      // 检查flutter_blue_plus是否支持并启用
      if (await fbp.FlutterBluePlus.isSupported) {
        try {
          // 启动BLE扫描
          await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
          
          // 等待扫描完成
          await fbp.FlutterBluePlus.isScanning.where((scanning) => scanning == false).first;
          
          // 获取扫描结果
          List<fbp.ScanResult> scanResults = fbp.FlutterBluePlus.lastScanResults;
          
          for (fbp.ScanResult result in scanResults) {
            UnifiedBluetoothDevice device = UnifiedBluetoothDevice.fromBle(result.device);
            allDevices.add(device);
          }
          
          // 也获取已连接的设备
          List<fbp.BluetoothDevice> connectedDevices = fbp.FlutterBluePlus.connectedDevices;
          for (fbp.BluetoothDevice device in connectedDevices) {
            UnifiedBluetoothDevice unifiedDevice = UnifiedBluetoothDevice.fromBle(device);
            if (!allDevices.any((d) => d.address == unifiedDevice.address)) {
              allDevices.add(unifiedDevice);
            }
          }
        } catch (e) {
          print('BLE扫描失败: $e');
        }
      }
      
      return allDevices;
    } catch (e) {
      print('设备发现失败: $e');
      return [];
    }
  }

  // 连接到BLE设备
  Future<bool> connectToDevice(UnifiedBluetoothDevice device) async {
    try {
      // 在连接前，确保扫描已停止，并给予短暂延迟
      if (fbp.FlutterBluePlus.isScanningNow) {
        await fbp.FlutterBluePlus.stopScan();
        await Future.delayed(const Duration(milliseconds: 200));
        print('扫描已停止，准备连接...');
      }

      if (device.device == null) {
        print('设备对象为空');
        return false;
      }

      // 断开之前的连接
      if (_connectedDevice != null) {
        await disconnect();
      }

      _connectedDevice = device.device!;
      print('开始连接设备: ${device.name ?? device.address}');
      
      // 监听连接状态
      _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
        bool connected = state == fbp.BluetoothConnectionState.connected;
        print('连接状态变化: $connected');
        _isConnected = connected;
        _connectionStateController.add(connected);
        
        if (!connected) {
          print('检测到蓝牙断开，执行清理...');
          _cleanup();
          _connectedDevice = null;
          connectedDevice = null;
        }
      });
      
      // 连接设备
      await _connectedDevice!.connect();
      print('设备连接成功，开始发现服务...');
      
      // 发现服务
      List<fbp.BluetoothService> services = await _connectedDevice!.discoverServices();
      print('发现 ${services.length} 个服务');
      
      // 打印所有服务和特征用于调试
      for (fbp.BluetoothService service in services) {
        print('服务: ${service.uuid}');
        for (fbp.BluetoothCharacteristic char in service.characteristics) {
          print('  特征: ${char.uuid}, 属性: read=${char.properties.read}, write=${char.properties.write}, writeWithoutResponse=${char.properties.writeWithoutResponse}, notify=${char.properties.notify}, indicate=${char.properties.indicate}');
        }
      }
      
      // 查找UART服务和特征
      fbp.BluetoothService? uartService;
      
      // 首先尝试查找已知的UART服务
      for (String serviceUuid in _uartServiceUuids) {
        for (fbp.BluetoothService service in services) {
          if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
            uartService = service;
            print('找到UART服务: ${service.uuid}');
            break;
          }
        }
        if (uartService != null) break;
      }
      
      // 如果没找到已知服务，尝试查找具有读写特征的服务
      if (uartService == null) {
        for (fbp.BluetoothService service in services) {
          bool hasWritable = false;
          bool hasNotifiable = false;
          
          for (fbp.BluetoothCharacteristic char in service.characteristics) {
            if (char.properties.write || char.properties.writeWithoutResponse) {
              hasWritable = true;
            }
            if (char.properties.notify || char.properties.indicate) {
              hasNotifiable = true;
            }
          }
          
          if (hasWritable && hasNotifiable) {
            uartService = service;
            print('找到通用UART服务: ${service.uuid}');
            break;
          }
        }
      }
      
      if (uartService == null) {
        print('未找到任何可用的UART服务');
        await disconnect();
        return false;
      }
      
      // 查找写入和通知特征
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      
      // 优先查找已知的特征UUID
      for (fbp.BluetoothCharacteristic characteristic in uartService.characteristics) {
        String charUuid = characteristic.uuid.toString().toLowerCase();
        
        // 查找写入特征
        if (_uartTxCharacteristicUuids.contains(charUuid) && 
            (characteristic.properties.write || characteristic.properties.writeWithoutResponse)) {
          _writeCharacteristic = characteristic;
          print('找到写入特征: $charUuid');
        }
        
        // 查找通知特征
        if (_uartRxCharacteristicUuids.contains(charUuid) && 
            (characteristic.properties.notify || characteristic.properties.indicate)) {
          _notifyCharacteristic = characteristic;
          print('找到通知特征: $charUuid');
        }
      }
      
      // 如果没找到已知特征，使用第一个可用的
      if (_writeCharacteristic == null || _notifyCharacteristic == null) {
        for (fbp.BluetoothCharacteristic characteristic in uartService.characteristics) {
          if (_writeCharacteristic == null && 
              (characteristic.properties.write || characteristic.properties.writeWithoutResponse)) {
            _writeCharacteristic = characteristic;
            print('使用写入特征: ${characteristic.uuid}');
          }
          
          if (_notifyCharacteristic == null && 
              (characteristic.properties.notify || characteristic.properties.indicate)) {
            _notifyCharacteristic = characteristic;
            print('使用通知特征: ${characteristic.uuid}');
          }
        }
      }
      
      if (_writeCharacteristic == null) {
        print('未找到写入特征');
        await disconnect();
        return false;
      }
      
      // 设置通知
      if (_notifyCharacteristic != null) {
        print('启用通知...');
        await _notifyCharacteristic!.setNotifyValue(true);
        
        // 监听数据
        _dataStreamSubscription = _notifyCharacteristic!.lastValueStream.listen(
          (List<int> data) {
            if (data.isNotEmpty) {
              String message = _processReceivedData(data);
              
              // 检查是否为回环消息（如果启用了过滤）
              if (_enableEchoFilter && _isEchoMessage(message)) {
                print('过滤回环消息: "$message"');
                return; // 不发送到界面
              }
              
              _messageStreamController.add(message);
            }
          },
          onError: (error) {
            print('蓝牙数据接收错误: $error');
          },
        );
        print('通知设置完成');
      } else {
        print('警告: 未找到通知特征，无法接收数据');
      }
      
      connectedDevice = device;
      _isConnected = true;
      _connectionStateController.add(true);
      
      print('BLE连接完全成功');
      return true;
      
    } catch (e) {
      print('BLE连接失败: $e');
      await disconnect();
      return false;
    }
  }

  // 发送数据
  Future<bool> sendMessage(String message) async {
    if (!_isConnected || _writeCharacteristic == null) {
      print('设备未连接或写入特征不可用');
      return false;
    }

    try {
      // 为消息添加换行符（BT04等模块通常需要）
      String messageWithNewline = message.endsWith('\n') ? message : '$message\n';
      List<int> data = utf8.encode(messageWithNewline);
      
      print('发送数据: $messageWithNewline (长度: ${data.length})');
      
      // 如果数据太长，需要分包发送
      const int maxLength = 20; // BLE默认MTU为23，减去3字节头部
      
      for (int i = 0; i < data.length; i += maxLength) {
        int end = (i + maxLength < data.length) ? i + maxLength : data.length;
        List<int> chunk = data.sublist(i, end);
        
        if (_writeCharacteristic!.properties.writeWithoutResponse) {
          await _writeCharacteristic!.write(chunk, withoutResponse: true);
          print('发送数据包 (无响应): ${utf8.decode(chunk)}');
        } else {
          await _writeCharacteristic!.write(chunk);
          print('发送数据包 (有响应): ${utf8.decode(chunk)}');
        }
        
        // 小延迟以确保数据传输稳定
        if (end < data.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      // 记录发送的消息用于回环检测
      _recordSentMessage(message.trim());
      
      print('数据发送完成');
      return true;
    } catch (e) {
      print('发送消息失败: $e');
      return false;
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    try {
      print('开始断开连接...');
      _cleanup();
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        print('设备断开连接完成');
      }
      
    } catch (e) {
      print('断开连接失败: $e');
    } finally {
      _connectedDevice = null;
      connectedDevice = null;
      _isConnected = false;
      _connectionStateController.add(false);
    }
  }

  void _cleanup() {
    print('清理连接资源...');
    _dataStreamSubscription?.cancel();
    _connectionSubscription?.cancel();
    _dataStreamSubscription = null;
    _connectionSubscription = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
  }

  // 检查蓝牙是否启用
  Future<bool> isBluetoothEnabled() async {
    try {
      if (await fbp.FlutterBluePlus.isSupported) {
        fbp.BluetoothAdapterState state = await fbp.FlutterBluePlus.adapterState.first;
        return state == fbp.BluetoothAdapterState.on;
      }
      return false;
    } catch (e) {
      print('检查蓝牙状态失败: $e');
      return false;
    }
  }

  // 请求启用蓝牙
  Future<bool> enableBluetooth() async {
    try {
      if (await fbp.FlutterBluePlus.isSupported) {
        await fbp.FlutterBluePlus.turnOn();
        // 等待蓝牙启用
        fbp.BluetoothAdapterState state = await fbp.FlutterBluePlus.adapterState
            .where((state) => state == fbp.BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 10))
            .first;
        return state == fbp.BluetoothAdapterState.on;
      }
      return false;
    } catch (e) {
      print('启用蓝牙失败: $e');
      return false;
    }
  }

  void dispose() {
    disconnect();
    _messageStreamController.close();
    _connectionStateController.close();
  }
} 