import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project configuration.
///
/// Never place a secret or service-role key in this file.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = 'https://rgyejlwlchullubbhhvj.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_NAfeFsjU8elRcAH-wm5IKA__a9k_5MP';

  static bool isInitialized = false;
  static String? pendingOAuthError;

  static bool get isSupabaseConfigured {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) return false;
    if (supabaseUrl.startsWith('YOUR_') ||
        supabasePublishableKey.startsWith('YOUR_')) {
      return false;
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      return false;
    }
    return supabasePublishableKey.length >= 20;
  }

  static Future<void> initializeIfConfigured() async {
    if (!isSupabaseConfigured) return;
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        
      ),
    );
    isInitialized = true;
  }
}
