import 'package:flutter/material.dart';

class DiscountTaxWidget extends StatelessWidget {
  final TextEditingController discountPercentController;
  final TextEditingController discountAmountController;
  final bool isEditingPercent;
  final Function(bool) onModeChange;
  final double subtotal;
  final String? selectedTaxRate;
  final String selectedTaxType;

  final List<String> taxRateOptions;

  final Function(String?) onTaxRateChanged;
  final Function(String?) onTaxTypeChanged;

  final double taxAmount;
  final double parsedTaxRate;

  const DiscountTaxWidget({
    super.key,
    required this.discountPercentController,
    required this.discountAmountController,
    required this.isEditingPercent,
    required this.onModeChange,
    required this.subtotal,
    required this.selectedTaxRate,
    required this.selectedTaxType,
    required this.taxRateOptions,
    required this.onTaxRateChanged,
    required this.onTaxTypeChanged,
    required this.taxAmount,
    required this.parsedTaxRate,
  });

  num get scale => 1.0;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;
    final bool isTaxRateEnabled = selectedTaxType == "With Tax";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow(context, "Subtotal", subtotal),
        const SizedBox(height: 20),

        // ---------------- DISCOUNT ----------------
        Row(
          children: [
            Expanded(
              child: _glassTextField(
                context: context,
                label: "Discount %",
                icon: Icons.percent,
                controller: discountPercentController,
                suffixText: "%",
                onTap: () => onModeChange(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _glassTextField(
                context: context,
                label: "Discount ₹",
                icon: Icons.currency_rupee,
                controller: discountAmountController,
                prefixText: "₹ ",
                onTap: () => onModeChange(false),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ---------------- TAX TYPE + TAX RATE ----------------
        Row(
          children: [
            Expanded(
              child: _glassDropdown(
                context: context,
                label: "Tax Type",
                value: selectedTaxType,
                options: const ["With Tax", "Without Tax"],
                onChanged: onTaxTypeChanged,
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: IgnorePointer(
                ignoring: !isTaxRateEnabled,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: isTaxRateEnabled ? 1.0 : 0.4,
                  child: _glassDropdown(
                    context: context,
                    label: "Tax Rate",
                    value: selectedTaxRate,
                    options: taxRateOptions,
                    onChanged: onTaxRateChanged,
                  ),
                ),
              ),
            ),
          ],
        ),

        // ---------------- TAX INFO ----------------
        if (isTaxRateEnabled && parsedTaxRate > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  context,
                  "Tax Rate",
                  "${parsedTaxRate.toStringAsFixed(2)}%",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  context,
                  "Tax Amount",
                  "₹ ${taxAmount.toStringAsFixed(2)}",
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _summaryRow(BuildContext context, String label, double value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text1 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: text1),
        ),
        Text(
          "₹ ${value.toStringAsFixed(2)}",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text1),
        ),
      ],
    );
  }

  Widget _glassTextField({
    required BuildContext context,
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? prefixText,
    String? suffixText,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F7FA);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final text1 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
    final text2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double localScale = (constraints.maxWidth / 390).clamp(0.95, 1.1);

        final bool isCompact =
            icon == Icons.percent || icon == Icons.currency_rupee;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 6 * localScale),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12 * localScale),
            color: inputBg,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: TextFormField(
            controller: controller,
            onTap: onTap,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 14 * localScale,
              fontWeight: FontWeight.w500,
              color: text1,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              labelText: label,
              labelStyle: TextStyle(
                fontSize: 13 * localScale,
                color: text2,
                fontWeight: FontWeight.w500,
              ),

              // ICON
              prefixIcon: Icon(
                icon,
                size: 18 * localScale,
                color: text2,
              ),

              prefixIconConstraints: BoxConstraints(
                minWidth: isCompact ? 32 * localScale : 40 * localScale,
                minHeight: 36 * localScale,
              ),

              contentPadding: EdgeInsets.fromLTRB(
                isCompact ? 6 * localScale : 12 * localScale,
                12 * localScale,
                12 * localScale,
                12 * localScale,
              ),

              prefixText: prefixText,
              prefixStyle: TextStyle(
                fontSize: 13 * localScale,
                color: text1,
                fontWeight: FontWeight.w500,
              ),

              suffixText: suffixText,
              suffixStyle: TextStyle(
                fontSize: 13 * localScale,
                color: text1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glassDropdown({
    required BuildContext context,
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
    double fontSize = 12,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F7FA);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final text1 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
    final text2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: inputBg,
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          labelStyle: TextStyle(
            fontSize: fontSize * scale,
            color: text2,
          ),
        ),
        style: TextStyle(
          fontSize: fontSize * scale,
          color: text1,
        ),
        dropdownColor: inputBg,
        items:
            options
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(
                      e,
                      style: TextStyle(fontSize: fontSize * scale, color: text1),
                    ),
                  ),
                )
                .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _infoCard(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F7FA);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final text1 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
    final text2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: text2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: text1),
          ),
        ],
      ),
    );
  }
}
