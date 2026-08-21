import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration - ISI CMI Prep project
class SupabaseConfig {
  static const String supabaseUrl = 'https://clttuvvgysazcdineztz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsdHR1dnZneXNhemNkaW5lenR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczMjIzNTMsImV4cCI6MjEwMjg5ODM1M30.bIGf-8rEyL5Wt68p5aPnOQW6Vaj1h31RJQF-E3tXHEk';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}

/// Global Supabase client accessor
SupabaseClient get supabase => Supabase.instance.client;