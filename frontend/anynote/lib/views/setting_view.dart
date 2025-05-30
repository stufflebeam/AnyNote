import 'package:anynote/GlobalConfig.dart';
import 'package:anynote/views/login.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../MainController.dart';
import 'HeatMap.dart';

class SettingView extends StatefulWidget {
  const SettingView({super.key});

  @override
  _SettingViewState createState() => _SettingViewState();
}

class _SettingViewState extends State<SettingView> {
  late int fontSize;
  late TextEditingController _aiApiKeyController;
  late TextEditingController _aiUrlController;
  late TextEditingController _aiModelController;

  @override
  void initState() {
    super.initState();
    fontSize = GlobalConfig.fontSize;
    _aiApiKeyController = TextEditingController(text: GlobalConfig.aiApiKey);
    _aiUrlController = TextEditingController(text: GlobalConfig.aiUrl);
    _aiModelController = TextEditingController(text: GlobalConfig.aiModel);
  }

  @override
  void dispose() {
    _aiApiKeyController.dispose();
    _aiUrlController.dispose();
    _aiModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Setup 🛠️'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Font size',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Slider(
                value: fontSize.toDouble(),
                min: 6,
                max: 24,
                divisions: 15,
                label: fontSize.toString(),
                activeColor: Colors.blue,
                inactiveColor: Colors.blue.withOpacity(0.3),
                onChanged: (double value) {
                  setState(() {
                    fontSize = value.round();
                    GlobalConfig.fontSize = fontSize;
                    Get.find<MainController>().fontSize.value = fontSize;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                height: 70,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Preview text 示例文本 📄',
                    style: TextStyle(fontSize: fontSize.toDouble()),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text('AI Setup',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildTextField(_aiUrlController, 'AI URL'),
              const SizedBox(height: 16),
              _buildTextField(_aiApiKeyController, 'AI API Key',
                  ispassword: true),
              const SizedBox(height: 16),
              _buildTextField(_aiModelController, 'AI Model'),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  GlobalConfig.clear();
                  var c = Get.find<MainController>();
                  c.logout();
                  Get.offAll(() => LoginPage());
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Log out', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool ispassword = false}) {
    return TextField(
      obscureText: ispassword,
      controller: controller,
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        switch (label) {
          case 'AI API Key':
            GlobalConfig.aiApiKey = value;
            break;
          case 'AI URL':
            GlobalConfig.aiUrl = value;
            break;
          case 'AI Model':
            GlobalConfig.aiModel = value;
            break;
        }
      },
    );
  }
}
