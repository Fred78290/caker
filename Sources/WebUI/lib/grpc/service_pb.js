// source: service.proto
/**
 * @fileoverview
 * @enhanceable
 * @suppress {missingRequire} reports error on implicit type usages.
 * @suppress {messageConventions} JS Compiler reports an error if a variable or
 *     field starts with 'MSG_' and isn't a translatable message.
 * @public
 */
// GENERATED CODE -- DO NOT EDIT!
/* eslint-disable */
// @ts-nocheck

var jspb = require('google-protobuf');
var goog = jspb;
var global = (function() {
  if (this) { return this; }
  if (typeof window !== 'undefined') { return window; }
  if (typeof global !== 'undefined') { return global; }
  if (typeof self !== 'undefined') { return self; }
  return Function('return this')();
}.call(null));

goog.exportSymbol('proto.caked.Caked', null, global);
goog.exportSymbol('proto.caked.Caked.CakedCommandRequest', null, global);
goog.exportSymbol('proto.caked.Caked.ImageRequest', null, global);
goog.exportSymbol('proto.caked.Caked.ImageRequest.ImageCommand', null, global);
goog.exportSymbol('proto.caked.Caked.LoginRequest', null, global);
goog.exportSymbol('proto.caked.Caked.LogoutRequest', null, global);
goog.exportSymbol('proto.caked.Caked.MountRequest', null, global);
goog.exportSymbol('proto.caked.Caked.MountRequest.MountCommand', null, global);
goog.exportSymbol('proto.caked.Caked.MountRequest.MountVirtioFS', null, global);
goog.exportSymbol('proto.caked.Caked.NetworkRequest', null, global);
goog.exportSymbol('proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest', null, global);
goog.exportSymbol('proto.caked.Caked.NetworkRequest.CreateNetworkRequest', null, global);
goog.exportSymbol('proto.caked.Caked.NetworkRequest.NetworkCase', null, global);
goog.exportSymbol('proto.caked.Caked.NetworkRequest.NetworkCommand', null, global);
goog.exportSymbol('proto.caked.Caked.NetworkRequest.NetworkMode', null, global);
goog.exportSymbol('proto.caked.Caked.PurgeRequest', null, global);
goog.exportSymbol('proto.caked.Caked.RemoteRequest', null, global);
goog.exportSymbol('proto.caked.Caked.RemoteRequest.RemoteCase', null, global);
goog.exportSymbol('proto.caked.Caked.RemoteRequest.RemoteCommand', null, global);
goog.exportSymbol('proto.caked.Caked.RemoteRequest.RemoteRequestAdd', null, global);
goog.exportSymbol('proto.caked.Caked.Reply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.Error', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.ImageReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.ImageReply.ImageInfo', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.ImageReply.PulledImageInfo', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.ImageReply.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.MountReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.MountReply.MountVirtioFSReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.MountReply.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.NetworksReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.NetworksReply.ListNetworksReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.NetworksReply.NetworkInfo', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.NetworksReply.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.RemoteReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.RemoteReply.ListRemoteReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.RemoteReply.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.RunReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.TartReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.TemplateReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.TemplateReply.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.TunnelCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.StopReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply', null, global);
goog.exportSymbol('proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.BuildRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.CloneRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.CommonBuildRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ConfigureRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.DeleteRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.DeleteRequest.DeleteCase', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.DeleteRequest.VMNames', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.DuplicateRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ExecuteRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCase', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.ExecuteCase', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ExecuteResponse', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ExecuteResponse.ResponseCase', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.InfoRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.LaunchRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.ListRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.RenameRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.RunCommand', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.StartRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.StopRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.StopRequest.StopCase', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.StopRequest.VMNames', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.TemplateRequest', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.TemplateRequest.TemplateCase', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.TemplateRequest.TemplateCommand', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd', null, global);
goog.exportSymbol('proto.caked.Caked.VMRequest.WaitIPRequest', null, global);
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.displayName = 'proto.caked.Caked';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.displayName = 'proto.caked.Caked.VMRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.CommonBuildRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.CommonBuildRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.CommonBuildRequest.displayName = 'proto.caked.Caked.VMRequest.CommonBuildRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.BuildRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.BuildRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.BuildRequest.displayName = 'proto.caked.Caked.VMRequest.BuildRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.StartRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.StartRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.StartRequest.displayName = 'proto.caked.Caked.VMRequest.StartRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.CloneRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.CloneRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.CloneRequest.displayName = 'proto.caked.Caked.VMRequest.CloneRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.DuplicateRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.DuplicateRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.DuplicateRequest.displayName = 'proto.caked.Caked.VMRequest.DuplicateRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.LaunchRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.LaunchRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.LaunchRequest.displayName = 'proto.caked.Caked.VMRequest.LaunchRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.ConfigureRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.ConfigureRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.ConfigureRequest.displayName = 'proto.caked.Caked.VMRequest.ConfigureRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.WaitIPRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.WaitIPRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.WaitIPRequest.displayName = 'proto.caked.Caked.VMRequest.WaitIPRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.StopRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.VMRequest.StopRequest.oneofGroups_);
};
goog.inherits(proto.caked.Caked.VMRequest.StopRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.StopRequest.displayName = 'proto.caked.Caked.VMRequest.StopRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.VMRequest.StopRequest.VMNames.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.VMRequest.StopRequest.VMNames, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.StopRequest.VMNames.displayName = 'proto.caked.Caked.VMRequest.StopRequest.VMNames';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.DeleteRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.VMRequest.DeleteRequest.oneofGroups_);
};
goog.inherits(proto.caked.Caked.VMRequest.DeleteRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.DeleteRequest.displayName = 'proto.caked.Caked.VMRequest.DeleteRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.VMRequest.DeleteRequest.VMNames.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.VMRequest.DeleteRequest.VMNames, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.DeleteRequest.VMNames.displayName = 'proto.caked.Caked.VMRequest.DeleteRequest.VMNames';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.ListRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.ListRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.ListRequest.displayName = 'proto.caked.Caked.VMRequest.ListRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.InfoRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.InfoRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.InfoRequest.displayName = 'proto.caked.Caked.VMRequest.InfoRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.RenameRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.RenameRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.RenameRequest.displayName = 'proto.caked.Caked.VMRequest.RenameRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.TemplateRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.VMRequest.TemplateRequest.oneofGroups_);
};
goog.inherits(proto.caked.Caked.VMRequest.TemplateRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.TemplateRequest.displayName = 'proto.caked.Caked.VMRequest.TemplateRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.displayName = 'proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.RunCommand = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.VMRequest.RunCommand.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.VMRequest.RunCommand, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.RunCommand.displayName = 'proto.caked.Caked.VMRequest.RunCommand';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.ExecuteResponse = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_);
};
goog.inherits(proto.caked.Caked.VMRequest.ExecuteResponse, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.ExecuteResponse.displayName = 'proto.caked.Caked.VMRequest.ExecuteResponse';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.ExecuteRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_);
};
goog.inherits(proto.caked.Caked.VMRequest.ExecuteRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.ExecuteRequest.displayName = 'proto.caked.Caked.VMRequest.ExecuteRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.oneofGroups_);
};
goog.inherits(proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.displayName = 'proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.displayName = 'proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.displayName = 'proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.Reply.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.displayName = 'proto.caked.Caked.Reply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.Error = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.Error, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.Error.displayName = 'proto.caked.Caked.Reply.Error';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.VirtualMachineReply.StopReply.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.StopReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.StopReply.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.StopReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.InfoReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.InfoReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.displayName = 'proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.ImageReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.Reply.ImageReply.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply.ImageReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.ImageReply.displayName = 'proto.caked.Caked.Reply.ImageReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.displayName = 'proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.ImageReply.ImageInfo.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.ImageReply.ImageInfo, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.ImageReply.ImageInfo.displayName = 'proto.caked.Caked.Reply.ImageReply.ImageInfo';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.ImageReply.PulledImageInfo, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.ImageReply.PulledImageInfo.displayName = 'proto.caked.Caked.Reply.ImageReply.PulledImageInfo';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.NetworksReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.Reply.NetworksReply.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply.NetworksReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.NetworksReply.displayName = 'proto.caked.Caked.Reply.NetworksReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.NetworksReply.NetworkInfo, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.NetworksReply.NetworkInfo.displayName = 'proto.caked.Caked.Reply.NetworksReply.NetworkInfo';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.NetworksReply.ListNetworksReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.displayName = 'proto.caked.Caked.Reply.NetworksReply.ListNetworksReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.RemoteReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.Reply.RemoteReply.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply.RemoteReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.RemoteReply.displayName = 'proto.caked.Caked.Reply.RemoteReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.RemoteReply.ListRemoteReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.displayName = 'proto.caked.Caked.Reply.RemoteReply.ListRemoteReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.displayName = 'proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.TemplateReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.Reply.TemplateReply.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply.TemplateReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.TemplateReply.displayName = 'proto.caked.Caked.Reply.TemplateReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.displayName = 'proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.displayName = 'proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.displayName = 'proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.displayName = 'proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.RunReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.RunReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.RunReply.displayName = 'proto.caked.Caked.Reply.RunReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.MountReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.Reply.MountReply.repeatedFields_, proto.caked.Caked.Reply.MountReply.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply.MountReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.MountReply.displayName = 'proto.caked.Caked.Reply.MountReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.oneofGroups_);
};
goog.inherits(proto.caked.Caked.Reply.MountReply.MountVirtioFSReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.displayName = 'proto.caked.Caked.Reply.MountReply.MountVirtioFSReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.Reply.TartReply = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.Reply.TartReply, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.Reply.TartReply.displayName = 'proto.caked.Caked.Reply.TartReply';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.NetworkRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.NetworkRequest.oneofGroups_);
};
goog.inherits(proto.caked.Caked.NetworkRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.NetworkRequest.displayName = 'proto.caked.Caked.NetworkRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.displayName = 'proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.NetworkRequest.CreateNetworkRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.NetworkRequest.CreateNetworkRequest.displayName = 'proto.caked.Caked.NetworkRequest.CreateNetworkRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.ImageRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.ImageRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.ImageRequest.displayName = 'proto.caked.Caked.ImageRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.RemoteRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, proto.caked.Caked.RemoteRequest.oneofGroups_);
};
goog.inherits(proto.caked.Caked.RemoteRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.RemoteRequest.displayName = 'proto.caked.Caked.RemoteRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.RemoteRequest.RemoteRequestAdd, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.RemoteRequest.RemoteRequestAdd.displayName = 'proto.caked.Caked.RemoteRequest.RemoteRequestAdd';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.CakedCommandRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.CakedCommandRequest.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.CakedCommandRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.CakedCommandRequest.displayName = 'proto.caked.Caked.CakedCommandRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.PurgeRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.PurgeRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.PurgeRequest.displayName = 'proto.caked.Caked.PurgeRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.LogoutRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.LogoutRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.LogoutRequest.displayName = 'proto.caked.Caked.LogoutRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.LoginRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.LoginRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.LoginRequest.displayName = 'proto.caked.Caked.LoginRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.MountRequest = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, proto.caked.Caked.MountRequest.repeatedFields_, null);
};
goog.inherits(proto.caked.Caked.MountRequest, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.MountRequest.displayName = 'proto.caked.Caked.MountRequest';
}
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.caked.Caked.MountRequest.MountVirtioFS = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.caked.Caked.MountRequest.MountVirtioFS, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.caked.Caked.MountRequest.MountVirtioFS.displayName = 'proto.caked.Caked.MountRequest.MountVirtioFS';
}



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.toObject = function(includeInstance, msg) {
  var f, obj = {

  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked}
 */
proto.caked.Caked.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked;
  return proto.caked.Caked.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked}
 */
proto.caked.Caked.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.toObject = function(includeInstance, msg) {
  var f, obj = {

  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest}
 */
proto.caked.Caked.VMRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest;
  return proto.caked.Caked.VMRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest}
 */
proto.caked.Caked.VMRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.CommonBuildRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.CommonBuildRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    cpu: jspb.Message.getFieldWithDefault(msg, 2, 0),
    memory: jspb.Message.getFieldWithDefault(msg, 3, 0),
    user: jspb.Message.getFieldWithDefault(msg, 4, ""),
    password: jspb.Message.getFieldWithDefault(msg, 22, ""),
    maingroup: jspb.Message.getFieldWithDefault(msg, 5, ""),
    sshpwauth: jspb.Message.getBooleanFieldWithDefault(msg, 6, false),
    image: jspb.Message.getFieldWithDefault(msg, 7, ""),
    sshauthorizedkey: msg.getSshauthorizedkey_asB64(),
    vendordata: msg.getVendordata_asB64(),
    userdata: msg.getUserdata_asB64(),
    networkconfig: msg.getNetworkconfig_asB64(),
    disksize: jspb.Message.getFieldWithDefault(msg, 12, 0),
    autostart: jspb.Message.getBooleanFieldWithDefault(msg, 13, false),
    nested: jspb.Message.getBooleanFieldWithDefault(msg, 14, false),
    forwardedport: jspb.Message.getFieldWithDefault(msg, 15, ""),
    mounts: jspb.Message.getFieldWithDefault(msg, 16, ""),
    networks: jspb.Message.getFieldWithDefault(msg, 17, ""),
    sockets: jspb.Message.getFieldWithDefault(msg, 18, ""),
    console: jspb.Message.getFieldWithDefault(msg, 19, ""),
    attacheddisks: jspb.Message.getFieldWithDefault(msg, 20, ""),
    dynamicportforwarding: jspb.Message.getBooleanFieldWithDefault(msg, 21, false),
    ifnames: jspb.Message.getBooleanFieldWithDefault(msg, 23, false),
    suspendable: jspb.Message.getBooleanFieldWithDefault(msg, 24, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.CommonBuildRequest;
  return proto.caked.Caked.VMRequest.CommonBuildRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.CommonBuildRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setCpu(value);
      break;
    case 3:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setMemory(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setUser(value);
      break;
    case 22:
      var value = /** @type {string} */ (reader.readString());
      msg.setPassword(value);
      break;
    case 5:
      var value = /** @type {string} */ (reader.readString());
      msg.setMaingroup(value);
      break;
    case 6:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setSshpwauth(value);
      break;
    case 7:
      var value = /** @type {string} */ (reader.readString());
      msg.setImage(value);
      break;
    case 8:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setSshauthorizedkey(value);
      break;
    case 9:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setVendordata(value);
      break;
    case 10:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setUserdata(value);
      break;
    case 11:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setNetworkconfig(value);
      break;
    case 12:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setDisksize(value);
      break;
    case 13:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setAutostart(value);
      break;
    case 14:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setNested(value);
      break;
    case 15:
      var value = /** @type {string} */ (reader.readString());
      msg.setForwardedport(value);
      break;
    case 16:
      var value = /** @type {string} */ (reader.readString());
      msg.setMounts(value);
      break;
    case 17:
      var value = /** @type {string} */ (reader.readString());
      msg.setNetworks(value);
      break;
    case 18:
      var value = /** @type {string} */ (reader.readString());
      msg.setSockets(value);
      break;
    case 19:
      var value = /** @type {string} */ (reader.readString());
      msg.setConsole(value);
      break;
    case 20:
      var value = /** @type {string} */ (reader.readString());
      msg.setAttacheddisks(value);
      break;
    case 21:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setDynamicportforwarding(value);
      break;
    case 23:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setIfnames(value);
      break;
    case 24:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setSuspendable(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.CommonBuildRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.CommonBuildRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeInt32(
      2,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeInt32(
      3,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeString(
      4,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 22));
  if (f != null) {
    writer.writeString(
      22,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeString(
      5,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 6));
  if (f != null) {
    writer.writeBool(
      6,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 7));
  if (f != null) {
    writer.writeString(
      7,
      f
    );
  }
  f = /** @type {!(string|Uint8Array)} */ (jspb.Message.getField(message, 8));
  if (f != null) {
    writer.writeBytes(
      8,
      f
    );
  }
  f = /** @type {!(string|Uint8Array)} */ (jspb.Message.getField(message, 9));
  if (f != null) {
    writer.writeBytes(
      9,
      f
    );
  }
  f = /** @type {!(string|Uint8Array)} */ (jspb.Message.getField(message, 10));
  if (f != null) {
    writer.writeBytes(
      10,
      f
    );
  }
  f = /** @type {!(string|Uint8Array)} */ (jspb.Message.getField(message, 11));
  if (f != null) {
    writer.writeBytes(
      11,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 12));
  if (f != null) {
    writer.writeInt32(
      12,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 13));
  if (f != null) {
    writer.writeBool(
      13,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 14));
  if (f != null) {
    writer.writeBool(
      14,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 15));
  if (f != null) {
    writer.writeString(
      15,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 16));
  if (f != null) {
    writer.writeString(
      16,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 17));
  if (f != null) {
    writer.writeString(
      17,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 18));
  if (f != null) {
    writer.writeString(
      18,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 19));
  if (f != null) {
    writer.writeString(
      19,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 20));
  if (f != null) {
    writer.writeString(
      20,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 21));
  if (f != null) {
    writer.writeBool(
      21,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 23));
  if (f != null) {
    writer.writeBool(
      23,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 24));
  if (f != null) {
    writer.writeBool(
      24,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional int32 cpu = 2;
 * @return {number}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getCpu = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setCpu = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearCpu = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasCpu = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional int32 memory = 3;
 * @return {number}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getMemory = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setMemory = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearMemory = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasMemory = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional string user = 4;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getUser = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setUser = function(value) {
  return jspb.Message.setField(this, 4, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearUser = function() {
  return jspb.Message.setField(this, 4, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasUser = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional string password = 22;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getPassword = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 22, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setPassword = function(value) {
  return jspb.Message.setField(this, 22, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearPassword = function() {
  return jspb.Message.setField(this, 22, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasPassword = function() {
  return jspb.Message.getField(this, 22) != null;
};


/**
 * optional string mainGroup = 5;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getMaingroup = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 5, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setMaingroup = function(value) {
  return jspb.Message.setField(this, 5, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearMaingroup = function() {
  return jspb.Message.setField(this, 5, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasMaingroup = function() {
  return jspb.Message.getField(this, 5) != null;
};


/**
 * optional bool sshPwAuth = 6;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getSshpwauth = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 6, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setSshpwauth = function(value) {
  return jspb.Message.setField(this, 6, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearSshpwauth = function() {
  return jspb.Message.setField(this, 6, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasSshpwauth = function() {
  return jspb.Message.getField(this, 6) != null;
};


/**
 * optional string image = 7;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getImage = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 7, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setImage = function(value) {
  return jspb.Message.setField(this, 7, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearImage = function() {
  return jspb.Message.setField(this, 7, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasImage = function() {
  return jspb.Message.getField(this, 7) != null;
};


/**
 * optional bytes sshAuthorizedKey = 8;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getSshauthorizedkey = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 8, ""));
};


/**
 * optional bytes sshAuthorizedKey = 8;
 * This is a type-conversion wrapper around `getSshauthorizedkey()`
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getSshauthorizedkey_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getSshauthorizedkey()));
};


/**
 * optional bytes sshAuthorizedKey = 8;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getSshauthorizedkey()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getSshauthorizedkey_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getSshauthorizedkey()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setSshauthorizedkey = function(value) {
  return jspb.Message.setField(this, 8, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearSshauthorizedkey = function() {
  return jspb.Message.setField(this, 8, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasSshauthorizedkey = function() {
  return jspb.Message.getField(this, 8) != null;
};


/**
 * optional bytes vendorData = 9;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getVendordata = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 9, ""));
};


/**
 * optional bytes vendorData = 9;
 * This is a type-conversion wrapper around `getVendordata()`
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getVendordata_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getVendordata()));
};


/**
 * optional bytes vendorData = 9;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getVendordata()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getVendordata_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getVendordata()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setVendordata = function(value) {
  return jspb.Message.setField(this, 9, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearVendordata = function() {
  return jspb.Message.setField(this, 9, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasVendordata = function() {
  return jspb.Message.getField(this, 9) != null;
};


/**
 * optional bytes userData = 10;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getUserdata = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 10, ""));
};


/**
 * optional bytes userData = 10;
 * This is a type-conversion wrapper around `getUserdata()`
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getUserdata_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getUserdata()));
};


/**
 * optional bytes userData = 10;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getUserdata()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getUserdata_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getUserdata()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setUserdata = function(value) {
  return jspb.Message.setField(this, 10, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearUserdata = function() {
  return jspb.Message.setField(this, 10, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasUserdata = function() {
  return jspb.Message.getField(this, 10) != null;
};


/**
 * optional bytes networkConfig = 11;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getNetworkconfig = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 11, ""));
};


/**
 * optional bytes networkConfig = 11;
 * This is a type-conversion wrapper around `getNetworkconfig()`
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getNetworkconfig_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getNetworkconfig()));
};


/**
 * optional bytes networkConfig = 11;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getNetworkconfig()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getNetworkconfig_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getNetworkconfig()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setNetworkconfig = function(value) {
  return jspb.Message.setField(this, 11, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearNetworkconfig = function() {
  return jspb.Message.setField(this, 11, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasNetworkconfig = function() {
  return jspb.Message.getField(this, 11) != null;
};


/**
 * optional int32 diskSize = 12;
 * @return {number}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getDisksize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 12, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setDisksize = function(value) {
  return jspb.Message.setField(this, 12, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearDisksize = function() {
  return jspb.Message.setField(this, 12, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasDisksize = function() {
  return jspb.Message.getField(this, 12) != null;
};


/**
 * optional bool autostart = 13;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getAutostart = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 13, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setAutostart = function(value) {
  return jspb.Message.setField(this, 13, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearAutostart = function() {
  return jspb.Message.setField(this, 13, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasAutostart = function() {
  return jspb.Message.getField(this, 13) != null;
};


/**
 * optional bool nested = 14;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getNested = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 14, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setNested = function(value) {
  return jspb.Message.setField(this, 14, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearNested = function() {
  return jspb.Message.setField(this, 14, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasNested = function() {
  return jspb.Message.getField(this, 14) != null;
};


/**
 * optional string forwardedPort = 15;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getForwardedport = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 15, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setForwardedport = function(value) {
  return jspb.Message.setField(this, 15, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearForwardedport = function() {
  return jspb.Message.setField(this, 15, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasForwardedport = function() {
  return jspb.Message.getField(this, 15) != null;
};


/**
 * optional string mounts = 16;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getMounts = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 16, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setMounts = function(value) {
  return jspb.Message.setField(this, 16, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearMounts = function() {
  return jspb.Message.setField(this, 16, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasMounts = function() {
  return jspb.Message.getField(this, 16) != null;
};


/**
 * optional string networks = 17;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getNetworks = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 17, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setNetworks = function(value) {
  return jspb.Message.setField(this, 17, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearNetworks = function() {
  return jspb.Message.setField(this, 17, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasNetworks = function() {
  return jspb.Message.getField(this, 17) != null;
};


/**
 * optional string sockets = 18;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getSockets = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 18, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setSockets = function(value) {
  return jspb.Message.setField(this, 18, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearSockets = function() {
  return jspb.Message.setField(this, 18, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasSockets = function() {
  return jspb.Message.getField(this, 18) != null;
};


/**
 * optional string console = 19;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getConsole = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 19, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setConsole = function(value) {
  return jspb.Message.setField(this, 19, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearConsole = function() {
  return jspb.Message.setField(this, 19, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasConsole = function() {
  return jspb.Message.getField(this, 19) != null;
};


/**
 * optional string attachedDisks = 20;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getAttacheddisks = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 20, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setAttacheddisks = function(value) {
  return jspb.Message.setField(this, 20, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearAttacheddisks = function() {
  return jspb.Message.setField(this, 20, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasAttacheddisks = function() {
  return jspb.Message.getField(this, 20) != null;
};


/**
 * optional bool dynamicPortForwarding = 21;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getDynamicportforwarding = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 21, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setDynamicportforwarding = function(value) {
  return jspb.Message.setField(this, 21, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearDynamicportforwarding = function() {
  return jspb.Message.setField(this, 21, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasDynamicportforwarding = function() {
  return jspb.Message.getField(this, 21) != null;
};


/**
 * optional bool ifnames = 23;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getIfnames = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 23, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setIfnames = function(value) {
  return jspb.Message.setField(this, 23, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearIfnames = function() {
  return jspb.Message.setField(this, 23, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasIfnames = function() {
  return jspb.Message.getField(this, 23) != null;
};


/**
 * optional bool suspendable = 24;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.getSuspendable = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 24, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.setSuspendable = function(value) {
  return jspb.Message.setField(this, 24, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CommonBuildRequest} returns this
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.clearSuspendable = function() {
  return jspb.Message.setField(this, 24, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CommonBuildRequest.prototype.hasSuspendable = function() {
  return jspb.Message.getField(this, 24) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.BuildRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.BuildRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.BuildRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.BuildRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    options: (f = msg.getOptions()) && proto.caked.Caked.VMRequest.CommonBuildRequest.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.BuildRequest}
 */
proto.caked.Caked.VMRequest.BuildRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.BuildRequest;
  return proto.caked.Caked.VMRequest.BuildRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.BuildRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.BuildRequest}
 */
proto.caked.Caked.VMRequest.BuildRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.VMRequest.CommonBuildRequest;
      reader.readMessage(value,proto.caked.Caked.VMRequest.CommonBuildRequest.deserializeBinaryFromReader);
      msg.setOptions(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.BuildRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.BuildRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.BuildRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.BuildRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getOptions();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.VMRequest.CommonBuildRequest.serializeBinaryToWriter
    );
  }
};


/**
 * optional CommonBuildRequest options = 1;
 * @return {?proto.caked.Caked.VMRequest.CommonBuildRequest}
 */
proto.caked.Caked.VMRequest.BuildRequest.prototype.getOptions = function() {
  return /** @type{?proto.caked.Caked.VMRequest.CommonBuildRequest} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.VMRequest.CommonBuildRequest, 1));
};


/**
 * @param {?proto.caked.Caked.VMRequest.CommonBuildRequest|undefined} value
 * @return {!proto.caked.Caked.VMRequest.BuildRequest} returns this
*/
proto.caked.Caked.VMRequest.BuildRequest.prototype.setOptions = function(value) {
  return jspb.Message.setWrapperField(this, 1, value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.BuildRequest} returns this
 */
proto.caked.Caked.VMRequest.BuildRequest.prototype.clearOptions = function() {
  return this.setOptions(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.BuildRequest.prototype.hasOptions = function() {
  return jspb.Message.getField(this, 1) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.StartRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.StartRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.StartRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.StartRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    waitiptimeout: jspb.Message.getFieldWithDefault(msg, 2, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.StartRequest}
 */
proto.caked.Caked.VMRequest.StartRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.StartRequest;
  return proto.caked.Caked.VMRequest.StartRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.StartRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.StartRequest}
 */
proto.caked.Caked.VMRequest.StartRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setWaitiptimeout(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.StartRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.StartRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.StartRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.StartRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeInt32(
      2,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.StartRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.StartRequest} returns this
 */
proto.caked.Caked.VMRequest.StartRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional int32 waitIPTimeout = 2;
 * @return {number}
 */
proto.caked.Caked.VMRequest.StartRequest.prototype.getWaitiptimeout = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.StartRequest} returns this
 */
proto.caked.Caked.VMRequest.StartRequest.prototype.setWaitiptimeout = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.StartRequest} returns this
 */
proto.caked.Caked.VMRequest.StartRequest.prototype.clearWaitiptimeout = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.StartRequest.prototype.hasWaitiptimeout = function() {
  return jspb.Message.getField(this, 2) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.CloneRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.CloneRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.CloneRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    sourcename: jspb.Message.getFieldWithDefault(msg, 1, ""),
    targetname: jspb.Message.getFieldWithDefault(msg, 2, ""),
    insecure: jspb.Message.getBooleanFieldWithDefault(msg, 3, false),
    concurrency: jspb.Message.getFieldWithDefault(msg, 4, 0),
    deduplicate: jspb.Message.getBooleanFieldWithDefault(msg, 5, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.CloneRequest}
 */
proto.caked.Caked.VMRequest.CloneRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.CloneRequest;
  return proto.caked.Caked.VMRequest.CloneRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.CloneRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.CloneRequest}
 */
proto.caked.Caked.VMRequest.CloneRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setSourcename(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setTargetname(value);
      break;
    case 3:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setInsecure(value);
      break;
    case 4:
      var value = /** @type {number} */ (reader.readUint32());
      msg.setConcurrency(value);
      break;
    case 5:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setDeduplicate(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.CloneRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.CloneRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.CloneRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getSourcename();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getTargetname();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeBool(
      3,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeUint32(
      4,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeBool(
      5,
      f
    );
  }
};


/**
 * optional string sourceName = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.getSourcename = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CloneRequest} returns this
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.setSourcename = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string targetName = 2;
 * @return {string}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.getTargetname = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.CloneRequest} returns this
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.setTargetname = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional bool insecure = 3;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.getInsecure = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 3, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.CloneRequest} returns this
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.setInsecure = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CloneRequest} returns this
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.clearInsecure = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.hasInsecure = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional uint32 concurrency = 4;
 * @return {number}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.getConcurrency = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 4, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.CloneRequest} returns this
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.setConcurrency = function(value) {
  return jspb.Message.setField(this, 4, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CloneRequest} returns this
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.clearConcurrency = function() {
  return jspb.Message.setField(this, 4, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.hasConcurrency = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional bool deduplicate = 5;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.getDeduplicate = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 5, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.CloneRequest} returns this
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.setDeduplicate = function(value) {
  return jspb.Message.setField(this, 5, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.CloneRequest} returns this
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.clearDeduplicate = function() {
  return jspb.Message.setField(this, 5, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.CloneRequest.prototype.hasDeduplicate = function() {
  return jspb.Message.getField(this, 5) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.DuplicateRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.DuplicateRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.DuplicateRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.DuplicateRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    from: jspb.Message.getFieldWithDefault(msg, 1, ""),
    to: jspb.Message.getFieldWithDefault(msg, 2, ""),
    resetmacaddress: jspb.Message.getBooleanFieldWithDefault(msg, 3, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.DuplicateRequest}
 */
proto.caked.Caked.VMRequest.DuplicateRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.DuplicateRequest;
  return proto.caked.Caked.VMRequest.DuplicateRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.DuplicateRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.DuplicateRequest}
 */
proto.caked.Caked.VMRequest.DuplicateRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setFrom(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setTo(value);
      break;
    case 3:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setResetmacaddress(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.DuplicateRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.DuplicateRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.DuplicateRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.DuplicateRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getFrom();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getTo();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getResetmacaddress();
  if (f) {
    writer.writeBool(
      3,
      f
    );
  }
};


/**
 * optional string from = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.DuplicateRequest.prototype.getFrom = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.DuplicateRequest} returns this
 */
proto.caked.Caked.VMRequest.DuplicateRequest.prototype.setFrom = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string to = 2;
 * @return {string}
 */
proto.caked.Caked.VMRequest.DuplicateRequest.prototype.getTo = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.DuplicateRequest} returns this
 */
proto.caked.Caked.VMRequest.DuplicateRequest.prototype.setTo = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional bool resetMacAddress = 3;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.DuplicateRequest.prototype.getResetmacaddress = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 3, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.DuplicateRequest} returns this
 */
proto.caked.Caked.VMRequest.DuplicateRequest.prototype.setResetmacaddress = function(value) {
  return jspb.Message.setProto3BooleanField(this, 3, value);
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.LaunchRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.LaunchRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.LaunchRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    options: (f = msg.getOptions()) && proto.caked.Caked.VMRequest.CommonBuildRequest.toObject(includeInstance, f),
    waitiptimeout: jspb.Message.getFieldWithDefault(msg, 2, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.LaunchRequest}
 */
proto.caked.Caked.VMRequest.LaunchRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.LaunchRequest;
  return proto.caked.Caked.VMRequest.LaunchRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.LaunchRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.LaunchRequest}
 */
proto.caked.Caked.VMRequest.LaunchRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.VMRequest.CommonBuildRequest;
      reader.readMessage(value,proto.caked.Caked.VMRequest.CommonBuildRequest.deserializeBinaryFromReader);
      msg.setOptions(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setWaitiptimeout(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.LaunchRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.LaunchRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.LaunchRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getOptions();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.VMRequest.CommonBuildRequest.serializeBinaryToWriter
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeInt32(
      2,
      f
    );
  }
};


/**
 * optional CommonBuildRequest options = 1;
 * @return {?proto.caked.Caked.VMRequest.CommonBuildRequest}
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.getOptions = function() {
  return /** @type{?proto.caked.Caked.VMRequest.CommonBuildRequest} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.VMRequest.CommonBuildRequest, 1));
};


/**
 * @param {?proto.caked.Caked.VMRequest.CommonBuildRequest|undefined} value
 * @return {!proto.caked.Caked.VMRequest.LaunchRequest} returns this
*/
proto.caked.Caked.VMRequest.LaunchRequest.prototype.setOptions = function(value) {
  return jspb.Message.setWrapperField(this, 1, value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.LaunchRequest} returns this
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.clearOptions = function() {
  return this.setOptions(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.hasOptions = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional int32 waitIPTimeout = 2;
 * @return {number}
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.getWaitiptimeout = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.LaunchRequest} returns this
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.setWaitiptimeout = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.LaunchRequest} returns this
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.clearWaitiptimeout = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.LaunchRequest.prototype.hasWaitiptimeout = function() {
  return jspb.Message.getField(this, 2) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.ConfigureRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.ConfigureRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ConfigureRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    cpu: jspb.Message.getFieldWithDefault(msg, 2, 0),
    memory: jspb.Message.getFieldWithDefault(msg, 3, 0),
    disksize: jspb.Message.getFieldWithDefault(msg, 4, 0),
    displayrefit: jspb.Message.getBooleanFieldWithDefault(msg, 5, false),
    autostart: jspb.Message.getBooleanFieldWithDefault(msg, 6, false),
    nested: jspb.Message.getBooleanFieldWithDefault(msg, 7, false),
    mounts: jspb.Message.getFieldWithDefault(msg, 8, ""),
    networks: jspb.Message.getFieldWithDefault(msg, 9, ""),
    sockets: jspb.Message.getFieldWithDefault(msg, 10, ""),
    console: jspb.Message.getFieldWithDefault(msg, 11, ""),
    randommac: jspb.Message.getBooleanFieldWithDefault(msg, 12, false),
    forwardedport: jspb.Message.getFieldWithDefault(msg, 13, ""),
    attacheddisks: jspb.Message.getFieldWithDefault(msg, 14, ""),
    dynamicportforwarding: jspb.Message.getBooleanFieldWithDefault(msg, 15, false),
    suspendable: jspb.Message.getBooleanFieldWithDefault(msg, 16, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.ConfigureRequest;
  return proto.caked.Caked.VMRequest.ConfigureRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.ConfigureRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setCpu(value);
      break;
    case 3:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setMemory(value);
      break;
    case 4:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setDisksize(value);
      break;
    case 5:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setDisplayrefit(value);
      break;
    case 6:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setAutostart(value);
      break;
    case 7:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setNested(value);
      break;
    case 8:
      var value = /** @type {string} */ (reader.readString());
      msg.setMounts(value);
      break;
    case 9:
      var value = /** @type {string} */ (reader.readString());
      msg.setNetworks(value);
      break;
    case 10:
      var value = /** @type {string} */ (reader.readString());
      msg.setSockets(value);
      break;
    case 11:
      var value = /** @type {string} */ (reader.readString());
      msg.setConsole(value);
      break;
    case 12:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setRandommac(value);
      break;
    case 13:
      var value = /** @type {string} */ (reader.readString());
      msg.setForwardedport(value);
      break;
    case 14:
      var value = /** @type {string} */ (reader.readString());
      msg.setAttacheddisks(value);
      break;
    case 15:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setDynamicportforwarding(value);
      break;
    case 16:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setSuspendable(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.ConfigureRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.ConfigureRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ConfigureRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeInt32(
      2,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeInt32(
      3,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeInt32(
      4,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeBool(
      5,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 6));
  if (f != null) {
    writer.writeBool(
      6,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 7));
  if (f != null) {
    writer.writeBool(
      7,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 8));
  if (f != null) {
    writer.writeString(
      8,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 9));
  if (f != null) {
    writer.writeString(
      9,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 10));
  if (f != null) {
    writer.writeString(
      10,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 11));
  if (f != null) {
    writer.writeString(
      11,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 12));
  if (f != null) {
    writer.writeBool(
      12,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 13));
  if (f != null) {
    writer.writeString(
      13,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 14));
  if (f != null) {
    writer.writeString(
      14,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 15));
  if (f != null) {
    writer.writeBool(
      15,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 16));
  if (f != null) {
    writer.writeBool(
      16,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional int32 cpu = 2;
 * @return {number}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getCpu = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setCpu = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearCpu = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasCpu = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional int32 memory = 3;
 * @return {number}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getMemory = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setMemory = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearMemory = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasMemory = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional int32 diskSize = 4;
 * @return {number}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getDisksize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 4, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setDisksize = function(value) {
  return jspb.Message.setField(this, 4, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearDisksize = function() {
  return jspb.Message.setField(this, 4, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasDisksize = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional bool displayRefit = 5;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getDisplayrefit = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 5, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setDisplayrefit = function(value) {
  return jspb.Message.setField(this, 5, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearDisplayrefit = function() {
  return jspb.Message.setField(this, 5, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasDisplayrefit = function() {
  return jspb.Message.getField(this, 5) != null;
};


/**
 * optional bool autostart = 6;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getAutostart = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 6, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setAutostart = function(value) {
  return jspb.Message.setField(this, 6, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearAutostart = function() {
  return jspb.Message.setField(this, 6, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasAutostart = function() {
  return jspb.Message.getField(this, 6) != null;
};


/**
 * optional bool nested = 7;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getNested = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 7, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setNested = function(value) {
  return jspb.Message.setField(this, 7, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearNested = function() {
  return jspb.Message.setField(this, 7, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasNested = function() {
  return jspb.Message.getField(this, 7) != null;
};


/**
 * optional string mounts = 8;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getMounts = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 8, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setMounts = function(value) {
  return jspb.Message.setField(this, 8, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearMounts = function() {
  return jspb.Message.setField(this, 8, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasMounts = function() {
  return jspb.Message.getField(this, 8) != null;
};


/**
 * optional string networks = 9;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getNetworks = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 9, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setNetworks = function(value) {
  return jspb.Message.setField(this, 9, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearNetworks = function() {
  return jspb.Message.setField(this, 9, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasNetworks = function() {
  return jspb.Message.getField(this, 9) != null;
};


/**
 * optional string sockets = 10;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getSockets = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 10, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setSockets = function(value) {
  return jspb.Message.setField(this, 10, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearSockets = function() {
  return jspb.Message.setField(this, 10, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasSockets = function() {
  return jspb.Message.getField(this, 10) != null;
};


/**
 * optional string console = 11;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getConsole = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 11, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setConsole = function(value) {
  return jspb.Message.setField(this, 11, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearConsole = function() {
  return jspb.Message.setField(this, 11, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasConsole = function() {
  return jspb.Message.getField(this, 11) != null;
};


/**
 * optional bool randomMAC = 12;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getRandommac = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 12, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setRandommac = function(value) {
  return jspb.Message.setField(this, 12, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearRandommac = function() {
  return jspb.Message.setField(this, 12, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasRandommac = function() {
  return jspb.Message.getField(this, 12) != null;
};


/**
 * optional string forwardedPort = 13;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getForwardedport = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 13, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setForwardedport = function(value) {
  return jspb.Message.setField(this, 13, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearForwardedport = function() {
  return jspb.Message.setField(this, 13, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasForwardedport = function() {
  return jspb.Message.getField(this, 13) != null;
};


/**
 * optional string attachedDisks = 14;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getAttacheddisks = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 14, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setAttacheddisks = function(value) {
  return jspb.Message.setField(this, 14, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearAttacheddisks = function() {
  return jspb.Message.setField(this, 14, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasAttacheddisks = function() {
  return jspb.Message.getField(this, 14) != null;
};


/**
 * optional bool dynamicPortForwarding = 15;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getDynamicportforwarding = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 15, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setDynamicportforwarding = function(value) {
  return jspb.Message.setField(this, 15, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearDynamicportforwarding = function() {
  return jspb.Message.setField(this, 15, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasDynamicportforwarding = function() {
  return jspb.Message.getField(this, 15) != null;
};


/**
 * optional bool suspendable = 16;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.getSuspendable = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 16, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.setSuspendable = function(value) {
  return jspb.Message.setField(this, 16, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ConfigureRequest} returns this
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.clearSuspendable = function() {
  return jspb.Message.setField(this, 16, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ConfigureRequest.prototype.hasSuspendable = function() {
  return jspb.Message.getField(this, 16) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.WaitIPRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.WaitIPRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.WaitIPRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.WaitIPRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    timeout: jspb.Message.getFieldWithDefault(msg, 2, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.WaitIPRequest}
 */
proto.caked.Caked.VMRequest.WaitIPRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.WaitIPRequest;
  return proto.caked.Caked.VMRequest.WaitIPRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.WaitIPRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.WaitIPRequest}
 */
proto.caked.Caked.VMRequest.WaitIPRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setTimeout(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.WaitIPRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.WaitIPRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.WaitIPRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.WaitIPRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getTimeout();
  if (f !== 0) {
    writer.writeInt32(
      2,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.WaitIPRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.WaitIPRequest} returns this
 */
proto.caked.Caked.VMRequest.WaitIPRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional int32 timeout = 2;
 * @return {number}
 */
proto.caked.Caked.VMRequest.WaitIPRequest.prototype.getTimeout = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.WaitIPRequest} returns this
 */
proto.caked.Caked.VMRequest.WaitIPRequest.prototype.setTimeout = function(value) {
  return jspb.Message.setProto3IntField(this, 2, value);
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.VMRequest.StopRequest.oneofGroups_ = [[2,3]];

/**
 * @enum {number}
 */
proto.caked.Caked.VMRequest.StopRequest.StopCase = {
  STOP_NOT_SET: 0,
  ALL: 2,
  NAMES: 3
};

/**
 * @return {proto.caked.Caked.VMRequest.StopRequest.StopCase}
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.getStopCase = function() {
  return /** @type {proto.caked.Caked.VMRequest.StopRequest.StopCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.VMRequest.StopRequest.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.StopRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.StopRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.StopRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    force: jspb.Message.getBooleanFieldWithDefault(msg, 1, false),
    all: jspb.Message.getBooleanFieldWithDefault(msg, 2, false),
    names: (f = msg.getNames()) && proto.caked.Caked.VMRequest.StopRequest.VMNames.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.StopRequest}
 */
proto.caked.Caked.VMRequest.StopRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.StopRequest;
  return proto.caked.Caked.VMRequest.StopRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.StopRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.StopRequest}
 */
proto.caked.Caked.VMRequest.StopRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setForce(value);
      break;
    case 2:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setAll(value);
      break;
    case 3:
      var value = new proto.caked.Caked.VMRequest.StopRequest.VMNames;
      reader.readMessage(value,proto.caked.Caked.VMRequest.StopRequest.VMNames.deserializeBinaryFromReader);
      msg.setNames(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.StopRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.StopRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.StopRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getForce();
  if (f) {
    writer.writeBool(
      1,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeBool(
      2,
      f
    );
  }
  f = message.getNames();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.VMRequest.StopRequest.VMNames.serializeBinaryToWriter
    );
  }
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.StopRequest.VMNames.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.StopRequest.VMNames} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.toObject = function(includeInstance, msg) {
  var f, obj = {
    listList: (f = jspb.Message.getRepeatedField(msg, 1)) == null ? undefined : f
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.StopRequest.VMNames}
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.StopRequest.VMNames;
  return proto.caked.Caked.VMRequest.StopRequest.VMNames.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.StopRequest.VMNames} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.StopRequest.VMNames}
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.addList(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.StopRequest.VMNames.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.StopRequest.VMNames} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getListList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      1,
      f
    );
  }
};


/**
 * repeated string list = 1;
 * @return {!Array<string>}
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.prototype.getListList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 1));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.VMRequest.StopRequest.VMNames} returns this
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.prototype.setListList = function(value) {
  return jspb.Message.setField(this, 1, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.VMRequest.StopRequest.VMNames} returns this
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.prototype.addList = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 1, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.VMRequest.StopRequest.VMNames} returns this
 */
proto.caked.Caked.VMRequest.StopRequest.VMNames.prototype.clearListList = function() {
  return this.setListList([]);
};


/**
 * optional bool force = 1;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.getForce = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 1, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.StopRequest} returns this
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.setForce = function(value) {
  return jspb.Message.setProto3BooleanField(this, 1, value);
};


/**
 * optional bool all = 2;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.getAll = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 2, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.StopRequest} returns this
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.setAll = function(value) {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.StopRequest.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.StopRequest} returns this
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.clearAll = function() {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.StopRequest.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.hasAll = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional VMNames names = 3;
 * @return {?proto.caked.Caked.VMRequest.StopRequest.VMNames}
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.getNames = function() {
  return /** @type{?proto.caked.Caked.VMRequest.StopRequest.VMNames} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.VMRequest.StopRequest.VMNames, 3));
};


/**
 * @param {?proto.caked.Caked.VMRequest.StopRequest.VMNames|undefined} value
 * @return {!proto.caked.Caked.VMRequest.StopRequest} returns this
*/
proto.caked.Caked.VMRequest.StopRequest.prototype.setNames = function(value) {
  return jspb.Message.setOneofWrapperField(this, 3, proto.caked.Caked.VMRequest.StopRequest.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.StopRequest} returns this
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.clearNames = function() {
  return this.setNames(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.StopRequest.prototype.hasNames = function() {
  return jspb.Message.getField(this, 3) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.VMRequest.DeleteRequest.oneofGroups_ = [[2,3]];

/**
 * @enum {number}
 */
proto.caked.Caked.VMRequest.DeleteRequest.DeleteCase = {
  DELETE_NOT_SET: 0,
  ALL: 2,
  NAMES: 3
};

/**
 * @return {proto.caked.Caked.VMRequest.DeleteRequest.DeleteCase}
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.getDeleteCase = function() {
  return /** @type {proto.caked.Caked.VMRequest.DeleteRequest.DeleteCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.VMRequest.DeleteRequest.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.DeleteRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.DeleteRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.DeleteRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    all: jspb.Message.getBooleanFieldWithDefault(msg, 2, false),
    names: (f = msg.getNames()) && proto.caked.Caked.VMRequest.DeleteRequest.VMNames.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest}
 */
proto.caked.Caked.VMRequest.DeleteRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.DeleteRequest;
  return proto.caked.Caked.VMRequest.DeleteRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.DeleteRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest}
 */
proto.caked.Caked.VMRequest.DeleteRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 2:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setAll(value);
      break;
    case 3:
      var value = new proto.caked.Caked.VMRequest.DeleteRequest.VMNames;
      reader.readMessage(value,proto.caked.Caked.VMRequest.DeleteRequest.VMNames.deserializeBinaryFromReader);
      msg.setNames(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.DeleteRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.DeleteRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.DeleteRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = /** @type {boolean} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeBool(
      2,
      f
    );
  }
  f = message.getNames();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.VMRequest.DeleteRequest.VMNames.serializeBinaryToWriter
    );
  }
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.DeleteRequest.VMNames.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.DeleteRequest.VMNames} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.toObject = function(includeInstance, msg) {
  var f, obj = {
    listList: (f = jspb.Message.getRepeatedField(msg, 1)) == null ? undefined : f
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest.VMNames}
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.DeleteRequest.VMNames;
  return proto.caked.Caked.VMRequest.DeleteRequest.VMNames.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.DeleteRequest.VMNames} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest.VMNames}
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.addList(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.DeleteRequest.VMNames.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.DeleteRequest.VMNames} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getListList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      1,
      f
    );
  }
};


/**
 * repeated string list = 1;
 * @return {!Array<string>}
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.prototype.getListList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 1));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest.VMNames} returns this
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.prototype.setListList = function(value) {
  return jspb.Message.setField(this, 1, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest.VMNames} returns this
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.prototype.addList = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 1, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest.VMNames} returns this
 */
proto.caked.Caked.VMRequest.DeleteRequest.VMNames.prototype.clearListList = function() {
  return this.setListList([]);
};


/**
 * optional bool all = 2;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.getAll = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 2, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest} returns this
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.setAll = function(value) {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.DeleteRequest.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest} returns this
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.clearAll = function() {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.DeleteRequest.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.hasAll = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional VMNames names = 3;
 * @return {?proto.caked.Caked.VMRequest.DeleteRequest.VMNames}
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.getNames = function() {
  return /** @type{?proto.caked.Caked.VMRequest.DeleteRequest.VMNames} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.VMRequest.DeleteRequest.VMNames, 3));
};


/**
 * @param {?proto.caked.Caked.VMRequest.DeleteRequest.VMNames|undefined} value
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest} returns this
*/
proto.caked.Caked.VMRequest.DeleteRequest.prototype.setNames = function(value) {
  return jspb.Message.setOneofWrapperField(this, 3, proto.caked.Caked.VMRequest.DeleteRequest.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.DeleteRequest} returns this
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.clearNames = function() {
  return this.setNames(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.DeleteRequest.prototype.hasNames = function() {
  return jspb.Message.getField(this, 3) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.ListRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.ListRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.ListRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ListRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    vmonly: jspb.Message.getBooleanFieldWithDefault(msg, 1, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.ListRequest}
 */
proto.caked.Caked.VMRequest.ListRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.ListRequest;
  return proto.caked.Caked.VMRequest.ListRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.ListRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.ListRequest}
 */
proto.caked.Caked.VMRequest.ListRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setVmonly(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ListRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.ListRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.ListRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ListRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getVmonly();
  if (f) {
    writer.writeBool(
      1,
      f
    );
  }
};


/**
 * optional bool vmonly = 1;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ListRequest.prototype.getVmonly = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 1, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ListRequest} returns this
 */
proto.caked.Caked.VMRequest.ListRequest.prototype.setVmonly = function(value) {
  return jspb.Message.setProto3BooleanField(this, 1, value);
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.InfoRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.InfoRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.InfoRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.InfoRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.InfoRequest}
 */
proto.caked.Caked.VMRequest.InfoRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.InfoRequest;
  return proto.caked.Caked.VMRequest.InfoRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.InfoRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.InfoRequest}
 */
proto.caked.Caked.VMRequest.InfoRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.InfoRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.InfoRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.InfoRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.InfoRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.InfoRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.InfoRequest} returns this
 */
proto.caked.Caked.VMRequest.InfoRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.RenameRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.RenameRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.RenameRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.RenameRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    oldname: jspb.Message.getFieldWithDefault(msg, 1, ""),
    newname: jspb.Message.getFieldWithDefault(msg, 2, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.RenameRequest}
 */
proto.caked.Caked.VMRequest.RenameRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.RenameRequest;
  return proto.caked.Caked.VMRequest.RenameRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.RenameRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.RenameRequest}
 */
proto.caked.Caked.VMRequest.RenameRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setOldname(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setNewname(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.RenameRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.RenameRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.RenameRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.RenameRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getOldname();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getNewname();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
};


/**
 * optional string oldname = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.RenameRequest.prototype.getOldname = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.RenameRequest} returns this
 */
proto.caked.Caked.VMRequest.RenameRequest.prototype.setOldname = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string newname = 2;
 * @return {string}
 */
proto.caked.Caked.VMRequest.RenameRequest.prototype.getNewname = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.RenameRequest} returns this
 */
proto.caked.Caked.VMRequest.RenameRequest.prototype.setNewname = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.VMRequest.TemplateRequest.oneofGroups_ = [[2,3]];

/**
 * @enum {number}
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateCase = {
  TEMPLATE_NOT_SET: 0,
  CREATEREQUEST: 2,
  DELETEREQUEST: 3
};

/**
 * @return {proto.caked.Caked.VMRequest.TemplateRequest.TemplateCase}
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.getTemplateCase = function() {
  return /** @type {proto.caked.Caked.VMRequest.TemplateRequest.TemplateCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.VMRequest.TemplateRequest.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.TemplateRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.TemplateRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.TemplateRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: jspb.Message.getFieldWithDefault(msg, 1, 0),
    createrequest: (f = msg.getCreaterequest()) && proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.toObject(includeInstance, f),
    deleterequest: jspb.Message.getFieldWithDefault(msg, 3, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest}
 */
proto.caked.Caked.VMRequest.TemplateRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.TemplateRequest;
  return proto.caked.Caked.VMRequest.TemplateRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.TemplateRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest}
 */
proto.caked.Caked.VMRequest.TemplateRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateCommand} */ (reader.readEnum());
      msg.setCommand(value);
      break;
    case 2:
      var value = new proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd;
      reader.readMessage(value,proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.deserializeBinaryFromReader);
      msg.setCreaterequest(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setDeleterequest(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.TemplateRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.TemplateRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.TemplateRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = message.getCreaterequest();
  if (f != null) {
    writer.writeMessage(
      2,
      f,
      proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.serializeBinaryToWriter
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
};


/**
 * @enum {number}
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateCommand = {
  NONE: 0,
  ADD: 1,
  DELETE: 2,
  LIST: 3
};




if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.toObject = function(includeInstance, msg) {
  var f, obj = {
    sourcename: jspb.Message.getFieldWithDefault(msg, 1, ""),
    templatename: jspb.Message.getFieldWithDefault(msg, 2, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd}
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd;
  return proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd}
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setSourcename(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setTemplatename(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getSourcename();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getTemplatename();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
};


/**
 * optional string sourceName = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.prototype.getSourcename = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd} returns this
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.prototype.setSourcename = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string templateName = 2;
 * @return {string}
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.prototype.getTemplatename = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd} returns this
 */
proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd.prototype.setTemplatename = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional TemplateCommand command = 1;
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateCommand}
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.getCommand = function() {
  return /** @type {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateCommand} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.VMRequest.TemplateRequest.TemplateCommand} value
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest} returns this
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.setCommand = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional TemplateRequestAdd createRequest = 2;
 * @return {?proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd}
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.getCreaterequest = function() {
  return /** @type{?proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd, 2));
};


/**
 * @param {?proto.caked.Caked.VMRequest.TemplateRequest.TemplateRequestAdd|undefined} value
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest} returns this
*/
proto.caked.Caked.VMRequest.TemplateRequest.prototype.setCreaterequest = function(value) {
  return jspb.Message.setOneofWrapperField(this, 2, proto.caked.Caked.VMRequest.TemplateRequest.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest} returns this
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.clearCreaterequest = function() {
  return this.setCreaterequest(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.hasCreaterequest = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional string deleteRequest = 3;
 * @return {string}
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.getDeleterequest = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest} returns this
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.setDeleterequest = function(value) {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.VMRequest.TemplateRequest.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.TemplateRequest} returns this
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.clearDeleterequest = function() {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.VMRequest.TemplateRequest.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.TemplateRequest.prototype.hasDeleterequest = function() {
  return jspb.Message.getField(this, 3) != null;
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.VMRequest.RunCommand.repeatedFields_ = [3];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.RunCommand.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.RunCommand} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.RunCommand.toObject = function(includeInstance, msg) {
  var f, obj = {
    vmname: jspb.Message.getFieldWithDefault(msg, 1, ""),
    command: jspb.Message.getFieldWithDefault(msg, 2, ""),
    argsList: (f = jspb.Message.getRepeatedField(msg, 3)) == null ? undefined : f,
    input: msg.getInput_asB64()
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.RunCommand}
 */
proto.caked.Caked.VMRequest.RunCommand.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.RunCommand;
  return proto.caked.Caked.VMRequest.RunCommand.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.RunCommand} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.RunCommand}
 */
proto.caked.Caked.VMRequest.RunCommand.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setVmname(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setCommand(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.addArgs(value);
      break;
    case 4:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setInput(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.RunCommand.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.RunCommand} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.RunCommand.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getVmname();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getCommand();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getArgsList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      3,
      f
    );
  }
  f = /** @type {!(string|Uint8Array)} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeBytes(
      4,
      f
    );
  }
};


/**
 * optional string vmname = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.getVmname = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.RunCommand} returns this
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.setVmname = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string command = 2;
 * @return {string}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.getCommand = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.RunCommand} returns this
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.setCommand = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * repeated string args = 3;
 * @return {!Array<string>}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.getArgsList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 3));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.VMRequest.RunCommand} returns this
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.setArgsList = function(value) {
  return jspb.Message.setField(this, 3, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.VMRequest.RunCommand} returns this
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.addArgs = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 3, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.VMRequest.RunCommand} returns this
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.clearArgsList = function() {
  return this.setArgsList([]);
};


/**
 * optional bytes input = 4;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.getInput = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * optional bytes input = 4;
 * This is a type-conversion wrapper around `getInput()`
 * @return {string}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.getInput_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getInput()));
};


/**
 * optional bytes input = 4;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getInput()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.getInput_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getInput()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.VMRequest.RunCommand} returns this
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.setInput = function(value) {
  return jspb.Message.setField(this, 4, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.RunCommand} returns this
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.clearInput = function() {
  return jspb.Message.setField(this, 4, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.RunCommand.prototype.hasInput = function() {
  return jspb.Message.getField(this, 4) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_ = [[1,2,3,4,5]];

/**
 * @enum {number}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  EXITCODE: 1,
  STDOUT: 2,
  STDERR: 3,
  FAILURE: 4,
  ESTABLISHED: 5
};

/**
 * @return {proto.caked.Caked.VMRequest.ExecuteResponse.ResponseCase}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.VMRequest.ExecuteResponse.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.ExecuteResponse.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.ExecuteResponse} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteResponse.toObject = function(includeInstance, msg) {
  var f, obj = {
    exitcode: jspb.Message.getFieldWithDefault(msg, 1, 0),
    stdout: msg.getStdout_asB64(),
    stderr: msg.getStderr_asB64(),
    failure: jspb.Message.getFieldWithDefault(msg, 4, ""),
    established: jspb.Message.getBooleanFieldWithDefault(msg, 5, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.ExecuteResponse;
  return proto.caked.Caked.VMRequest.ExecuteResponse.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.ExecuteResponse} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setExitcode(value);
      break;
    case 2:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setStdout(value);
      break;
    case 3:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setStderr(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setFailure(value);
      break;
    case 5:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setEstablished(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.ExecuteResponse.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.ExecuteResponse} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteResponse.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = /** @type {number} */ (jspb.Message.getField(message, 1));
  if (f != null) {
    writer.writeInt32(
      1,
      f
    );
  }
  f = /** @type {!(string|Uint8Array)} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeBytes(
      2,
      f
    );
  }
  f = /** @type {!(string|Uint8Array)} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeBytes(
      3,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeString(
      4,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeBool(
      5,
      f
    );
  }
};


/**
 * optional int32 exitCode = 1;
 * @return {number}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getExitcode = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.setExitcode = function(value) {
  return jspb.Message.setOneofField(this, 1, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.clearExitcode = function() {
  return jspb.Message.setOneofField(this, 1, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.hasExitcode = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional bytes stdout = 2;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getStdout = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * optional bytes stdout = 2;
 * This is a type-conversion wrapper around `getStdout()`
 * @return {string}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getStdout_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getStdout()));
};


/**
 * optional bytes stdout = 2;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getStdout()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getStdout_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getStdout()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.setStdout = function(value) {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.clearStdout = function() {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.hasStdout = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional bytes stderr = 3;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getStderr = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * optional bytes stderr = 3;
 * This is a type-conversion wrapper around `getStderr()`
 * @return {string}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getStderr_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getStderr()));
};


/**
 * optional bytes stderr = 3;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getStderr()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getStderr_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getStderr()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.setStderr = function(value) {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.clearStderr = function() {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.hasStderr = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional string failure = 4;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getFailure = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.setFailure = function(value) {
  return jspb.Message.setOneofField(this, 4, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.clearFailure = function() {
  return jspb.Message.setOneofField(this, 4, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.hasFailure = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional bool established = 5;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.getEstablished = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 5, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.setEstablished = function(value) {
  return jspb.Message.setOneofField(this, 5, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteResponse} returns this
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.clearEstablished = function() {
  return jspb.Message.setOneofField(this, 5, proto.caked.Caked.VMRequest.ExecuteResponse.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteResponse.prototype.hasEstablished = function() {
  return jspb.Message.getField(this, 5) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_ = [[1,2,3,4]];

/**
 * @enum {number}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCase = {
  EXECUTE_NOT_SET: 0,
  COMMAND: 1,
  INPUT: 2,
  SIZE: 3,
  EOF: 4
};

/**
 * @return {proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCase}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.getExecuteCase = function() {
  return /** @type {proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.ExecuteRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: (f = msg.getCommand()) && proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.toObject(includeInstance, f),
    input: msg.getInput_asB64(),
    size: (f = msg.getSize()) && proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.toObject(includeInstance, f),
    eof: jspb.Message.getBooleanFieldWithDefault(msg, 4, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.ExecuteRequest;
  return proto.caked.Caked.VMRequest.ExecuteRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand;
      reader.readMessage(value,proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.deserializeBinaryFromReader);
      msg.setCommand(value);
      break;
    case 2:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setInput(value);
      break;
    case 3:
      var value = new proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize;
      reader.readMessage(value,proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.deserializeBinaryFromReader);
      msg.setSize(value);
      break;
    case 4:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setEof(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.ExecuteRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.serializeBinaryToWriter
    );
  }
  f = /** @type {!(string|Uint8Array)} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeBytes(
      2,
      f
    );
  }
  f = message.getSize();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.serializeBinaryToWriter
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeBool(
      4,
      f
    );
  }
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.oneofGroups_ = [[1,2]];

/**
 * @enum {number}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.ExecuteCase = {
  EXECUTE_NOT_SET: 0,
  COMMAND: 1,
  SHELL: 2
};

/**
 * @return {proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.ExecuteCase}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.getExecuteCase = function() {
  return /** @type {proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.ExecuteCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: (f = msg.getCommand()) && proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.toObject(includeInstance, f),
    shell: jspb.Message.getBooleanFieldWithDefault(msg, 2, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand;
  return proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command;
      reader.readMessage(value,proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.deserializeBinaryFromReader);
      msg.setCommand(value);
      break;
    case 2:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setShell(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.serializeBinaryToWriter
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeBool(
      2,
      f
    );
  }
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.repeatedFields_ = [2];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: jspb.Message.getFieldWithDefault(msg, 1, ""),
    argsList: (f = jspb.Message.getRepeatedField(msg, 2)) == null ? undefined : f
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command;
  return proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setCommand(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.addArgs(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getArgsList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      2,
      f
    );
  }
};


/**
 * optional string command = 1;
 * @return {string}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.prototype.getCommand = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.prototype.setCommand = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * repeated string args = 2;
 * @return {!Array<string>}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.prototype.getArgsList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 2));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.prototype.setArgsList = function(value) {
  return jspb.Message.setField(this, 2, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.prototype.addArgs = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 2, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.prototype.clearArgsList = function() {
  return this.setArgsList([]);
};


/**
 * optional Command command = 1;
 * @return {?proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.getCommand = function() {
  return /** @type{?proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command, 1));
};


/**
 * @param {?proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command|undefined} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand} returns this
*/
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.setCommand = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.clearCommand = function() {
  return this.setCommand(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.hasCommand = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional bool shell = 2;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.getShell = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 2, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.setShell = function(value) {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.clearShell = function() {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand.prototype.hasShell = function() {
  return jspb.Message.getField(this, 2) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.toObject = function(includeInstance, msg) {
  var f, obj = {
    rows: jspb.Message.getFieldWithDefault(msg, 1, 0),
    cols: jspb.Message.getFieldWithDefault(msg, 2, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize;
  return proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setRows(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setCols(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getRows();
  if (f !== 0) {
    writer.writeInt32(
      1,
      f
    );
  }
  f = message.getCols();
  if (f !== 0) {
    writer.writeInt32(
      2,
      f
    );
  }
};


/**
 * optional int32 rows = 1;
 * @return {number}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.prototype.getRows = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.prototype.setRows = function(value) {
  return jspb.Message.setProto3IntField(this, 1, value);
};


/**
 * optional int32 cols = 2;
 * @return {number}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.prototype.getCols = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize.prototype.setCols = function(value) {
  return jspb.Message.setProto3IntField(this, 2, value);
};


/**
 * optional ExecuteCommand command = 1;
 * @return {?proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.getCommand = function() {
  return /** @type{?proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand, 1));
};


/**
 * @param {?proto.caked.Caked.VMRequest.ExecuteRequest.ExecuteCommand|undefined} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest} returns this
*/
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.setCommand = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.clearCommand = function() {
  return this.setCommand(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.hasCommand = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional bytes input = 2;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.getInput = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * optional bytes input = 2;
 * This is a type-conversion wrapper around `getInput()`
 * @return {string}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.getInput_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getInput()));
};


/**
 * optional bytes input = 2;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getInput()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.getInput_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getInput()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.setInput = function(value) {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.clearInput = function() {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.hasInput = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional TerminalSize size = 3;
 * @return {?proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.getSize = function() {
  return /** @type{?proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize, 3));
};


/**
 * @param {?proto.caked.Caked.VMRequest.ExecuteRequest.TerminalSize|undefined} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest} returns this
*/
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.setSize = function(value) {
  return jspb.Message.setOneofWrapperField(this, 3, proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.clearSize = function() {
  return this.setSize(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.hasSize = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional bool eof = 4;
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.getEof = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 4, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.setEof = function(value) {
  return jspb.Message.setOneofField(this, 4, proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.VMRequest.ExecuteRequest} returns this
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.clearEof = function() {
  return jspb.Message.setOneofField(this, 4, proto.caked.Caked.VMRequest.ExecuteRequest.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.VMRequest.ExecuteRequest.prototype.hasEof = function() {
  return jspb.Message.getField(this, 4) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.oneofGroups_ = [[1,3,4,5,6,7,8,9,10]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  ERROR: 1,
  VMS: 3,
  IMAGES: 4,
  NETWORKS: 5,
  REMOTES: 6,
  TEMPLATES: 7,
  RUN: 8,
  MOUNTS: 9,
  TART: 10
};

/**
 * @return {proto.caked.Caked.Reply.ResponseCase}
 */
proto.caked.Caked.Reply.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.Reply.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.toObject = function(includeInstance, msg) {
  var f, obj = {
    error: (f = msg.getError()) && proto.caked.Caked.Reply.Error.toObject(includeInstance, f),
    vms: (f = msg.getVms()) && proto.caked.Caked.Reply.VirtualMachineReply.toObject(includeInstance, f),
    images: (f = msg.getImages()) && proto.caked.Caked.Reply.ImageReply.toObject(includeInstance, f),
    networks: (f = msg.getNetworks()) && proto.caked.Caked.Reply.NetworksReply.toObject(includeInstance, f),
    remotes: (f = msg.getRemotes()) && proto.caked.Caked.Reply.RemoteReply.toObject(includeInstance, f),
    templates: (f = msg.getTemplates()) && proto.caked.Caked.Reply.TemplateReply.toObject(includeInstance, f),
    run: (f = msg.getRun()) && proto.caked.Caked.Reply.RunReply.toObject(includeInstance, f),
    mounts: (f = msg.getMounts()) && proto.caked.Caked.Reply.MountReply.toObject(includeInstance, f),
    tart: (f = msg.getTart()) && proto.caked.Caked.Reply.TartReply.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply}
 */
proto.caked.Caked.Reply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply;
  return proto.caked.Caked.Reply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply}
 */
proto.caked.Caked.Reply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.Error;
      reader.readMessage(value,proto.caked.Caked.Reply.Error.deserializeBinaryFromReader);
      msg.setError(value);
      break;
    case 3:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.deserializeBinaryFromReader);
      msg.setVms(value);
      break;
    case 4:
      var value = new proto.caked.Caked.Reply.ImageReply;
      reader.readMessage(value,proto.caked.Caked.Reply.ImageReply.deserializeBinaryFromReader);
      msg.setImages(value);
      break;
    case 5:
      var value = new proto.caked.Caked.Reply.NetworksReply;
      reader.readMessage(value,proto.caked.Caked.Reply.NetworksReply.deserializeBinaryFromReader);
      msg.setNetworks(value);
      break;
    case 6:
      var value = new proto.caked.Caked.Reply.RemoteReply;
      reader.readMessage(value,proto.caked.Caked.Reply.RemoteReply.deserializeBinaryFromReader);
      msg.setRemotes(value);
      break;
    case 7:
      var value = new proto.caked.Caked.Reply.TemplateReply;
      reader.readMessage(value,proto.caked.Caked.Reply.TemplateReply.deserializeBinaryFromReader);
      msg.setTemplates(value);
      break;
    case 8:
      var value = new proto.caked.Caked.Reply.RunReply;
      reader.readMessage(value,proto.caked.Caked.Reply.RunReply.deserializeBinaryFromReader);
      msg.setRun(value);
      break;
    case 9:
      var value = new proto.caked.Caked.Reply.MountReply;
      reader.readMessage(value,proto.caked.Caked.Reply.MountReply.deserializeBinaryFromReader);
      msg.setMounts(value);
      break;
    case 10:
      var value = new proto.caked.Caked.Reply.TartReply;
      reader.readMessage(value,proto.caked.Caked.Reply.TartReply.deserializeBinaryFromReader);
      msg.setTart(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getError();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.Reply.Error.serializeBinaryToWriter
    );
  }
  f = message.getVms();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.serializeBinaryToWriter
    );
  }
  f = message.getImages();
  if (f != null) {
    writer.writeMessage(
      4,
      f,
      proto.caked.Caked.Reply.ImageReply.serializeBinaryToWriter
    );
  }
  f = message.getNetworks();
  if (f != null) {
    writer.writeMessage(
      5,
      f,
      proto.caked.Caked.Reply.NetworksReply.serializeBinaryToWriter
    );
  }
  f = message.getRemotes();
  if (f != null) {
    writer.writeMessage(
      6,
      f,
      proto.caked.Caked.Reply.RemoteReply.serializeBinaryToWriter
    );
  }
  f = message.getTemplates();
  if (f != null) {
    writer.writeMessage(
      7,
      f,
      proto.caked.Caked.Reply.TemplateReply.serializeBinaryToWriter
    );
  }
  f = message.getRun();
  if (f != null) {
    writer.writeMessage(
      8,
      f,
      proto.caked.Caked.Reply.RunReply.serializeBinaryToWriter
    );
  }
  f = message.getMounts();
  if (f != null) {
    writer.writeMessage(
      9,
      f,
      proto.caked.Caked.Reply.MountReply.serializeBinaryToWriter
    );
  }
  f = message.getTart();
  if (f != null) {
    writer.writeMessage(
      10,
      f,
      proto.caked.Caked.Reply.TartReply.serializeBinaryToWriter
    );
  }
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.Error.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.Error.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.Error} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.Error.toObject = function(includeInstance, msg) {
  var f, obj = {
    code: jspb.Message.getFieldWithDefault(msg, 1, 0),
    reason: jspb.Message.getFieldWithDefault(msg, 2, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.Error}
 */
proto.caked.Caked.Reply.Error.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.Error;
  return proto.caked.Caked.Reply.Error.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.Error} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.Error}
 */
proto.caked.Caked.Reply.Error.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setCode(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setReason(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.Error.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.Error.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.Error} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.Error.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCode();
  if (f !== 0) {
    writer.writeInt32(
      1,
      f
    );
  }
  f = message.getReason();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
};


/**
 * optional int32 code = 1;
 * @return {number}
 */
proto.caked.Caked.Reply.Error.prototype.getCode = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.Error} returns this
 */
proto.caked.Caked.Reply.Error.prototype.setCode = function(value) {
  return jspb.Message.setProto3IntField(this, 1, value);
};


/**
 * optional string reason = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.Error.prototype.getReason = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.Error} returns this
 */
proto.caked.Caked.Reply.Error.prototype.setReason = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_ = [[1,2,3,4,5]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  LIST: 1,
  DELETE: 2,
  STOP: 3,
  INFOS: 4,
  MESSAGE: 5
};

/**
 * @return {proto.caked.Caked.Reply.VirtualMachineReply.ResponseCase}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.Reply.VirtualMachineReply.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    list: (f = msg.getList()) && proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.toObject(includeInstance, f),
    pb_delete: (f = msg.getDelete()) && proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.toObject(includeInstance, f),
    stop: (f = msg.getStop()) && proto.caked.Caked.Reply.VirtualMachineReply.StopReply.toObject(includeInstance, f),
    infos: (f = msg.getInfos()) && proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.toObject(includeInstance, f),
    message: jspb.Message.getFieldWithDefault(msg, 5, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply;
  return proto.caked.Caked.Reply.VirtualMachineReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.deserializeBinaryFromReader);
      msg.setList(value);
      break;
    case 2:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.deserializeBinaryFromReader);
      msg.setDelete(value);
      break;
    case 3:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.StopReply;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.StopReply.deserializeBinaryFromReader);
      msg.setStop(value);
      break;
    case 4:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.deserializeBinaryFromReader);
      msg.setInfos(value);
      break;
    case 5:
      var value = /** @type {string} */ (reader.readString());
      msg.setMessage(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getList();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.serializeBinaryToWriter
    );
  }
  f = message.getDelete();
  if (f != null) {
    writer.writeMessage(
      2,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.serializeBinaryToWriter
    );
  }
  f = message.getStop();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.StopReply.serializeBinaryToWriter
    );
  }
  f = message.getInfos();
  if (f != null) {
    writer.writeMessage(
      4,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.serializeBinaryToWriter
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeString(
      5,
      f
    );
  }
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    infosList: jspb.Message.toObjectList(msg.getInfosList(),
    proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply;
  return proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.deserializeBinaryFromReader);
      msg.addInfos(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getInfosList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      1,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.serializeBinaryToWriter
    );
  }
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.repeatedFields_ = [4];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.toObject = function(includeInstance, msg) {
  var f, obj = {
    type: jspb.Message.getFieldWithDefault(msg, 1, ""),
    source: jspb.Message.getFieldWithDefault(msg, 2, ""),
    name: jspb.Message.getFieldWithDefault(msg, 3, ""),
    fqnList: (f = jspb.Message.getRepeatedField(msg, 4)) == null ? undefined : f,
    instanceid: jspb.Message.getFieldWithDefault(msg, 5, ""),
    disksize: jspb.Message.getFieldWithDefault(msg, 6, 0),
    totalsize: jspb.Message.getFieldWithDefault(msg, 7, 0),
    state: jspb.Message.getFieldWithDefault(msg, 8, ""),
    ip: jspb.Message.getFieldWithDefault(msg, 9, ""),
    fingerprint: jspb.Message.getFieldWithDefault(msg, 10, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo;
  return proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setType(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setSource(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.addFqn(value);
      break;
    case 5:
      var value = /** @type {string} */ (reader.readString());
      msg.setInstanceid(value);
      break;
    case 6:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setDisksize(value);
      break;
    case 7:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setTotalsize(value);
      break;
    case 8:
      var value = /** @type {string} */ (reader.readString());
      msg.setState(value);
      break;
    case 9:
      var value = /** @type {string} */ (reader.readString());
      msg.setIp(value);
      break;
    case 10:
      var value = /** @type {string} */ (reader.readString());
      msg.setFingerprint(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getType();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getSource();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      3,
      f
    );
  }
  f = message.getFqnList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      4,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeString(
      5,
      f
    );
  }
  f = message.getDisksize();
  if (f !== 0) {
    writer.writeUint64(
      6,
      f
    );
  }
  f = message.getTotalsize();
  if (f !== 0) {
    writer.writeUint64(
      7,
      f
    );
  }
  f = message.getState();
  if (f.length > 0) {
    writer.writeString(
      8,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 9));
  if (f != null) {
    writer.writeString(
      9,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 10));
  if (f != null) {
    writer.writeString(
      10,
      f
    );
  }
};


/**
 * optional string type = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getType = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setType = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string source = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getSource = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setSource = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional string name = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 3, value);
};


/**
 * repeated string fqn = 4;
 * @return {!Array<string>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getFqnList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 4));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setFqnList = function(value) {
  return jspb.Message.setField(this, 4, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.addFqn = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 4, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.clearFqnList = function() {
  return this.setFqnList([]);
};


/**
 * optional string instanceID = 5;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getInstanceid = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 5, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setInstanceid = function(value) {
  return jspb.Message.setField(this, 5, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.clearInstanceid = function() {
  return jspb.Message.setField(this, 5, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.hasInstanceid = function() {
  return jspb.Message.getField(this, 5) != null;
};


/**
 * optional uint64 diskSize = 6;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getDisksize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 6, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setDisksize = function(value) {
  return jspb.Message.setProto3IntField(this, 6, value);
};


/**
 * optional uint64 totalSize = 7;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getTotalsize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 7, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setTotalsize = function(value) {
  return jspb.Message.setProto3IntField(this, 7, value);
};


/**
 * optional string state = 8;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getState = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 8, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setState = function(value) {
  return jspb.Message.setProto3StringField(this, 8, value);
};


/**
 * optional string ip = 9;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getIp = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 9, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setIp = function(value) {
  return jspb.Message.setField(this, 9, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.clearIp = function() {
  return jspb.Message.setField(this, 9, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.hasIp = function() {
  return jspb.Message.getField(this, 9) != null;
};


/**
 * optional string fingerprint = 10;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.getFingerprint = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 10, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.setFingerprint = function(value) {
  return jspb.Message.setField(this, 10, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.clearFingerprint = function() {
  return jspb.Message.setField(this, 10, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.prototype.hasFingerprint = function() {
  return jspb.Message.getField(this, 10) != null;
};


/**
 * repeated VirtualMachineInfo infos = 1;
 * @return {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.prototype.getInfosList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo, 1));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.prototype.setInfosList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 1, value);
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.prototype.addInfos = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 1, opt_value, proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.prototype.clearInfosList = function() {
  return this.setInfosList([]);
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    objectsList: jspb.Message.toObjectList(msg.getObjectsList(),
    proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply;
  return proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.deserializeBinaryFromReader);
      msg.addObjects(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getObjectsList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      1,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.serializeBinaryToWriter
    );
  }
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.toObject = function(includeInstance, msg) {
  var f, obj = {
    source: jspb.Message.getFieldWithDefault(msg, 1, ""),
    name: jspb.Message.getFieldWithDefault(msg, 2, ""),
    deleted: jspb.Message.getBooleanFieldWithDefault(msg, 3, false),
    reason: jspb.Message.getFieldWithDefault(msg, 4, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject;
  return proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setSource(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 3:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setDeleted(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setReason(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getSource();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getDeleted();
  if (f) {
    writer.writeBool(
      3,
      f
    );
  }
  f = message.getReason();
  if (f.length > 0) {
    writer.writeString(
      4,
      f
    );
  }
};


/**
 * optional string source = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.getSource = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.setSource = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string name = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional bool deleted = 3;
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.getDeleted = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 3, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.setDeleted = function(value) {
  return jspb.Message.setProto3BooleanField(this, 3, value);
};


/**
 * optional string reason = 4;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.getReason = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.prototype.setReason = function(value) {
  return jspb.Message.setProto3StringField(this, 4, value);
};


/**
 * repeated DeletedObject objects = 1;
 * @return {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.prototype.getObjectsList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject, 1));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.prototype.setObjectsList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 1, value);
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject}
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.prototype.addObjects = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 1, opt_value, proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply.prototype.clearObjectsList = function() {
  return this.setObjectsList([]);
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.StopReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    objectsList: jspb.Message.toObjectList(msg.getObjectsList(),
    proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.StopReply;
  return proto.caked.Caked.Reply.VirtualMachineReply.StopReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.deserializeBinaryFromReader);
      msg.addObjects(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.StopReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getObjectsList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      1,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.serializeBinaryToWriter
    );
  }
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    status: jspb.Message.getFieldWithDefault(msg, 2, ""),
    stopped: jspb.Message.getBooleanFieldWithDefault(msg, 3, false),
    reason: jspb.Message.getFieldWithDefault(msg, 4, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject;
  return proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setStatus(value);
      break;
    case 3:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setStopped(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setReason(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getStatus();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getStopped();
  if (f) {
    writer.writeBool(
      3,
      f
    );
  }
  f = message.getReason();
  if (f.length > 0) {
    writer.writeString(
      4,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string status = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.getStatus = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.setStatus = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional bool stopped = 3;
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.getStopped = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 3, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.setStopped = function(value) {
  return jspb.Message.setProto3BooleanField(this, 3, value);
};


/**
 * optional string reason = 4;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.getReason = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.prototype.setReason = function(value) {
  return jspb.Message.setProto3StringField(this, 4, value);
};


/**
 * repeated StoppedObject objects = 1;
 * @return {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.prototype.getObjectsList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject, 1));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.prototype.setObjectsList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 1, value);
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject}
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.prototype.addObjects = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 1, opt_value, proto.caked.Caked.Reply.VirtualMachineReply.StopReply.StoppedObject, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.StopReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.StopReply.prototype.clearObjectsList = function() {
  return this.setObjectsList([]);
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.repeatedFields_ = [5,6,11,13,14,15];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    version: jspb.Message.getFieldWithDefault(msg, 1, ""),
    uptime: jspb.Message.getFieldWithDefault(msg, 2, 0),
    memory: (f = msg.getMemory()) && proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.toObject(includeInstance, f),
    cpucount: jspb.Message.getFieldWithDefault(msg, 4, 0),
    diskinfosList: jspb.Message.toObjectList(msg.getDiskinfosList(),
    proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.toObject, includeInstance),
    ipaddressesList: (f = jspb.Message.getRepeatedField(msg, 6)) == null ? undefined : f,
    osname: jspb.Message.getFieldWithDefault(msg, 7, ""),
    hostname: jspb.Message.getFieldWithDefault(msg, 8, ""),
    release: jspb.Message.getFieldWithDefault(msg, 9, ""),
    status: jspb.Message.getFieldWithDefault(msg, 10, ""),
    mountsList: (f = jspb.Message.getRepeatedField(msg, 11)) == null ? undefined : f,
    name: jspb.Message.getFieldWithDefault(msg, 12, ""),
    networksList: jspb.Message.toObjectList(msg.getNetworksList(),
    proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.toObject, includeInstance),
    tunnelsList: jspb.Message.toObjectList(msg.getTunnelsList(),
    proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.toObject, includeInstance),
    socketsList: jspb.Message.toObjectList(msg.getSocketsList(),
    proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply;
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setVersion(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setUptime(value);
      break;
    case 3:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.deserializeBinaryFromReader);
      msg.setMemory(value);
      break;
    case 4:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setCpucount(value);
      break;
    case 5:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.deserializeBinaryFromReader);
      msg.addDiskinfos(value);
      break;
    case 6:
      var value = /** @type {string} */ (reader.readString());
      msg.addIpaddresses(value);
      break;
    case 7:
      var value = /** @type {string} */ (reader.readString());
      msg.setOsname(value);
      break;
    case 8:
      var value = /** @type {string} */ (reader.readString());
      msg.setHostname(value);
      break;
    case 9:
      var value = /** @type {string} */ (reader.readString());
      msg.setRelease(value);
      break;
    case 10:
      var value = /** @type {string} */ (reader.readString());
      msg.setStatus(value);
      break;
    case 11:
      var value = /** @type {string} */ (reader.readString());
      msg.addMounts(value);
      break;
    case 12:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 13:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.deserializeBinaryFromReader);
      msg.addNetworks(value);
      break;
    case 14:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.deserializeBinaryFromReader);
      msg.addTunnels(value);
      break;
    case 15:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.deserializeBinaryFromReader);
      msg.addSockets(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = /** @type {string} */ (jspb.Message.getField(message, 1));
  if (f != null) {
    writer.writeString(
      1,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeUint64(
      2,
      f
    );
  }
  f = message.getMemory();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.serializeBinaryToWriter
    );
  }
  f = message.getCpucount();
  if (f !== 0) {
    writer.writeInt32(
      4,
      f
    );
  }
  f = message.getDiskinfosList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      5,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.serializeBinaryToWriter
    );
  }
  f = message.getIpaddressesList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      6,
      f
    );
  }
  f = message.getOsname();
  if (f.length > 0) {
    writer.writeString(
      7,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 8));
  if (f != null) {
    writer.writeString(
      8,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 9));
  if (f != null) {
    writer.writeString(
      9,
      f
    );
  }
  f = message.getStatus();
  if (f.length > 0) {
    writer.writeString(
      10,
      f
    );
  }
  f = message.getMountsList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      11,
      f
    );
  }
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      12,
      f
    );
  }
  f = message.getNetworksList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      13,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.serializeBinaryToWriter
    );
  }
  f = message.getTunnelsList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      14,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.serializeBinaryToWriter
    );
  }
  f = message.getSocketsList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      15,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.serializeBinaryToWriter
    );
  }
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.toObject = function(includeInstance, msg) {
  var f, obj = {
    total: jspb.Message.getFieldWithDefault(msg, 1, 0),
    free: jspb.Message.getFieldWithDefault(msg, 2, 0),
    used: jspb.Message.getFieldWithDefault(msg, 3, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo;
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setTotal(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setFree(value);
      break;
    case 3:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setUsed(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getTotal();
  if (f !== 0) {
    writer.writeUint64(
      1,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeUint64(
      2,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeUint64(
      3,
      f
    );
  }
};


/**
 * optional uint64 total = 1;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.getTotal = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.setTotal = function(value) {
  return jspb.Message.setProto3IntField(this, 1, value);
};


/**
 * optional uint64 free = 2;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.getFree = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.setFree = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.clearFree = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.hasFree = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional uint64 used = 3;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.getUsed = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.setUsed = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.clearUsed = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.prototype.hasUsed = function() {
  return jspb.Message.getField(this, 3) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.toObject = function(includeInstance, msg) {
  var f, obj = {
    device: jspb.Message.getFieldWithDefault(msg, 1, ""),
    mount: jspb.Message.getFieldWithDefault(msg, 2, ""),
    fstype: jspb.Message.getFieldWithDefault(msg, 3, ""),
    size: jspb.Message.getFieldWithDefault(msg, 4, 0),
    used: jspb.Message.getFieldWithDefault(msg, 5, 0),
    free: jspb.Message.getFieldWithDefault(msg, 6, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo;
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setDevice(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setMount(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setFstype(value);
      break;
    case 4:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setSize(value);
      break;
    case 5:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setUsed(value);
      break;
    case 6:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setFree(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getDevice();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getMount();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getFstype();
  if (f.length > 0) {
    writer.writeString(
      3,
      f
    );
  }
  f = message.getSize();
  if (f !== 0) {
    writer.writeUint64(
      4,
      f
    );
  }
  f = message.getUsed();
  if (f !== 0) {
    writer.writeUint64(
      5,
      f
    );
  }
  f = message.getFree();
  if (f !== 0) {
    writer.writeUint64(
      6,
      f
    );
  }
};


/**
 * optional string device = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.getDevice = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.setDevice = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string mount = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.getMount = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.setMount = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional string fsType = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.getFstype = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.setFstype = function(value) {
  return jspb.Message.setProto3StringField(this, 3, value);
};


/**
 * optional uint64 size = 4;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.getSize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 4, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.setSize = function(value) {
  return jspb.Message.setProto3IntField(this, 4, value);
};


/**
 * optional uint64 used = 5;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.getUsed = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 5, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.setUsed = function(value) {
  return jspb.Message.setProto3IntField(this, 5, value);
};


/**
 * optional uint64 free = 6;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.getFree = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 6, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.prototype.setFree = function(value) {
  return jspb.Message.setProto3IntField(this, 6, value);
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.toObject = function(includeInstance, msg) {
  var f, obj = {
    network: jspb.Message.getFieldWithDefault(msg, 1, ""),
    mode: jspb.Message.getFieldWithDefault(msg, 2, ""),
    macaddress: jspb.Message.getFieldWithDefault(msg, 3, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork;
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setNetwork(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setMode(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setMacaddress(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getNetwork();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeString(
      2,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
};


/**
 * optional string network = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.getNetwork = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.setNetwork = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string mode = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.getMode = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.setMode = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.clearMode = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.hasMode = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional string macAddress = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.getMacaddress = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.setMacaddress = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.clearMacaddress = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.prototype.hasMacaddress = function() {
  return jspb.Message.getField(this, 3) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.oneofGroups_ = [[1,2]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.TunnelCase = {
  TUNNEL_NOT_SET: 0,
  FORWARD: 1,
  UNIXDOMAIN: 2
};

/**
 * @return {proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.TunnelCase}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.getTunnelCase = function() {
  return /** @type {proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.TunnelCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.toObject = function(includeInstance, msg) {
  var f, obj = {
    forward: (f = msg.getForward()) && proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.toObject(includeInstance, f),
    unixdomain: (f = msg.getUnixdomain()) && proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo;
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.deserializeBinaryFromReader);
      msg.setForward(value);
      break;
    case 2:
      var value = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel;
      reader.readMessage(value,proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.deserializeBinaryFromReader);
      msg.setUnixdomain(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getForward();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.serializeBinaryToWriter
    );
  }
  f = message.getUnixdomain();
  if (f != null) {
    writer.writeMessage(
      2,
      f,
      proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.serializeBinaryToWriter
    );
  }
};


/**
 * @enum {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol = {
  TCP: 0,
  UDP: 1
};




if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.toObject = function(includeInstance, msg) {
  var f, obj = {
    protocol: jspb.Message.getFieldWithDefault(msg, 1, 0),
    host: jspb.Message.getFieldWithDefault(msg, 2, 0),
    guest: jspb.Message.getFieldWithDefault(msg, 3, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort;
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol} */ (reader.readEnum());
      msg.setProtocol(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setHost(value);
      break;
    case 3:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setGuest(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getProtocol();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = message.getHost();
  if (f !== 0) {
    writer.writeInt32(
      2,
      f
    );
  }
  f = message.getGuest();
  if (f !== 0) {
    writer.writeInt32(
      3,
      f
    );
  }
};


/**
 * optional Protocol protocol = 1;
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.prototype.getProtocol = function() {
  return /** @type {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.prototype.setProtocol = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional int32 host = 2;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.prototype.getHost = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.prototype.setHost = function(value) {
  return jspb.Message.setProto3IntField(this, 2, value);
};


/**
 * optional int32 guest = 3;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.prototype.getGuest = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.prototype.setGuest = function(value) {
  return jspb.Message.setProto3IntField(this, 3, value);
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.toObject = function(includeInstance, msg) {
  var f, obj = {
    protocol: jspb.Message.getFieldWithDefault(msg, 1, 0),
    host: jspb.Message.getFieldWithDefault(msg, 2, ""),
    guest: jspb.Message.getFieldWithDefault(msg, 3, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel;
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol} */ (reader.readEnum());
      msg.setProtocol(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setHost(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setGuest(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getProtocol();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = message.getHost();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getGuest();
  if (f.length > 0) {
    writer.writeString(
      3,
      f
    );
  }
};


/**
 * optional Protocol protocol = 1;
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.prototype.getProtocol = function() {
  return /** @type {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.prototype.setProtocol = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional string host = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.prototype.getHost = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.prototype.setHost = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional string guest = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.prototype.getGuest = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.prototype.setGuest = function(value) {
  return jspb.Message.setProto3StringField(this, 3, value);
};


/**
 * optional ForwardedPort forward = 1;
 * @return {?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.getForward = function() {
  return /** @type{?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort, 1));
};


/**
 * @param {?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort|undefined} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.setForward = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.clearForward = function() {
  return this.setForward(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.hasForward = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional Tunnel unixDomain = 2;
 * @return {?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.getUnixdomain = function() {
  return /** @type{?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel, 2));
};


/**
 * @param {?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel|undefined} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.setUnixdomain = function(value) {
  return jspb.Message.setOneofWrapperField(this, 2, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.clearUnixdomain = function() {
  return this.setUnixdomain(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.prototype.hasUnixdomain = function() {
  return jspb.Message.getField(this, 2) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.toObject = function(includeInstance, msg) {
  var f, obj = {
    mode: jspb.Message.getFieldWithDefault(msg, 1, 0),
    host: jspb.Message.getFieldWithDefault(msg, 2, ""),
    port: jspb.Message.getFieldWithDefault(msg, 3, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo;
  return proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode} */ (reader.readEnum());
      msg.setMode(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setHost(value);
      break;
    case 3:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setPort(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getMode();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = message.getHost();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getPort();
  if (f !== 0) {
    writer.writeInt32(
      3,
      f
    );
  }
};


/**
 * @enum {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode = {
  BIND: 0,
  CONNECT: 1,
  TCP: 2,
  UDP: 3
};

/**
 * optional Mode mode = 1;
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.prototype.getMode = function() {
  return /** @type {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.prototype.setMode = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional string host = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.prototype.getHost = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.prototype.setHost = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional int32 port = 3;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.prototype.getPort = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.prototype.setPort = function(value) {
  return jspb.Message.setProto3IntField(this, 3, value);
};


/**
 * optional string version = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getVersion = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setVersion = function(value) {
  return jspb.Message.setField(this, 1, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearVersion = function() {
  return jspb.Message.setField(this, 1, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.hasVersion = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional uint64 uptime = 2;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getUptime = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setUptime = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearUptime = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.hasUptime = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional MemoryInfo memory = 3;
 * @return {?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getMemory = function() {
  return /** @type{?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo, 3));
};


/**
 * @param {?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo|undefined} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setMemory = function(value) {
  return jspb.Message.setWrapperField(this, 3, value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearMemory = function() {
  return this.setMemory(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.hasMemory = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional int32 cpuCount = 4;
 * @return {number}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getCpucount = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 4, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setCpucount = function(value) {
  return jspb.Message.setProto3IntField(this, 4, value);
};


/**
 * repeated DiskInfo diskInfos = 5;
 * @return {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getDiskinfosList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo, 5));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setDiskinfosList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 5, value);
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.addDiskinfos = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 5, opt_value, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearDiskinfosList = function() {
  return this.setDiskinfosList([]);
};


/**
 * repeated string ipaddresses = 6;
 * @return {!Array<string>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getIpaddressesList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 6));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setIpaddressesList = function(value) {
  return jspb.Message.setField(this, 6, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.addIpaddresses = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 6, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearIpaddressesList = function() {
  return this.setIpaddressesList([]);
};


/**
 * optional string osname = 7;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getOsname = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 7, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setOsname = function(value) {
  return jspb.Message.setProto3StringField(this, 7, value);
};


/**
 * optional string hostname = 8;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getHostname = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 8, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setHostname = function(value) {
  return jspb.Message.setField(this, 8, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearHostname = function() {
  return jspb.Message.setField(this, 8, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.hasHostname = function() {
  return jspb.Message.getField(this, 8) != null;
};


/**
 * optional string release = 9;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getRelease = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 9, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setRelease = function(value) {
  return jspb.Message.setField(this, 9, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearRelease = function() {
  return jspb.Message.setField(this, 9, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.hasRelease = function() {
  return jspb.Message.getField(this, 9) != null;
};


/**
 * optional string status = 10;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getStatus = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 10, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setStatus = function(value) {
  return jspb.Message.setProto3StringField(this, 10, value);
};


/**
 * repeated string mounts = 11;
 * @return {!Array<string>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getMountsList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 11));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setMountsList = function(value) {
  return jspb.Message.setField(this, 11, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.addMounts = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 11, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearMountsList = function() {
  return this.setMountsList([]);
};


/**
 * optional string name = 12;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 12, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 12, value);
};


/**
 * repeated AttachedNetwork networks = 13;
 * @return {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getNetworksList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork, 13));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setNetworksList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 13, value);
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.addNetworks = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 13, opt_value, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearNetworksList = function() {
  return this.setNetworksList([]);
};


/**
 * repeated TunnelInfo tunnels = 14;
 * @return {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getTunnelsList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo, 14));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setTunnelsList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 14, value);
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.addTunnels = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 14, opt_value, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearTunnelsList = function() {
  return this.setTunnelsList([]);
};


/**
 * repeated SocketInfo sockets = 15;
 * @return {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo>}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.getSocketsList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo, 15));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo>} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.setSocketsList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 15, value);
};


/**
 * @param {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo}
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.addSockets = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 15, opt_value, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.InfoReply.prototype.clearSocketsList = function() {
  return this.setSocketsList([]);
};


/**
 * optional VirtualMachineInfoReply list = 1;
 * @return {?proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.getList = function() {
  return /** @type{?proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply, 1));
};


/**
 * @param {?proto.caked.Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply|undefined} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.prototype.setList = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.clearList = function() {
  return this.setList(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.hasList = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional DeleteReply delete = 2;
 * @return {?proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.getDelete = function() {
  return /** @type{?proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply, 2));
};


/**
 * @param {?proto.caked.Caked.Reply.VirtualMachineReply.DeleteReply|undefined} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.prototype.setDelete = function(value) {
  return jspb.Message.setOneofWrapperField(this, 2, proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.clearDelete = function() {
  return this.setDelete(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.hasDelete = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional StopReply stop = 3;
 * @return {?proto.caked.Caked.Reply.VirtualMachineReply.StopReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.getStop = function() {
  return /** @type{?proto.caked.Caked.Reply.VirtualMachineReply.StopReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.StopReply, 3));
};


/**
 * @param {?proto.caked.Caked.Reply.VirtualMachineReply.StopReply|undefined} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.prototype.setStop = function(value) {
  return jspb.Message.setOneofWrapperField(this, 3, proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.clearStop = function() {
  return this.setStop(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.hasStop = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional InfoReply infos = 4;
 * @return {?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.getInfos = function() {
  return /** @type{?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply.InfoReply, 4));
};


/**
 * @param {?proto.caked.Caked.Reply.VirtualMachineReply.InfoReply|undefined} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
*/
proto.caked.Caked.Reply.VirtualMachineReply.prototype.setInfos = function(value) {
  return jspb.Message.setOneofWrapperField(this, 4, proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.clearInfos = function() {
  return this.setInfos(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.hasInfos = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional string message = 5;
 * @return {string}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.getMessage = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 5, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.setMessage = function(value) {
  return jspb.Message.setOneofField(this, 5, proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.VirtualMachineReply} returns this
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.clearMessage = function() {
  return jspb.Message.setOneofField(this, 5, proto.caked.Caked.Reply.VirtualMachineReply.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.VirtualMachineReply.prototype.hasMessage = function() {
  return jspb.Message.getField(this, 5) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.ImageReply.oneofGroups_ = [[1,2,3]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.ImageReply.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  INFOS: 1,
  PULL: 2,
  LIST: 3
};

/**
 * @return {proto.caked.Caked.Reply.ImageReply.ResponseCase}
 */
proto.caked.Caked.Reply.ImageReply.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.Reply.ImageReply.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.ImageReply.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.ImageReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.ImageReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.ImageReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.ImageReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    infos: (f = msg.getInfos()) && proto.caked.Caked.Reply.ImageReply.ImageInfo.toObject(includeInstance, f),
    pull: (f = msg.getPull()) && proto.caked.Caked.Reply.ImageReply.PulledImageInfo.toObject(includeInstance, f),
    list: (f = msg.getList()) && proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.ImageReply}
 */
proto.caked.Caked.Reply.ImageReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.ImageReply;
  return proto.caked.Caked.Reply.ImageReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.ImageReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.ImageReply}
 */
proto.caked.Caked.Reply.ImageReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.ImageReply.ImageInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.ImageReply.ImageInfo.deserializeBinaryFromReader);
      msg.setInfos(value);
      break;
    case 2:
      var value = new proto.caked.Caked.Reply.ImageReply.PulledImageInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.ImageReply.PulledImageInfo.deserializeBinaryFromReader);
      msg.setPull(value);
      break;
    case 3:
      var value = new proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply;
      reader.readMessage(value,proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.deserializeBinaryFromReader);
      msg.setList(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.ImageReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.ImageReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.ImageReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.ImageReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getInfos();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.Reply.ImageReply.ImageInfo.serializeBinaryToWriter
    );
  }
  f = message.getPull();
  if (f != null) {
    writer.writeMessage(
      2,
      f,
      proto.caked.Caked.Reply.ImageReply.PulledImageInfo.serializeBinaryToWriter
    );
  }
  f = message.getList();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.serializeBinaryToWriter
    );
  }
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    infosList: jspb.Message.toObjectList(msg.getInfosList(),
    proto.caked.Caked.Reply.ImageReply.ImageInfo.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply}
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply;
  return proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply}
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.ImageReply.ImageInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.ImageReply.ImageInfo.deserializeBinaryFromReader);
      msg.addInfos(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getInfosList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      1,
      f,
      proto.caked.Caked.Reply.ImageReply.ImageInfo.serializeBinaryToWriter
    );
  }
};


/**
 * repeated ImageInfo infos = 1;
 * @return {!Array<!proto.caked.Caked.Reply.ImageReply.ImageInfo>}
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.prototype.getInfosList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.ImageReply.ImageInfo>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.ImageReply.ImageInfo, 1));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.ImageReply.ImageInfo>} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply} returns this
*/
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.prototype.setInfosList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 1, value);
};


/**
 * @param {!proto.caked.Caked.Reply.ImageReply.ImageInfo=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo}
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.prototype.addInfos = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 1, opt_value, proto.caked.Caked.Reply.ImageReply.ImageInfo, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply} returns this
 */
proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply.prototype.clearInfosList = function() {
  return this.setInfosList([]);
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.ImageReply.ImageInfo.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.ImageReply.ImageInfo} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.toObject = function(includeInstance, msg) {
  var f, obj = {
    aliasesList: (f = jspb.Message.getRepeatedField(msg, 1)) == null ? undefined : f,
    architecture: jspb.Message.getFieldWithDefault(msg, 2, ""),
    pub: jspb.Message.getBooleanFieldWithDefault(msg, 3, false),
    filename: jspb.Message.getFieldWithDefault(msg, 4, ""),
    fingerprint: jspb.Message.getFieldWithDefault(msg, 5, ""),
    size: jspb.Message.getFieldWithDefault(msg, 6, 0),
    type: jspb.Message.getFieldWithDefault(msg, 7, ""),
    created: jspb.Message.getFieldWithDefault(msg, 8, ""),
    expires: jspb.Message.getFieldWithDefault(msg, 9, ""),
    uploaded: jspb.Message.getFieldWithDefault(msg, 10, ""),
    propertiesMap: (f = msg.getPropertiesMap()) ? f.toObject(includeInstance, undefined) : []
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.ImageReply.ImageInfo;
  return proto.caked.Caked.Reply.ImageReply.ImageInfo.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.ImageReply.ImageInfo} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.addAliases(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setArchitecture(value);
      break;
    case 3:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setPub(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setFilename(value);
      break;
    case 5:
      var value = /** @type {string} */ (reader.readString());
      msg.setFingerprint(value);
      break;
    case 6:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setSize(value);
      break;
    case 7:
      var value = /** @type {string} */ (reader.readString());
      msg.setType(value);
      break;
    case 8:
      var value = /** @type {string} */ (reader.readString());
      msg.setCreated(value);
      break;
    case 9:
      var value = /** @type {string} */ (reader.readString());
      msg.setExpires(value);
      break;
    case 10:
      var value = /** @type {string} */ (reader.readString());
      msg.setUploaded(value);
      break;
    case 11:
      var value = msg.getPropertiesMap();
      reader.readMessage(value, function(message, reader) {
        jspb.Map.deserializeBinary(message, reader, jspb.BinaryReader.prototype.readString, jspb.BinaryReader.prototype.readString, null, "", "");
         });
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.ImageReply.ImageInfo.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.ImageReply.ImageInfo} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getAliasesList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      1,
      f
    );
  }
  f = message.getArchitecture();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getPub();
  if (f) {
    writer.writeBool(
      3,
      f
    );
  }
  f = message.getFilename();
  if (f.length > 0) {
    writer.writeString(
      4,
      f
    );
  }
  f = message.getFingerprint();
  if (f.length > 0) {
    writer.writeString(
      5,
      f
    );
  }
  f = message.getSize();
  if (f !== 0) {
    writer.writeUint64(
      6,
      f
    );
  }
  f = message.getType();
  if (f.length > 0) {
    writer.writeString(
      7,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 8));
  if (f != null) {
    writer.writeString(
      8,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 9));
  if (f != null) {
    writer.writeString(
      9,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 10));
  if (f != null) {
    writer.writeString(
      10,
      f
    );
  }
  f = message.getPropertiesMap(true);
  if (f && f.getLength() > 0) {
    f.serializeBinary(11, writer, jspb.BinaryWriter.prototype.writeString, jspb.BinaryWriter.prototype.writeString);
  }
};


/**
 * repeated string aliases = 1;
 * @return {!Array<string>}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getAliasesList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 1));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setAliasesList = function(value) {
  return jspb.Message.setField(this, 1, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.addAliases = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 1, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.clearAliasesList = function() {
  return this.setAliasesList([]);
};


/**
 * optional string architecture = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getArchitecture = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setArchitecture = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional bool pub = 3;
 * @return {boolean}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getPub = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 3, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setPub = function(value) {
  return jspb.Message.setProto3BooleanField(this, 3, value);
};


/**
 * optional string fileName = 4;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getFilename = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setFilename = function(value) {
  return jspb.Message.setProto3StringField(this, 4, value);
};


/**
 * optional string fingerprint = 5;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getFingerprint = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 5, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setFingerprint = function(value) {
  return jspb.Message.setProto3StringField(this, 5, value);
};


/**
 * optional uint64 size = 6;
 * @return {number}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getSize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 6, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setSize = function(value) {
  return jspb.Message.setProto3IntField(this, 6, value);
};


/**
 * optional string type = 7;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getType = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 7, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setType = function(value) {
  return jspb.Message.setProto3StringField(this, 7, value);
};


/**
 * optional string created = 8;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getCreated = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 8, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setCreated = function(value) {
  return jspb.Message.setField(this, 8, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.clearCreated = function() {
  return jspb.Message.setField(this, 8, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.hasCreated = function() {
  return jspb.Message.getField(this, 8) != null;
};


/**
 * optional string expires = 9;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getExpires = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 9, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setExpires = function(value) {
  return jspb.Message.setField(this, 9, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.clearExpires = function() {
  return jspb.Message.setField(this, 9, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.hasExpires = function() {
  return jspb.Message.getField(this, 9) != null;
};


/**
 * optional string uploaded = 10;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getUploaded = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 10, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.setUploaded = function(value) {
  return jspb.Message.setField(this, 10, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.clearUploaded = function() {
  return jspb.Message.setField(this, 10, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.hasUploaded = function() {
  return jspb.Message.getField(this, 10) != null;
};


/**
 * map<string, string> properties = 11;
 * @param {boolean=} opt_noLazyCreate Do not create the map if
 * empty, instead returning `undefined`
 * @return {!jspb.Map<string,string>}
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.getPropertiesMap = function(opt_noLazyCreate) {
  return /** @type {!jspb.Map<string,string>} */ (
      jspb.Message.getMapField(this, 11, opt_noLazyCreate,
      null));
};


/**
 * Clears values from the map. The map will be non-null.
 * @return {!proto.caked.Caked.Reply.ImageReply.ImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.ImageInfo.prototype.clearPropertiesMap = function() {
  this.getPropertiesMap().clear();
  return this;};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.ImageReply.PulledImageInfo.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.toObject = function(includeInstance, msg) {
  var f, obj = {
    alias: jspb.Message.getFieldWithDefault(msg, 1, ""),
    path: jspb.Message.getFieldWithDefault(msg, 2, ""),
    size: jspb.Message.getFieldWithDefault(msg, 3, 0),
    fingerprint: jspb.Message.getFieldWithDefault(msg, 4, ""),
    remotename: jspb.Message.getFieldWithDefault(msg, 5, ""),
    description: jspb.Message.getFieldWithDefault(msg, 6, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.ImageReply.PulledImageInfo;
  return proto.caked.Caked.Reply.ImageReply.PulledImageInfo.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setAlias(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setPath(value);
      break;
    case 3:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setSize(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setFingerprint(value);
      break;
    case 5:
      var value = /** @type {string} */ (reader.readString());
      msg.setRemotename(value);
      break;
    case 6:
      var value = /** @type {string} */ (reader.readString());
      msg.setDescription(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.ImageReply.PulledImageInfo.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = /** @type {string} */ (jspb.Message.getField(message, 1));
  if (f != null) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getPath();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getSize();
  if (f !== 0) {
    writer.writeUint64(
      3,
      f
    );
  }
  f = message.getFingerprint();
  if (f.length > 0) {
    writer.writeString(
      4,
      f
    );
  }
  f = message.getRemotename();
  if (f.length > 0) {
    writer.writeString(
      5,
      f
    );
  }
  f = message.getDescription();
  if (f.length > 0) {
    writer.writeString(
      6,
      f
    );
  }
};


/**
 * optional string alias = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.getAlias = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.setAlias = function(value) {
  return jspb.Message.setField(this, 1, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.clearAlias = function() {
  return jspb.Message.setField(this, 1, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.hasAlias = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional string path = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.getPath = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.setPath = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional uint64 size = 3;
 * @return {number}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.getSize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.setSize = function(value) {
  return jspb.Message.setProto3IntField(this, 3, value);
};


/**
 * optional string fingerprint = 4;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.getFingerprint = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.setFingerprint = function(value) {
  return jspb.Message.setProto3StringField(this, 4, value);
};


/**
 * optional string remoteName = 5;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.getRemotename = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 5, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.setRemotename = function(value) {
  return jspb.Message.setProto3StringField(this, 5, value);
};


/**
 * optional string description = 6;
 * @return {string}
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.getDescription = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 6, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.ImageReply.PulledImageInfo} returns this
 */
proto.caked.Caked.Reply.ImageReply.PulledImageInfo.prototype.setDescription = function(value) {
  return jspb.Message.setProto3StringField(this, 6, value);
};


/**
 * optional ImageInfo infos = 1;
 * @return {?proto.caked.Caked.Reply.ImageReply.ImageInfo}
 */
proto.caked.Caked.Reply.ImageReply.prototype.getInfos = function() {
  return /** @type{?proto.caked.Caked.Reply.ImageReply.ImageInfo} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.ImageReply.ImageInfo, 1));
};


/**
 * @param {?proto.caked.Caked.Reply.ImageReply.ImageInfo|undefined} value
 * @return {!proto.caked.Caked.Reply.ImageReply} returns this
*/
proto.caked.Caked.Reply.ImageReply.prototype.setInfos = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.Reply.ImageReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.ImageReply} returns this
 */
proto.caked.Caked.Reply.ImageReply.prototype.clearInfos = function() {
  return this.setInfos(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.ImageReply.prototype.hasInfos = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional PulledImageInfo pull = 2;
 * @return {?proto.caked.Caked.Reply.ImageReply.PulledImageInfo}
 */
proto.caked.Caked.Reply.ImageReply.prototype.getPull = function() {
  return /** @type{?proto.caked.Caked.Reply.ImageReply.PulledImageInfo} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.ImageReply.PulledImageInfo, 2));
};


/**
 * @param {?proto.caked.Caked.Reply.ImageReply.PulledImageInfo|undefined} value
 * @return {!proto.caked.Caked.Reply.ImageReply} returns this
*/
proto.caked.Caked.Reply.ImageReply.prototype.setPull = function(value) {
  return jspb.Message.setOneofWrapperField(this, 2, proto.caked.Caked.Reply.ImageReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.ImageReply} returns this
 */
proto.caked.Caked.Reply.ImageReply.prototype.clearPull = function() {
  return this.setPull(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.ImageReply.prototype.hasPull = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional ListImagesInfoReply list = 3;
 * @return {?proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply}
 */
proto.caked.Caked.Reply.ImageReply.prototype.getList = function() {
  return /** @type{?proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply, 3));
};


/**
 * @param {?proto.caked.Caked.Reply.ImageReply.ListImagesInfoReply|undefined} value
 * @return {!proto.caked.Caked.Reply.ImageReply} returns this
*/
proto.caked.Caked.Reply.ImageReply.prototype.setList = function(value) {
  return jspb.Message.setOneofWrapperField(this, 3, proto.caked.Caked.Reply.ImageReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.ImageReply} returns this
 */
proto.caked.Caked.Reply.ImageReply.prototype.clearList = function() {
  return this.setList(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.ImageReply.prototype.hasList = function() {
  return jspb.Message.getField(this, 3) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.NetworksReply.oneofGroups_ = [[1,2,3]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.NetworksReply.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  LIST: 1,
  STATUS: 2,
  MESSAGE: 3
};

/**
 * @return {proto.caked.Caked.Reply.NetworksReply.ResponseCase}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.Reply.NetworksReply.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.NetworksReply.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.NetworksReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.NetworksReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.NetworksReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    list: (f = msg.getList()) && proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.toObject(includeInstance, f),
    status: (f = msg.getStatus()) && proto.caked.Caked.Reply.NetworksReply.NetworkInfo.toObject(includeInstance, f),
    message: jspb.Message.getFieldWithDefault(msg, 3, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.NetworksReply}
 */
proto.caked.Caked.Reply.NetworksReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.NetworksReply;
  return proto.caked.Caked.Reply.NetworksReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.NetworksReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.NetworksReply}
 */
proto.caked.Caked.Reply.NetworksReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.NetworksReply.ListNetworksReply;
      reader.readMessage(value,proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.deserializeBinaryFromReader);
      msg.setList(value);
      break;
    case 2:
      var value = new proto.caked.Caked.Reply.NetworksReply.NetworkInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.NetworksReply.NetworkInfo.deserializeBinaryFromReader);
      msg.setStatus(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setMessage(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.NetworksReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.NetworksReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.NetworksReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getList();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.serializeBinaryToWriter
    );
  }
  f = message.getStatus();
  if (f != null) {
    writer.writeMessage(
      2,
      f,
      proto.caked.Caked.Reply.NetworksReply.NetworkInfo.serializeBinaryToWriter
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.NetworksReply.NetworkInfo.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    mode: jspb.Message.getFieldWithDefault(msg, 2, ""),
    description: jspb.Message.getFieldWithDefault(msg, 3, ""),
    gateway: jspb.Message.getFieldWithDefault(msg, 4, ""),
    dhcpend: jspb.Message.getFieldWithDefault(msg, 5, ""),
    netmask: jspb.Message.getFieldWithDefault(msg, 6, ""),
    interfaceid: jspb.Message.getFieldWithDefault(msg, 7, ""),
    endpoint: jspb.Message.getFieldWithDefault(msg, 8, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.NetworksReply.NetworkInfo;
  return proto.caked.Caked.Reply.NetworksReply.NetworkInfo.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setMode(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setDescription(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setGateway(value);
      break;
    case 5:
      var value = /** @type {string} */ (reader.readString());
      msg.setDhcpend(value);
      break;
    case 6:
      var value = /** @type {string} */ (reader.readString());
      msg.setNetmask(value);
      break;
    case 7:
      var value = /** @type {string} */ (reader.readString());
      msg.setInterfaceid(value);
      break;
    case 8:
      var value = /** @type {string} */ (reader.readString());
      msg.setEndpoint(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.NetworksReply.NetworkInfo.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getMode();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getDescription();
  if (f.length > 0) {
    writer.writeString(
      3,
      f
    );
  }
  f = message.getGateway();
  if (f.length > 0) {
    writer.writeString(
      4,
      f
    );
  }
  f = message.getDhcpend();
  if (f.length > 0) {
    writer.writeString(
      5,
      f
    );
  }
  f = message.getNetmask();
  if (f.length > 0) {
    writer.writeString(
      6,
      f
    );
  }
  f = message.getInterfaceid();
  if (f.length > 0) {
    writer.writeString(
      7,
      f
    );
  }
  f = message.getEndpoint();
  if (f.length > 0) {
    writer.writeString(
      8,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} returns this
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string mode = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.getMode = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} returns this
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.setMode = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional string description = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.getDescription = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} returns this
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.setDescription = function(value) {
  return jspb.Message.setProto3StringField(this, 3, value);
};


/**
 * optional string gateway = 4;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.getGateway = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} returns this
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.setGateway = function(value) {
  return jspb.Message.setProto3StringField(this, 4, value);
};


/**
 * optional string dhcpEnd = 5;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.getDhcpend = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 5, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} returns this
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.setDhcpend = function(value) {
  return jspb.Message.setProto3StringField(this, 5, value);
};


/**
 * optional string netmask = 6;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.getNetmask = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 6, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} returns this
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.setNetmask = function(value) {
  return jspb.Message.setProto3StringField(this, 6, value);
};


/**
 * optional string interfaceID = 7;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.getInterfaceid = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 7, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} returns this
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.setInterfaceid = function(value) {
  return jspb.Message.setProto3StringField(this, 7, value);
};


/**
 * optional string endpoint = 8;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.getEndpoint = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 8, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo} returns this
 */
proto.caked.Caked.Reply.NetworksReply.NetworkInfo.prototype.setEndpoint = function(value) {
  return jspb.Message.setProto3StringField(this, 8, value);
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.NetworksReply.ListNetworksReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    networksList: jspb.Message.toObjectList(msg.getNetworksList(),
    proto.caked.Caked.Reply.NetworksReply.NetworkInfo.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.NetworksReply.ListNetworksReply}
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.NetworksReply.ListNetworksReply;
  return proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.NetworksReply.ListNetworksReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.NetworksReply.ListNetworksReply}
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.NetworksReply.NetworkInfo;
      reader.readMessage(value,proto.caked.Caked.Reply.NetworksReply.NetworkInfo.deserializeBinaryFromReader);
      msg.addNetworks(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.NetworksReply.ListNetworksReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getNetworksList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      1,
      f,
      proto.caked.Caked.Reply.NetworksReply.NetworkInfo.serializeBinaryToWriter
    );
  }
};


/**
 * repeated NetworkInfo networks = 1;
 * @return {!Array<!proto.caked.Caked.Reply.NetworksReply.NetworkInfo>}
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.prototype.getNetworksList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.NetworksReply.NetworkInfo>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.NetworksReply.NetworkInfo, 1));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.NetworksReply.NetworkInfo>} value
 * @return {!proto.caked.Caked.Reply.NetworksReply.ListNetworksReply} returns this
*/
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.prototype.setNetworksList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 1, value);
};


/**
 * @param {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.NetworksReply.NetworkInfo}
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.prototype.addNetworks = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 1, opt_value, proto.caked.Caked.Reply.NetworksReply.NetworkInfo, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.NetworksReply.ListNetworksReply} returns this
 */
proto.caked.Caked.Reply.NetworksReply.ListNetworksReply.prototype.clearNetworksList = function() {
  return this.setNetworksList([]);
};


/**
 * optional ListNetworksReply list = 1;
 * @return {?proto.caked.Caked.Reply.NetworksReply.ListNetworksReply}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.getList = function() {
  return /** @type{?proto.caked.Caked.Reply.NetworksReply.ListNetworksReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.NetworksReply.ListNetworksReply, 1));
};


/**
 * @param {?proto.caked.Caked.Reply.NetworksReply.ListNetworksReply|undefined} value
 * @return {!proto.caked.Caked.Reply.NetworksReply} returns this
*/
proto.caked.Caked.Reply.NetworksReply.prototype.setList = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.Reply.NetworksReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.NetworksReply} returns this
 */
proto.caked.Caked.Reply.NetworksReply.prototype.clearList = function() {
  return this.setList(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.hasList = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional NetworkInfo status = 2;
 * @return {?proto.caked.Caked.Reply.NetworksReply.NetworkInfo}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.getStatus = function() {
  return /** @type{?proto.caked.Caked.Reply.NetworksReply.NetworkInfo} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.NetworksReply.NetworkInfo, 2));
};


/**
 * @param {?proto.caked.Caked.Reply.NetworksReply.NetworkInfo|undefined} value
 * @return {!proto.caked.Caked.Reply.NetworksReply} returns this
*/
proto.caked.Caked.Reply.NetworksReply.prototype.setStatus = function(value) {
  return jspb.Message.setOneofWrapperField(this, 2, proto.caked.Caked.Reply.NetworksReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.NetworksReply} returns this
 */
proto.caked.Caked.Reply.NetworksReply.prototype.clearStatus = function() {
  return this.setStatus(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.hasStatus = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional string message = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.getMessage = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.NetworksReply} returns this
 */
proto.caked.Caked.Reply.NetworksReply.prototype.setMessage = function(value) {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.Reply.NetworksReply.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.NetworksReply} returns this
 */
proto.caked.Caked.Reply.NetworksReply.prototype.clearMessage = function() {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.Reply.NetworksReply.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.NetworksReply.prototype.hasMessage = function() {
  return jspb.Message.getField(this, 3) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.RemoteReply.oneofGroups_ = [[1,2]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.RemoteReply.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  LIST: 1,
  MESSAGE: 2
};

/**
 * @return {proto.caked.Caked.Reply.RemoteReply.ResponseCase}
 */
proto.caked.Caked.Reply.RemoteReply.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.Reply.RemoteReply.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.RemoteReply.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.RemoteReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.RemoteReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.RemoteReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.RemoteReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    list: (f = msg.getList()) && proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.toObject(includeInstance, f),
    message: jspb.Message.getFieldWithDefault(msg, 2, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.RemoteReply}
 */
proto.caked.Caked.Reply.RemoteReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.RemoteReply;
  return proto.caked.Caked.Reply.RemoteReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.RemoteReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.RemoteReply}
 */
proto.caked.Caked.Reply.RemoteReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.RemoteReply.ListRemoteReply;
      reader.readMessage(value,proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.deserializeBinaryFromReader);
      msg.setList(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setMessage(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.RemoteReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.RemoteReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.RemoteReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.RemoteReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getList();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.serializeBinaryToWriter
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeString(
      2,
      f
    );
  }
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    remotesList: jspb.Message.toObjectList(msg.getRemotesList(),
    proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.RemoteReply.ListRemoteReply;
  return proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry;
      reader.readMessage(value,proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.deserializeBinaryFromReader);
      msg.addRemotes(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getRemotesList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      1,
      f,
      proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.serializeBinaryToWriter
    );
  }
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    url: jspb.Message.getFieldWithDefault(msg, 2, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry;
  return proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setUrl(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getUrl();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry} returns this
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string url = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.prototype.getUrl = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry} returns this
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.prototype.setUrl = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * repeated RemoteEntry remotes = 1;
 * @return {!Array<!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry>}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.prototype.getRemotesList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry, 1));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry>} value
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply} returns this
*/
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.prototype.setRemotesList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 1, value);
};


/**
 * @param {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry}
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.prototype.addRemotes = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 1, opt_value, proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.RemoteReply.ListRemoteReply} returns this
 */
proto.caked.Caked.Reply.RemoteReply.ListRemoteReply.prototype.clearRemotesList = function() {
  return this.setRemotesList([]);
};


/**
 * optional ListRemoteReply list = 1;
 * @return {?proto.caked.Caked.Reply.RemoteReply.ListRemoteReply}
 */
proto.caked.Caked.Reply.RemoteReply.prototype.getList = function() {
  return /** @type{?proto.caked.Caked.Reply.RemoteReply.ListRemoteReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.RemoteReply.ListRemoteReply, 1));
};


/**
 * @param {?proto.caked.Caked.Reply.RemoteReply.ListRemoteReply|undefined} value
 * @return {!proto.caked.Caked.Reply.RemoteReply} returns this
*/
proto.caked.Caked.Reply.RemoteReply.prototype.setList = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.Reply.RemoteReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.RemoteReply} returns this
 */
proto.caked.Caked.Reply.RemoteReply.prototype.clearList = function() {
  return this.setList(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.RemoteReply.prototype.hasList = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional string message = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.RemoteReply.prototype.getMessage = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.RemoteReply} returns this
 */
proto.caked.Caked.Reply.RemoteReply.prototype.setMessage = function(value) {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.Reply.RemoteReply.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.RemoteReply} returns this
 */
proto.caked.Caked.Reply.RemoteReply.prototype.clearMessage = function() {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.Reply.RemoteReply.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.RemoteReply.prototype.hasMessage = function() {
  return jspb.Message.getField(this, 2) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.TemplateReply.oneofGroups_ = [[1,2,3]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.TemplateReply.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  LIST: 1,
  CREATE: 2,
  DELETE: 3
};

/**
 * @return {proto.caked.Caked.Reply.TemplateReply.ResponseCase}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.Reply.TemplateReply.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.TemplateReply.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.TemplateReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.TemplateReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    list: (f = msg.getList()) && proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.toObject(includeInstance, f),
    create: (f = msg.getCreate()) && proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.toObject(includeInstance, f),
    pb_delete: (f = msg.getDelete()) && proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.TemplateReply}
 */
proto.caked.Caked.Reply.TemplateReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.TemplateReply;
  return proto.caked.Caked.Reply.TemplateReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.TemplateReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.TemplateReply}
 */
proto.caked.Caked.Reply.TemplateReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply;
      reader.readMessage(value,proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.deserializeBinaryFromReader);
      msg.setList(value);
      break;
    case 2:
      var value = new proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply;
      reader.readMessage(value,proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.deserializeBinaryFromReader);
      msg.setCreate(value);
      break;
    case 3:
      var value = new proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply;
      reader.readMessage(value,proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.deserializeBinaryFromReader);
      msg.setDelete(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.TemplateReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.TemplateReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getList();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.serializeBinaryToWriter
    );
  }
  f = message.getCreate();
  if (f != null) {
    writer.writeMessage(
      2,
      f,
      proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.serializeBinaryToWriter
    );
  }
  f = message.getDelete();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.serializeBinaryToWriter
    );
  }
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.repeatedFields_ = [1];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    templatesList: jspb.Message.toObjectList(msg.getTemplatesList(),
    proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply;
  return proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry;
      reader.readMessage(value,proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.deserializeBinaryFromReader);
      msg.addTemplates(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getTemplatesList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      1,
      f,
      proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.serializeBinaryToWriter
    );
  }
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    fqn: jspb.Message.getFieldWithDefault(msg, 2, ""),
    disksize: jspb.Message.getFieldWithDefault(msg, 3, 0),
    totalsize: jspb.Message.getFieldWithDefault(msg, 4, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry;
  return proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setFqn(value);
      break;
    case 3:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setDisksize(value);
      break;
    case 4:
      var value = /** @type {number} */ (reader.readUint64());
      msg.setTotalsize(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getFqn();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getDisksize();
  if (f !== 0) {
    writer.writeUint64(
      3,
      f
    );
  }
  f = message.getTotalsize();
  if (f !== 0) {
    writer.writeUint64(
      4,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry} returns this
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string fqn = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.getFqn = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry} returns this
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.setFqn = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional uint64 diskSize = 3;
 * @return {number}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.getDisksize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry} returns this
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.setDisksize = function(value) {
  return jspb.Message.setProto3IntField(this, 3, value);
};


/**
 * optional uint64 totalSize = 4;
 * @return {number}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.getTotalsize = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 4, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry} returns this
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.prototype.setTotalsize = function(value) {
  return jspb.Message.setProto3IntField(this, 4, value);
};


/**
 * repeated TemplateEntry templates = 1;
 * @return {!Array<!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry>}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.prototype.getTemplatesList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry, 1));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry>} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply} returns this
*/
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.prototype.setTemplatesList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 1, value);
};


/**
 * @param {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry}
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.prototype.addTemplates = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 1, opt_value, proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply.prototype.clearTemplatesList = function() {
  return this.setTemplatesList([]);
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    created: jspb.Message.getBooleanFieldWithDefault(msg, 2, false),
    reason: jspb.Message.getFieldWithDefault(msg, 3, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply}
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply;
  return proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply}
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setCreated(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setReason(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getCreated();
  if (f) {
    writer.writeBool(
      2,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional bool created = 2;
 * @return {boolean}
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.getCreated = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 2, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.setCreated = function(value) {
  return jspb.Message.setProto3BooleanField(this, 2, value);
};


/**
 * optional string reason = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.getReason = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.setReason = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.clearReason = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply.prototype.hasReason = function() {
  return jspb.Message.getField(this, 3) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    deleted: jspb.Message.getBooleanFieldWithDefault(msg, 2, false),
    reason: jspb.Message.getFieldWithDefault(msg, 3, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply}
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply;
  return proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply}
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setDeleted(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setReason(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getDeleted();
  if (f) {
    writer.writeBool(
      2,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional bool deleted = 2;
 * @return {boolean}
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.getDeleted = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 2, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.setDeleted = function(value) {
  return jspb.Message.setProto3BooleanField(this, 2, value);
};


/**
 * optional string reason = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.getReason = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.setReason = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.clearReason = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply.prototype.hasReason = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional ListTemplatesReply list = 1;
 * @return {?proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.getList = function() {
  return /** @type{?proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply, 1));
};


/**
 * @param {?proto.caked.Caked.Reply.TemplateReply.ListTemplatesReply|undefined} value
 * @return {!proto.caked.Caked.Reply.TemplateReply} returns this
*/
proto.caked.Caked.Reply.TemplateReply.prototype.setList = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.Reply.TemplateReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.TemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.prototype.clearList = function() {
  return this.setList(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.hasList = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional CreateTemplateReply create = 2;
 * @return {?proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.getCreate = function() {
  return /** @type{?proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply, 2));
};


/**
 * @param {?proto.caked.Caked.Reply.TemplateReply.CreateTemplateReply|undefined} value
 * @return {!proto.caked.Caked.Reply.TemplateReply} returns this
*/
proto.caked.Caked.Reply.TemplateReply.prototype.setCreate = function(value) {
  return jspb.Message.setOneofWrapperField(this, 2, proto.caked.Caked.Reply.TemplateReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.TemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.prototype.clearCreate = function() {
  return this.setCreate(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.hasCreate = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional DeleteTemplateReply delete = 3;
 * @return {?proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.getDelete = function() {
  return /** @type{?proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply, 3));
};


/**
 * @param {?proto.caked.Caked.Reply.TemplateReply.DeleteTemplateReply|undefined} value
 * @return {!proto.caked.Caked.Reply.TemplateReply} returns this
*/
proto.caked.Caked.Reply.TemplateReply.prototype.setDelete = function(value) {
  return jspb.Message.setOneofWrapperField(this, 3, proto.caked.Caked.Reply.TemplateReply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply.TemplateReply} returns this
 */
proto.caked.Caked.Reply.TemplateReply.prototype.clearDelete = function() {
  return this.setDelete(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.TemplateReply.prototype.hasDelete = function() {
  return jspb.Message.getField(this, 3) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.RunReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.RunReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.RunReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.RunReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    exitcode: jspb.Message.getFieldWithDefault(msg, 1, 0),
    stdout: msg.getStdout_asB64(),
    stderr: msg.getStderr_asB64()
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.RunReply}
 */
proto.caked.Caked.Reply.RunReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.RunReply;
  return proto.caked.Caked.Reply.RunReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.RunReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.RunReply}
 */
proto.caked.Caked.Reply.RunReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setExitcode(value);
      break;
    case 2:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setStdout(value);
      break;
    case 3:
      var value = /** @type {!Uint8Array} */ (reader.readBytes());
      msg.setStderr(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.RunReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.RunReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.RunReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.RunReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getExitcode();
  if (f !== 0) {
    writer.writeInt32(
      1,
      f
    );
  }
  f = message.getStdout_asU8();
  if (f.length > 0) {
    writer.writeBytes(
      2,
      f
    );
  }
  f = message.getStderr_asU8();
  if (f.length > 0) {
    writer.writeBytes(
      3,
      f
    );
  }
};


/**
 * optional int32 exitCode = 1;
 * @return {number}
 */
proto.caked.Caked.Reply.RunReply.prototype.getExitcode = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.Reply.RunReply} returns this
 */
proto.caked.Caked.Reply.RunReply.prototype.setExitcode = function(value) {
  return jspb.Message.setProto3IntField(this, 1, value);
};


/**
 * optional bytes stdout = 2;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.Reply.RunReply.prototype.getStdout = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * optional bytes stdout = 2;
 * This is a type-conversion wrapper around `getStdout()`
 * @return {string}
 */
proto.caked.Caked.Reply.RunReply.prototype.getStdout_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getStdout()));
};


/**
 * optional bytes stdout = 2;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getStdout()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.RunReply.prototype.getStdout_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getStdout()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.Reply.RunReply} returns this
 */
proto.caked.Caked.Reply.RunReply.prototype.setStdout = function(value) {
  return jspb.Message.setProto3BytesField(this, 2, value);
};


/**
 * optional bytes stderr = 3;
 * @return {!(string|Uint8Array)}
 */
proto.caked.Caked.Reply.RunReply.prototype.getStderr = function() {
  return /** @type {!(string|Uint8Array)} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * optional bytes stderr = 3;
 * This is a type-conversion wrapper around `getStderr()`
 * @return {string}
 */
proto.caked.Caked.Reply.RunReply.prototype.getStderr_asB64 = function() {
  return /** @type {string} */ (jspb.Message.bytesAsB64(
      this.getStderr()));
};


/**
 * optional bytes stderr = 3;
 * Note that Uint8Array is not supported on all browsers.
 * @see http://caniuse.com/Uint8Array
 * This is a type-conversion wrapper around `getStderr()`
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.RunReply.prototype.getStderr_asU8 = function() {
  return /** @type {!Uint8Array} */ (jspb.Message.bytesAsU8(
      this.getStderr()));
};


/**
 * @param {!(string|Uint8Array)} value
 * @return {!proto.caked.Caked.Reply.RunReply} returns this
 */
proto.caked.Caked.Reply.RunReply.prototype.setStderr = function(value) {
  return jspb.Message.setProto3BytesField(this, 3, value);
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.Reply.MountReply.repeatedFields_ = [1];

/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.MountReply.oneofGroups_ = [[2,3]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.MountReply.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  ERROR: 2,
  SUCCESS: 3
};

/**
 * @return {proto.caked.Caked.Reply.MountReply.ResponseCase}
 */
proto.caked.Caked.Reply.MountReply.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.Reply.MountReply.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.MountReply.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.MountReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.MountReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.MountReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.MountReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    mountsList: jspb.Message.toObjectList(msg.getMountsList(),
    proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.toObject, includeInstance),
    error: jspb.Message.getFieldWithDefault(msg, 2, ""),
    success: jspb.Message.getBooleanFieldWithDefault(msg, 3, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.MountReply}
 */
proto.caked.Caked.Reply.MountReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.MountReply;
  return proto.caked.Caked.Reply.MountReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.MountReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.MountReply}
 */
proto.caked.Caked.Reply.MountReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new proto.caked.Caked.Reply.MountReply.MountVirtioFSReply;
      reader.readMessage(value,proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.deserializeBinaryFromReader);
      msg.addMounts(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setError(value);
      break;
    case 3:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setSuccess(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.MountReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.MountReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.MountReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.MountReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getMountsList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      1,
      f,
      proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.serializeBinaryToWriter
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeString(
      2,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeBool(
      3,
      f
    );
  }
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.oneofGroups_ = [[3,4]];

/**
 * @enum {number}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.ResponseCase = {
  RESPONSE_NOT_SET: 0,
  ERROR: 3,
  SUCCESS: 4
};

/**
 * @return {proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.ResponseCase}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.getResponseCase = function() {
  return /** @type {proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.ResponseCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    path: jspb.Message.getFieldWithDefault(msg, 2, ""),
    error: jspb.Message.getFieldWithDefault(msg, 3, ""),
    success: jspb.Message.getBooleanFieldWithDefault(msg, 4, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.MountReply.MountVirtioFSReply;
  return proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setPath(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setError(value);
      break;
    case 4:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setSuccess(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getPath();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeBool(
      4,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} returns this
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string path = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.getPath = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} returns this
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.setPath = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional string error = 3;
 * @return {string}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.getError = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} returns this
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.setError = function(value) {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} returns this
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.clearError = function() {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.hasError = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional bool success = 4;
 * @return {boolean}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.getSuccess = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 4, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} returns this
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.setSuccess = function(value) {
  return jspb.Message.setOneofField(this, 4, proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply} returns this
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.clearSuccess = function() {
  return jspb.Message.setOneofField(this, 4, proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.MountReply.MountVirtioFSReply.prototype.hasSuccess = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * repeated MountVirtioFSReply mounts = 1;
 * @return {!Array<!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply>}
 */
proto.caked.Caked.Reply.MountReply.prototype.getMountsList = function() {
  return /** @type{!Array<!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.Reply.MountReply.MountVirtioFSReply, 1));
};


/**
 * @param {!Array<!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply>} value
 * @return {!proto.caked.Caked.Reply.MountReply} returns this
*/
proto.caked.Caked.Reply.MountReply.prototype.setMountsList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 1, value);
};


/**
 * @param {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.Reply.MountReply.MountVirtioFSReply}
 */
proto.caked.Caked.Reply.MountReply.prototype.addMounts = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 1, opt_value, proto.caked.Caked.Reply.MountReply.MountVirtioFSReply, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.Reply.MountReply} returns this
 */
proto.caked.Caked.Reply.MountReply.prototype.clearMountsList = function() {
  return this.setMountsList([]);
};


/**
 * optional string error = 2;
 * @return {string}
 */
proto.caked.Caked.Reply.MountReply.prototype.getError = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.MountReply} returns this
 */
proto.caked.Caked.Reply.MountReply.prototype.setError = function(value) {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.Reply.MountReply.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.MountReply} returns this
 */
proto.caked.Caked.Reply.MountReply.prototype.clearError = function() {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.Reply.MountReply.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.MountReply.prototype.hasError = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional bool success = 3;
 * @return {boolean}
 */
proto.caked.Caked.Reply.MountReply.prototype.getSuccess = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 3, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.Reply.MountReply} returns this
 */
proto.caked.Caked.Reply.MountReply.prototype.setSuccess = function(value) {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.Reply.MountReply.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.Reply.MountReply} returns this
 */
proto.caked.Caked.Reply.MountReply.prototype.clearSuccess = function() {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.Reply.MountReply.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.MountReply.prototype.hasSuccess = function() {
  return jspb.Message.getField(this, 3) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.Reply.TartReply.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.Reply.TartReply.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.Reply.TartReply} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TartReply.toObject = function(includeInstance, msg) {
  var f, obj = {
    message: jspb.Message.getFieldWithDefault(msg, 1, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.Reply.TartReply}
 */
proto.caked.Caked.Reply.TartReply.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.Reply.TartReply;
  return proto.caked.Caked.Reply.TartReply.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.Reply.TartReply} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.Reply.TartReply}
 */
proto.caked.Caked.Reply.TartReply.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setMessage(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.Reply.TartReply.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.Reply.TartReply.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.Reply.TartReply} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.Reply.TartReply.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getMessage();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
};


/**
 * optional string message = 1;
 * @return {string}
 */
proto.caked.Caked.Reply.TartReply.prototype.getMessage = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.Reply.TartReply} returns this
 */
proto.caked.Caked.Reply.TartReply.prototype.setMessage = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional Error error = 1;
 * @return {?proto.caked.Caked.Reply.Error}
 */
proto.caked.Caked.Reply.prototype.getError = function() {
  return /** @type{?proto.caked.Caked.Reply.Error} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.Error, 1));
};


/**
 * @param {?proto.caked.Caked.Reply.Error|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setError = function(value) {
  return jspb.Message.setOneofWrapperField(this, 1, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearError = function() {
  return this.setError(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasError = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional VirtualMachineReply vms = 3;
 * @return {?proto.caked.Caked.Reply.VirtualMachineReply}
 */
proto.caked.Caked.Reply.prototype.getVms = function() {
  return /** @type{?proto.caked.Caked.Reply.VirtualMachineReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.VirtualMachineReply, 3));
};


/**
 * @param {?proto.caked.Caked.Reply.VirtualMachineReply|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setVms = function(value) {
  return jspb.Message.setOneofWrapperField(this, 3, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearVms = function() {
  return this.setVms(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasVms = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional ImageReply images = 4;
 * @return {?proto.caked.Caked.Reply.ImageReply}
 */
proto.caked.Caked.Reply.prototype.getImages = function() {
  return /** @type{?proto.caked.Caked.Reply.ImageReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.ImageReply, 4));
};


/**
 * @param {?proto.caked.Caked.Reply.ImageReply|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setImages = function(value) {
  return jspb.Message.setOneofWrapperField(this, 4, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearImages = function() {
  return this.setImages(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasImages = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional NetworksReply networks = 5;
 * @return {?proto.caked.Caked.Reply.NetworksReply}
 */
proto.caked.Caked.Reply.prototype.getNetworks = function() {
  return /** @type{?proto.caked.Caked.Reply.NetworksReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.NetworksReply, 5));
};


/**
 * @param {?proto.caked.Caked.Reply.NetworksReply|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setNetworks = function(value) {
  return jspb.Message.setOneofWrapperField(this, 5, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearNetworks = function() {
  return this.setNetworks(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasNetworks = function() {
  return jspb.Message.getField(this, 5) != null;
};


/**
 * optional RemoteReply remotes = 6;
 * @return {?proto.caked.Caked.Reply.RemoteReply}
 */
proto.caked.Caked.Reply.prototype.getRemotes = function() {
  return /** @type{?proto.caked.Caked.Reply.RemoteReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.RemoteReply, 6));
};


/**
 * @param {?proto.caked.Caked.Reply.RemoteReply|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setRemotes = function(value) {
  return jspb.Message.setOneofWrapperField(this, 6, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearRemotes = function() {
  return this.setRemotes(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasRemotes = function() {
  return jspb.Message.getField(this, 6) != null;
};


/**
 * optional TemplateReply templates = 7;
 * @return {?proto.caked.Caked.Reply.TemplateReply}
 */
proto.caked.Caked.Reply.prototype.getTemplates = function() {
  return /** @type{?proto.caked.Caked.Reply.TemplateReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.TemplateReply, 7));
};


/**
 * @param {?proto.caked.Caked.Reply.TemplateReply|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setTemplates = function(value) {
  return jspb.Message.setOneofWrapperField(this, 7, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearTemplates = function() {
  return this.setTemplates(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasTemplates = function() {
  return jspb.Message.getField(this, 7) != null;
};


/**
 * optional RunReply run = 8;
 * @return {?proto.caked.Caked.Reply.RunReply}
 */
proto.caked.Caked.Reply.prototype.getRun = function() {
  return /** @type{?proto.caked.Caked.Reply.RunReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.RunReply, 8));
};


/**
 * @param {?proto.caked.Caked.Reply.RunReply|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setRun = function(value) {
  return jspb.Message.setOneofWrapperField(this, 8, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearRun = function() {
  return this.setRun(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasRun = function() {
  return jspb.Message.getField(this, 8) != null;
};


/**
 * optional MountReply mounts = 9;
 * @return {?proto.caked.Caked.Reply.MountReply}
 */
proto.caked.Caked.Reply.prototype.getMounts = function() {
  return /** @type{?proto.caked.Caked.Reply.MountReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.MountReply, 9));
};


/**
 * @param {?proto.caked.Caked.Reply.MountReply|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setMounts = function(value) {
  return jspb.Message.setOneofWrapperField(this, 9, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearMounts = function() {
  return this.setMounts(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasMounts = function() {
  return jspb.Message.getField(this, 9) != null;
};


/**
 * optional TartReply tart = 10;
 * @return {?proto.caked.Caked.Reply.TartReply}
 */
proto.caked.Caked.Reply.prototype.getTart = function() {
  return /** @type{?proto.caked.Caked.Reply.TartReply} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.Reply.TartReply, 10));
};


/**
 * @param {?proto.caked.Caked.Reply.TartReply|undefined} value
 * @return {!proto.caked.Caked.Reply} returns this
*/
proto.caked.Caked.Reply.prototype.setTart = function(value) {
  return jspb.Message.setOneofWrapperField(this, 10, proto.caked.Caked.Reply.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.Reply} returns this
 */
proto.caked.Caked.Reply.prototype.clearTart = function() {
  return this.setTart(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.Reply.prototype.hasTart = function() {
  return jspb.Message.getField(this, 10) != null;
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.NetworkRequest.oneofGroups_ = [[2,3,4]];

/**
 * @enum {number}
 */
proto.caked.Caked.NetworkRequest.NetworkCase = {
  NETWORK_NOT_SET: 0,
  NAME: 2,
  CREATE: 3,
  CONFIGURE: 4
};

/**
 * @return {proto.caked.Caked.NetworkRequest.NetworkCase}
 */
proto.caked.Caked.NetworkRequest.prototype.getNetworkCase = function() {
  return /** @type {proto.caked.Caked.NetworkRequest.NetworkCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.NetworkRequest.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.NetworkRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.NetworkRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.NetworkRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.NetworkRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: jspb.Message.getFieldWithDefault(msg, 1, 0),
    name: jspb.Message.getFieldWithDefault(msg, 2, ""),
    create: (f = msg.getCreate()) && proto.caked.Caked.NetworkRequest.CreateNetworkRequest.toObject(includeInstance, f),
    configure: (f = msg.getConfigure()) && proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.NetworkRequest}
 */
proto.caked.Caked.NetworkRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.NetworkRequest;
  return proto.caked.Caked.NetworkRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.NetworkRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.NetworkRequest}
 */
proto.caked.Caked.NetworkRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.NetworkRequest.NetworkCommand} */ (reader.readEnum());
      msg.setCommand(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 3:
      var value = new proto.caked.Caked.NetworkRequest.CreateNetworkRequest;
      reader.readMessage(value,proto.caked.Caked.NetworkRequest.CreateNetworkRequest.deserializeBinaryFromReader);
      msg.setCreate(value);
      break;
    case 4:
      var value = new proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest;
      reader.readMessage(value,proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.deserializeBinaryFromReader);
      msg.setConfigure(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.NetworkRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.NetworkRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.NetworkRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.NetworkRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getCreate();
  if (f != null) {
    writer.writeMessage(
      3,
      f,
      proto.caked.Caked.NetworkRequest.CreateNetworkRequest.serializeBinaryToWriter
    );
  }
  f = message.getConfigure();
  if (f != null) {
    writer.writeMessage(
      4,
      f,
      proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.serializeBinaryToWriter
    );
  }
};


/**
 * @enum {number}
 */
proto.caked.Caked.NetworkRequest.NetworkMode = {
  SHARED: 0,
  HOST: 1
};

/**
 * @enum {number}
 */
proto.caked.Caked.NetworkRequest.NetworkCommand = {
  INFOS: 0,
  NEW: 1,
  SET: 2,
  START: 3,
  SHUTDOWN: 4,
  REMOVE: 5,
  STATUS: 6
};




if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    gateway: jspb.Message.getFieldWithDefault(msg, 2, ""),
    dhcpend: jspb.Message.getFieldWithDefault(msg, 3, ""),
    netmask: jspb.Message.getFieldWithDefault(msg, 4, ""),
    uuid: jspb.Message.getFieldWithDefault(msg, 5, ""),
    nat66prefix: jspb.Message.getFieldWithDefault(msg, 6, ""),
    dhcplease: jspb.Message.getFieldWithDefault(msg, 7, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest;
  return proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setGateway(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setDhcpend(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setNetmask(value);
      break;
    case 5:
      var value = /** @type {string} */ (reader.readString());
      msg.setUuid(value);
      break;
    case 6:
      var value = /** @type {string} */ (reader.readString());
      msg.setNat66prefix(value);
      break;
    case 7:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setDhcplease(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeString(
      2,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeString(
      4,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeString(
      5,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 6));
  if (f != null) {
    writer.writeString(
      6,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 7));
  if (f != null) {
    writer.writeInt32(
      7,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string gateway = 2;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.getGateway = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.setGateway = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.clearGateway = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.hasGateway = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional string dhcpEnd = 3;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.getDhcpend = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.setDhcpend = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.clearDhcpend = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.hasDhcpend = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional string netmask = 4;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.getNetmask = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.setNetmask = function(value) {
  return jspb.Message.setField(this, 4, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.clearNetmask = function() {
  return jspb.Message.setField(this, 4, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.hasNetmask = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional string uuid = 5;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.getUuid = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 5, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.setUuid = function(value) {
  return jspb.Message.setField(this, 5, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.clearUuid = function() {
  return jspb.Message.setField(this, 5, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.hasUuid = function() {
  return jspb.Message.getField(this, 5) != null;
};


/**
 * optional string nat66prefix = 6;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.getNat66prefix = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 6, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.setNat66prefix = function(value) {
  return jspb.Message.setField(this, 6, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.clearNat66prefix = function() {
  return jspb.Message.setField(this, 6, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.hasNat66prefix = function() {
  return jspb.Message.getField(this, 6) != null;
};


/**
 * optional int32 dhcpLease = 7;
 * @return {number}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.getDhcplease = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 7, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.setDhcplease = function(value) {
  return jspb.Message.setField(this, 7, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.clearDhcplease = function() {
  return jspb.Message.setField(this, 7, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest.prototype.hasDhcplease = function() {
  return jspb.Message.getField(this, 7) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.NetworkRequest.CreateNetworkRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    mode: jspb.Message.getFieldWithDefault(msg, 1, 0),
    name: jspb.Message.getFieldWithDefault(msg, 2, ""),
    gateway: jspb.Message.getFieldWithDefault(msg, 3, ""),
    dhcpend: jspb.Message.getFieldWithDefault(msg, 4, ""),
    netmask: jspb.Message.getFieldWithDefault(msg, 5, ""),
    uuid: jspb.Message.getFieldWithDefault(msg, 6, ""),
    nat66prefix: jspb.Message.getFieldWithDefault(msg, 7, ""),
    dhcplease: jspb.Message.getFieldWithDefault(msg, 8, 0)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.NetworkRequest.CreateNetworkRequest;
  return proto.caked.Caked.NetworkRequest.CreateNetworkRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.NetworkRequest.NetworkMode} */ (reader.readEnum());
      msg.setMode(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setGateway(value);
      break;
    case 4:
      var value = /** @type {string} */ (reader.readString());
      msg.setDhcpend(value);
      break;
    case 5:
      var value = /** @type {string} */ (reader.readString());
      msg.setNetmask(value);
      break;
    case 6:
      var value = /** @type {string} */ (reader.readString());
      msg.setUuid(value);
      break;
    case 7:
      var value = /** @type {string} */ (reader.readString());
      msg.setNat66prefix(value);
      break;
    case 8:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setDhcplease(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.NetworkRequest.CreateNetworkRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getMode();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getGateway();
  if (f.length > 0) {
    writer.writeString(
      3,
      f
    );
  }
  f = message.getDhcpend();
  if (f.length > 0) {
    writer.writeString(
      4,
      f
    );
  }
  f = message.getNetmask();
  if (f.length > 0) {
    writer.writeString(
      5,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 6));
  if (f != null) {
    writer.writeString(
      6,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 7));
  if (f != null) {
    writer.writeString(
      7,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 8));
  if (f != null) {
    writer.writeInt32(
      8,
      f
    );
  }
};


/**
 * optional NetworkMode mode = 1;
 * @return {!proto.caked.Caked.NetworkRequest.NetworkMode}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.getMode = function() {
  return /** @type {!proto.caked.Caked.NetworkRequest.NetworkMode} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.NetworkRequest.NetworkMode} value
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.setMode = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional string name = 2;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional string gateway = 3;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.getGateway = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.setGateway = function(value) {
  return jspb.Message.setProto3StringField(this, 3, value);
};


/**
 * optional string dhcpEnd = 4;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.getDhcpend = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 4, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.setDhcpend = function(value) {
  return jspb.Message.setProto3StringField(this, 4, value);
};


/**
 * optional string netmask = 5;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.getNetmask = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 5, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.setNetmask = function(value) {
  return jspb.Message.setProto3StringField(this, 5, value);
};


/**
 * optional string uuid = 6;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.getUuid = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 6, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.setUuid = function(value) {
  return jspb.Message.setField(this, 6, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.clearUuid = function() {
  return jspb.Message.setField(this, 6, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.hasUuid = function() {
  return jspb.Message.getField(this, 6) != null;
};


/**
 * optional string nat66prefix = 7;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.getNat66prefix = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 7, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.setNat66prefix = function(value) {
  return jspb.Message.setField(this, 7, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.clearNat66prefix = function() {
  return jspb.Message.setField(this, 7, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.hasNat66prefix = function() {
  return jspb.Message.getField(this, 7) != null;
};


/**
 * optional int32 dhcpLease = 8;
 * @return {number}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.getDhcplease = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 8, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.setDhcplease = function(value) {
  return jspb.Message.setField(this, 8, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest.CreateNetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.clearDhcplease = function() {
  return jspb.Message.setField(this, 8, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.CreateNetworkRequest.prototype.hasDhcplease = function() {
  return jspb.Message.getField(this, 8) != null;
};


/**
 * optional NetworkCommand command = 1;
 * @return {!proto.caked.Caked.NetworkRequest.NetworkCommand}
 */
proto.caked.Caked.NetworkRequest.prototype.getCommand = function() {
  return /** @type {!proto.caked.Caked.NetworkRequest.NetworkCommand} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.NetworkRequest.NetworkCommand} value
 * @return {!proto.caked.Caked.NetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.prototype.setCommand = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional string name = 2;
 * @return {string}
 */
proto.caked.Caked.NetworkRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.NetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.prototype.setName = function(value) {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.NetworkRequest.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.prototype.clearName = function() {
  return jspb.Message.setOneofField(this, 2, proto.caked.Caked.NetworkRequest.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.prototype.hasName = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional CreateNetworkRequest create = 3;
 * @return {?proto.caked.Caked.NetworkRequest.CreateNetworkRequest}
 */
proto.caked.Caked.NetworkRequest.prototype.getCreate = function() {
  return /** @type{?proto.caked.Caked.NetworkRequest.CreateNetworkRequest} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.NetworkRequest.CreateNetworkRequest, 3));
};


/**
 * @param {?proto.caked.Caked.NetworkRequest.CreateNetworkRequest|undefined} value
 * @return {!proto.caked.Caked.NetworkRequest} returns this
*/
proto.caked.Caked.NetworkRequest.prototype.setCreate = function(value) {
  return jspb.Message.setOneofWrapperField(this, 3, proto.caked.Caked.NetworkRequest.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.prototype.clearCreate = function() {
  return this.setCreate(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.prototype.hasCreate = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional ConfigureNetworkRequest configure = 4;
 * @return {?proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest}
 */
proto.caked.Caked.NetworkRequest.prototype.getConfigure = function() {
  return /** @type{?proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest, 4));
};


/**
 * @param {?proto.caked.Caked.NetworkRequest.ConfigureNetworkRequest|undefined} value
 * @return {!proto.caked.Caked.NetworkRequest} returns this
*/
proto.caked.Caked.NetworkRequest.prototype.setConfigure = function(value) {
  return jspb.Message.setOneofWrapperField(this, 4, proto.caked.Caked.NetworkRequest.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.NetworkRequest} returns this
 */
proto.caked.Caked.NetworkRequest.prototype.clearConfigure = function() {
  return this.setConfigure(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.NetworkRequest.prototype.hasConfigure = function() {
  return jspb.Message.getField(this, 4) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.ImageRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.ImageRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.ImageRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.ImageRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: jspb.Message.getFieldWithDefault(msg, 1, 0),
    name: jspb.Message.getFieldWithDefault(msg, 2, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.ImageRequest}
 */
proto.caked.Caked.ImageRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.ImageRequest;
  return proto.caked.Caked.ImageRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.ImageRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.ImageRequest}
 */
proto.caked.Caked.ImageRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.ImageRequest.ImageCommand} */ (reader.readEnum());
      msg.setCommand(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.ImageRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.ImageRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.ImageRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.ImageRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
};


/**
 * @enum {number}
 */
proto.caked.Caked.ImageRequest.ImageCommand = {
  NONE: 0,
  INFO: 1,
  PULL: 2,
  LIST: 3
};

/**
 * optional ImageCommand command = 1;
 * @return {!proto.caked.Caked.ImageRequest.ImageCommand}
 */
proto.caked.Caked.ImageRequest.prototype.getCommand = function() {
  return /** @type {!proto.caked.Caked.ImageRequest.ImageCommand} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.ImageRequest.ImageCommand} value
 * @return {!proto.caked.Caked.ImageRequest} returns this
 */
proto.caked.Caked.ImageRequest.prototype.setCommand = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional string name = 2;
 * @return {string}
 */
proto.caked.Caked.ImageRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.ImageRequest} returns this
 */
proto.caked.Caked.ImageRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};



/**
 * Oneof group definitions for this message. Each group defines the field
 * numbers belonging to that group. When of these fields' value is set, all
 * other fields in the group are cleared. During deserialization, if multiple
 * fields are encountered for a group, only the last value seen will be kept.
 * @private {!Array<!Array<number>>}
 * @const
 */
proto.caked.Caked.RemoteRequest.oneofGroups_ = [[2,3]];

/**
 * @enum {number}
 */
proto.caked.Caked.RemoteRequest.RemoteCase = {
  REMOTE_NOT_SET: 0,
  ADDREQUEST: 2,
  DELETEREQUEST: 3
};

/**
 * @return {proto.caked.Caked.RemoteRequest.RemoteCase}
 */
proto.caked.Caked.RemoteRequest.prototype.getRemoteCase = function() {
  return /** @type {proto.caked.Caked.RemoteRequest.RemoteCase} */(jspb.Message.computeOneofCase(this, proto.caked.Caked.RemoteRequest.oneofGroups_[0]));
};



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.RemoteRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.RemoteRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.RemoteRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.RemoteRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: jspb.Message.getFieldWithDefault(msg, 1, 0),
    addrequest: (f = msg.getAddrequest()) && proto.caked.Caked.RemoteRequest.RemoteRequestAdd.toObject(includeInstance, f),
    deleterequest: jspb.Message.getFieldWithDefault(msg, 3, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.RemoteRequest}
 */
proto.caked.Caked.RemoteRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.RemoteRequest;
  return proto.caked.Caked.RemoteRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.RemoteRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.RemoteRequest}
 */
proto.caked.Caked.RemoteRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.RemoteRequest.RemoteCommand} */ (reader.readEnum());
      msg.setCommand(value);
      break;
    case 2:
      var value = new proto.caked.Caked.RemoteRequest.RemoteRequestAdd;
      reader.readMessage(value,proto.caked.Caked.RemoteRequest.RemoteRequestAdd.deserializeBinaryFromReader);
      msg.setAddrequest(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setDeleterequest(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.RemoteRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.RemoteRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.RemoteRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.RemoteRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = message.getAddrequest();
  if (f != null) {
    writer.writeMessage(
      2,
      f,
      proto.caked.Caked.RemoteRequest.RemoteRequestAdd.serializeBinaryToWriter
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
};


/**
 * @enum {number}
 */
proto.caked.Caked.RemoteRequest.RemoteCommand = {
  NONE: 0,
  LIST: 1,
  ADD: 2,
  DELETE: 3
};




if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.RemoteRequest.RemoteRequestAdd.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.RemoteRequest.RemoteRequestAdd} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.toObject = function(includeInstance, msg) {
  var f, obj = {
    name: jspb.Message.getFieldWithDefault(msg, 1, ""),
    url: jspb.Message.getFieldWithDefault(msg, 2, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.RemoteRequest.RemoteRequestAdd}
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.RemoteRequest.RemoteRequestAdd;
  return proto.caked.Caked.RemoteRequest.RemoteRequestAdd.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.RemoteRequest.RemoteRequestAdd} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.RemoteRequest.RemoteRequestAdd}
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setUrl(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.RemoteRequest.RemoteRequestAdd.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.RemoteRequest.RemoteRequestAdd} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getUrl();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
};


/**
 * optional string name = 1;
 * @return {string}
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.RemoteRequest.RemoteRequestAdd} returns this
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string url = 2;
 * @return {string}
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.prototype.getUrl = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.RemoteRequest.RemoteRequestAdd} returns this
 */
proto.caked.Caked.RemoteRequest.RemoteRequestAdd.prototype.setUrl = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional RemoteCommand command = 1;
 * @return {!proto.caked.Caked.RemoteRequest.RemoteCommand}
 */
proto.caked.Caked.RemoteRequest.prototype.getCommand = function() {
  return /** @type {!proto.caked.Caked.RemoteRequest.RemoteCommand} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.RemoteRequest.RemoteCommand} value
 * @return {!proto.caked.Caked.RemoteRequest} returns this
 */
proto.caked.Caked.RemoteRequest.prototype.setCommand = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional RemoteRequestAdd addRequest = 2;
 * @return {?proto.caked.Caked.RemoteRequest.RemoteRequestAdd}
 */
proto.caked.Caked.RemoteRequest.prototype.getAddrequest = function() {
  return /** @type{?proto.caked.Caked.RemoteRequest.RemoteRequestAdd} */ (
    jspb.Message.getWrapperField(this, proto.caked.Caked.RemoteRequest.RemoteRequestAdd, 2));
};


/**
 * @param {?proto.caked.Caked.RemoteRequest.RemoteRequestAdd|undefined} value
 * @return {!proto.caked.Caked.RemoteRequest} returns this
*/
proto.caked.Caked.RemoteRequest.prototype.setAddrequest = function(value) {
  return jspb.Message.setOneofWrapperField(this, 2, proto.caked.Caked.RemoteRequest.oneofGroups_[0], value);
};


/**
 * Clears the message field making it undefined.
 * @return {!proto.caked.Caked.RemoteRequest} returns this
 */
proto.caked.Caked.RemoteRequest.prototype.clearAddrequest = function() {
  return this.setAddrequest(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.RemoteRequest.prototype.hasAddrequest = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional string deleteRequest = 3;
 * @return {string}
 */
proto.caked.Caked.RemoteRequest.prototype.getDeleterequest = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.RemoteRequest} returns this
 */
proto.caked.Caked.RemoteRequest.prototype.setDeleterequest = function(value) {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.RemoteRequest.oneofGroups_[0], value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.RemoteRequest} returns this
 */
proto.caked.Caked.RemoteRequest.prototype.clearDeleterequest = function() {
  return jspb.Message.setOneofField(this, 3, proto.caked.Caked.RemoteRequest.oneofGroups_[0], undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.RemoteRequest.prototype.hasDeleterequest = function() {
  return jspb.Message.getField(this, 3) != null;
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.CakedCommandRequest.repeatedFields_ = [2];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.CakedCommandRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.CakedCommandRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.CakedCommandRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.CakedCommandRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: jspb.Message.getFieldWithDefault(msg, 1, ""),
    argumentsList: (f = jspb.Message.getRepeatedField(msg, 2)) == null ? undefined : f
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.CakedCommandRequest}
 */
proto.caked.Caked.CakedCommandRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.CakedCommandRequest;
  return proto.caked.Caked.CakedCommandRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.CakedCommandRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.CakedCommandRequest}
 */
proto.caked.Caked.CakedCommandRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setCommand(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.addArguments(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.CakedCommandRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.CakedCommandRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.CakedCommandRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.CakedCommandRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getArgumentsList();
  if (f.length > 0) {
    writer.writeRepeatedString(
      2,
      f
    );
  }
};


/**
 * optional string command = 1;
 * @return {string}
 */
proto.caked.Caked.CakedCommandRequest.prototype.getCommand = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.CakedCommandRequest} returns this
 */
proto.caked.Caked.CakedCommandRequest.prototype.setCommand = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * repeated string arguments = 2;
 * @return {!Array<string>}
 */
proto.caked.Caked.CakedCommandRequest.prototype.getArgumentsList = function() {
  return /** @type {!Array<string>} */ (jspb.Message.getRepeatedField(this, 2));
};


/**
 * @param {!Array<string>} value
 * @return {!proto.caked.Caked.CakedCommandRequest} returns this
 */
proto.caked.Caked.CakedCommandRequest.prototype.setArgumentsList = function(value) {
  return jspb.Message.setField(this, 2, value || []);
};


/**
 * @param {string} value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.CakedCommandRequest} returns this
 */
proto.caked.Caked.CakedCommandRequest.prototype.addArguments = function(value, opt_index) {
  return jspb.Message.addToRepeatedField(this, 2, value, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.CakedCommandRequest} returns this
 */
proto.caked.Caked.CakedCommandRequest.prototype.clearArgumentsList = function() {
  return this.setArgumentsList([]);
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.PurgeRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.PurgeRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.PurgeRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.PurgeRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    entries: jspb.Message.getFieldWithDefault(msg, 1, ""),
    olderthan: jspb.Message.getFieldWithDefault(msg, 2, 0),
    spacebudget: jspb.Message.getFieldWithDefault(msg, 3, 0),
    gc: jspb.Message.getBooleanFieldWithDefault(msg, 5, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.PurgeRequest}
 */
proto.caked.Caked.PurgeRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.PurgeRequest;
  return proto.caked.Caked.PurgeRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.PurgeRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.PurgeRequest}
 */
proto.caked.Caked.PurgeRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setEntries(value);
      break;
    case 2:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setOlderthan(value);
      break;
    case 3:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setSpacebudget(value);
      break;
    case 5:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setGc(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.PurgeRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.PurgeRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.PurgeRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.PurgeRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = /** @type {string} */ (jspb.Message.getField(message, 1));
  if (f != null) {
    writer.writeString(
      1,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeInt32(
      2,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeInt32(
      3,
      f
    );
  }
  f = /** @type {boolean} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeBool(
      5,
      f
    );
  }
};


/**
 * optional string entries = 1;
 * @return {string}
 */
proto.caked.Caked.PurgeRequest.prototype.getEntries = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.PurgeRequest} returns this
 */
proto.caked.Caked.PurgeRequest.prototype.setEntries = function(value) {
  return jspb.Message.setField(this, 1, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.PurgeRequest} returns this
 */
proto.caked.Caked.PurgeRequest.prototype.clearEntries = function() {
  return jspb.Message.setField(this, 1, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.PurgeRequest.prototype.hasEntries = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional int32 olderThan = 2;
 * @return {number}
 */
proto.caked.Caked.PurgeRequest.prototype.getOlderthan = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.PurgeRequest} returns this
 */
proto.caked.Caked.PurgeRequest.prototype.setOlderthan = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.PurgeRequest} returns this
 */
proto.caked.Caked.PurgeRequest.prototype.clearOlderthan = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.PurgeRequest.prototype.hasOlderthan = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional int32 spaceBudget = 3;
 * @return {number}
 */
proto.caked.Caked.PurgeRequest.prototype.getSpacebudget = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.PurgeRequest} returns this
 */
proto.caked.Caked.PurgeRequest.prototype.setSpacebudget = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.PurgeRequest} returns this
 */
proto.caked.Caked.PurgeRequest.prototype.clearSpacebudget = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.PurgeRequest.prototype.hasSpacebudget = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional bool gc = 5;
 * @return {boolean}
 */
proto.caked.Caked.PurgeRequest.prototype.getGc = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 5, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.PurgeRequest} returns this
 */
proto.caked.Caked.PurgeRequest.prototype.setGc = function(value) {
  return jspb.Message.setField(this, 5, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.PurgeRequest} returns this
 */
proto.caked.Caked.PurgeRequest.prototype.clearGc = function() {
  return jspb.Message.setField(this, 5, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.PurgeRequest.prototype.hasGc = function() {
  return jspb.Message.getField(this, 5) != null;
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.LogoutRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.LogoutRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.LogoutRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.LogoutRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    host: jspb.Message.getFieldWithDefault(msg, 1, "")
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.LogoutRequest}
 */
proto.caked.Caked.LogoutRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.LogoutRequest;
  return proto.caked.Caked.LogoutRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.LogoutRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.LogoutRequest}
 */
proto.caked.Caked.LogoutRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setHost(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.LogoutRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.LogoutRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.LogoutRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.LogoutRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getHost();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
};


/**
 * optional string host = 1;
 * @return {string}
 */
proto.caked.Caked.LogoutRequest.prototype.getHost = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.LogoutRequest} returns this
 */
proto.caked.Caked.LogoutRequest.prototype.setHost = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};





if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.LoginRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.LoginRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.LoginRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.LoginRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    host: jspb.Message.getFieldWithDefault(msg, 1, ""),
    username: jspb.Message.getFieldWithDefault(msg, 2, ""),
    password: jspb.Message.getFieldWithDefault(msg, 3, ""),
    insecure: jspb.Message.getBooleanFieldWithDefault(msg, 4, false),
    novalidate: jspb.Message.getBooleanFieldWithDefault(msg, 5, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.LoginRequest}
 */
proto.caked.Caked.LoginRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.LoginRequest;
  return proto.caked.Caked.LoginRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.LoginRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.LoginRequest}
 */
proto.caked.Caked.LoginRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setHost(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setUsername(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setPassword(value);
      break;
    case 4:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setInsecure(value);
      break;
    case 5:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setNovalidate(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.LoginRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.LoginRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.LoginRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.LoginRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getHost();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = message.getUsername();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getPassword();
  if (f.length > 0) {
    writer.writeString(
      3,
      f
    );
  }
  f = message.getInsecure();
  if (f) {
    writer.writeBool(
      4,
      f
    );
  }
  f = message.getNovalidate();
  if (f) {
    writer.writeBool(
      5,
      f
    );
  }
};


/**
 * optional string host = 1;
 * @return {string}
 */
proto.caked.Caked.LoginRequest.prototype.getHost = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.LoginRequest} returns this
 */
proto.caked.Caked.LoginRequest.prototype.setHost = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string username = 2;
 * @return {string}
 */
proto.caked.Caked.LoginRequest.prototype.getUsername = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.LoginRequest} returns this
 */
proto.caked.Caked.LoginRequest.prototype.setUsername = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * optional string password = 3;
 * @return {string}
 */
proto.caked.Caked.LoginRequest.prototype.getPassword = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.LoginRequest} returns this
 */
proto.caked.Caked.LoginRequest.prototype.setPassword = function(value) {
  return jspb.Message.setProto3StringField(this, 3, value);
};


/**
 * optional bool insecure = 4;
 * @return {boolean}
 */
proto.caked.Caked.LoginRequest.prototype.getInsecure = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 4, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.LoginRequest} returns this
 */
proto.caked.Caked.LoginRequest.prototype.setInsecure = function(value) {
  return jspb.Message.setProto3BooleanField(this, 4, value);
};


/**
 * optional bool noValidate = 5;
 * @return {boolean}
 */
proto.caked.Caked.LoginRequest.prototype.getNovalidate = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 5, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.LoginRequest} returns this
 */
proto.caked.Caked.LoginRequest.prototype.setNovalidate = function(value) {
  return jspb.Message.setProto3BooleanField(this, 5, value);
};



/**
 * List of repeated fields within this message type.
 * @private {!Array<number>}
 * @const
 */
proto.caked.Caked.MountRequest.repeatedFields_ = [3];



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.MountRequest.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.MountRequest.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.MountRequest} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.MountRequest.toObject = function(includeInstance, msg) {
  var f, obj = {
    command: jspb.Message.getFieldWithDefault(msg, 1, 0),
    name: jspb.Message.getFieldWithDefault(msg, 2, ""),
    mountsList: jspb.Message.toObjectList(msg.getMountsList(),
    proto.caked.Caked.MountRequest.MountVirtioFS.toObject, includeInstance)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.MountRequest}
 */
proto.caked.Caked.MountRequest.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.MountRequest;
  return proto.caked.Caked.MountRequest.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.MountRequest} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.MountRequest}
 */
proto.caked.Caked.MountRequest.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {!proto.caked.Caked.MountRequest.MountCommand} */ (reader.readEnum());
      msg.setCommand(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 3:
      var value = new proto.caked.Caked.MountRequest.MountVirtioFS;
      reader.readMessage(value,proto.caked.Caked.MountRequest.MountVirtioFS.deserializeBinaryFromReader);
      msg.addMounts(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.MountRequest.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.MountRequest.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.MountRequest} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.MountRequest.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getCommand();
  if (f !== 0.0) {
    writer.writeEnum(
      1,
      f
    );
  }
  f = message.getName();
  if (f.length > 0) {
    writer.writeString(
      2,
      f
    );
  }
  f = message.getMountsList();
  if (f.length > 0) {
    writer.writeRepeatedMessage(
      3,
      f,
      proto.caked.Caked.MountRequest.MountVirtioFS.serializeBinaryToWriter
    );
  }
};


/**
 * @enum {number}
 */
proto.caked.Caked.MountRequest.MountCommand = {
  NONE: 0,
  MOUNT: 1,
  UMOUNT: 2
};




if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * Optional fields that are not set will be set to undefined.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     net/proto2/compiler/js/internal/generator.cc#kKeyword.
 * @param {boolean=} opt_includeInstance Deprecated. whether to include the
 *     JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @return {!Object}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.toObject = function(opt_includeInstance) {
  return proto.caked.Caked.MountRequest.MountVirtioFS.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Deprecated. Whether to include
 *     the JSPB instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.caked.Caked.MountRequest.MountVirtioFS} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.MountRequest.MountVirtioFS.toObject = function(includeInstance, msg) {
  var f, obj = {
    source: jspb.Message.getFieldWithDefault(msg, 1, ""),
    target: jspb.Message.getFieldWithDefault(msg, 2, ""),
    name: jspb.Message.getFieldWithDefault(msg, 3, ""),
    uid: jspb.Message.getFieldWithDefault(msg, 4, 0),
    gid: jspb.Message.getFieldWithDefault(msg, 5, 0),
    readonly: jspb.Message.getBooleanFieldWithDefault(msg, 6, false)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.caked.Caked.MountRequest.MountVirtioFS;
  return proto.caked.Caked.MountRequest.MountVirtioFS.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.caked.Caked.MountRequest.MountVirtioFS} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = /** @type {string} */ (reader.readString());
      msg.setSource(value);
      break;
    case 2:
      var value = /** @type {string} */ (reader.readString());
      msg.setTarget(value);
      break;
    case 3:
      var value = /** @type {string} */ (reader.readString());
      msg.setName(value);
      break;
    case 4:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setUid(value);
      break;
    case 5:
      var value = /** @type {number} */ (reader.readInt32());
      msg.setGid(value);
      break;
    case 6:
      var value = /** @type {boolean} */ (reader.readBool());
      msg.setReadonly(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.caked.Caked.MountRequest.MountVirtioFS.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.caked.Caked.MountRequest.MountVirtioFS} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.caked.Caked.MountRequest.MountVirtioFS.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getSource();
  if (f.length > 0) {
    writer.writeString(
      1,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 2));
  if (f != null) {
    writer.writeString(
      2,
      f
    );
  }
  f = /** @type {string} */ (jspb.Message.getField(message, 3));
  if (f != null) {
    writer.writeString(
      3,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 4));
  if (f != null) {
    writer.writeInt32(
      4,
      f
    );
  }
  f = /** @type {number} */ (jspb.Message.getField(message, 5));
  if (f != null) {
    writer.writeInt32(
      5,
      f
    );
  }
  f = message.getReadonly();
  if (f) {
    writer.writeBool(
      6,
      f
    );
  }
};


/**
 * optional string source = 1;
 * @return {string}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.getSource = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 1, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.setSource = function(value) {
  return jspb.Message.setProto3StringField(this, 1, value);
};


/**
 * optional string target = 2;
 * @return {string}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.getTarget = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.setTarget = function(value) {
  return jspb.Message.setField(this, 2, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.clearTarget = function() {
  return jspb.Message.setField(this, 2, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.hasTarget = function() {
  return jspb.Message.getField(this, 2) != null;
};


/**
 * optional string name = 3;
 * @return {string}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 3, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.setName = function(value) {
  return jspb.Message.setField(this, 3, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.clearName = function() {
  return jspb.Message.setField(this, 3, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.hasName = function() {
  return jspb.Message.getField(this, 3) != null;
};


/**
 * optional int32 uid = 4;
 * @return {number}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.getUid = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 4, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.setUid = function(value) {
  return jspb.Message.setField(this, 4, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.clearUid = function() {
  return jspb.Message.setField(this, 4, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.hasUid = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional int32 gid = 5;
 * @return {number}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.getGid = function() {
  return /** @type {number} */ (jspb.Message.getFieldWithDefault(this, 5, 0));
};


/**
 * @param {number} value
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.setGid = function(value) {
  return jspb.Message.setField(this, 5, value);
};


/**
 * Clears the field making it undefined.
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.clearGid = function() {
  return jspb.Message.setField(this, 5, undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.hasGid = function() {
  return jspb.Message.getField(this, 5) != null;
};


/**
 * optional bool readonly = 6;
 * @return {boolean}
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.getReadonly = function() {
  return /** @type {boolean} */ (jspb.Message.getBooleanFieldWithDefault(this, 6, false));
};


/**
 * @param {boolean} value
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS} returns this
 */
proto.caked.Caked.MountRequest.MountVirtioFS.prototype.setReadonly = function(value) {
  return jspb.Message.setProto3BooleanField(this, 6, value);
};


/**
 * optional MountCommand command = 1;
 * @return {!proto.caked.Caked.MountRequest.MountCommand}
 */
proto.caked.Caked.MountRequest.prototype.getCommand = function() {
  return /** @type {!proto.caked.Caked.MountRequest.MountCommand} */ (jspb.Message.getFieldWithDefault(this, 1, 0));
};


/**
 * @param {!proto.caked.Caked.MountRequest.MountCommand} value
 * @return {!proto.caked.Caked.MountRequest} returns this
 */
proto.caked.Caked.MountRequest.prototype.setCommand = function(value) {
  return jspb.Message.setProto3EnumField(this, 1, value);
};


/**
 * optional string name = 2;
 * @return {string}
 */
proto.caked.Caked.MountRequest.prototype.getName = function() {
  return /** @type {string} */ (jspb.Message.getFieldWithDefault(this, 2, ""));
};


/**
 * @param {string} value
 * @return {!proto.caked.Caked.MountRequest} returns this
 */
proto.caked.Caked.MountRequest.prototype.setName = function(value) {
  return jspb.Message.setProto3StringField(this, 2, value);
};


/**
 * repeated MountVirtioFS mounts = 3;
 * @return {!Array<!proto.caked.Caked.MountRequest.MountVirtioFS>}
 */
proto.caked.Caked.MountRequest.prototype.getMountsList = function() {
  return /** @type{!Array<!proto.caked.Caked.MountRequest.MountVirtioFS>} */ (
    jspb.Message.getRepeatedWrapperField(this, proto.caked.Caked.MountRequest.MountVirtioFS, 3));
};


/**
 * @param {!Array<!proto.caked.Caked.MountRequest.MountVirtioFS>} value
 * @return {!proto.caked.Caked.MountRequest} returns this
*/
proto.caked.Caked.MountRequest.prototype.setMountsList = function(value) {
  return jspb.Message.setRepeatedWrapperField(this, 3, value);
};


/**
 * @param {!proto.caked.Caked.MountRequest.MountVirtioFS=} opt_value
 * @param {number=} opt_index
 * @return {!proto.caked.Caked.MountRequest.MountVirtioFS}
 */
proto.caked.Caked.MountRequest.prototype.addMounts = function(opt_value, opt_index) {
  return jspb.Message.addToRepeatedWrapperField(this, 3, opt_value, proto.caked.Caked.MountRequest.MountVirtioFS, opt_index);
};


/**
 * Clears the list making it empty but non-null.
 * @return {!proto.caked.Caked.MountRequest} returns this
 */
proto.caked.Caked.MountRequest.prototype.clearMountsList = function() {
  return this.setMountsList([]);
};


goog.object.extend(exports, proto.caked);
