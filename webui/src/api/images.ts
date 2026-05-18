import type { LXDImage, LXDResponse } from '../types/lxd';
import client from './client';

export const listImages = () =>
  client.get<LXDResponse<LXDImage[]>>('/1.0/images?recursion=1')

export const listRemoteImages = (remote: string) =>
  client.get<LXDResponse<LXDImage[]>>(`/1.0/images/remote/${encodeURIComponent(remote)}`)

export const pullImage = (payload: { remote: string; alias: string }) =>
  client.post<LXDResponse<Record<string, never>>>('/1.0/images/pull', payload)

export const deleteImage = (fingerprint: string) =>
  client.delete<LXDResponse<Record<string, never>>>(`/1.0/images/${encodeURIComponent(fingerprint)}`)

export const deleteImageAlias = (name: string) =>
  client.delete<LXDResponse<Record<string, never>>>(`/1.0/images/aliases/${encodeURIComponent(name)}`)

export const getImage = (fingerprint: string) =>
  client.get<LXDResponse<LXDImage>>(`/1.0/images/${fingerprint}`)
