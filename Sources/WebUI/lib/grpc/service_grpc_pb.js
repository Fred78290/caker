// GENERATED CODE -- DO NOT EDIT!

// Original file comments:
// limitations under the License.
'use strict';
var grpc = require('grpc');
var service_pb = require('./service_pb.js');

function serialize_caked_Caked_CakedCommandRequest(arg) {
  if (!(arg instanceof service_pb.Caked.CakedCommandRequest)) {
    throw new Error('Expected argument of type caked.Caked.CakedCommandRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_CakedCommandRequest(buffer_arg) {
  return service_pb.Caked.CakedCommandRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_ImageRequest(arg) {
  if (!(arg instanceof service_pb.Caked.ImageRequest)) {
    throw new Error('Expected argument of type caked.Caked.ImageRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_ImageRequest(buffer_arg) {
  return service_pb.Caked.ImageRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_LoginRequest(arg) {
  if (!(arg instanceof service_pb.Caked.LoginRequest)) {
    throw new Error('Expected argument of type caked.Caked.LoginRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_LoginRequest(buffer_arg) {
  return service_pb.Caked.LoginRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_LogoutRequest(arg) {
  if (!(arg instanceof service_pb.Caked.LogoutRequest)) {
    throw new Error('Expected argument of type caked.Caked.LogoutRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_LogoutRequest(buffer_arg) {
  return service_pb.Caked.LogoutRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_MountRequest(arg) {
  if (!(arg instanceof service_pb.Caked.MountRequest)) {
    throw new Error('Expected argument of type caked.Caked.MountRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_MountRequest(buffer_arg) {
  return service_pb.Caked.MountRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_NetworkRequest(arg) {
  if (!(arg instanceof service_pb.Caked.NetworkRequest)) {
    throw new Error('Expected argument of type caked.Caked.NetworkRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_NetworkRequest(buffer_arg) {
  return service_pb.Caked.NetworkRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_PurgeRequest(arg) {
  if (!(arg instanceof service_pb.Caked.PurgeRequest)) {
    throw new Error('Expected argument of type caked.Caked.PurgeRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_PurgeRequest(buffer_arg) {
  return service_pb.Caked.PurgeRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_RemoteRequest(arg) {
  if (!(arg instanceof service_pb.Caked.RemoteRequest)) {
    throw new Error('Expected argument of type caked.Caked.RemoteRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_RemoteRequest(buffer_arg) {
  return service_pb.Caked.RemoteRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_Reply(arg) {
  if (!(arg instanceof service_pb.Caked.Reply)) {
    throw new Error('Expected argument of type caked.Caked.Reply');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_Reply(buffer_arg) {
  return service_pb.Caked.Reply.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_BuildRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.BuildRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.BuildRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_BuildRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.BuildRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_CloneRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.CloneRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.CloneRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_CloneRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.CloneRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_ConfigureRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.ConfigureRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.ConfigureRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_ConfigureRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.ConfigureRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_DeleteRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.DeleteRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.DeleteRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_DeleteRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.DeleteRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_DuplicateRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.DuplicateRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.DuplicateRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_DuplicateRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.DuplicateRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_ExecuteRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.ExecuteRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.ExecuteRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_ExecuteRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.ExecuteRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_ExecuteResponse(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.ExecuteResponse)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.ExecuteResponse');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_ExecuteResponse(buffer_arg) {
  return service_pb.Caked.VMRequest.ExecuteResponse.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_InfoRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.InfoRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.InfoRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_InfoRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.InfoRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_LaunchRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.LaunchRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.LaunchRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_LaunchRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.LaunchRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_ListRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.ListRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.ListRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_ListRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.ListRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_RenameRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.RenameRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.RenameRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_RenameRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.RenameRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_RunCommand(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.RunCommand)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.RunCommand');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_RunCommand(buffer_arg) {
  return service_pb.Caked.VMRequest.RunCommand.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_StartRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.StartRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.StartRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_StartRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.StartRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_StopRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.StopRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.StopRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_StopRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.StopRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_TemplateRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.TemplateRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.TemplateRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_TemplateRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.TemplateRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_caked_Caked_VMRequest_WaitIPRequest(arg) {
  if (!(arg instanceof service_pb.Caked.VMRequest.WaitIPRequest)) {
    throw new Error('Expected argument of type caked.Caked.VMRequest.WaitIPRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_caked_Caked_VMRequest_WaitIPRequest(buffer_arg) {
  return service_pb.Caked.VMRequest.WaitIPRequest.deserializeBinary(new Uint8Array(buffer_arg));
}


var ServiceService = exports.ServiceService = {
  build: {
    path: '/caked.Service/Build',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.BuildRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_BuildRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_BuildRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  clone: {
    path: '/caked.Service/Clone',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.CloneRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_CloneRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_CloneRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  configure: {
    path: '/caked.Service/Configure',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.ConfigureRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_ConfigureRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_ConfigureRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  delete: {
    path: '/caked.Service/Delete',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.DeleteRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_DeleteRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_DeleteRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  duplicate: {
    path: '/caked.Service/Duplicate',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.DuplicateRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_DuplicateRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_DuplicateRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  execute: {
    path: '/caked.Service/Execute',
    requestStream: true,
    responseStream: true,
    requestType: service_pb.Caked.VMRequest.ExecuteRequest,
    responseType: service_pb.Caked.VMRequest.ExecuteResponse,
    requestSerialize: serialize_caked_Caked_VMRequest_ExecuteRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_ExecuteRequest,
    responseSerialize: serialize_caked_Caked_VMRequest_ExecuteResponse,
    responseDeserialize: deserialize_caked_Caked_VMRequest_ExecuteResponse,
  },
  info: {
    path: '/caked.Service/Info',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.InfoRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_InfoRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_InfoRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  launch: {
    path: '/caked.Service/Launch',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.LaunchRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_LaunchRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_LaunchRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  list: {
    path: '/caked.Service/List',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.ListRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_ListRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_ListRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  rename: {
    path: '/caked.Service/Rename',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.RenameRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_RenameRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_RenameRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  run: {
    path: '/caked.Service/Run',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.RunCommand,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_RunCommand,
    requestDeserialize: deserialize_caked_Caked_VMRequest_RunCommand,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  start: {
    path: '/caked.Service/Start',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.StartRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_StartRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_StartRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  stop: {
    path: '/caked.Service/Stop',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.StopRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_StopRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_StopRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  template: {
    path: '/caked.Service/Template',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.TemplateRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_TemplateRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_TemplateRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  waitIP: {
    path: '/caked.Service/WaitIP',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.VMRequest.WaitIPRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_VMRequest_WaitIPRequest,
    requestDeserialize: deserialize_caked_Caked_VMRequest_WaitIPRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  image: {
    path: '/caked.Service/Image',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.ImageRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_ImageRequest,
    requestDeserialize: deserialize_caked_Caked_ImageRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  cakeCommand: {
    path: '/caked.Service/CakeCommand',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.CakedCommandRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_CakedCommandRequest,
    requestDeserialize: deserialize_caked_Caked_CakedCommandRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  login: {
    path: '/caked.Service/Login',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.LoginRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_LoginRequest,
    requestDeserialize: deserialize_caked_Caked_LoginRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  logout: {
    path: '/caked.Service/Logout',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.LogoutRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_LogoutRequest,
    requestDeserialize: deserialize_caked_Caked_LogoutRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  purge: {
    path: '/caked.Service/Purge',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.PurgeRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_PurgeRequest,
    requestDeserialize: deserialize_caked_Caked_PurgeRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  remote: {
    path: '/caked.Service/Remote',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.RemoteRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_RemoteRequest,
    requestDeserialize: deserialize_caked_Caked_RemoteRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  networks: {
    path: '/caked.Service/Networks',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.NetworkRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_NetworkRequest,
    requestDeserialize: deserialize_caked_Caked_NetworkRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  mount: {
    path: '/caked.Service/Mount',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.MountRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_MountRequest,
    requestDeserialize: deserialize_caked_Caked_MountRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
  umount: {
    path: '/caked.Service/Umount',
    requestStream: false,
    responseStream: false,
    requestType: service_pb.Caked.MountRequest,
    responseType: service_pb.Caked.Reply,
    requestSerialize: serialize_caked_Caked_MountRequest,
    requestDeserialize: deserialize_caked_Caked_MountRequest,
    responseSerialize: serialize_caked_Caked_Reply,
    responseDeserialize: deserialize_caked_Caked_Reply,
  },
};

exports.ServiceClient = grpc.makeGenericClientConstructor(ServiceService, 'Service');
