import type {
    LXDCreateInstanceRequest,
    LXDInstance,
    LXDInstanceState,
    LXDOperation,
    LXDResponse,
} from '../types/lxd';
import client from './client';

export const listInstances = () =>
  client.get<LXDResponse<LXDInstance[]>>('/1.0/instances?recursion=1')

export const getInstance = (name: string) =>
  client.get<LXDResponse<LXDInstance>>(`/1.0/instances/${name}`)

export const getInstanceState = (name: string) =>
  client.get<LXDResponse<LXDInstanceState>>(`/1.0/instances/${name}/state`)

export const createInstance = (body: LXDCreateInstanceRequest) =>
  client.post<LXDResponse<LXDOperation>>('/1.0/instances', body)

export const deleteInstance = (name: string) =>
  client.delete<LXDResponse<LXDOperation>>(`/1.0/instances/${name}`)

export const changeInstanceState = (
  name: string,
  action: 'start' | 'stop' | 'restart' | 'freeze' | 'unfreeze',
  force = false,
) =>
  client.put<LXDResponse<LXDOperation>>(`/1.0/instances/${name}/state`, {
    action,
    force,
    timeout: 30,
  })
