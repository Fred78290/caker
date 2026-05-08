import type { LXDImage, LXDResponse } from '../types/lxd';
import client from './client';

export const listImages = () =>
  client.get<LXDResponse<LXDImage[]>>('/1.0/images?recursion=1')

export const getImage = (fingerprint: string) =>
  client.get<LXDResponse<LXDImage>>(`/1.0/images/${fingerprint}`)
