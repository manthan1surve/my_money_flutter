import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../base/base_screen.dart';
import '../base/base_card.dart';
import '../base/base_dialog.dart';
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

class ProfileScreen extends BaseScreen {
  const ProfileScreen({super.key});

  @override
  BaseScreenState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends BaseScreenState<ProfileScreen> {
  @override
  String? get screenTitle => "Profile";

  @override
  bool get showBackButton => true;

  bool _isSyncingOnline = false;

  Future<void> _handleManualSync(AppProvider provider) async {
    if (_isSyncingOnline) return;
    setState(() {
      _isSyncingOnline = true;
    });
    try {
      await provider.syncOnline();
      if (mounted) {
        showSuccessNotification(
          context,
          'Data Synced Successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        showValidationDialog(context, 'Sync failed: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingOnline = false;
        });
      }
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    final user = context.select((AppProvider p) => p.user);
    final currency = context.select((AppProvider p) => p.currency);
    final isSynced = context.select((AppProvider p) => p.isSynced);

    final selectedCurrency = _currencies.firstWhere(
      (c) => c['code'] == currency.code,
      orElse: () => _currencies.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.read<AppProvider>().pickProfilePhoto(),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(
                      color: isSynced ? const Color(0xFF00E676) : const Color(0xFFFF3D00),
                      width: 3.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isSynced ? const Color(0xFF00E676) : const Color(0xFFFF3D00))
                            .withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: user?.photoPath != null
                      ? Image.file(
                          File(user!.photoPath!),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/avatar.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
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
                  padding: const EdgeInsets.all(5),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user?.name ?? user?.email.split('@').first ?? 'User',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showEditNameDialog(
                    context, context.read<AppProvider>(), user?.name ?? user?.email.split('@').first ?? 'User'),
                child: const Icon(Icons.edit, color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            user?.email ?? '',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_isSyncingOnline
                          ? const Color(0xFFFF9800)
                          : isSynced
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFF3D00))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isSyncingOnline
                            ? const Color(0xFFFF9800)
                            : isSynced
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF3D00))
                        .withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: _isSyncingOnline
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSyncingOnline
                          ? Icons.cloud_sync
                          : isSynced
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                      size: 14,
                      color: _isSyncingOnline
                          ? const Color(0xFFFF9800)
                          : isSynced
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFF3D00),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isSyncingOnline
                          ? 'Syncing…'
                          : isSynced
                              ? 'Cloud Synced'
                              : 'Sync Pending',
                      style: TextStyle(
                        color: _isSyncingOnline
                            ? const Color(0xFFFF9800)
                            : isSynced
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF3D00),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _handleManualSync(context.read<AppProvider>()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isSyncingOnline
                        ? const Color(0xFFFF9800).withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSyncingOnline
                          ? const Color(0xFFFF9800).withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: _isSyncingOnline
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: _isSyncingOnline
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF9800),
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          size: 14,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          GlassCardWidget(
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

                DropdownSelector<Map<String, String>>(
                  label: 'Currency',
                  items: _currencies.cast<Map<String, String>>(),
                  selectedItem: selectedCurrency.cast<String, String>(),
                  onSelect: (c) {
                    context.read<AppProvider>().updateCurrency(CurrencyModel(
                      code: c['code']!,
                      symbol: c['symbol']!,
                      name: c['name']!,
                    ));
                  },
                  getName: (c) => '${c['symbol']}  ${c['name']} (${c['code']})',
                  getId: (c) => c['id']!,
                ),
                const SizedBox(height: 10),

                _buildMenuItem(Icons.download_outlined, 'Import Records (CSV)', context, onTap: () async {
                  final progressNotifier = ValueNotifier<ImportStatus>(
                    ImportStatus(isDone: false, current: 0, total: 0)
                  );
                  bool dialogShown = false;

                  try {
                    final count = await context.read<AppProvider>().importTransactionsCSV(
                      onStartImport: () async {
                        final overwrite = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => GlassModalDialog(
                            title: 'Overwrite Transactions?',
                            content: const Text('Do you want to overwrite your existing transactions with the imported ones, or append them?', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(null),
                                child: Text('Cancel', style: GoogleFonts.fraunces(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text('Append', style: GoogleFonts.fraunces(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text('Overwrite', style: GoogleFonts.fraunces(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        );

                        if (overwrite == null) return null;

                        if (!context.mounted) return null;
                        dialogShown = true;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => ImportProgressDialog(notifier: progressNotifier),
                        );
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
                    String errorMsg = e.toString();
                    if (errorMsg.startsWith('Exception: ')) {
                      errorMsg = errorMsg.substring(11);
                    }
                    if (dialogShown) {
                      progressNotifier.value = ImportStatus(
                        isDone: true,
                        error: errorMsg,
                      );
                    } else {
                      if (context.mounted) {
                        showValidationDialog(context, errorMsg);
                      }
                    }
                  }
                }),
                _buildMenuItem(Icons.upload_outlined, 'Export Records (CSV)', context, onTap: () async {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const GlassModalDialog(
                        title: 'Exporting Data',
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
                    await context.read<AppProvider>().exportTransactionsCSV();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showValidationDialog(context, 'Something went wrong: $e');
                    }
                  }
                }),
                _buildMenuItem(Icons.delete_forever_outlined, 'Clear All Data', context, onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => GlassModalDialog(
                      title: 'Are you sure?',
                      content: const Text('This will delete all your accounts, transactions, and categories. This action cannot be undone.', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('No', style: GoogleFonts.fraunces(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Yes', style: GoogleFonts.fraunces(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (!context.mounted) return;
                    final provider = context.read<AppProvider>();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const GlassModalDialog(
                        title: 'Clearing Data',
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

                    await provider.clearAllData();

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showSuccessNotification(
                        context,
                        'Data Cleared',
                        'All accounts, transactions, and categories have been cleared.',
                      );
                    }
                  }
                }),
              ],
            ),
          ),

          GestureDetector(
            onTap: () async {
              await context.read<AppProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0x1AFE0000),
                borderRadius: BorderRadius.circular(20),
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

  Future<void> _showEditNameDialog(BuildContext context, AppProvider provider, String currentName) async {
    final TextEditingController controller = TextEditingController(text: currentName);
    return showDialog(
      context: context,
      builder: (context) {
        return GlassModalDialog(
          title: 'Edit Username',
          content: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Enter new username',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                border: InputBorder.none,
              ),
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(context);
              },
              child: Text('Cancel', style: GoogleFonts.fraunces(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                if (controller.text.trim().isNotEmpty) {
                  provider.updateUserName(controller.text.trim());
                }
                Navigator.pop(context);
              },
              child: Text('Save', style: GoogleFonts.fraunces(color: const Color(0xFF6366F1))),
            ),
          ],
        );
      },
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
          return Center(
            child: Material(
              color: Colors.transparent,
              child: GlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 24),
                        SizedBox(width: 10),
                        Text("Import Failed", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      status.error!,
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("OK", style: GoogleFonts.fraunces(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (status.isDone) {
          return GlassModalDialog(
            titleIcon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
            title: "Import Complete",
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("OK", style: GoogleFonts.fraunces(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        }

        return GlassModalDialog(
          title: 'Importing Records',
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
