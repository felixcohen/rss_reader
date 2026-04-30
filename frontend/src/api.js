const BASE = '/api'

async function req(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  })
  if (!res.ok) throw new Error(`${options.method || 'GET'} ${path} → ${res.status}`)
  return res.status === 204 ? null : res.json()
}

export const api = {
  getFeeds: () => req('/feeds'),
  getGroups: () => req('/groups'),

  getItems: (params = {}) => {
    const qs = new URLSearchParams(
      Object.fromEntries(Object.entries(params).filter(([, v]) => v != null))
    ).toString()
    return req(`/items${qs ? `?${qs}` : ''}`)
  },

  patchItem: (id, updates) =>
    req(`/items/${id}`, { method: 'PATCH', body: JSON.stringify(updates) }),

  markAllRead: (params = {}) => {
    const qs = new URLSearchParams(params).toString()
    return req(`/items/mark-all-read${qs ? `?${qs}` : ''}`, { method: 'POST' })
  },

  refreshFeed: (id) => req(`/feeds/${id}/refresh`),
}
