import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static const _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const _anonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url => _urlFromDefine.isNotEmpty
      ? _urlFromDefine
      : dotenv.maybeGet('SUPABASE_URL') ?? '';

  static String get anonKey => _anonKeyFromDefine.isNotEmpty
      ? _anonKeyFromDefine
      : dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
