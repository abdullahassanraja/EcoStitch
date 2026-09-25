import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Screen: Garment Type Selector
/// "What are you upcycling?" — a 5-card grid letting the user pick
/// T-shirt, Sweater, Pants, Jeans, or Maxi Dress before proceeding
/// to the Size Selector screen.
class GarmentTypeScreen extends StatefulWidget {
  const GarmentTypeScreen({super.key});

  @override
  State<GarmentTypeScreen> createState() => _GarmentTypeScreenState();
}

class _GarmentTypeScreenState extends State<GarmentTypeScreen> {
  String? _selectedType;

  /// Garment type definitions.
  /// `key` maps to the `garment_type` column in size_standards.
  static const List<Map<String, dynamic>> _garmentTypes = [
    {'key': 't_shirt', 'label': 'T-shirt', 'icon': Icons.dry_cleaning_outlined},
    {'key': 'sweater', 'label': 'Sweater', 'icon': Icons.checkroom_outlined},
    {'key': 'pants', 'label': 'Pants', 'icon': Icons.straighten_outlined},
    {'key': 'jeans', 'label': 'Jeans', 'icon': Icons.style_outlined},
    {'key': 'maxi_dress', 'label': 'Maxi Dress', 'icon': Icons.accessibility_new_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header row: back button + title
              _buildHeader(context),

              // Grid of garment cards
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    children: [
                      _buildGarmentGrid(),
                      const SizedBox(height: 28),
                      // "Next" CTA — only visible once a type is selected
                      if (_selectedType != null) _buildNextButton(context),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Circular back button (matches capture_screen pattern)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.mintMid,
                  border: Border.all(
                    color: AppTheme.greenSoft.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppTheme.greenDeep,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'What are you upcycling?',
              style: AppTheme.headlineMedium(color: AppTheme.greenDeep).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarmentGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.15,
      ),
      itemCount: _garmentTypes.length,
      itemBuilder: (context, index) {
        final item = _garmentTypes[index];
        final String key = item['key'] as String;
        final bool isSelected = _selectedType == key;

        return _GarmentCard(
          label: item['label'] as String,
          icon: item['icon'] as IconData,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedType = key;
            });
          },
        );
      },
    );
  }

  Widget _buildNextButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          context.push('/size-selector', extra: _selectedType);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.greenDeep,
          foregroundColor: AppTheme.cream,
          elevation: 2,
          shadowColor: AppTheme.greenDeep.withOpacity(0.3),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Next',
              style: AppTheme.buttonText(color: AppTheme.cream).copyWith(
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.cream,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual selectable card for a garment type.
/// Unselected: inkSoft icon/label, subtle border.
/// Selected: dashed greenDeep border, greenDeep icon/label.
class _GarmentCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GarmentCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.greenDeep.withOpacity(0.06)
              : AppTheme.cream.withOpacity(0.8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: CustomPaint(
          painter: isSelected
              ? _DashedBorderPainter(
                  color: AppTheme.greenDeep,
                  borderRadius: 18,
                  strokeWidth: 2.0,
                  dashLength: 7,
                  dashGap: 5,
                )
              : _DashedBorderPainter(
                  color: AppTheme.greenSoft.withOpacity(0.35),
                  borderRadius: 18,
                  strokeWidth: 1.2,
                  dashLength: 7,
                  dashGap: 5,
                ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: isSelected ? AppTheme.greenDeep : AppTheme.inkSoft,
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium(
                    color: isSelected ? AppTheme.greenDeep : AppTheme.inkSoft,
                  ).copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws a dashed rounded-rectangle border.
/// Used for the garment card selection state (dashed, not solid).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 2.0,
    this.dashLength = 6.0,
    this.dashGap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rRect);

    // Walk along the path and draw dashes
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        final extractedPath = metric.extractPath(distance, end);
        canvas.drawPath(extractedPath, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      strokeWidth != oldDelegate.strokeWidth;
}
