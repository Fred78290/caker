import type {
    LXDCreateInstanceRequest,
    LXDExecAsyncResponse,
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

export const execInstance = (
  name: string,
  command: string[],
  opts: { width?: number; height?: number } = {},
) =>
  client.post<LXDExecAsyncResponse>(`/1.0/instances/${name}/exec`, {
    command,
    environment: { TERM: 'xterm-256color', LANG: 'en_US.UTF-8' },
    interactive: true,
    'wait-for-websocket': true,
    width: opts.width ?? 80,
    height: opts.height ?? 24,
  })

export const consoleInstance = (
  name: string,
  type: 'console' | 'vga',
  opts: { width?: number; height?: number } = {},
) =>
  client.post<LXDExecAsyncResponse>(`/1.0/instances/${name}/console`, {
    type: type,
    width: opts.width ?? 80,
    height: opts.height ?? 24,
  })

export const getInstanceLogs = (name: string) =>
  client.get<LXDResponse<string[]>>(`/1.0/instances/${name}/logs`)

export const getInstanceLogFile = (name: string, filename: string) => {
  const safeFilename = filename.split('/').pop() || filename
  return client.get<string>(`/1.0/instances/${name}/logs/${safeFilename}`, {
    responseType: 'text',
  })
}
