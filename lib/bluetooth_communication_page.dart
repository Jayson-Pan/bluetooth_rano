import 'package:flutter/material.dart';
import 'bluetooth_service.dart';
import 'dart:async';

class BluetoothCommunicationPage extends StatefulWidget {
  const BluetoothCommunicationPage({Key? key}) : super(key: key);

  @override
  State<BluetoothCommunicationPage> createState() => _BluetoothCommunicationPageState();
}

class _BluetoothCommunicationPageState extends State<BluetoothCommunicationPage> {
  final BluetoothService _bluetoothService = BluetoothService();
  final TextEditingController _sendController = TextEditingController(text: 'on');
  final TextEditingController _receiveController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  
  bool _isConnected = false;
  List<String> _receivedMessages = [];
  ReceiveMode _currentReceiveMode = ReceiveMode.ascii;
  bool _enableEchoFilter = true;

  @override
  void initState() {
    super.initState();
    _listenToMessages();
    _listenToConnectionState();
    _updateConnectionState();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _sendController.dispose();
    _receiveController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToMessages() {
    _messageSubscription = _bluetoothService.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          String timestamp = DateTime.now().toString().substring(11, 19);
          String formattedMessage = '[$timestamp] 接收: $message';
          _receivedMessages.add(formattedMessage);
          _updateReceiveTextBox();
        });
        _scrollToBottom();
      }
    });
  }

  void _listenToConnectionState() {
    _connectionSubscription = _bluetoothService.connectionStateStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          if (!connected) {
            _receivedMessages.clear();
            _updateReceiveTextBox();
          }
        });
      }
    });
  }

  void _updateConnectionState() {
    setState(() {
      _isConnected = _bluetoothService.isConnected;
    });
  }

  void _updateReceiveTextBox() {
    _receiveController.text = _receivedMessages.join('\n');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (!_isConnected) {
      _showSnackBar('未连接到BLE设备');
      return;
    }

    String message = _sendController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('请输入要发送的消息');
      return;
    }

    bool sent = await _bluetoothService.sendMessage(message);
    if (sent) {
      _showSnackBar('消息发送成功: $message');
    } else {
      _showSnackBar('消息发送失败');
    }
  }

  void _refreshMessages() {
    setState(() {
      _updateReceiveTextBox();
    });
    _showSnackBar('消息已刷新');
  }

  void _clearMessages() {
    setState(() {
      _receivedMessages.clear();
      _receiveController.clear();
    });
    _showSnackBar('消息已清空');
  }

  void _toggleReceiveMode() {
    setState(() {
      _currentReceiveMode = _currentReceiveMode == ReceiveMode.ascii 
          ? ReceiveMode.hex 
          : ReceiveMode.ascii;
    });
    _bluetoothService.setReceiveMode(_currentReceiveMode);
    
    String modeName = _currentReceiveMode == ReceiveMode.ascii ? 'ASCII字符串' : '十六进制';
    _showSnackBar('接收模式已切换为: $modeName');
  }

  void _toggleEchoFilter() {
    setState(() {
      _enableEchoFilter = !_enableEchoFilter;
    });
    _bluetoothService.setEchoFilter(_enableEchoFilter);
    
    String status = _enableEchoFilter ? '已启用' : '已禁用';
    _showSnackBar('回环过滤$status');
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE蓝牙通信'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 连接状态显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.grey,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: _isConnected ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isConnected 
                          ? 'BLE已连接: ${_bluetoothService.connectedDevice?.name ?? '未知设备'}'
                          : 'BLE未连接到设备',
                      style: TextStyle(
                        color: _isConnected ? Colors.green.shade800 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 接收消息区域
            const Text(
              '接收的消息:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // 消息操作按钮
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Column(
                        children: [
                          // 第一行：消息数量和操作按钮
                          Row(
                            children: [
                              Text(
                                '消息数量: ${_receivedMessages.length}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _refreshMessages,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('刷新', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: _clearMessages,
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('清空', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // 第二行：模式切换按钮
                          Row(
                            children: [
                              // 接收模式切换按钮
                              Expanded(
                                child: InkWell(
                                  onTap: _toggleReceiveMode,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _currentReceiveMode == ReceiveMode.ascii 
                                          ? Colors.blue.shade100 
                                          : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _currentReceiveMode == ReceiveMode.ascii 
                                            ? Colors.blue.shade300 
                                            : Colors.orange.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _currentReceiveMode == ReceiveMode.ascii 
                                              ? Icons.text_fields 
                                              : Icons.memory,
                                          size: 14,
                                          color: _currentReceiveMode == ReceiveMode.ascii 
                                              ? Colors.blue.shade700 
                                              : Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _currentReceiveMode == ReceiveMode.ascii ? 'ASCII字符' : 'HEX十六进制',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: _currentReceiveMode == ReceiveMode.ascii 
                                                ? Colors.blue.shade700 
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 回环过滤开关
                              Expanded(
                                child: InkWell(
                                  onTap: _toggleEchoFilter,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _enableEchoFilter 
                                          ? Colors.green.shade100 
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _enableEchoFilter 
                                            ? Colors.green.shade300 
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _enableEchoFilter 
                                              ? Icons.filter_alt 
                                              : Icons.filter_alt_off,
                                          size: 14,
                                          color: _enableEchoFilter 
                                              ? Colors.green.shade700 
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _enableEchoFilter ? '回环过滤开' : '回环过滤关',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: _enableEchoFilter 
                                                ? Colors.green.shade700 
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // 消息显示区域
                    Expanded(
                      child: TextField(
                        controller: _receiveController,
                        maxLines: null,
                        expands: true,
                        readOnly: true,
                        scrollController: _scrollController,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: _isConnected 
                              ? '等待接收BLE消息...' 
                              : '请先连接BLE设备',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // 发送消息区域
            const Text(
              '发送消息:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sendController,
                    enabled: _isConnected,
                    decoration: InputDecoration(
                      hintText: _isConnected ? '输入要发送的消息' : '请先连接BLE设备',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: _isConnected ? null : Colors.grey.shade100,
                    ),
                    onSubmitted: _isConnected ? (_) => _sendMessage() : null,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isConnected ? _sendMessage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  child: const Text('发送'),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 快捷发送按钮
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '快捷命令:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickSendButton('on'),
                    _buildQuickSendButton('off'),
                    _buildQuickSendButton('status'),
                    _buildQuickSendButton('reset'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSendButton(String command) {
    return ElevatedButton(
      onPressed: _isConnected ? () async {
        _sendController.text = command;
        await _sendMessage();
      } : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade400,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: Text(command, style: const TextStyle(fontSize: 12)),
    );
  }
} 