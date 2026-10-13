import type { VMImageCatalog } from '../data/vmImages';
import type { LXDResponse } from '../types/lxd';
import client from './client';

// Caker extension, not part of the LXD API: the VM image catalog of the connected caked's host
// (its architecture, its own <CAKE_HOME>/VMImages.json). A caked that predates it answers 404.
export const getVMImages = () =>
  client.get<LXDResponse<VMImageCatalog>>('/1.0/vm-images')
