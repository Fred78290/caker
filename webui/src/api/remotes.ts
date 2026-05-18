import type { LXDRemote, LXDResponse } from '../types/lxd';
import client from './client';

export const listRemotes = () =>
  client.get<LXDResponse<LXDRemote[]>>('/1.0/remotes?recursion=1')

export const createRemote = (payload: { name: string; url: string }) =>
  client.post<LXDResponse<Record<string, never>>>('/1.0/remotes', payload)

export const updateRemote = (name: string, payload: { name?: string; url?: string }) =>
  client.patch<LXDResponse<Record<string, never>>>(`/1.0/remotes/${encodeURIComponent(name)}`, payload)

export const deleteRemote = (name: string) =>
  client.delete<LXDResponse<Record<string, never>>>(`/1.0/remotes/${encodeURIComponent(name)}`)