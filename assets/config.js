// ============================================================
// إعدادات الاتصال بـ Supabase
// عدّل القيمتين التاليتين بالقيم الخاصة بمشروعك في Supabase:
// Project Settings -> API -> Project URL / anon public key
// ============================================================
const SUPABASE_URL = "https://uivdggyetztcmxogcaob.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpdmRnZ3lldHp0Y214b2djYW9iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4NDE5MjMsImV4cCI6MjA5ODQxNzkyM30.qH00B5Q6u6HpaREmlxcfMQq5BjFEFSlraFmwc-AeGMc";

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
