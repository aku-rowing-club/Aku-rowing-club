// ═══════════════════════════════════════════════════════
// AKU Rowing Club — Supabase Auth Client
// Include this script in every portal page
// ═══════════════════════════════════════════════════════

// Replace these two values with yours from Supabase dashboard
// Settings → API → Project URL and anon public key
const SUPABASE_URL = 'YOUR_SUPABASE_URL'
const SUPABASE_KEY = 'YOUR_SUPABASE_ANON_KEY'

const { createClient } = supabase
const db = createClient(SUPABASE_URL, SUPABASE_KEY)

// ─── AUTH GUARD ──────────────────────────────────────────
// Call this at the top of every portal page
// It redirects to login if no session, returns {user, profile}
async function requireAuth(expectedRole = null) {
  const { data: { session }, error } = await db.auth.getSession()

  if (!session) {
    window.location.replace('../login.html')
    return null
  }

  const { data: profile } = await db
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .single()

  if (!profile) {
    window.location.replace('../login.html')
    return null
  }

  // Role check — redirect wrong portal
  if (expectedRole && profile.portal_role !== expectedRole) {
    const redirects = {
      member: '../portal/dashboard.html',
      coach:  '../coach/dashboard.html',
      admin:  '../admin/dashboard.html',
    }
    window.location.replace(redirects[profile.portal_role] || '../login.html')
    return null
  }

  return { user: session.user, profile }
}

// ─── SIGN OUT ────────────────────────────────────────────
async function signOut() {
  await db.auth.signOut()
  window.location.replace('../login.html')
}

// ─── FILL USER UI ────────────────────────────────────────
// Populates avatar, name in topbar once profile is loaded
function fillUserUI(profile) {
  const av = document.querySelector('.tb-av')
  const nm = document.querySelector('.tb-name')
  if (av) {
    av.textContent = profile.initials || profile.full_name?.slice(0,2).toUpperCase()
    av.style.background = profile.color || '#1FB8C9'
  }
  if (nm) nm.textContent = profile.full_name
}
