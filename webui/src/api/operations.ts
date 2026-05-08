import type { LXDOperation, LXDResponse } from '../types/lxd';
import client from './client';

export const listOperations = () =>
  client.get<LXDResponse<LXDOperation[]>>('/1.0/operations?recursion=1')

export const getOperation = (id: string) =>
  client.get<LXDResponse<LXDOperation>>(`/1.0/operations/${id}`)

export const cancelOperation = (id: string) =>
  client.delete<LXDResponse<unknown>>(`/1.0/operations/${id}`)
