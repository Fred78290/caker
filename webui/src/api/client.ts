import axios from 'axios';

// In production the web UI is served from the same origin as caked,
// so relative URLs work for both dev (via Vite proxy) and production.
const client = axios.create({
  baseURL: '/',
  headers: { 'Content-Type': 'application/json' },
})

export default client
