// ============================================================
// إعدادات الاتصال بـ Supabase
// عدّل القيمتين التاليتين بالقيم الخاصة بمشروعك في Supabase:
// Project Settings -> API -> Project URL / anon public key
// ============================================================
const SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
const SUPABASE_ANON_KEY = "YOUR-ANON-PUBLIC-KEY";

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
