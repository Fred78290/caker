import type { LXDNetwork, LXDResponse } from '../types/lxd';
import client from './client';

export const listNetworks = () =>
  client.get<LXDResponse<LXDNetwork[]>>('/1.0/networks?recursion=1')

export const getNetwork = (name: string) =>
  client.get<LXDResponse<LXDNetwork>>(`/1.0/networks/${name}`)
