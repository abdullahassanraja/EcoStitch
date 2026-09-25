import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for fetching size standard data from the Supabase `size_standards` table.
/// Kept separate from GarmentUploadService to maintain single-responsibility.
class SizeStandardsService {
  SizeStandardsService._();
  static final SizeStandardsService instance = SizeStandardsService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Returns the list of available size labels for a given garment type.
  /// e.g. for 't_shirt' -> ['S', 'M', 'L', 'XL', 'XXL']
  /// e.g. for 'maxi_dress' -> ['XS', 'S', 'M', 'L', 'XL']
  // Note: sweater and t_shirt currently share identical rows in size_standards on purpose, this is intentional, not a bug to fix.
  Future<List<String>> fetchSizeLabels(String garmentType) async {
    try {
      final response = await _client
          .from('size_standards')
          .select('size_label')
          .eq('garment_type', garmentType)
          .order('id', ascending: true);

      final labels = (response as List)
          .map((row) => row['size_label'] as String)
          .toList();

      if (kDebugMode) {
        print('[SizeStandardsService] Fetched ${labels.length} sizes for $garmentType: $labels');
      }

      return labels;
    } catch (e) {
      if (kDebugMode) {
        print('[SizeStandardsService] Error fetching size labels for $garmentType: $e');
      }
      rethrow;
    }
  }

  /// Fetches the full size chart for a given garment type from the `size_standards` table.
  /// Returns a list of maps, each containing 'size_label' and 'dimensions' (decoded jsonb).
  /// Used by the "View size chart" bottom sheet.
  Future<List<Map<String, dynamic>>> fetchSizeChart(String garmentType) async {
    try {
      final response = await _client
          .from('size_standards')
          .select('size_label, dimensions')
          .eq('garment_type', garmentType)
          .order('id', ascending: true);

      final rows = (response as List)
          .map((row) => {
                'size_label': row['size_label'] as String,
                'dimensions': row['dimensions'] as Map<String, dynamic>,
              })
          .toList();

      if (kDebugMode) {
        print('[SizeStandardsService] Fetched size chart for $garmentType: ${rows.length} rows');
      }

      return rows;
    } catch (e) {
      if (kDebugMode) {
        print('[SizeStandardsService] Error fetching size chart for $garmentType: $e');
      }
      rethrow;
    }
  }
}
