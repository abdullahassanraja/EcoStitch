import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/size_standards_service.dart';

/// Screen: Size Selector
/// Shows size chips (e.g. S/M/L/XL/XXL) for the chosen garment type,
/// a "View size chart" link that opens a bottom sheet with dimension data,
/// and a "Continue" CTA that navigates to the Capture screen carrying
/// both garment_type and size_label forward.
class SizeSelectorScreen extends StatefulWidget {
  final String garmentType;

  const SizeSelectorScreen({super.key, required this.garmentType});

  @override
  State<SizeSelectorScreen> createState() => _SizeSelectorScreenState();
}

class _SizeSelectorScreenState extends State<SizeSelectorScreen> {
  final SizeStandardsService _sizeService = SizeStandardsService.instance;

  List<String> _sizeLabels = [];
  bool _loadingSizes = true;
  String? _loadError;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    _fetchSizeLabels();
  }

  Future<void> _fetchSizeLabels() async {
    try {
      final labels = await _sizeService.fetchSizeLabels(widget.garmentType);
      if (!mounted) return;
      setState(() {
        _sizeLabels = labels;
        _loadingSizes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingSizes = false;
      });
    }
  }

  /// Pretty display name for the garment_type database key.
  String get _garmentDisplayName {
    const displayNames = {
      't_shirt': 'T-shirt',
      'sweater': 'Sweater',
      'pants': 'Pants',
      'jeans': 'Jeans',
      'maxi_dress': 'Maxi Dress',
    };
    return displayNames[widget.garmentType] ?? widget.garmentType;
  }

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
              _buildHeader(context),
              Expanded(
                child: _loadingSizes
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.greenDeep),
                        ),
                      )
                    : _loadError != null
                        ? _buildErrorState()
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSizeChips(),
                                const SizedBox(height: 20),
                                _buildSizeChartLink(context),
                                const SizedBox(height: 32),
                                if (_selectedSize != null) _buildContinueButton(context),
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
          // Circular back button (same pattern as capture_screen / garment_type_screen)
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select your size',
                  style: AppTheme.headlineMedium(color: AppTheme.greenDeep).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _garmentDisplayName,
                  style: AppTheme.bodySmall(color: AppTheme.inkSoft).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.inkSoft),
            const SizedBox(height: 12),
            Text(
              'Could not load sizes',
              style: AppTheme.bodyLarge(color: AppTheme.ink),
            ),
            const SizedBox(height: 6),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall(color: AppTheme.inkSoft),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loadingSizes = true;
                  _loadError = null;
                });
                _fetchSizeLabels();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.greenDeep,
                foregroundColor: AppTheme.cream,
                shape: const StadiumBorder(),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Row of pill-shaped size chips.
  /// Unselected: dashed border, transparent fill.
  /// Selected: filled greenDeep, cream text.
  Widget _buildSizeChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _sizeLabels.map((label) {
        final isSelected = _selectedSize == label;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedSize = label;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.greenDeep : Colors.transparent,
              borderRadius: BorderRadius.circular(40),
            ),
            child: CustomPaint(
              painter: isSelected
                  ? null
                  : _DashedPillPainter(
                      color: AppTheme.inkSoft.withOpacity(0.5),
                      strokeWidth: 1.4,
                      dashLength: 5,
                      dashGap: 4,
                      borderRadius: 40,
                    ),
              child: Text(
                label,
                style: AppTheme.buttonText(
                  color: isSelected ? AppTheme.cream : AppTheme.inkSoft,
                ).copyWith(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// "View size chart" text link that opens a bottom sheet.
  Widget _buildSizeChartLink(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSizeChartBottomSheet(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.straighten_outlined,
            size: 18,
            color: AppTheme.greenMid,
          ),
          const SizedBox(width: 6),
          Text(
            'View size chart',
            style: AppTheme.bodyMedium(color: AppTheme.greenMid).copyWith(
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: AppTheme.greenMid,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens a bottom sheet displaying the full size chart for the selected garment type.
  /// Fetches data from Supabase via SizeStandardsService.
  void _showSizeChartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _SizeChartSheet(
          garmentType: widget.garmentType,
          displayName: _garmentDisplayName,
          sizeService: _sizeService,
        );
      },
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // Pass both garment_type and size_label to the capture screen
          context.push('/capture', extra: {
            'garment_type': widget.garmentType,
            'size_label': _selectedSize,
          });
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
              'Continue',
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

/// Bottom sheet widget that fetches and displays the size_standards table
/// for the given garment type.
class _SizeChartSheet extends StatefulWidget {
  final String garmentType;
  final String displayName;
  final SizeStandardsService sizeService;

  const _SizeChartSheet({
    required this.garmentType,
    required this.displayName,
    required this.sizeService,
  });

  @override
  State<_SizeChartSheet> createState() => _SizeChartSheetState();
}

class _SizeChartSheetState extends State<_SizeChartSheet> {
  List<Map<String, dynamic>>? _chartData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchChart();
  }

  Future<void> _fetchChart() async {
    try {
      final data = await widget.sizeService.fetchSizeChart(widget.garmentType);
      if (!mounted) return;
      setState(() {
        _chartData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Collects all unique dimension keys across every size row,
  /// preserving insertion order from the first row they appear in.
  List<String> _dimensionKeys() {
    if (_chartData == null || _chartData!.isEmpty) return [];
    final keys = <String>[];
    for (final row in _chartData!) {
      final dims = row['dimensions'] as Map<String, dynamic>;
      for (final k in dims.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    return keys;
  }

  /// Convert a dimension key like "chest_width" to "Chest Width"
  String _prettifyKey(String key) {
    return key
        .split('_')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.greenSoft.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.displayName} Size Chart',
                    style: AppTheme.headlineSmall(color: AppTheme.greenDeep).copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.mintMid,
                        border: Border.all(
                          color: AppTheme.greenSoft.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.greenDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'All measurements in inches',
              style: AppTheme.bodySmall(color: AppTheme.inkSoft),
            ),
          ),
          const SizedBox(height: 12),
          // Content
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.greenDeep),
                      ),
                    ),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Error loading chart: $_error',
                            textAlign: TextAlign.center,
                            style: AppTheme.bodyMedium(color: AppTheme.inkSoft),
                          ),
                        ),
                      )
                    : _buildTable(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_chartData == null || _chartData!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No size data available.',
            style: AppTheme.bodyMedium(color: AppTheme.inkSoft),
          ),
        ),
      );
    }

    final dimKeys = _dimensionKeys();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.mintTop),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        border: TableBorder.all(
          color: AppTheme.greenSoft.withOpacity(0.25),
          width: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        columnSpacing: 18,
        horizontalMargin: 14,
        headingTextStyle: AppTheme.bodySmall(color: AppTheme.greenDeep).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        dataTextStyle: AppTheme.bodyMedium(color: AppTheme.ink).copyWith(
          fontSize: 13,
        ),
        columns: [
          const DataColumn(label: Text('Size')),
          ...dimKeys.map(
            (k) => DataColumn(label: Text(_prettifyKey(k))),
          ),
        ],
        rows: _chartData!.map((row) {
          final dims = row['dimensions'] as Map<String, dynamic>;
          return DataRow(cells: [
            DataCell(Text(
              row['size_label'] as String,
              style: AppTheme.bodyMedium(color: AppTheme.greenDeep).copyWith(
                fontWeight: FontWeight.w700,
              ),
            )),
            ...dimKeys.map(
              (k) => DataCell(Text(dims[k]?.toString() ?? '–')),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

/// Dashed pill-shaped border painter, used for unselected size chips.
class _DashedPillPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double borderRadius;

  _DashedPillPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rRect);
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
  bool shouldRepaint(_DashedPillPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth;
}
