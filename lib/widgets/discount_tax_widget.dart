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
  final Function(String?) onTaxTypeChanged; // ✅ ADD THIS

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
    required this.onTaxTypeChanged, // ✅ REQUIRED
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
        _summaryRow("Subtotal", subtotal),
        const SizedBox(height: 20),

        // ---------------- DISCOUNT ----------------
        Row(
          children: [
            Expanded(
              child: _glassTextField(
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
                label: "Tax Type",
                value: selectedTaxType,
                options: const ["With Tax", "Without Tax"],
                onChanged: onTaxTypeChanged, // ✅ FIXED
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
                  "Tax Rate",
                  "${parsedTaxRate.toStringAsFixed(2)}%",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
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

  Widget _summaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Text(
          "₹ ${value.toStringAsFixed(2)}",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _glassTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? prefixText,
    String? suffixText,
    VoidCallback? onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double localScale = (constraints.maxWidth / 390).clamp(0.95, 1.1);

        final bool isCompact =
            icon == Icons.percent || icon == Icons.currency_rupee;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 6 * localScale),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12 * localScale),
            color: Colors.grey.shade200.withOpacity(0.3),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: TextFormField(
            controller: controller,
            onTap: onTap,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 14 * localScale,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              labelText: label,
              labelStyle: TextStyle(
                fontSize: 13 * localScale,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),

              // ICON
              prefixIcon: Icon(
                icon,
                size: 18 * localScale,
                color: Colors.grey.shade700,
              ),

              // 🔥 Better icon alignment
              prefixIconConstraints: BoxConstraints(
                minWidth: isCompact ? 32 * localScale : 40 * localScale,
                minHeight: 36 * localScale,
              ),

              // 🔥 Clean compact padding
              contentPadding: EdgeInsets.fromLTRB(
                isCompact ? 6 * localScale : 12 * localScale,
                12 * localScale,
                12 * localScale,
                12 * localScale,
              ),

              prefixText: prefixText,
              prefixStyle: TextStyle(
                fontSize: 13 * localScale,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),

              suffixText: suffixText,
              suffixStyle: TextStyle(
                fontSize: 13 * localScale,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glassDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
    double fontSize = 12, // ✅ Add this
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade200.withOpacity(0.3),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          labelStyle: TextStyle(
            // ✅ LABEL FONT SIZE
            fontSize: fontSize * scale,
          ),
        ),
        style: TextStyle(
          // ✅ SELECTED VALUE FONT SIZE
          fontSize: fontSize * scale,
          color: Colors.black,
        ),
        dropdownColor: Colors.white,
        items:
            options
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(
                      e,
                      style: TextStyle(fontSize: fontSize * scale),
                    ),
                  ),
                )
                .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
