import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';
import '../services/backup_scheduler.dart';
import '../utils/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_theme_toggle.dart';
import '../widgets/confirm_delete_dialog.dart';

class ExpenseCategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategoryInfo(this.name, this.icon, this.color);
}

class ExpensesPage extends StatefulWidget {
  final String userEmail;
  final bool isEmbedded;

  const ExpensesPage({
    super.key,
    required this.userEmail,
    this.isEmbedded = false,
  });

  static const List<ExpenseCategoryInfo> categories = [
    ExpenseCategoryInfo('Rent', Icons.apartment_rounded, Colors.purple),
    ExpenseCategoryInfo('Maintenance & Repairs', Icons.build_rounded, Colors.orange),
    ExpenseCategoryInfo('Salaries & Staff', Icons.badge_rounded, Colors.teal),
    ExpenseCategoryInfo('Utilities & Bills', Icons.bolt_rounded, Colors.amber),
    ExpenseCategoryInfo('Equipment & Gear', Icons.camera_alt_rounded, Colors.indigo),
    ExpenseCategoryInfo('Marketing & Ads', Icons.campaign_rounded, Colors.pink),
    ExpenseCategoryInfo('Supplies & Packaging', Icons.inventory_2_rounded, Colors.brown),
    ExpenseCategoryInfo('Travel & Fuel', Icons.local_shipping_rounded, Colors.blue),
    ExpenseCategoryInfo('Taxes & Licences', Icons.receipt_long_rounded, Colors.cyan),
    ExpenseCategoryInfo('Other', Icons.category_rounded, Colors.blueGrey),
  ];

  static ExpenseCategoryInfo getCategoryInfo(String category) {
    return categories.firstWhere(
      (c) => c.name.toLowerCase() == category.toLowerCase(),
      orElse: () => const ExpenseCategoryInfo(
        'Other',
        Icons.category_rounded,
        Colors.blueGrey,
      ),
    );
  }

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<ExpenseCategoryInfo> get categories => ExpensesPage.categories;
  ExpenseCategoryInfo getCategoryInfo(String category) =>
      ExpensesPage.getCategoryInfo(category);

  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedFilter = 'This Month'; // All, This Month, Last 30 Days, This Year

  late Box _userBox;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final safeEmail =
          widget.userEmail.replaceAll('.', '_').replaceAll('@', '_');
      final boxName = "userdata_$safeEmail";

      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      _userBox = Hive.box(boxName);

      final raw = _userBox.get('expenses', defaultValue: []);
      final List<Expense> loaded = (raw as List).map((e) {
        if (e is Expense) return e;
        return Expense.fromJson(Map<String, dynamic>.from(e as Map));
      }).toList();

      loaded.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (mounted) {
        setState(() {
          _expenses = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      if (mounted) {
        setState(() {
          _expenses = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveExpenses() async {
    try {
      await _userBox.put('expenses', _expenses);
      BackupScheduler.markDirty();
    } catch (e) {
      debugPrint('Error saving expenses: $e');
    }
  }

  List<Expense> get _filteredExpenses {
    final now = DateTime.now();

    return _expenses.where((exp) {
      // Date preset filtering
      if (_selectedFilter == 'This Month') {
        if (exp.dateTime.year != now.year || exp.dateTime.month != now.month) {
          return false;
        }
      } else if (_selectedFilter == 'Last 30 Days') {
        final diff = now.difference(exp.dateTime).inDays;
        if (diff < 0 || diff > 30) return false;
      } else if (_selectedFilter == 'This Year') {
        if (exp.dateTime.year != now.year) return false;
      }

      // Category filtering
      if (_selectedCategory != 'All' &&
          exp.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }

      // Text search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = exp.title.toLowerCase().contains(q);
        final matchCat = exp.category.toLowerCase().contains(q);
        final matchNotes = (exp.notes ?? '').toLowerCase().contains(q);
        final matchMode = exp.paymentMode.toLowerCase().contains(q);
        if (!matchTitle && !matchCat && !matchNotes && !matchMode) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double get _totalFilteredAmount {
    return _filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  Future<void> _openExpenseDialog({Expense? expenseToEdit}) async {
    final isEditing = expenseToEdit != null;
    final titleController =
        TextEditingController(text: isEditing ? expenseToEdit.title : '');
    final amountController = TextEditingController(
      text: isEditing ? expenseToEdit.amount.toStringAsFixed(2) : '',
    );
    final notesController =
        TextEditingController(text: isEditing ? (expenseToEdit.notes ?? '') : '');

    String selectedCategory =
        isEditing ? expenseToEdit.category : categories.first.name;
    String selectedMode = isEditing ? expenseToEdit.paymentMode : 'Cash';
    DateTime selectedDate = isEditing ? expenseToEdit.dateTime : DateTime.now();

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = ctx.isDark;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.90,
              ),
              padding: EdgeInsets.only(
                top: 18,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: ctx.cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEditing ? 'Edit Expense' : 'Add New Expense',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ctx.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(
                              Icons.close_rounded,
                              color: ctx.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        'Expense Title *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ctx.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Studio Rent, Sensor Cleaning, Extra Battery',
                          prefixIcon: const Icon(Icons.edit_note_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Amount
                      Text(
                        'Amount (₹) *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ctx.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '₹ ',
                          prefixStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(Icons.currency_rupee_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter an amount';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid positive amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Category Selector
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ctx.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final cat = categories[idx];
                            final isSel = selectedCategory == cat.name;
                            return ChoiceChip(
                              avatar: Icon(
                                cat.icon,
                                size: 16,
                                color: isSel ? Colors.white : cat.color,
                              ),
                              label: Text(cat.name),
                              selected: isSel,
                              selectedColor: cat.color,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white : ctx.textPrimary,
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  selectedCategory = cat.name;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date & Payment Mode Row
                      Row(
                        children: [
                          // Date Picker
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ctx.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: modalContext,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        selectedDate = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          selectedDate.hour,
                                          selectedDate.minute,
                                        );
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: ctx.borderColor,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                          color: Color(0xFF1E40AF),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat('dd MMM yyyy')
                                              .format(selectedDate),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: ctx.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Payment Mode Dropdown
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Mode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ctx.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: ctx.borderColor,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedMode,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Cash',
                                          child: Text('Cash'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'UPI',
                                          child: Text('UPI'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Bank Transfer',
                                          child: Text('Bank Transfer'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Card',
                                          child: Text('Card'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() {
                                            selectedMode = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      Text(
                        'Notes / Remarks (Optional)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ctx.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Paid to vendor Rahul, Invoice #582',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final amount =
                                double.parse(amountController.text.trim());

                            if (isEditing) {
                              expenseToEdit.title = titleController.text.trim();
                              expenseToEdit.amount = amount;
                              expenseToEdit.category = selectedCategory;
                              expenseToEdit.dateTime = selectedDate;
                              expenseToEdit.paymentMode = selectedMode;
                              expenseToEdit.notes = notesController.text.trim();
                            } else {
                              final newExp = Expense(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                title: titleController.text.trim(),
                                amount: amount,
                                category: selectedCategory,
                                dateTime: selectedDate,
                                paymentMode: selectedMode,
                                notes: notesController.text.trim(),
                              );
                              _expenses.insert(0, newExp);
                            }

                            _expenses.sort(
                              (a, b) => b.dateTime.compareTo(a.dateTime),
                            );

                            await _saveExpenses();
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);

                            if (mounted) {
                              AppSnackBar.showSuccess(
                                context,
                                message: isEditing
                                    ? 'Expense updated successfully!'
                                    : 'Expense added successfully!',
                              );
                            }
                          },
                          icon: Icon(
                            isEditing
                                ? Icons.save_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isEditing ? 'Save Changes' : 'Record Expense',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteExpense(Expense exp) async {
    await showConfirmDialog(
      context: context,
      title: 'Delete Expense?',
      message: 'Are you sure you want to delete "${exp.title}" of ₹${exp.amount.toStringAsFixed(2)}?',
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () async {
        setState(() {
          _expenses.removeWhere((e) => e.id == exp.id);
        });
        await _saveExpenses();
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            message: 'Expense removed successfully',
          );
        }
      },
    );
  }

  Future<void> _exportExpensesCsv() async {
    try {
      final list = _filteredExpenses;
      if (list.isEmpty) {
        AppSnackBar.showWarning(context, message: 'No expenses to export.');
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('ID,Title,Category,Amount (INR),Date,Payment Mode,Notes');

      for (final exp in list) {
        final row = [
          exp.id,
          exp.title,
          exp.category,
          exp.amount.toStringAsFixed(2),
          DateFormat('yyyy-MM-dd').format(exp.dateTime),
          exp.paymentMode,
          exp.notes ?? '',
        ];
        buffer.writeln(
          row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','),
        );
      }

      final csvData = buffer.toString();
      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final file = File('${dir.path}/BizMate_Expenses_$dateStr.csv');
      await file.writeAsString(csvData);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'BizMate Expense Report ($dateStr)',
          text: 'Here is your BizMate Expense export for $dateStr.',
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Failed to export CSV: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final width = MediaQuery.sizeOf(context).width;
    final filtered = _filteredExpenses;
    final bool showAppBar =
        !widget.isEmbedded && (ModalRoute.of(context)?.canPop ?? false);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF1E40AF),
                        Color(0xFF020617),
                      ],
                      stops: [0.0, 0.6, 1.0],
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                    ),
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  'Expense Tracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                    tooltip: 'Export CSV',
                    onPressed: _exportExpensesCsv,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: AppThemeToggle(),
                  ),
                ],
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Banner
                        _buildSummaryCard(isDark),
                        const SizedBox(height: 16),

                        // Date Filter Tabs
                        _buildDateFilterRow(),
                        const SizedBox(height: 12),

                        // Search & Category Dropdown
                        _buildSearchAndCategoryRow(isDark, width),
                        const SizedBox(height: 16),

                        // Section Heading with Count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Records (${filtered.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.file_download_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'Export CSV',
                                  color: const Color(0xFF1E40AF),
                                  onPressed: _exportExpensesCsv,
                                ),
                                TextButton.icon(
                                  onPressed: () => _openExpenseDialog(),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Expense'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E40AF),
                                    textStyle:
                                        const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Expense List
                        if (filtered.isEmpty)
                          _buildEmptyState(isDark)
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              return _buildExpenseTile(filtered[i], isDark);
                            },
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _openExpenseDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final count = _filteredExpenses.length;
    final total = _totalFilteredAmount;
    final avg = count > 0 ? (total / count) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E40AF), const Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Expenses ($_selectedFilter)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count transactions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₹${total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.stacked_bar_chart_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Avg: ₹${avg.toStringAsFixed(0)} / record',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedCategory != 'All') ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _selectedCategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterRow() {
    final filters = ['All Time', 'This Month', 'Last 30 Days', 'This Year'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSel = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSel,
              selectedColor: const Color(0xFF1E40AF),
              labelStyle: TextStyle(
                color: isSel ? Colors.white : context.textPrimary,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedFilter = f;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchAndCategoryRow(bool isDark, double width) {
    final searchField = TextField(
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search title, notes, mode…',
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor:
            isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      ),
    );

    final categoryDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        border: Border.all(color: context.borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
          dropdownColor: context.cardBg,
          items: [
            const DropdownMenuItem(value: 'All', child: Text('All Categories')),
            ...categories.map(
              (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCategory = val;
              });
            }
          },
        ),
      ),
    );

    if (width < 360) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: 8),
          categoryDropdown,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: searchField),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: categoryDropdown),
      ],
    );
  }

  Widget _buildExpenseTile(Expense exp, bool isDark) {
    final catInfo = getCategoryInfo(exp.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: catInfo.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(catInfo.icon, color: catInfo.color, size: 22),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exp.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      exp.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: catInfo.color,
                      ),
                    ),
                    Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: context.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(exp.dateTime),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        exp.paymentMode,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (exp.notes != null && exp.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exp.notes!.trim(),
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: context.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '- ₹${exp.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: context.textSecondary,
                ),
                onSelected: (val) {
                  if (val == 'edit') {
                    _openExpenseDialog(expenseToEdit: exp);
                  } else if (val == 'delete') {
                    _deleteExpense(exp);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: Color(0xFF1E40AF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Expenses Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "+ Add Expense" to track rent, repairs, gear, and supplies.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _openExpenseDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add First Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
