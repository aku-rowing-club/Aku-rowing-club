// api/invite-member.js
// Vercel serverless function — auto-deployed when pushed to GitHub
// No CLI, no terminal needed

export default async function handler(req, res) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')

  if (req.method === 'OPTIONS') return res.status(200).end()
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })

  try {
    const { email, full_name, admin_role } = req.body

    if (!email || !full_name) {
      return res.status(400).json({ error: 'Email and full name are required' })
    }

    // Verify the caller is an admin using their JWT
    const authHeader = req.headers.authorization
    if (!authHeader) return res.status(401).json({ error: 'Not authenticated' })

    const SUPABASE_URL = process.env.SUPABASE_URL
    const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
    const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY
    const SITE_URL = process.env.SITE_URL || 'https://project-uadgz.vercel.app'

    // Verify caller is admin
    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        'Authorization': authHeader,
        'apikey': SUPABASE_ANON_KEY,
      }
    })
    const userData = await userRes.json()
    if (!userData.id) return res.status(401).json({ error: 'Invalid session' })

    const profileRes = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${userData.id}&select=admin_role`,
      {
        headers: {
          'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
          'apikey': SUPABASE_SERVICE_KEY,
        }
      }
    )
    const profiles = await profileRes.json()
    if (!profiles?.[0] || profiles[0].admin_role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' })
    }

    // Send invite via Supabase Admin API
    const inviteRes = await fetch(`${SUPABASE_URL}/auth/v1/invite`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'apikey': SUPABASE_SERVICE_KEY,
      },
      body: JSON.stringify({
        email,
        data: { full_name },
        redirect_to: `${SITE_URL}/onboarding.html`,
      })
    })

    const inviteData = await inviteRes.json()

    if (!inviteRes.ok) {
      throw new Error(inviteData.msg || inviteData.error || 'Failed to send invite')
    }

    // Pre-create profile
    const initials = full_name.split(' ').filter(Boolean).map(w => w[0]).join('').slice(0,2).toUpperCase()

    await fetch(`${SUPABASE_URL}/rest/v1/profiles`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'apikey': SUPABASE_SERVICE_KEY,
        'Prefer': 'resolution=merge-duplicates',
      },
      body: JSON.stringify({
        id: inviteData.id,
        full_name,
        initials,
        admin_role: admin_role || null,
        onboarding_complete: false,
      })
    })

    return res.status(200).json({
      success: true,
      message: `Invite sent to ${email}`
    })

  } catch (err) {
    console.error('Invite error:', err)
    return res.status(500).json({ error: err.message })
  }
}
