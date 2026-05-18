// portal-init.js
// Include in every portal page — loads real user, fills topbar, checks onboarding

async function portalInit() {
  const { data: { session } } = await db.auth.getSession()
  if (!session) { window.location.replace('../login.html'); return null; }

  const { data: profile, error } = await db
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .single()

  if (error || !profile) { window.location.replace('../login.html'); return null; }

  // If onboarding not complete, send them back
  if (!profile.onboarding_complete) {
    window.location.replace('../onboarding.html'); return null;
  }

  // Fill topbar
  const av = document.getElementById('user-av')
  const nm = document.getElementById('user-name')
  if (av) {
    av.textContent = profile.initials || (profile.full_name?.split(' ').map(w=>w[0]).join('').slice(0,2).toUpperCase()) || '?'
    av.style.background = profile.color || 'linear-gradient(135deg,#534AB7,#7A6FD4)'
  }
  if (nm) nm.textContent = profile.full_name || 'Member'

  // Fill sidebar name if present
  const sbName = document.getElementById('sb-member-name')
  if (sbName) sbName.textContent = profile.full_name || 'Member'

  const sbRole = document.getElementById('sb-member-role')
  if (sbRole) sbRole.textContent = profile.role || 'Member'

  return { user: session.user, profile }
}
