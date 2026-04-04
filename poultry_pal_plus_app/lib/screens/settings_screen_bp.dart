import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/models/settings_data_bp.dart';
import 'package:poultry_pal_plus_app/screens/common.dart';

import '../service/poultry_pal_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _poultryPalService = PoultryPalService();
  final SettingsData _settingsData = SettingsData();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loadedSettings = await _poultryPalService.loadSettings("","");
    setState(() {
      //_settingsData = loadedSettings;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      //await _poultryPalService.saveSettings(_settingsData);
      _showSuccessSnackBar('Settings saved successfully!');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      Common.buildSnackBar(message, Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Please note that some value you "
                "enter will be used to predict potential "
                "profit and provide guidance on selling "
                "your products. Please ensure the accuracy "
                "of the data, as it will directly "
                "impact the calculations.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Common.buildTextField(
                label: 'Price per Chicken',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                initialValue: _settingsData.pricePerChicken?.toString(),
                onChanged: (value) =>
                    _settingsData.pricePerChicken = double.tryParse(value),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a price' : null,
                context: context,
              ),
              const SizedBox(height: 16),
              Common.buildTextField(
                label: 'Chicken Stock Price',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                initialValue: _settingsData.stockPrice?.toString(),
                onChanged: (value) =>
                    _settingsData.stockPrice = double.tryParse(value),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a price' : null,
                context: context,
              ),
              const SizedBox(height: 16),
              Common.buildTextField(
                label: 'Price per Batch of 5 Chickens',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                initialValue: _settingsData.pricePerBatch5?.toString(),
                onChanged: (value) =>
                    _settingsData.pricePerBatch5 = double.tryParse(value),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a price' : null,
                context: context,
              ),
              const SizedBox(height: 16),
              Common.buildTextField(
                label: 'How many eggs per chicken per day?',
                icon: Icons.egg,
                keyboardType: TextInputType.number,
                initialValue: _settingsData.eggsPerChicken?.toString(),
                onChanged: (value) =>
                    _settingsData.eggsPerChicken = int.tryParse(value),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a number' : null,
                context: context,
              ),
              const SizedBox(height: 16),
              Common.buildTextField(
                label: 'How many eggs are in a dozen?',
                icon: Icons.egg,
                keyboardType: TextInputType.number,
                initialValue: _settingsData.eggsPerDozen?.toString(),
                onChanged: (value) =>
                    _settingsData.eggsPerDozen = int.tryParse(value),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a number' : null,
                context: context,
              ),
              const SizedBox(height: 16),
              Common.buildTextField(
                label: 'Price per Dozen',
                icon: Icons.shopping_bag,
                keyboardType: TextInputType.number,
                initialValue: _settingsData.pricePerDozen?.toString(),
                onChanged: (value) =>
                    _settingsData.pricePerDozen = double.tryParse(value),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a price' : null,
                context: context,
              ),
              const SizedBox(height: 16),
              Common.buildTextField(
                label: 'Price per Batch Dozen',
                icon: Icons.shopping_basket,
                keyboardType: TextInputType.number,
                initialValue: _settingsData.pricePerBatchDozen?.toString(),
                onChanged: (value) =>
                    _settingsData.pricePerBatchDozen = double.tryParse(value),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a price' : null,
                context: context,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Save Settings',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
