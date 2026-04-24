import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CategoryGroupHeader extends StatelessWidget {
  final String categoryName;

  const CategoryGroupHeader({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: GraceWayColor.golden.withValues(alpha: 0.25),
            thickness: 0.5,
          ),
          const SizedBox(height: 8),
          Text(
            categoryName.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              color: Colors.white.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
