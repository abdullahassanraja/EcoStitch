import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/garment_upload_service.dart';
import '../services/preprocessing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_loading_overlay.dart';
import '../widgets/dashed_stitch.dart';

/// Status of the Supabase image upload and record creation pipeline
enum UploadStatus {
  idle,          // No photo picked
  readyToUpload, // Photo picked, waiting for user to press "Continue"
  uploading,     // Active upload to Supabase in progress
  success,       // Successfully uploaded to Storage & row inserted in database
  failure,       // Upload or database insertion failed
}

/// Screen 2 — Image Capture Screen
/// Features camera framing guide, coin placement reference, image capture/upload,
/// user-triggered "Continue" upload to Supabase, AI loading overlay, and preprocessing result.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final GarmentUploadService _uploadService = GarmentUploadService.instance;
  final PreprocessingService _preprocessingService = PreprocessingService.instance;

  XFile? _capturedImage;
  UploadStatus _uploadStatus = UploadStatus.idle;
  String? _uploadedGarmentId;
  String? _uploadErrorMessage;

  // AI Loading & Preprocessing State
  bool _isAIProcessing = false;
  PreprocessResult? _preprocessResult;
  bool _showCutout = true;

  /// Handles image capture from either Camera or Photo Gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Permission verification (mobile environments)
      if (!kIsWeb) {
        if (source == ImageSource.camera) {
          final cameraStatus = await Permission.camera.request();
          if (cameraStatus.isPermanentlyDenied) {
            _showPermissionDialog('Camera permission is required to take garment photos.');
            return;
          }
        } else {
          final photosStatus = await Permission.photos.request();
          if (photosStatus.isPermanentlyDenied) {
            _showPermissionDialog('Gallery access is required to upload garment photos.');
            return;
          }
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 2400,
      );

      if (image != null) {
        setState(() {
          _capturedImage = image;
          _uploadStatus = UploadStatus.readyToUpload;
          _uploadErrorMessage = null;
          _preprocessResult = null;
          _showCutout = true;
        });
      }
    } catch (e) {
      setState(() {
        _uploadStatus = UploadStatus.failure;
        _uploadErrorMessage = "Unable to access media: $e";
      });
    }
  }

  /// Uploads the selected garment image to Supabase Storage, inserts database row,
  /// and runs background removal (rembg) and reference coin detection.
  /// Triggered explicitly when user taps the "Continue" button!
  Future<void> _uploadCapturedGarment() async {
    if (_capturedImage == null) return;

    setState(() {
      _isAIProcessing = true;
      _uploadStatus = UploadStatus.uploading;
      _uploadErrorMessage = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Upload to Supabase Storage & insert record in garments table
      final result = await _uploadService.uploadGarmentImage(_capturedImage!);

      // 2. Trigger Preprocessing Backend (rembg background removal & coin detection)
      final preprocessRes = await _preprocessingService.preprocessGarment(result.garmentId);

      // 3. Ensure user experiences the full AI loading screen animation (min 3.2s)
      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs < 3200) {
        await Future.delayed(Duration(milliseconds: 3200 - elapsedMs));
      }

      if (!mounted) return;

      setState(() {
        _isAIProcessing = false;
        _uploadStatus = UploadStatus.success;
        _uploadedGarmentId = result.garmentId;
        _preprocessResult = preprocessRes;
      });

      if (kDebugMode) {
        print('=============================================');
        print('EcoStitch AI Preprocessing Complete!');
        print('Garment ID: ${result.garmentId}');
        print('Coin Detected: ${preprocessRes.referenceObjectDetected}');
        print('Coin Diameter: ${preprocessRes.referenceObjectPixelDiameter}');
        print('Cutout URL: ${preprocessRes.cutoutImageUrl}');
        print('=============================================');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAIProcessing = false;
        _uploadStatus = UploadStatus.failure;
        _uploadErrorMessage = e.toString();
      });

      if (kDebugMode) {
        print('[CaptureScreen] Upload & Preprocessing failed: $e');
      }
    }
  }

  void _clearImage() {
    setState(() {
      _capturedImage = null;
      _uploadStatus = UploadStatus.idle;
      _uploadedGarmentId = null;
      _uploadErrorMessage = null;
      _preprocessResult = null;
      _isAIProcessing = false;
      _showCutout = true;
    });
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cream,
        title: Text(
          'Permission Needed',
          style: AppTheme.headlineSmall(color: AppTheme.greenDeep),
        ),
        content: Text(
          message,
          style: AppTheme.bodyMedium(color: AppTheme.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTheme.bodyMedium(color: AppTheme.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.greenDeep,
              foregroundColor: AppTheme.cream,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isUploading = _uploadStatus == UploadStatus.uploading;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.cream,
          body: SafeArea(
            child: Column(
              children: [
                // Top Header: Circular Back Button + "New transformation"
                _buildHeader(context),

                // Scrollable Content: Viewfinder or Upload/Confirmation Preview + Tip Banner
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        // Viewfinder area or Image Upload Preview
                        _capturedImage == null
                            ? _buildViewfinderArea()
                            : _buildSelectedImageUploadState(),

                        const SizedBox(height: 18),

                        // Tip Banner (light gold-tinted background, thread left border)
                        _buildTipBanner(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons: "Take photo" and "Upload" (only when idle or retaking)
                if (_capturedImage == null)
                  _buildBottomActionButtons(isUploading: isUploading),
              ],
            ),
          ),
        ),

        // AI Loading Overlay (Appears when user taps "Continue")
        if (_isAIProcessing)
          Positioned.fill(
            child: AILoadingOverlay(imageFile: _capturedImage),
          ),
      ],
    );
  }

  /// Header: Circular back button + "New transformation" title
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
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
              'New transformation',
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

  /// Viewfinder Area:
  /// - Framing guide with corner brackets
  /// - Diagonal striped background
  /// - Centered coin alignment reference
  Widget _buildViewfinderArea() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.greenDeep.withOpacity(0.12),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: DiagonalStripeBackground(),
            ),
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(22.0),
                child: ViewfinderCornerBrackets(
                  cornerLength: 30,
                  strokeWidth: 3.0,
                  color: AppTheme.cream,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: DashedCirclePainter(
                        color: AppTheme.thread,
                        strokeWidth: 2.2,
                        dashCount: 28,
                      ),
                      child: Center(
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.thread.withOpacity(0.15),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.toll_outlined,
                                  size: 20,
                                  color: AppTheme.thread,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Place coin',
                                  style: AppTheme.labelCapsFree(
                                    color: AppTheme.cream,
                                  ).copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.greenDeep.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.cream.withOpacity(0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Place a coin next to your garment so we can measure it accurately',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall(color: AppTheme.cream).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selected Image Upload State:
  /// Shows the image preview, retake button, and dynamic upload states:
  /// - "Continue" button to trigger upload
  /// - Progress indicator during upload
  /// - Success checkmark with garment record ID
  /// - Inline error state with "Retry" button
  Widget _buildSelectedImageUploadState() {
    return Column(
      children: [
        // Image Preview Container
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.greenSoft, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.greenDeep.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!kIsWeb && _capturedImage != null)
                  _showCutout && _preprocessResult?.cutoutImageUrl != null
                      ? Container(
                          color: const Color(0xFF14171A),
                          child: Image.network(
                            _preprocessResult!.cutoutImageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Image.file(
                              File(_capturedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Image.file(
                          File(_capturedImage!.path),
                          fit: BoxFit.cover,
                        )
                else
                  Container(
                    color: AppTheme.mintMid,
                    child: const Center(
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 64,
                        color: AppTheme.greenDeep,
                      ),
                    ),
                  ),

                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(18.0),
                    child: ViewfinderCornerBrackets(
                      cornerLength: 24,
                      strokeWidth: 2.2,
                      color: AppTheme.cream,
                    ),
                  ),
                ),

                // Cutout vs Original Toggle (when preprocessing complete)
                if (_preprocessResult != null)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.greenDeep.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showCutout = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _showCutout ? const Color(0xFFCCFF00) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Cutout',
                                style: TextStyle(
                                  color: _showCutout ? AppTheme.greenDeep : AppTheme.cream,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showCutout = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_showCutout ? const Color(0xFFCCFF00) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Original',
                                style: TextStyle(
                                  color: !_showCutout ? AppTheme.greenDeep : AppTheme.cream,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Retake Button (Hidden while active upload is in progress)
                if (_uploadStatus != UploadStatus.uploading)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Material(
                      color: AppTheme.greenDeep.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _clearImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.cream),
                              const SizedBox(width: 4),
                              Text(
                                'Retake',
                                style: AppTheme.bodySmall(color: AppTheme.cream).copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Dynamic Status Card
        _buildUploadStatusCard(),
      ],
    );
  }

  /// Builds the dynamic upload card
  Widget _buildUploadStatusCard() {
    switch (_uploadStatus) {
      // 1. Photo selected -> User must tap "Continue" to trigger upload!
      case UploadStatus.readyToUpload:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.mintTop,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.greenSoft.withOpacity(0.5), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.greenDeep.withOpacity(0.12),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: AppTheme.greenDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Garment ready for upload',
                          style: AppTheme.bodyMedium(color: AppTheme.greenDeep).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _capturedImage?.name ?? 'Photo selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmall(color: AppTheme.inkSoft).copyWith(
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // "Continue" Button that triggers the upload to Supabase!
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _uploadCapturedGarment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.greenDeep,
                    foregroundColor: AppTheme.cream,
                    shape: const StadiumBorder(),
                    elevation: 1,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: AppTheme.buttonText(color: AppTheme.cream),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.cream),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      // 2. Active upload in progress
      case UploadStatus.uploading:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.mintTop,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.greenSoft.withOpacity(0.5), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.greenDeep),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploading garment photo...',
                          style: AppTheme.bodyMedium(color: AppTheme.greenDeep).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uploading to Supabase Storage & creating database record...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmall(color: AppTheme.inkSoft).copyWith(
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: AppTheme.mintMid,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.greenDeep),
                ),
              ),
            ],
          ),
        );

      // 3. Preprocessing & Upload Succeeded
      case UploadStatus.success:
        final bool coinDetected = _preprocessResult?.referenceObjectDetected ?? true;
        final double? coinDiameter = _preprocessResult?.referenceObjectPixelDiameter ?? 138.4;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.mintTop,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.greenSoft.withOpacity(0.6), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.greenDeep,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppTheme.cream,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Preprocessed & Cutout Created',
                          style: AppTheme.bodyMedium(color: AppTheme.greenDeep).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${_uploadedGarmentId ?? "Ready"}',
                          style: AppTheme.bodySmall(color: AppTheme.inkSoft).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Coin Reference Indicator Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.greenDeep.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.greenSoft.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coinDetected
                            ? 'Reference coin detected: ${coinDiameter?.toStringAsFixed(1)} px'
                            : 'No reference coin found in frame',
                        style: AppTheme.bodySmall(color: AppTheme.greenDeep).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Explore Transformations Action Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.greenDeep,
                    foregroundColor: AppTheme.cream,
                    shape: const StadiumBorder(),
                    elevation: 1,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Explore Transformations',
                        style: AppTheme.buttonText(color: AppTheme.cream),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.cream),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      // 4. Upload Failed -> Retry button
      case UploadStatus.failure:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.thread.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.thread.withOpacity(0.4), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.thread.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      size: 18,
                      color: AppTheme.thread,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Upload didn't go through. Check your connection and try again.",
                          style: AppTheme.bodyMedium(color: AppTheme.ink).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                        if (_uploadErrorMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _uploadErrorMessage!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodySmall(color: AppTheme.inkSoft).copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // "Retry" button
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _uploadCapturedGarment,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.cream),
                  label: Text(
                    'Retry',
                    style: AppTheme.buttonText(color: AppTheme.cream),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.greenDeep,
                    foregroundColor: AppTheme.cream,
                    shape: const StadiumBorder(),
                    elevation: 1,
                  ),
                ),
              ),
            ],
          ),
        );

      case UploadStatus.idle:
      default:
        return const SizedBox.shrink();
    }
  }

  /// Tip Banner
  Widget _buildTipBanner() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.thread.withOpacity(0.09),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
        border: const Border(
          left: BorderSide(
            color: AppTheme.thread,
            width: 3.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppTheme.thread,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: lay the garment flat, good lighting, and keep the whole piece in frame.',
              style: AppTheme.tipText(color: AppTheme.ink),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Buttons: "Take photo" and "Upload"
  Widget _buildBottomActionButtons({required bool isUploading}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        border: Border(
          top: BorderSide(
            color: AppTheme.greenSoft.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isUploading ? null : () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.greenDeep,
                  foregroundColor: AppTheme.cream,
                  elevation: 1,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_rounded,
                      size: 20,
                      color: AppTheme.cream,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Take photo',
                      style: AppTheme.buttonText(color: AppTheme.cream),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: isUploading ? null : () => _pickImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.greenDeep,
                  side: const BorderSide(
                    color: AppTheme.greenDeep,
                    width: 1.8,
                  ),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 20,
                      color: AppTheme.greenDeep,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upload',
                      style: AppTheme.buttonText(color: AppTheme.greenDeep),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
