import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/models/settings_data.dart';
import 'package:poultry_pal_plus_app/screens/common.dart';

import '../models/farm.dart';
import '../models/user.dart';
import '../service/poultry_pal_service.dart';

class SettingsScreen extends StatefulWidget {
  final Farm farm;
  final User user;

  const SettingsScreen(
      {super.key, required this.farm, required this.user});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _poultryPalService = PoultryPalService();
  SettingsData _settingsData = SettingsData();
  final List<Map<String, String>> _currencies = [
    {'code': 'AED', 'symbol': 'د.إ'}, {'code': 'AFN', 'symbol': '؋'}, {'code': 'ALL', 'symbol': 'L'},
    {'code': 'AMD', 'symbol': '֏'}, {'code': 'ANG', 'symbol': 'ƒ'}, {'code': 'AOA', 'symbol': 'Kz'},
    {'code': 'ARS', 'symbol': '\$'}, {'code': 'AUD', 'symbol': 'A\$'}, {'code': 'AWG', 'symbol': 'ƒ'},
    {'code': 'AZN', 'symbol': '₼'}, {'code': 'BAM', 'symbol': 'KM'}, {'code': 'BBD', 'symbol': 'Bds\$'},
    {'code': 'BDT', 'symbol': '৳'}, {'code': 'BGN', 'symbol': 'лв'}, {'code': 'BHD', 'symbol': '.د.ب'},
    {'code': 'BIF', 'symbol': 'FBu'}, {'code': 'BMD', 'symbol': '\$'}, {'code': 'BND', 'symbol': 'B\$'},
    {'code': 'BOB', 'symbol': 'Bs.'}, {'code': 'BRL', 'symbol': 'R\$'}, {'code': 'BSD', 'symbol': 'B\$'},
    {'code': 'BTN', 'symbol': 'Nu.'}, {'code': 'BWP', 'symbol': 'P'}, {'code': 'BYN', 'symbol': 'Br'},
    {'code': 'BZD', 'symbol': 'BZ\$'}, {'code': 'CAD', 'symbol': 'C\$'}, {'code': 'CDF', 'symbol': 'FC'},
    {'code': 'CHF', 'symbol': 'CHF'}, {'code': 'CLP', 'symbol': '\$'}, {'code': 'CNY', 'symbol': '¥'},
    {'code': 'COP', 'symbol': '\$'}, {'code': 'CRC', 'symbol': '₡'}, {'code': 'CUC', 'symbol': '\$'},
    {'code': 'CUP', 'symbol': '\$'}, {'code': 'CVE', 'symbol': 'Esc'}, {'code': 'CZK', 'symbol': 'Kč'},
    {'code': 'DJF', 'symbol': 'Fdj'}, {'code': 'DKK', 'symbol': 'kr'}, {'code': 'DOP', 'symbol': 'RD\$'},
    {'code': 'DZD', 'symbol': 'د.ج'}, {'code': 'EGP', 'symbol': 'E£'}, {'code': 'ERN', 'symbol': 'Nfk'},
    {'code': 'ETB', 'symbol': 'Br'}, {'code': 'EUR', 'symbol': '€'}, {'code': 'FJD', 'symbol': 'FJ\$'},
    {'code': 'FKP', 'symbol': '£'}, {'code': 'FOK', 'symbol': 'kr'}, {'code': 'GBP', 'symbol': '£'},
    {'code': 'GEL', 'symbol': '₾'}, {'code': 'GGP', 'symbol': '£'}, {'code': 'GHS', 'symbol': '₵'},
    {'code': 'GIP', 'symbol': '£'}, {'code': 'GMD', 'symbol': 'D'}, {'code': 'GNF', 'symbol': 'FG'},
    {'code': 'GTQ', 'symbol': 'Q'}, {'code': 'GYD', 'symbol': 'G\$'}, {'code': 'HKD', 'symbol': 'HK\$'},
    {'code': 'HNL', 'symbol': 'L'}, {'code': 'HRK', 'symbol': 'kn'}, {'code': 'HTG', 'symbol': 'G'},
    {'code': 'HUF', 'symbol': 'Ft'}, {'code': 'IDR', 'symbol': 'Rp'}, {'code': 'ILS', 'symbol': '₪'},
    {'code': 'IMP', 'symbol': '£'}, {'code': 'INR', 'symbol': '₹'}, {'code': 'IQD', 'symbol': 'ع.د'},
    {'code': 'IRR', 'symbol': '﷼'}, {'code': 'ISK', 'symbol': 'kr'}, {'code': 'JMD', 'symbol': 'J\$'},
    {'code': 'JOD', 'symbol': 'د.ا'}, {'code': 'JPY', 'symbol': '¥'}, {'code': 'KES', 'symbol': 'KSh'},
    {'code': 'KGS', 'symbol': 'с'}, {'code': 'KHR', 'symbol': '៛'}, {'code': 'KID', 'symbol': '\$'},
    {'code': 'KMF', 'symbol': 'CF'}, {'code': 'KRW', 'symbol': '₩'}, {'code': 'KWD', 'symbol': 'د.ك'},
    {'code': 'KYD', 'symbol': 'KY\$'}, {'code': 'KZT', 'symbol': '₸'}, {'code': 'LAK', 'symbol': '₭'},
    {'code': 'LBP', 'symbol': 'ل.ل'}, {'code': 'LKR', 'symbol': 'Rs'}, {'code': 'LRD', 'symbol': 'L\$'},
    {'code': 'LSL', 'symbol': 'L'}, {'code': 'LYD', 'symbol': 'ل.د'}, {'code': 'MAD', 'symbol': 'د.م.'},
    {'code': 'USD', 'symbol': '\$'},
    {'code': 'ZAR', 'symbol': 'R'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loadedSettings = await _poultryPalService.loadSettings(widget.farm.id, widget.user.id);
    setState(() {
      _settingsData = loadedSettings;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();


      final response = await _poultryPalService.saveSettings(_settingsData);

      response.success
          ? _showSuccessSnackBar('Settings saved successfully!')
          : _showErrorSnackBar(response.message);

    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      Common.buildSnackBar(message, Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      Common.buildSnackBar(message, Colors.red),
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

              SwitchListTile(
                title: const Text('Automatically Create Reminders'),
                subtitle: Text(
                  'Enable to automatically create reminders for tasks',
                  style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                ),
                value: _settingsData.autoCreateReminders ?? false,
                onChanged: (value) =>
                    setState(() => _settingsData.autoCreateReminders = value),
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[300],
              ),

              const SizedBox(height: 5),
              SwitchListTile(
                title: const Text('Receive Daily Reminders'),
                subtitle: Text(
                  'Enable daily reminders for medications, vaccinations and feeding schedules',
                  style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                ),
                value: _settingsData.dailyReminders ?? false,
                onChanged: (value) =>
                    setState(() => _settingsData.dailyReminders = value),
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[300],
              ),

              const SizedBox(height: 5),
              SwitchListTile(
                title: const Text('Sales Alerts'),
                subtitle: Text(
                  'Enable to receive alerts when a sale is recorded.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                ),
                value: _settingsData.salesAlerts ?? false,
                onChanged: (value) =>
                    setState(() => _settingsData.salesAlerts = value),
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[300],
              ),

              const SizedBox(height: 5),
              SwitchListTile(
                title: const Text('Mortality Alerts'),
                subtitle: Text(
                  'Enable to receive alerts when a mortality is recorded.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                ),
                value: _settingsData.mortalityAlerts ?? false,
                onChanged: (value) =>
                    setState(() => _settingsData.mortalityAlerts = value),
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[300],
              ),
              const SizedBox(height: 5),
              SwitchListTile(
                title: const Text('Expense Alerts'),
                subtitle: Text(
                  'Enable to receive alerts when an expense is recorded.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                ),
                value: _settingsData.expenseAlerts ?? false,
                onChanged: (value) =>
                    setState(() => _settingsData.expenseAlerts = value),
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[300],
              ),
              const SizedBox(height: 5),
              Autocomplete<Map<String, String>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Map<String, String>>.empty();
                  }
                  return _currencies.where((Map<String, String> option) {
                    return option['code']!.contains(textEditingValue.text.toUpperCase()) ||
                        option['symbol']!.contains(textEditingValue.text);
                  });
                },
                displayStringForOption: (Map<String, String> option) =>
                '${option['code']} (${option['symbol']})',
                onSelected: (Map<String, String> selection) {
                  setState(() {
                    _settingsData.currency = selection['symbol'];
                  });
                },
                initialValue:
                TextEditingValue(text: _settingsData.currency ?? ''),
                fieldViewBuilder: (BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                        labelText: 'Currency',
                        labelStyle: const TextStyle(fontSize: 14),
                        prefixIcon: Icon(Icons.attach_money,
                            color: Theme.of(context).primaryColor),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        hintText: 'Select or enter your currency code or symbol (e.g. ZAR or USD)'
                    ),
                    validator: (value) =>
                    value!.isEmpty ? 'Please enter your currency' : null,
                  );
                },
              ),


              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    ),
                    child: const Text(
                      'Save Settings',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}