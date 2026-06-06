import axios from 'axios';

// In production the web UI is served from the same origin as caked,
// so relative URLs work for both dev (via Vite proxy) and production.
const client = axios.create({
  baseURL: '/',
  // `X-Requested-With` flags this as the SPA's own XHR traffic so caked can
  // avoid sending a `WWW-Authenticate: Basic` challenge that would trigger the
  // browser's native credential dialog over our custom login page.
  headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
})

// Apply any credential stored from a previous login in this session.
const stored = sessionStorage.getItem('cakerCredential')
if (stored) {
  client.defaults.headers.common['Authorization'] = `Basic ${stored}`
}

// Notify AuthContext of 401 responses so it can reset the auth state.
client.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err?.response?.status === 401) {
      window.dispatchEvent(new CustomEvent('caker:unauthorized'))
    }
    return Promise.reject(err)
  }
)

export default client
