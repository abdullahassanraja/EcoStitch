import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';

/// Result object containing details of an uploaded garment.
class GarmentUploadResult {
  final String garmentId;
  final String storagePath;
  final String userId;

  const GarmentUploadResult({
    required this.garmentId,
    required this.storagePath,
    required this.userId,
  });
}

/// Service dedicated to handling Supabase image uploads and database record creation.
/// Keeps backend & data access logic strictly decoupled from the UI widgets.
class GarmentUploadService {
  GarmentUploadService._();
  static final GarmentUploadService instance = GarmentUploadService._();

  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  /// Ensures an authenticated user session exists.
  /// If the current user is null, triggers anonymous sign-in so every user
  /// receives a valid auth.uid().
  Future<String> ensureAuthenticatedUserId() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser != null) {
      return currentUser.id;
    }

    // Sign in anonymously to establish a session with auth.uid()
    final AuthResponse response = await _client.auth.signInAnonymously();
    if (response.user == null) {
      throw const AuthException('Unable to establish anonymous session with Supabase.');
    }
    return response.user!.id;
  }

  /// Uploads a captured or picked image file to Supabase Storage at:
  /// `garment-images/{userId}/{uuid}.jpg`
  /// and creates a corresponding record in the `garments` database table.
  ///
  /// Returns a [GarmentUploadResult] containing the generated garment ID.
  Future<GarmentUploadResult> uploadGarmentImage(XFile imageFile) async {
    try {
      // 1. Ensure user authentication
      final String userId = await ensureAuthenticatedUserId();

      // 2. Read raw image bytes (cross-platform compatible: mobile, desktop, web)
      final Uint8List fileBytes = await imageFile.readAsBytes();

      if (fileBytes.isEmpty) {
        throw Exception('Selected image file is empty.');
      }

      // 3. Generate a unique filename using UUID v4
      final String fileUuid = _uuid.v4();
      final String storagePath = '$userId/$fileUuid.jpg';

      if (kDebugMode) {
        print('[GarmentUploadService] Uploading image (${fileBytes.length} bytes) to: $storagePath');
      }

      // 4. Upload binary to Supabase Storage bucket 'garment-images'
      await _client.storage.from(SupabaseConfig.garmentImagesBucket).uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      if (kDebugMode) {
        print('[GarmentUploadService] Storage upload successful. Creating database record...');
      }

      // 5. Insert row into 'garments' table
      final Map<String, dynamic> insertPayload = {
        'user_id': userId,
        'image_url': storagePath,
        'status': 'uploaded',
      };

      final response = await _client
          .from(SupabaseConfig.garmentsTable)
          .insert(insertPayload)
          .select('id')
          .single();

      final String garmentId = response['id'].toString();

      if (kDebugMode) {
        print('[GarmentUploadService] Garment record created with ID: $garmentId');
      }

      return GarmentUploadResult(
        garmentId: garmentId,
        storagePath: storagePath,
        userId: userId,
      );
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('[GarmentUploadService] Storage error: ${e.message} (status: ${e.statusCode})');
      }
      throw Exception('Storage upload error: ${e.message}');
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        print('[GarmentUploadService] Database error: ${e.message} (code: ${e.code})');
      }
      throw Exception('Database record error: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        print('[GarmentUploadService] Unexpected upload error: $e');
      }
      rethrow;
    }
  }
}
