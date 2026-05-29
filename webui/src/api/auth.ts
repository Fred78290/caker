import type { LXDAuthGroup, LXDCertificate, LXDIdentity, LXDResponse } from '../types/lxd';
import client from './client';

// ---------------------------------------------------------------------------
// Auth groups
// ---------------------------------------------------------------------------

export const listGroups = () =>
  client.get<LXDResponse<LXDAuthGroup[]>>('/1.0/auth/groups?recursion=1')

export const getGroup = (name: string) =>
  client.get<LXDResponse<LXDAuthGroup>>(`/1.0/auth/groups/${name}`)

export const createGroup = (name: string, description = '') =>
  client.post<LXDResponse<unknown>>('/1.0/auth/groups', {
    name,
    description,
    permissions: [],
    identities: { oidc: [], tls: [] },
    identity_provider_groups: [],
  })

export const deleteGroup = (name: string) =>
  client.delete<LXDResponse<unknown>>(`/1.0/auth/groups/${name}`)

// ---------------------------------------------------------------------------
// Identities
// ---------------------------------------------------------------------------

export const listIdentities = () =>
  client.get<LXDResponse<LXDIdentity[]>>('/1.0/auth/identities?recursion=1')

export const deleteIdentity = (authMethod: string, id: string) =>
  client.delete<LXDResponse<unknown>>(`/1.0/auth/identities/${authMethod}/${id}`)

// ---------------------------------------------------------------------------
// Certificates
// ---------------------------------------------------------------------------

export const listCertificates = () =>
  client.get<LXDResponse<LXDCertificate[]>>('/1.0/certificates?recursion=1')

export const addCertificate = (name: string, certificate: string, type = 'client') =>
  client.post<LXDResponse<unknown>>('/1.0/certificates', {
    name,
    certificate,
    type,
    restricted: false,
    projects: [],
  })

export const deleteCertificate = (fingerprint: string) =>
  client.delete<LXDResponse<unknown>>(`/1.0/certificates/${fingerprint}`)
