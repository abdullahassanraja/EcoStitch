import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class AILoadingStage {
  final String text;
  final String detail;
  final String step;
  final double progress;
  final String subsystem;

  const AILoadingStage({
    required this.text,
    required this.detail,
    required this.step,
    required this.progress,
    required this.subsystem,
  });
}

/// An impressive AI-style loading screen overlay featuring:
/// - Rotating cybernetic radar rings
/// - Vertical laser beam scanning across the garment preview
/// - Smooth rolling text messages (Saving image -> Eco impact -> Background removal -> Coin scale)
/// - Shimmering electric lime progress indicators and subsystem tags
class AILoadingOverlay extends StatefulWidget {
  final XFile? imageFile;
  final VoidCallback? onCancel;

  const AILoadingOverlay({
    super.key,
    this.imageFile,
    this.onCancel,
  });

  @override
  State<AILoadingOverlay> createState() => _AILoadingOverlayState();
}

class _AILoadingOverlayState extends State<AILoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _radarController;
  late final AnimationController _laserController;
  late final AnimationController _textFadeController;

  int _currentStageIndex = 0;
  Timer? _stageTimer;

  static const List<AILoadingStage> _stages = [
    AILoadingStage(
      text: "You're making the world a better place to live",
      detail: 'Saving image to Supabase cloud storage...',
      step: 'Stage 1 of 4: Cloud Ingestion',
      progress: 0.24,
      subsystem: 'Storage Sync',
    ),
    AILoadingStage(
      text: 'One less garment in a landfill, one more creative piece',
      detail: 'Removing background with rembg AI...',
      step: 'Stage 2 of 4: Neural Segmentation',
      progress: 0.60,
      subsystem: 'rembg AI',
    ),
    AILoadingStage(
      text: 'Every rescued thread writes a fresh sustainable story',
      detail: 'Detecting reference coin & scale calibration 🪙',
      step: 'Stage 3 of 4: Scale Calibration',
      progress: 0.86,
      subsystem: 'Hough Scale',
    ),
    AILoadingStage(
      text: 'Saving water, reducing waste, transforming style',
      detail: 'Preprocessed cutout blueprint ready ✨',
      step: 'Complete: Ready for Upcycling',
      progress: 1.0,
      subsystem: 'Ready',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1.0,
    );

    // Roll through stages smoothly every 1600ms
    _stageTimer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (_currentStageIndex < _stages.length - 1) {
        _textFadeController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentStageIndex++;
            });
            _textFadeController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _laserController.dispose();
    _textFadeController.dispose();
    _stageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = _stages[_currentStageIndex];

    return Material(
      color: const Color(0xF2080D0A), // Deep obsidian glass backdrop
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient radial glow
          Positioned(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFCCFF00).withOpacity(0.16),
                    const Color(0xFF00E599).withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Card Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top AI Engine Chip
                  _buildEngineChip(),

                  const SizedBox(height: 28),

                  // Scanner Viewport with Radar and Laser Beam
                  _buildScannerStage(),

                  const SizedBox(height: 28),

                  // Rolling Text Carousel Box
                  _buildRollingTextBox(currentStage),

                  const SizedBox(height: 24),

                  // Progress Bar & Percentage
                  _buildProgressSection(currentStage),

                  const SizedBox(height: 20),

                  // Subsystems Badges
                  _buildSubsystemsRow(currentStage),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFCCFF00).withOpacity(0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCCFF00).withOpacity(0.12),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFCCFF00),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFCCFF00),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'ECOSTITCH AI VISION ENGINE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFF00),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'v3.4',
              style: TextStyle(
                color: Color(0xFF0C0D0E),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerStage() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating Radar Outer Ring
          AnimatedBuilder(
            animation: _radarController,
            builder: (_, __) {
              return Transform.rotate(
                angle: _radarController.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(160, 160),
                  painter: _RadarRingPainter(color: const Color(0xFFCCFF00)),
                ),
              );
            },
          ),

          // Central Garment Thumbnail
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF142018),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!kIsWeb && widget.imageFile != null)
                  Image.file(
                    File(widget.imageFile!.path),
                    fit: BoxFit.cover,
                  )
                else
                  const Center(
                    child: Icon(
                      Icons.checkroom_rounded,
                      size: 48,
                      color: Color(0xFFCCFF00),
                    ),
                  ),

                // Scanning Laser Beam Sweeping Vertically
                AnimatedBuilder(
                  animation: _laserController,
                  builder: (_, __) {
                    return Align(
                      alignment: Alignment(0, (_laserController.value * 2) - 1),
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFFCCFF00),
                              const Color(0xFF00FF9D),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCCFF00).withOpacity(0.8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRollingTextBox(AILoadingStage currentStage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 12),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: Color(0xFFCCFF00),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, animation) {
                final inAnimation = Tween<Offset>(
                  begin: const Offset(0.0, 0.8),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                return ClipRect(
                  child: SlideTransition(
                    position: inAnimation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
              child: Column(
                key: ValueKey<int>(_currentStageIndex),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentStage.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    currentStage.detail,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(AILoadingStage currentStage) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentStage.step,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(currentStage.progress * 100).toInt()}%',
              style: const TextStyle(
                color: Color(0xFFCCFF00),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStage.progress,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCCFF00)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubsystemsRow(AILoadingStage currentStage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSubsystemPill(
          'Storage Sync',
          isActive: currentStage.progress >= 0.2,
          isDone: currentStage.progress >= 0.45,
        ),
        const SizedBox(width: 6),
        _buildSubsystemPill(
          'rembg AI',
          isActive: currentStage.progress >= 0.46,
          isDone: currentStage.progress >= 0.75,
        ),
        const SizedBox(width: 6),
        _buildSubsystemPill(
          'Hough Scale',
          isActive: currentStage.progress >= 0.75,
          isDone: currentStage.progress >= 0.95,
        ),
      ],
    );
  }

  Widget _buildSubsystemPill(String label, {required bool isActive, required bool isDone}) {
    Color textColor = Colors.white.withOpacity(0.35);
    Color borderColor = Colors.white.withOpacity(0.06);
    Color dotColor = Colors.white.withOpacity(0.2);

    if (isDone) {
      textColor = const Color(0xFF00E599);
      borderColor = const Color(0xFF00E599).withOpacity(0.35);
      dotColor = const Color(0xFF00E599);
    } else if (isActive) {
      textColor = const Color(0xFFCCFF00);
      borderColor = const Color(0xFFCCFF00).withOpacity(0.35);
      dotColor = const Color(0xFFCCFF00);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarRingPainter extends CustomPainter {
  final Color color;
  const _RadarRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    const count = 36;
    const sweep = (2 * math.pi) / count;

    for (int i = 0; i < count; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * 0.8,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarRingPainter oldDelegate) => false;
}
