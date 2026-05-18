import type { LXDResponse, LXDServerInfo } from '../types/lxd';
import client from './client';

export const getServerInfo = () =>
  client.get<LXDResponse<LXDServerInfo>>('/1.0')
