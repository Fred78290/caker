import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';
import client from '../api/client';

export type AuthMethod = 'basic' | 'bearer' | 'tls-certificate'

interface AuthState {
  isAuthenticated: boolean
  isAuthLoading: boolean
  /** Auth methods advertised by the server's 401 WWW-Authenticate header. */
  authMethods: AuthMethod[]
  login: (password: string) => Promise<void>
  logout: () => void
}

const STORAGE_KEY = 'cakerCredential' // sessionStorage key for Basic auth token

const AuthContext = createContext<AuthState | null>(null)

/** Encode and apply stored credentials (Basic auth) to the shared axios instance. */
export function applyStoredCredential() {
  const token = sessionStorage.getItem(STORAGE_KEY)
  if (token) {
    client.defaults.headers.common['Authorization'] = `Basic ${token}`
  } else {
    delete client.defaults.headers.common['Authorization']
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [isAuthLoading, setIsAuthLoading] = useState(true)
  const [authMethods, setAuthMethods] = useState<AuthMethod[]>([])

  const checkAuth = useCallback(async () => {
    try {
      applyStoredCredential()
      await client.get('/1.0')
      setIsAuthenticated(true)
    } catch (err: any) {
      setIsAuthenticated(false)
      if (err?.response?.status === 401) {
        const wwwAuth: string = err.response.headers['www-authenticate'] ?? ''
        const methods: AuthMethod[] = []
        if (wwwAuth.includes('Basic')) methods.push('basic')
        if (wwwAuth.includes('Bearer')) methods.push('bearer')
        if (wwwAuth.toLowerCase().includes('tls-certificate')) methods.push('tls-certificate')
        setAuthMethods(methods)
      }
    } finally {
      setIsAuthLoading(false)
    }
  }, [])

  // Listen for 401s emitted by the axios interceptor in client.ts
  useEffect(() => {
    const handle = () => {
      sessionStorage.removeItem(STORAGE_KEY)
      setIsAuthenticated(false)
    }
    window.addEventListener('caker:unauthorized', handle)
    return () => window.removeEventListener('caker:unauthorized', handle)
  }, [])

  useEffect(() => {
    checkAuth()
  }, [checkAuth])

  const login = useCallback(async (password: string) => {
    // Basic auth: base64("caker:<password>") — username is ignored by PasswordAuthMiddleware
    const token = btoa(`caker:${password}`)
    sessionStorage.setItem(STORAGE_KEY, token)
    client.defaults.headers.common['Authorization'] = `Basic ${token}`

    // Verify credentials
    await client.get('/1.0') // throws on 401 → caller shows error
    setIsAuthenticated(true)
  }, [])

  const logout = useCallback(() => {
    sessionStorage.removeItem(STORAGE_KEY)
    delete client.defaults.headers.common['Authorization']
    setIsAuthenticated(false)
  }, [])

  return (
    <AuthContext.Provider value={{ isAuthenticated, isAuthLoading, authMethods, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>')
  return ctx
}
