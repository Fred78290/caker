// package: caked
// file: service.proto

/* tslint:disable */
/* eslint-disable */

import * as grpc from "grpc";
import * as service_pb from "./service_pb";

interface IServiceService extends grpc.ServiceDefinition<grpc.UntypedServiceImplementation> {
    build: IServiceService_IBuild;
    clone: IServiceService_IClone;
    configure: IServiceService_IConfigure;
    delete: IServiceService_IDelete;
    duplicate: IServiceService_IDuplicate;
    execute: IServiceService_IExecute;
    info: IServiceService_IInfo;
    launch: IServiceService_ILaunch;
    list: IServiceService_IList;
    rename: IServiceService_IRename;
    run: IServiceService_IRun;
    start: IServiceService_IStart;
    stop: IServiceService_IStop;
    template: IServiceService_ITemplate;
    waitIP: IServiceService_IWaitIP;
    image: IServiceService_IImage;
    cakeCommand: IServiceService_ICakeCommand;
    login: IServiceService_ILogin;
    logout: IServiceService_ILogout;
    purge: IServiceService_IPurge;
    remote: IServiceService_IRemote;
    networks: IServiceService_INetworks;
    mount: IServiceService_IMount;
    umount: IServiceService_IUmount;
}

interface IServiceService_IBuild extends grpc.MethodDefinition<service_pb.Caked.VMRequest.BuildRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Build";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.BuildRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.BuildRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IClone extends grpc.MethodDefinition<service_pb.Caked.VMRequest.CloneRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Clone";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.CloneRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.CloneRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IConfigure extends grpc.MethodDefinition<service_pb.Caked.VMRequest.ConfigureRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Configure";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.ConfigureRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.ConfigureRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IDelete extends grpc.MethodDefinition<service_pb.Caked.VMRequest.DeleteRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Delete";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.DeleteRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.DeleteRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IDuplicate extends grpc.MethodDefinition<service_pb.Caked.VMRequest.DuplicateRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Duplicate";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.DuplicateRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.DuplicateRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IExecute extends grpc.MethodDefinition<service_pb.Caked.VMRequest.ExecuteRequest, service_pb.Caked.VMRequest.ExecuteResponse> {
    path: "/caked.Service/Execute";
    requestStream: true;
    responseStream: true;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.ExecuteRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.ExecuteRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.VMRequest.ExecuteResponse>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.ExecuteResponse>;
}
interface IServiceService_IInfo extends grpc.MethodDefinition<service_pb.Caked.VMRequest.InfoRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Info";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.InfoRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.InfoRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_ILaunch extends grpc.MethodDefinition<service_pb.Caked.VMRequest.LaunchRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Launch";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.LaunchRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.LaunchRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IList extends grpc.MethodDefinition<service_pb.Caked.VMRequest.ListRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/List";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.ListRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.ListRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IRename extends grpc.MethodDefinition<service_pb.Caked.VMRequest.RenameRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Rename";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.RenameRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.RenameRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IRun extends grpc.MethodDefinition<service_pb.Caked.VMRequest.RunCommand, service_pb.Caked.Reply> {
    path: "/caked.Service/Run";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.RunCommand>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.RunCommand>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IStart extends grpc.MethodDefinition<service_pb.Caked.VMRequest.StartRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Start";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.StartRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.StartRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IStop extends grpc.MethodDefinition<service_pb.Caked.VMRequest.StopRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Stop";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.StopRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.StopRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_ITemplate extends grpc.MethodDefinition<service_pb.Caked.VMRequest.TemplateRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Template";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.TemplateRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.TemplateRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IWaitIP extends grpc.MethodDefinition<service_pb.Caked.VMRequest.WaitIPRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/WaitIP";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.VMRequest.WaitIPRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.VMRequest.WaitIPRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IImage extends grpc.MethodDefinition<service_pb.Caked.ImageRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Image";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.ImageRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.ImageRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_ICakeCommand extends grpc.MethodDefinition<service_pb.Caked.CakedCommandRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/CakeCommand";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.CakedCommandRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.CakedCommandRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_ILogin extends grpc.MethodDefinition<service_pb.Caked.LoginRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Login";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.LoginRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.LoginRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_ILogout extends grpc.MethodDefinition<service_pb.Caked.LogoutRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Logout";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.LogoutRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.LogoutRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IPurge extends grpc.MethodDefinition<service_pb.Caked.PurgeRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Purge";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.PurgeRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.PurgeRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IRemote extends grpc.MethodDefinition<service_pb.Caked.RemoteRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Remote";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.RemoteRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.RemoteRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_INetworks extends grpc.MethodDefinition<service_pb.Caked.NetworkRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Networks";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.NetworkRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.NetworkRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IMount extends grpc.MethodDefinition<service_pb.Caked.MountRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Mount";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.MountRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.MountRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}
interface IServiceService_IUmount extends grpc.MethodDefinition<service_pb.Caked.MountRequest, service_pb.Caked.Reply> {
    path: "/caked.Service/Umount";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<service_pb.Caked.MountRequest>;
    requestDeserialize: grpc.deserialize<service_pb.Caked.MountRequest>;
    responseSerialize: grpc.serialize<service_pb.Caked.Reply>;
    responseDeserialize: grpc.deserialize<service_pb.Caked.Reply>;
}

export const ServiceService: IServiceService;

export interface IServiceServer {
    build: grpc.handleUnaryCall<service_pb.Caked.VMRequest.BuildRequest, service_pb.Caked.Reply>;
    clone: grpc.handleUnaryCall<service_pb.Caked.VMRequest.CloneRequest, service_pb.Caked.Reply>;
    configure: grpc.handleUnaryCall<service_pb.Caked.VMRequest.ConfigureRequest, service_pb.Caked.Reply>;
    delete: grpc.handleUnaryCall<service_pb.Caked.VMRequest.DeleteRequest, service_pb.Caked.Reply>;
    duplicate: grpc.handleUnaryCall<service_pb.Caked.VMRequest.DuplicateRequest, service_pb.Caked.Reply>;
    execute: grpc.handleBidiStreamingCall<service_pb.Caked.VMRequest.ExecuteRequest, service_pb.Caked.VMRequest.ExecuteResponse>;
    info: grpc.handleUnaryCall<service_pb.Caked.VMRequest.InfoRequest, service_pb.Caked.Reply>;
    launch: grpc.handleUnaryCall<service_pb.Caked.VMRequest.LaunchRequest, service_pb.Caked.Reply>;
    list: grpc.handleUnaryCall<service_pb.Caked.VMRequest.ListRequest, service_pb.Caked.Reply>;
    rename: grpc.handleUnaryCall<service_pb.Caked.VMRequest.RenameRequest, service_pb.Caked.Reply>;
    run: grpc.handleUnaryCall<service_pb.Caked.VMRequest.RunCommand, service_pb.Caked.Reply>;
    start: grpc.handleUnaryCall<service_pb.Caked.VMRequest.StartRequest, service_pb.Caked.Reply>;
    stop: grpc.handleUnaryCall<service_pb.Caked.VMRequest.StopRequest, service_pb.Caked.Reply>;
    template: grpc.handleUnaryCall<service_pb.Caked.VMRequest.TemplateRequest, service_pb.Caked.Reply>;
    waitIP: grpc.handleUnaryCall<service_pb.Caked.VMRequest.WaitIPRequest, service_pb.Caked.Reply>;
    image: grpc.handleUnaryCall<service_pb.Caked.ImageRequest, service_pb.Caked.Reply>;
    cakeCommand: grpc.handleUnaryCall<service_pb.Caked.CakedCommandRequest, service_pb.Caked.Reply>;
    login: grpc.handleUnaryCall<service_pb.Caked.LoginRequest, service_pb.Caked.Reply>;
    logout: grpc.handleUnaryCall<service_pb.Caked.LogoutRequest, service_pb.Caked.Reply>;
    purge: grpc.handleUnaryCall<service_pb.Caked.PurgeRequest, service_pb.Caked.Reply>;
    remote: grpc.handleUnaryCall<service_pb.Caked.RemoteRequest, service_pb.Caked.Reply>;
    networks: grpc.handleUnaryCall<service_pb.Caked.NetworkRequest, service_pb.Caked.Reply>;
    mount: grpc.handleUnaryCall<service_pb.Caked.MountRequest, service_pb.Caked.Reply>;
    umount: grpc.handleUnaryCall<service_pb.Caked.MountRequest, service_pb.Caked.Reply>;
}

export interface IServiceClient {
    build(request: service_pb.Caked.VMRequest.BuildRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    build(request: service_pb.Caked.VMRequest.BuildRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    build(request: service_pb.Caked.VMRequest.BuildRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    clone(request: service_pb.Caked.VMRequest.CloneRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    clone(request: service_pb.Caked.VMRequest.CloneRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    clone(request: service_pb.Caked.VMRequest.CloneRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    configure(request: service_pb.Caked.VMRequest.ConfigureRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    configure(request: service_pb.Caked.VMRequest.ConfigureRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    configure(request: service_pb.Caked.VMRequest.ConfigureRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    delete(request: service_pb.Caked.VMRequest.DeleteRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    delete(request: service_pb.Caked.VMRequest.DeleteRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    delete(request: service_pb.Caked.VMRequest.DeleteRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    duplicate(request: service_pb.Caked.VMRequest.DuplicateRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    duplicate(request: service_pb.Caked.VMRequest.DuplicateRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    duplicate(request: service_pb.Caked.VMRequest.DuplicateRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    execute(): grpc.ClientDuplexStream<service_pb.Caked.VMRequest.ExecuteRequest, service_pb.Caked.VMRequest.ExecuteResponse>;
    execute(options: Partial<grpc.CallOptions>): grpc.ClientDuplexStream<service_pb.Caked.VMRequest.ExecuteRequest, service_pb.Caked.VMRequest.ExecuteResponse>;
    execute(metadata: grpc.Metadata, options?: Partial<grpc.CallOptions>): grpc.ClientDuplexStream<service_pb.Caked.VMRequest.ExecuteRequest, service_pb.Caked.VMRequest.ExecuteResponse>;
    info(request: service_pb.Caked.VMRequest.InfoRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    info(request: service_pb.Caked.VMRequest.InfoRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    info(request: service_pb.Caked.VMRequest.InfoRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    launch(request: service_pb.Caked.VMRequest.LaunchRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    launch(request: service_pb.Caked.VMRequest.LaunchRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    launch(request: service_pb.Caked.VMRequest.LaunchRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    list(request: service_pb.Caked.VMRequest.ListRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    list(request: service_pb.Caked.VMRequest.ListRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    list(request: service_pb.Caked.VMRequest.ListRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    rename(request: service_pb.Caked.VMRequest.RenameRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    rename(request: service_pb.Caked.VMRequest.RenameRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    rename(request: service_pb.Caked.VMRequest.RenameRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    run(request: service_pb.Caked.VMRequest.RunCommand, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    run(request: service_pb.Caked.VMRequest.RunCommand, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    run(request: service_pb.Caked.VMRequest.RunCommand, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    start(request: service_pb.Caked.VMRequest.StartRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    start(request: service_pb.Caked.VMRequest.StartRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    start(request: service_pb.Caked.VMRequest.StartRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    stop(request: service_pb.Caked.VMRequest.StopRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    stop(request: service_pb.Caked.VMRequest.StopRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    stop(request: service_pb.Caked.VMRequest.StopRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    template(request: service_pb.Caked.VMRequest.TemplateRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    template(request: service_pb.Caked.VMRequest.TemplateRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    template(request: service_pb.Caked.VMRequest.TemplateRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    waitIP(request: service_pb.Caked.VMRequest.WaitIPRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    waitIP(request: service_pb.Caked.VMRequest.WaitIPRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    waitIP(request: service_pb.Caked.VMRequest.WaitIPRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    image(request: service_pb.Caked.ImageRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    image(request: service_pb.Caked.ImageRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    image(request: service_pb.Caked.ImageRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    cakeCommand(request: service_pb.Caked.CakedCommandRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    cakeCommand(request: service_pb.Caked.CakedCommandRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    cakeCommand(request: service_pb.Caked.CakedCommandRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    login(request: service_pb.Caked.LoginRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    login(request: service_pb.Caked.LoginRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    login(request: service_pb.Caked.LoginRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    logout(request: service_pb.Caked.LogoutRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    logout(request: service_pb.Caked.LogoutRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    logout(request: service_pb.Caked.LogoutRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    purge(request: service_pb.Caked.PurgeRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    purge(request: service_pb.Caked.PurgeRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    purge(request: service_pb.Caked.PurgeRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    remote(request: service_pb.Caked.RemoteRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    remote(request: service_pb.Caked.RemoteRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    remote(request: service_pb.Caked.RemoteRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    networks(request: service_pb.Caked.NetworkRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    networks(request: service_pb.Caked.NetworkRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    networks(request: service_pb.Caked.NetworkRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    mount(request: service_pb.Caked.MountRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    mount(request: service_pb.Caked.MountRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    mount(request: service_pb.Caked.MountRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    umount(request: service_pb.Caked.MountRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    umount(request: service_pb.Caked.MountRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    umount(request: service_pb.Caked.MountRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
}

export class ServiceClient extends grpc.Client implements IServiceClient {
    constructor(address: string, credentials: grpc.ChannelCredentials, options?: object);
    public build(request: service_pb.Caked.VMRequest.BuildRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public build(request: service_pb.Caked.VMRequest.BuildRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public build(request: service_pb.Caked.VMRequest.BuildRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public clone(request: service_pb.Caked.VMRequest.CloneRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public clone(request: service_pb.Caked.VMRequest.CloneRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public clone(request: service_pb.Caked.VMRequest.CloneRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public configure(request: service_pb.Caked.VMRequest.ConfigureRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public configure(request: service_pb.Caked.VMRequest.ConfigureRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public configure(request: service_pb.Caked.VMRequest.ConfigureRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public delete(request: service_pb.Caked.VMRequest.DeleteRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public delete(request: service_pb.Caked.VMRequest.DeleteRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public delete(request: service_pb.Caked.VMRequest.DeleteRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public duplicate(request: service_pb.Caked.VMRequest.DuplicateRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public duplicate(request: service_pb.Caked.VMRequest.DuplicateRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public duplicate(request: service_pb.Caked.VMRequest.DuplicateRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public execute(options?: Partial<grpc.CallOptions>): grpc.ClientDuplexStream<service_pb.Caked.VMRequest.ExecuteRequest, service_pb.Caked.VMRequest.ExecuteResponse>;
    public execute(metadata?: grpc.Metadata, options?: Partial<grpc.CallOptions>): grpc.ClientDuplexStream<service_pb.Caked.VMRequest.ExecuteRequest, service_pb.Caked.VMRequest.ExecuteResponse>;
    public info(request: service_pb.Caked.VMRequest.InfoRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public info(request: service_pb.Caked.VMRequest.InfoRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public info(request: service_pb.Caked.VMRequest.InfoRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public launch(request: service_pb.Caked.VMRequest.LaunchRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public launch(request: service_pb.Caked.VMRequest.LaunchRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public launch(request: service_pb.Caked.VMRequest.LaunchRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public list(request: service_pb.Caked.VMRequest.ListRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public list(request: service_pb.Caked.VMRequest.ListRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public list(request: service_pb.Caked.VMRequest.ListRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public rename(request: service_pb.Caked.VMRequest.RenameRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public rename(request: service_pb.Caked.VMRequest.RenameRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public rename(request: service_pb.Caked.VMRequest.RenameRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public run(request: service_pb.Caked.VMRequest.RunCommand, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public run(request: service_pb.Caked.VMRequest.RunCommand, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public run(request: service_pb.Caked.VMRequest.RunCommand, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public start(request: service_pb.Caked.VMRequest.StartRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public start(request: service_pb.Caked.VMRequest.StartRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public start(request: service_pb.Caked.VMRequest.StartRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public stop(request: service_pb.Caked.VMRequest.StopRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public stop(request: service_pb.Caked.VMRequest.StopRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public stop(request: service_pb.Caked.VMRequest.StopRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public template(request: service_pb.Caked.VMRequest.TemplateRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public template(request: service_pb.Caked.VMRequest.TemplateRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public template(request: service_pb.Caked.VMRequest.TemplateRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public waitIP(request: service_pb.Caked.VMRequest.WaitIPRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public waitIP(request: service_pb.Caked.VMRequest.WaitIPRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public waitIP(request: service_pb.Caked.VMRequest.WaitIPRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public image(request: service_pb.Caked.ImageRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public image(request: service_pb.Caked.ImageRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public image(request: service_pb.Caked.ImageRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public cakeCommand(request: service_pb.Caked.CakedCommandRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public cakeCommand(request: service_pb.Caked.CakedCommandRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public cakeCommand(request: service_pb.Caked.CakedCommandRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public login(request: service_pb.Caked.LoginRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public login(request: service_pb.Caked.LoginRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public login(request: service_pb.Caked.LoginRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public logout(request: service_pb.Caked.LogoutRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public logout(request: service_pb.Caked.LogoutRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public logout(request: service_pb.Caked.LogoutRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public purge(request: service_pb.Caked.PurgeRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public purge(request: service_pb.Caked.PurgeRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public purge(request: service_pb.Caked.PurgeRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public remote(request: service_pb.Caked.RemoteRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public remote(request: service_pb.Caked.RemoteRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public remote(request: service_pb.Caked.RemoteRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public networks(request: service_pb.Caked.NetworkRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public networks(request: service_pb.Caked.NetworkRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public networks(request: service_pb.Caked.NetworkRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public mount(request: service_pb.Caked.MountRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public mount(request: service_pb.Caked.MountRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public mount(request: service_pb.Caked.MountRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public umount(request: service_pb.Caked.MountRequest, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public umount(request: service_pb.Caked.MountRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
    public umount(request: service_pb.Caked.MountRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: service_pb.Caked.Reply) => void): grpc.ClientUnaryCall;
}
