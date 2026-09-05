import 'package:supabase_flutter/supabase_flutter.dart';

// Practical 11: the Supabase connection details are kept as top-level
// constants. Server URL from the dashboard's Connect -> Flutter tab; the
// publishable key from Project Settings -> API Keys (the "publishable"
// key is safe to ship in a client app - Row Level Security protects the
// data; never paste the secret key here).
const String supabaseUrl = 'https://jytfarbtchbqvaoaxufg.supabase.co';
const String supabaseKey = 'sb_publishable_8p0rG6mrJjk_tH-OvPB8jA_pxgAIjBw';

// Practical 11: one shared Supabase client for the whole app.
// Safe to read only after Supabase.initialize() has run in main().
final supabase = Supabase.instance.client;
