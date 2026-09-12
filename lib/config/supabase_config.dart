/// Supabase Configuration for EcoStitch
///
/// Contains the Supabase project URL, anonymous public key,
/// and storage bucket constants.
class SupabaseConfig {
  /// Supabase Project URL
  /// Replace with your own project URL if needed.
  static const String supabaseUrl = 'https://pxwzpklkpbiycslxytqm.supabase.co';

  /// Supabase Anonymous Public API Key (anon key)
  /// Replace with your own anon key if needed.
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4d3pwa2xrcGJpeWNzbHh5dHFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4ODkzNjQsImV4cCI6MjEwNDQ2NTM2NH0.waPaLKcslvzc6SyTIHDHE2TQaIZ1DcjoERVZ3Om2CLI';

  /// Storage bucket for raw and uploaded garment images
  static const String garmentImagesBucket = 'garment-images';

  /// Database table for garments
  static const String garmentsTable = 'garments';
}
