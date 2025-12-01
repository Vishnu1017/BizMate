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
    required this.taxAmount,
    required this.parsedTaxRate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow("Subtotal", subtotal),

        const SizedBox(height: 20),

        // --------------------------
        // 🔥 EXACT SAME ROW YOU WANT
        // --------------------------
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

        // TAX TYPE
        _glassDropdown(
          label: "Tax Type",
          value: selectedTaxType,
          options: ["With Tax", "Without Tax"],
          onChanged: (_) {},
          enabled: false, // keep same as rental page
        ),

        const SizedBox(height: 14),

        // TAX RATE (enabled only if With Tax is selected)
        IgnorePointer(
          ignoring: selectedTaxType != "With Tax",
          child: Opacity(
            opacity: selectedTaxType == "With Tax" ? 1 : 0.3,
            child: _glassDropdown(
              label: "Select Tax Rate",
              value: selectedTaxRate,
              options: taxRateOptions,
              onChanged: onTaxRateChanged,
              enabled: selectedTaxType == "With Tax",
            ),
          ),
        ),

        // TAX DETAILS CARDS
        if (selectedTaxType == "With Tax" && parsedTaxRate > 0) ...[
          const SizedBox(height: 14),
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

  // ---------------------- UI ELEMENTS ----------------------

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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // 🔥 SAME GLASS TEXT FIELD DESIGN FROM RentalAddCustomerPage
  Widget _glassTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? prefixText,
    String? suffixText,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade200.withOpacity(0.3),
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: TextFormField(
        controller: controller,
        onTap: onTap,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) {},
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          prefixText: prefixText,
          suffixText: suffixText,
          prefixIcon: Icon(icon, color: Colors.black87),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _glassDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
    bool enabled = true,
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
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        items:
            options
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
        onChanged: enabled ? onChanged : null,
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
