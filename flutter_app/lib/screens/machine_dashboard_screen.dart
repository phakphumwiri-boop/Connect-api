import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import 'chat_screen.dart';

const _configuredApiBase = String.fromEnvironment('API_BASE_URL');

String get _defaultApiBase {
  if (_configuredApiBase.isNotEmpty) return _configuredApiBase;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

class MachineDashboardScreen extends StatefulWidget {
  const MachineDashboardScreen({super.key});

  @override
  State<MachineDashboardScreen> createState() => _MachineDashboardScreenState();
}

class _MachineDashboardScreenState extends State<MachineDashboardScreen> {
  final _apiController = TextEditingController(text: _defaultApiBase);
  final _tokenController = TextEditingController();
  List<Map<String, dynamic>> _machines = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _apiController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Admin-Token': _tokenController.text.trim(),
      };

  Uri _uri(String path) {
    final base = _apiController.text.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Future<void> _request(Future<void> Function() action) async {
    if (_tokenController.text.trim().isEmpty) {
      setState(() => _error = 'กรุณากรอก Admin token ก่อนเชื่อมต่อ');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMachines() => _request(() async {
        final response = await http.get(_uri('/machines'), headers: _headers);
        if (response.statusCode != 200) {
          throw Exception('โหลดรายการเครื่องไม่สำเร็จ: ${response.statusCode} ${response.body}');
        }
        final data = jsonDecode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() => _machines =
              data.map((item) => Map<String, dynamic>.from(item as Map)).toList());
        }
      });

  Future<void> _createMachine() async {
    final name = TextEditingController();
    final cpu = TextEditingController(text: '2');
    final memory = TextEditingController(text: '4096');
    final disk = TextEditingController(text: '10');
    String mode = 'web';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('สร้างเครื่องใหม่'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'ชื่อเครื่อง')),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Runtime'),
                  items: const [
                    DropdownMenuItem(value: 'web', child: Text('Web Workspace')),
                    DropdownMenuItem(value: 'android', child: Text('Android Emulator (Linux KVM)')),
                    DropdownMenuItem(value: 'desktop', child: Text('Linux Desktop')),
                  ],
                  onChanged: (value) => setDialogState(() => mode = value ?? 'web'),
                ),
                TextField(controller: cpu, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'CPU cores (1–8)')),
                TextField(controller: memory, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'RAM MB (1024–16384)')),
                TextField(controller: disk, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Disk GB (requested only)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('สร้าง')),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    await _request(() async {
      final response = await http.post(
        _uri('/machines'),
        headers: _headers,
        body: jsonEncode({
          'name': name.text.trim(),
          'mode': mode,
          'cpu_cores': int.tryParse(cpu.text) ?? 2,
          'memory_mb': int.tryParse(memory.text) ?? 4096,
          'disk_gb': int.tryParse(disk.text) ?? 10,
        }),
      );
      if (response.statusCode != 201) {
        throw Exception('สร้างเครื่องไม่สำเร็จ: ${response.statusCode} ${response.body}');
      }
      await _refreshWithoutBusy();
    });
  }

  Future<void> _refreshWithoutBusy() async {
    final response = await http.get(_uri('/machines'), headers: _headers);
    if (response.statusCode != 200) throw Exception(response.body);
    final data = jsonDecode(response.body) as List<dynamic>;
    if (mounted) {
      setState(() => _machines =
          data.map((item) => Map<String, dynamic>.from(item as Map)).toList());
    }
  }

  Future<void> _control(String id, String action) => _request(() async {
        final response = await http.post(
          _uri('/machines/$id/$action'),
          headers: _headers,
        );
        if (response.statusCode != 200) {
          throw Exception('$action ไม่สำเร็จ: ${response.statusCode} ${response.body}');
        }
        await _refreshWithoutBusy();
      });

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบเครื่องนี้?'),
        content: const Text('การลบจะหยุดและลบ container ที่จัดการโดย API'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _request(() async {
      final response = await http.delete(_uri('/machines/$id'), headers: _headers);
      if (response.statusCode != 204) {
        throw Exception('ลบไม่สำเร็จ: ${response.statusCode} ${response.body}');
      }
      await _refreshWithoutBusy();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Machine Lab'),
        actions: [
          IconButton(
            tooltip: 'ISH Assistant',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เชื่อมต่อ Python API', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _apiController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          hintText: 'http://192.168.1.10:8000',
                        ),
                      ),
                      TextField(
                        controller: _tokenController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Admin token',
                          helperText: 'เก็บไว้ในหน่วยความจำของแอปเท่านั้น ไม่บันทึกลงไฟล์',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _loading ? null : _loadMachines,
                            icon: const Icon(Icons.link),
                            label: const Text('เชื่อมต่อ / โหลดเครื่อง'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _createMachine,
                            icon: const Icon(Icons.add),
                            label: const Text('สร้างเครื่อง'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('เครื่องที่จัดการได้', style: Theme.of(context).textTheme.titleLarge)),
                  Text('${_machines.length} เครื่อง'),
                ],
              ),
              if (_machines.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('ยังไม่มีรายการเครื่อง หรือยังไม่ได้เชื่อมต่อ API')),
                  ),
                ),
              for (final machine in _machines) _machineCard(machine),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'หมายเหตุ: Disk quota ยังไม่ถูกบังคับใช้จริง และ Android container ต้องใช้ Linux host ที่มี /dev/kvm; หน้านี้ยังไม่ใช่ Live Screen Viewer',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _machineCard(Map<String, dynamic> machine) {
    final id = machine['id']?.toString() ?? '';
    final status = machine['status']?.toString() ?? 'unknown';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(machine['name']?.toString() ?? 'Unnamed',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(label: Text(status)),
              ],
            ),
            Text('Runtime: ${machine['mode']}  •  CPU: ${machine['cpu_cores']} cores  •  RAM: ${machine['memory_mb']} MB'),
            Text('Disk: ${machine['disk_gb_requested']} GB requested • Enforced: ${machine['disk_quota_enforced']}'),
            if (machine['preview_url'] != null) SelectableText('Preview: ${machine['preview_url']}'),
            if (machine['note'] != null) Text(machine['note'].toString()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final action in ['start', 'stop', 'restart'])
                  OutlinedButton(
                    onPressed: _loading ? null : () => _control(id, action),
                    child: Text(action),
                  ),
                TextButton.icon(
                  onPressed: _loading ? null : () => _delete(id),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ลบ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
