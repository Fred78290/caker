// TypeScript types mirroring the Swift LXD models in LXDModels.swift.
// All field names use snake_case to match Vapor's useDefaultKeys JSON strategy.

export interface LXDResponse<T> {
  type: 'sync' | 'async' | 'error'
  status: string
  status_code: number
  operation: string
  error_code: number
  error: string
  metadata: T
}

// ---------------------------------------------------------------------------
// Server info
// ---------------------------------------------------------------------------

export interface LXDServerInfo {
  api_extensions: string[]
  api_status: string
  api_version: string
  auth: string
  config: Record<string, string>
  environment: {
    architectures: string[]
    certificate: string
    certificate_fingerprint: string
    driver: string
    driver_version: string
    firewall: string
    kernel: string
    kernel_architecture: string
    kernel_version: string
    ovmf_path: string
    server: string
    server_name: string
    server_version: string
    storage: string
    storage_version: string
  }
}

// ---------------------------------------------------------------------------
// Instances
// ---------------------------------------------------------------------------

export interface LXDInstance {
  architecture: string
  config: Record<string, string>
  created_at: string
  description: string
  ephemeral: boolean
  expanded_config: Record<string, string>
  expanded_devices: Record<string, Record<string, string>>
  last_used_at: string
  location: string
  name: string
  profiles: string[]
  project: string
  stateful: boolean
  status: string
  status_code: number
  type: 'container' | 'virtual-machine'
}

export interface LXDInstanceState {
  cpu: { usage: number }
  disk: Record<string, { usage: number; total: number }>
  memory: {
    swap_usage: number
    swap_usage_peak: number
    total: number
    usage: number
    usage_peak: number
  }
  network?: Record<
    string,
    {
      addresses: { address: string; family: string; netmask: string; scope: string }[]
      hwaddr: string
      mtu: number
      state: string
      type: string
    }
  >
  pid: number
  processes: number
  status: string
  status_code: number
}

export interface LXDCreateInstanceRequest {
  name: string
  source: {
    type: 'image' | 'url' | 'none'
    alias?: string
    fingerprint?: string
    url?: string
  }
  type?: 'virtual-machine' | 'container'
  description?: string
  config?: Record<string, string>
  profiles?: string[]
  user_data?: string
  network_config?: string
}

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

export interface LXDImage {
  aliases: LXDImageAlias[]
  architecture: string
  auto_update: boolean
  cached: boolean
  created_at: string
  expires_at: string
  filename: string
  fingerprint: string
  last_used_at: string
  public: boolean
  size: number
  type: 'container' | 'virtual-machine' | 'iso'
  uploaded_at: string
}

export interface LXDImageAlias {
  description: string
  name: string
}

// ---------------------------------------------------------------------------
// Networks
// ---------------------------------------------------------------------------

export interface LXDNetwork {
  config: Record<string, string>
  description: string
  locations: string[]
  managed: boolean
  name: string
  status: string
  type: string
  used_by: string[]
}

// ---------------------------------------------------------------------------
// Operations
// ---------------------------------------------------------------------------

export interface LXDOperation {
  id: string
  type: string
  description: string
  created_at: string
  updated_at: string
  status: string
  status_code: number
  resources: Record<string, string[]>
  may_cancel: boolean
  error: string
}

// ---------------------------------------------------------------------------
// Auth groups
// ---------------------------------------------------------------------------

export interface LXDAuthGroupPermission {
  entity_type: string
  url: string
  entitlement: string
}

export interface LXDAuthGroup {
  name: string
  description: string
  permissions: LXDAuthGroupPermission[]
  identities: { oidc: string[]; tls: string[] }
  identity_provider_groups: string[]
}

// ---------------------------------------------------------------------------
// Identities
// ---------------------------------------------------------------------------

export interface LXDIdentity {
  authentication_method: string
  type: string
  id: string
  name: string
  groups: string[]
  tls_certificate: string
}

// ---------------------------------------------------------------------------
// Certificates
// ---------------------------------------------------------------------------

export interface LXDCertificate {
  name: string
  type: string
  restricted: boolean
  projects: string[]
  certificate: string
  fingerprint: string
}
