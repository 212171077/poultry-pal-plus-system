import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:poultry_pal_plus_app/models/settings_data.dart';
import 'package:poultry_pal_plus_app/screens/common.dart';

import '../models/farm.dart';
import '../models/user.dart';
import '../service/poultry_pal_service.dart';

class SettingsScreen extends StatefulWidget {
  final Farm farm;
  final User user;

  const SettingsScreen({super.key, required this.farm, required this.user});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _poultryPalService = PoultryPalService();
  SettingsData _settingsData = SettingsData();

  // Key changes when currency loads → forces Autocomplete to rebuild with the
  // correct initialValue (the widget ignores prop changes after first build).
  Key _currencyKey = const ValueKey('currency_unloaded');

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
    final loadedSettings =
        await _poultryPalService.loadSettings(widget.farm.id, widget.user.id);
    setState(() {
      _settingsData = loadedSettings;
      // Changing the key forces the Autocomplete to rebuild with the new
      // initialValue — without this the controller ignores the update.
      _currencyKey = ValueKey('currency_${loadedSettings.currency ?? ''}');
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
    ScaffoldMessenger.of(context)
        .showSnackBar(Common.buildSnackBar(message, AppColors.success));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(Common.buildSnackBar(message, AppColors.error));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.adaptivePrimary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.adaptivePrimary(context)),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.adaptivePrimary(context),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                          height: 1.3,
                        )),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.adaptivePrimary(context),
                activeTrackColor: AppColors.adaptivePrimary(context).withValues(alpha: 0.35),
                inactiveThumbColor: AppColors.textTertiary(context),
                inactiveTrackColor: AppColors.border(context),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: AppColors.divider(context),
          ),
      ],
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // ── Notifications ──────────────────────────────────────────────
            _sectionHeader(context, 'Notifications', Icons.notifications_outlined),
            _sectionCard(context, children: [
              _settingsTile(
                context: context,
                icon: Icons.auto_mode_rounded,
                iconColor: AppColors.info,
                title: 'Auto-Create Reminders',
                subtitle: 'Automatically create reminders for tasks',
                value: _settingsData.autoCreateReminders ?? false,
                onChanged: (v) => setState(() => _settingsData.autoCreateReminders = v),
              ),
              _settingsTile(
                context: context,
                icon: Icons.calendar_today_outlined,
                iconColor: AppColors.adaptivePrimary(context),
                title: 'Daily Reminders',
                subtitle: 'Medications, vaccinations & feeding schedules',
                value: _settingsData.dailyReminders ?? false,
                onChanged: (v) => setState(() => _settingsData.dailyReminders = v),
              ),
              _settingsTile(
                context: context,
                icon: Icons.point_of_sale_outlined,
                iconColor: AppColors.success,
                title: 'Sales Alerts',
                subtitle: 'Get notified when a sale is recorded',
                value: _settingsData.salesAlerts ?? false,
                onChanged: (v) => setState(() => _settingsData.salesAlerts = v),
              ),
              _settingsTile(
                context: context,
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.warning,
                title: 'Mortality Alerts',
                subtitle: 'Get notified when a mortality is recorded',
                value: _settingsData.mortalityAlerts ?? false,
                onChanged: (v) => setState(() => _settingsData.mortalityAlerts = v),
              ),
              _settingsTile(
                context: context,
                icon: Icons.receipt_long_outlined,
                iconColor: AppColors.error,
                title: 'Expense Alerts',
                subtitle: 'Get notified when an expense is recorded',
                value: _settingsData.expenseAlerts ?? false,
                onChanged: (v) => setState(() => _settingsData.expenseAlerts = v),
                isLast: true,
              ),
            ]),

            const SizedBox(height: 24),

            // ── Financial ──────────────────────────────────────────────────
            _sectionHeader(context, 'Financial', Icons.account_balance_wallet_outlined),
            _sectionCard(context, children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currency',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Key forces full rebuild when loaded currency changes so
                    // the Autocomplete's internal controller reflects the saved value.
                    Autocomplete<Map<String, String>>(
                      key: _currencyKey,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Map<String, String>>.empty();
                        }
                        return _currencies.where((option) =>
                            option['code']!.contains(textEditingValue.text.toUpperCase()) ||
                            option['symbol']!.contains(textEditingValue.text));
                      },
                      displayStringForOption: (option) =>
                          '${option['code']} (${option['symbol']})',
                      onSelected: (selection) {
                        setState(() => _settingsData.currency = selection['symbol']);
                      },
                      initialValue: TextEditingValue(
                        text: _settingsData.currency ?? '',
                      ),
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.surface(context),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: AppColors.divider(context),
                                ),
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Text(
                                        '${option['code']} (${option['symbol']})',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'Search by code or symbol (e.g. ZAR, R)',
                            prefixIcon: Icon(
                              Icons.attach_money_rounded,
                              color: AppColors.adaptivePrimary(context),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 14),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Please enter a currency' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 13,
                            color: AppColors.textTertiary(context)),
                        const SizedBox(width: 5),
                        Text(
                          'Used for all financial figures across the app',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_outlined, size: 20),
                label: const Text(
                  'Save Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adaptivePrimary(context),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


