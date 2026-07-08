import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../components/app_background.dart';
import '../components/glass_card.dart';
import '../components/dropdown_selector.dart';
import '../components/loading_spinner.dart';
import '../components/validation_dialog.dart';

const _currencies = [
  {'id': 'USD', 'name': 'USA',       'code': 'USD', 'symbol': '\$'},
  {'id': 'INR', 'name': 'India',     'code': 'INR', 'symbol': '₹'},
  {'id': 'GBP', 'name': 'UK',        'code': 'GBP', 'symbol': '£'},
  {'id': 'EUR', 'name': 'Europe',    'code': 'EUR', 'symbol': '€'},
  {'id': 'JPY', 'name': 'Japan',     'code': 'JPY', 'symbol': '¥'},
  {'id': 'CAD', 'name': 'Canada',    'code': 'CAD', 'symbol': 'CA\$'},
  {'id': 'AUD', 'name': 'Australia', 'code': 'AUD', 'symbol': 'A\$'},
  {'id': 'AED', 'name': 'UAE',       'code': 'AED', 'symbol': 'د.إ'},
  {'id': 'SGD', 'name': 'Singapore', 'code': 'SGD', 'symbol': 'S\$'},
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final currency = provider.currency;

    // Find selected currency model from our list
    final selectedCurrency = _currencies.firstWhere(
      (c) => c['code'] == currency.code,
      orElse: () => _currencies.first,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 10),
                    Text("Profile", style: AppTypography.screenTitle),
                    const Spacer(),
                    const SizedBox(width: 30),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    children: [
                      // Avatar
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => provider.pickProfilePhoto(),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                              ),
                              child: ClipOval(
                                child: user?.photoPath != null
                                  ? Image.file(
                                      File(user!.photoPath!),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      'assets/avatar.png',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      color: Colors.white,
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 12, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        user?.email.split('@').first ?? 'User',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                      ),
                      const SizedBox(height: 40),

                      // Settings Card
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACCOUNT SETTINGS',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Currency Dropdown
                            DropdownSelector<Map<String, String>>(
                              label: 'Currency',
                              items: _currencies.cast<Map<String, String>>(),
                              selectedItem: selectedCurrency.cast<String, String>(),
                              onSelect: (c) {
                                provider.updateCurrency(CurrencyModel(
                                  code: c['code']!,
                                  symbol: c['symbol']!,
                                  name: c['name']!,
                                ));
                              },
                              getName: (c) => '${c['symbol']}  ${c['name']} (${c['code']})',
                              getId: (c) => c['id']!,
                            ),
                            const SizedBox(height: 10),

                            _buildMenuItem(Icons.notifications_outlined, 'Notifications', context),
                            _buildMenuItem(Icons.shield_outlined, 'Security', context),
                            _buildMenuItem(Icons.download_outlined, 'Import Records (CSV)', context, onTap: () async {
                              final progressNotifier = ValueNotifier<ImportStatus>(
                                ImportStatus(isDone: false, current: 0, total: 0)
                              );
                              bool dialogShown = false;

                              try {
                                final count = await provider.importTransactionsCSV(
                                  onStartImport: () async {
                                    final overwrite = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E1E1E),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text('Overwrite Transactions?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        content: const Text('Do you want to overwrite your existing transactions with the imported ones, or append them?', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                                        actionsAlignment: MainAxisAlignment.end,
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(null), // cancel
                                            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('Append', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: const Text('Overwrite', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (overwrite == null) return null;

                                    if (context.mounted) {
                                      dialogShown = true;
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) => ImportProgressDialog(notifier: progressNotifier),
                                      );
                                    }
                                    return overwrite;
                                  },
                                  onProgress: (current, total) {
                                    progressNotifier.value = ImportStatus(
                                      isDone: false,
                                      current: current,
                                      total: total,
                                    );
                                  },
                                );

                                if (count != -1) {
                                  progressNotifier.value = ImportStatus(
                                    isDone: true,
                                    current: count,
                                    total: count,
                                  );
                                }
                              } catch (e) {
                                if (dialogShown) {
                                  progressNotifier.value = ImportStatus(
                                    isDone: true,
                                    error: e.toString(),
                                  );
                                } else {
                                  if (context.mounted) {
                                    showValidationDialog(context, 'Import failed: $e');
                                  }
                                }
                              }
                            }),
                            _buildMenuItem(Icons.upload_outlined, 'Export Records (CSV)', context, onTap: () async {
                              try {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => const AlertDialog(
                                    backgroundColor: Color(0xFF1E1E1E),
                                    content: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(width: 24, height: 24, child: LoadingSpinner()),
                                        SizedBox(width: 20),
                                        Text("Exporting data...", style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                );
                                await provider.exportTransactionsCSV();
                                if (context.mounted) {
                                  Navigator.of(context).pop(); // dismiss loading dialog
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.of(context).pop(); // dismiss loading dialog
                                  showValidationDialog(context, 'Something went wrong: $e');
                                }
                              }
                            }),
                            _buildMenuItem(Icons.help_outline, 'Help & Support', context),
                            _buildMenuItem(Icons.delete_forever_outlined, 'Clear All Data', context, onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Are you sure?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  content: const Text('This will delete all your accounts, transactions, and categories. This action cannot be undone.', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                                  actionsAlignment: MainAxisAlignment.end,
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('No', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Yes', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => const AlertDialog(
                                      backgroundColor: Color(0xFF1E1E1E),
                                      content: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(width: 24, height: 24, child: LoadingSpinner()),
                                          SizedBox(width: 20),
                                          Text("Clearing data...", style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                
                                await provider.clearAllData();
                                
                                if (context.mounted) {
                                  Navigator.of(context).pop(); // Dismiss loading dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('All data has been cleared.'))
                                  );
                                }
                              }
                            }),
                          ],
                        ),
                      ),

                      // Logout Button
                      GestureDetector(
                        onTap: () async {
                          await provider.logout();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: const Color(0x1AFE0000),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0x33FE0000)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, color: Color(0xFFFE0000), size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Logout',
                                style: TextStyle(color: Color(0xFFFE0000), fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, BuildContext context, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16))),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
      ),
    );
  }
}

class ImportStatus {
  final bool isDone;
  final int current;
  final int total;
  final String? error;

  ImportStatus({this.isDone = false, this.current = 0, this.total = 0, this.error});
}

class ImportProgressDialog extends StatefulWidget {
  final ValueNotifier<ImportStatus> notifier;

  const ImportProgressDialog({super.key, required this.notifier});

  @override
  State<ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ImportStatus>(
      valueListenable: widget.notifier,
      builder: (context, status, _) {
        final double percent = status.total > 0 ? (status.current / status.total) : 0.0;
        final String percentText = (percent * 100).toStringAsFixed(0);

        if (status.error != null) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 24),
                SizedBox(width: 10),
                Text("Import Failed", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              status.error!,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK", style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        }

        if (status.isDone) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                SizedBox(width: 10),
                Text("Import Complete", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Successfully imported ${status.current} transactions.",
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your balances and transactions have been updated.",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK", style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 24, height: 24, child: LoadingSpinner()),
                  SizedBox(width: 20),
                  Text(
                    "Importing records...",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${status.current} of ${status.total}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    "$percentText%",
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
