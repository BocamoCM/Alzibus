import 'package:flutter/material.dart';
import '../constants/line_colors.dart';

class LineFilter extends StatelessWidget {
  final Set<String> selectedLines;
  final Function(String) onLineToggle;

  const LineFilter({
    super.key,
    required this.selectedLines,
    required this.onLineToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Líneas', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...['L1', 'L2', 'L3'].map((line) {
            final isSelected = selectedLines.contains(line);
            return GestureDetector(
              onTap: () => onLineToggle(line),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? LineColors.getColor(line) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  line,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
