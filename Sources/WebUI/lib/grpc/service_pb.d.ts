// package: caked
// file: service.proto

/* tslint:disable */
/* eslint-disable */

import * as jspb from "google-protobuf";

export class Caked extends jspb.Message { 

    serializeBinary(): Uint8Array;
    toObject(includeInstance?: boolean): Caked.AsObject;
    static toObject(includeInstance: boolean, msg: Caked): Caked.AsObject;
    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
    static serializeBinaryToWriter(message: Caked, writer: jspb.BinaryWriter): void;
    static deserializeBinary(bytes: Uint8Array): Caked;
    static deserializeBinaryFromReader(message: Caked, reader: jspb.BinaryReader): Caked;
}

export namespace Caked {
    export type AsObject = {
    }


    export class VMRequest extends jspb.Message { 

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): VMRequest.AsObject;
        static toObject(includeInstance: boolean, msg: VMRequest): VMRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: VMRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): VMRequest;
        static deserializeBinaryFromReader(message: VMRequest, reader: jspb.BinaryReader): VMRequest;
    }

    export namespace VMRequest {
        export type AsObject = {
        }


        export class CommonBuildRequest extends jspb.Message { 
            getName(): string;
            setName(value: string): CommonBuildRequest;

            hasCpu(): boolean;
            clearCpu(): void;
            getCpu(): number | undefined;
            setCpu(value: number): CommonBuildRequest;

            hasMemory(): boolean;
            clearMemory(): void;
            getMemory(): number | undefined;
            setMemory(value: number): CommonBuildRequest;

            hasUser(): boolean;
            clearUser(): void;
            getUser(): string | undefined;
            setUser(value: string): CommonBuildRequest;

            hasPassword(): boolean;
            clearPassword(): void;
            getPassword(): string | undefined;
            setPassword(value: string): CommonBuildRequest;

            hasMaingroup(): boolean;
            clearMaingroup(): void;
            getMaingroup(): string | undefined;
            setMaingroup(value: string): CommonBuildRequest;

            hasSshpwauth(): boolean;
            clearSshpwauth(): void;
            getSshpwauth(): boolean | undefined;
            setSshpwauth(value: boolean): CommonBuildRequest;

            hasImage(): boolean;
            clearImage(): void;
            getImage(): string | undefined;
            setImage(value: string): CommonBuildRequest;

            hasSshauthorizedkey(): boolean;
            clearSshauthorizedkey(): void;
            getSshauthorizedkey(): Uint8Array | string;
            getSshauthorizedkey_asU8(): Uint8Array;
            getSshauthorizedkey_asB64(): string;
            setSshauthorizedkey(value: Uint8Array | string): CommonBuildRequest;

            hasVendordata(): boolean;
            clearVendordata(): void;
            getVendordata(): Uint8Array | string;
            getVendordata_asU8(): Uint8Array;
            getVendordata_asB64(): string;
            setVendordata(value: Uint8Array | string): CommonBuildRequest;

            hasUserdata(): boolean;
            clearUserdata(): void;
            getUserdata(): Uint8Array | string;
            getUserdata_asU8(): Uint8Array;
            getUserdata_asB64(): string;
            setUserdata(value: Uint8Array | string): CommonBuildRequest;

            hasNetworkconfig(): boolean;
            clearNetworkconfig(): void;
            getNetworkconfig(): Uint8Array | string;
            getNetworkconfig_asU8(): Uint8Array;
            getNetworkconfig_asB64(): string;
            setNetworkconfig(value: Uint8Array | string): CommonBuildRequest;

            hasDisksize(): boolean;
            clearDisksize(): void;
            getDisksize(): number | undefined;
            setDisksize(value: number): CommonBuildRequest;

            hasAutostart(): boolean;
            clearAutostart(): void;
            getAutostart(): boolean | undefined;
            setAutostart(value: boolean): CommonBuildRequest;

            hasNested(): boolean;
            clearNested(): void;
            getNested(): boolean | undefined;
            setNested(value: boolean): CommonBuildRequest;

            hasForwardedport(): boolean;
            clearForwardedport(): void;
            getForwardedport(): string | undefined;
            setForwardedport(value: string): CommonBuildRequest;

            hasMounts(): boolean;
            clearMounts(): void;
            getMounts(): string | undefined;
            setMounts(value: string): CommonBuildRequest;

            hasNetworks(): boolean;
            clearNetworks(): void;
            getNetworks(): string | undefined;
            setNetworks(value: string): CommonBuildRequest;

            hasSockets(): boolean;
            clearSockets(): void;
            getSockets(): string | undefined;
            setSockets(value: string): CommonBuildRequest;

            hasConsole(): boolean;
            clearConsole(): void;
            getConsole(): string | undefined;
            setConsole(value: string): CommonBuildRequest;

            hasAttacheddisks(): boolean;
            clearAttacheddisks(): void;
            getAttacheddisks(): string | undefined;
            setAttacheddisks(value: string): CommonBuildRequest;

            hasDynamicportforwarding(): boolean;
            clearDynamicportforwarding(): void;
            getDynamicportforwarding(): boolean | undefined;
            setDynamicportforwarding(value: boolean): CommonBuildRequest;

            hasIfnames(): boolean;
            clearIfnames(): void;
            getIfnames(): boolean | undefined;
            setIfnames(value: boolean): CommonBuildRequest;

            hasSuspendable(): boolean;
            clearSuspendable(): void;
            getSuspendable(): boolean | undefined;
            setSuspendable(value: boolean): CommonBuildRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): CommonBuildRequest.AsObject;
            static toObject(includeInstance: boolean, msg: CommonBuildRequest): CommonBuildRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: CommonBuildRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): CommonBuildRequest;
            static deserializeBinaryFromReader(message: CommonBuildRequest, reader: jspb.BinaryReader): CommonBuildRequest;
        }

        export namespace CommonBuildRequest {
            export type AsObject = {
                name: string,
                cpu?: number,
                memory?: number,
                user?: string,
                password?: string,
                maingroup?: string,
                sshpwauth?: boolean,
                image?: string,
                sshauthorizedkey: Uint8Array | string,
                vendordata: Uint8Array | string,
                userdata: Uint8Array | string,
                networkconfig: Uint8Array | string,
                disksize?: number,
                autostart?: boolean,
                nested?: boolean,
                forwardedport?: string,
                mounts?: string,
                networks?: string,
                sockets?: string,
                console?: string,
                attacheddisks?: string,
                dynamicportforwarding?: boolean,
                ifnames?: boolean,
                suspendable?: boolean,
            }
        }

        export class BuildRequest extends jspb.Message { 

            hasOptions(): boolean;
            clearOptions(): void;
            getOptions(): Caked.VMRequest.CommonBuildRequest | undefined;
            setOptions(value?: Caked.VMRequest.CommonBuildRequest): BuildRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): BuildRequest.AsObject;
            static toObject(includeInstance: boolean, msg: BuildRequest): BuildRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: BuildRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): BuildRequest;
            static deserializeBinaryFromReader(message: BuildRequest, reader: jspb.BinaryReader): BuildRequest;
        }

        export namespace BuildRequest {
            export type AsObject = {
                options?: Caked.VMRequest.CommonBuildRequest.AsObject,
            }
        }

        export class StartRequest extends jspb.Message { 
            getName(): string;
            setName(value: string): StartRequest;

            hasWaitiptimeout(): boolean;
            clearWaitiptimeout(): void;
            getWaitiptimeout(): number | undefined;
            setWaitiptimeout(value: number): StartRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): StartRequest.AsObject;
            static toObject(includeInstance: boolean, msg: StartRequest): StartRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: StartRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): StartRequest;
            static deserializeBinaryFromReader(message: StartRequest, reader: jspb.BinaryReader): StartRequest;
        }

        export namespace StartRequest {
            export type AsObject = {
                name: string,
                waitiptimeout?: number,
            }
        }

        export class CloneRequest extends jspb.Message { 
            getSourcename(): string;
            setSourcename(value: string): CloneRequest;
            getTargetname(): string;
            setTargetname(value: string): CloneRequest;

            hasInsecure(): boolean;
            clearInsecure(): void;
            getInsecure(): boolean | undefined;
            setInsecure(value: boolean): CloneRequest;

            hasConcurrency(): boolean;
            clearConcurrency(): void;
            getConcurrency(): number | undefined;
            setConcurrency(value: number): CloneRequest;

            hasDeduplicate(): boolean;
            clearDeduplicate(): void;
            getDeduplicate(): boolean | undefined;
            setDeduplicate(value: boolean): CloneRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): CloneRequest.AsObject;
            static toObject(includeInstance: boolean, msg: CloneRequest): CloneRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: CloneRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): CloneRequest;
            static deserializeBinaryFromReader(message: CloneRequest, reader: jspb.BinaryReader): CloneRequest;
        }

        export namespace CloneRequest {
            export type AsObject = {
                sourcename: string,
                targetname: string,
                insecure?: boolean,
                concurrency?: number,
                deduplicate?: boolean,
            }
        }

        export class DuplicateRequest extends jspb.Message { 
            getFrom(): string;
            setFrom(value: string): DuplicateRequest;
            getTo(): string;
            setTo(value: string): DuplicateRequest;
            getResetmacaddress(): boolean;
            setResetmacaddress(value: boolean): DuplicateRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): DuplicateRequest.AsObject;
            static toObject(includeInstance: boolean, msg: DuplicateRequest): DuplicateRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: DuplicateRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): DuplicateRequest;
            static deserializeBinaryFromReader(message: DuplicateRequest, reader: jspb.BinaryReader): DuplicateRequest;
        }

        export namespace DuplicateRequest {
            export type AsObject = {
                from: string,
                to: string,
                resetmacaddress: boolean,
            }
        }

        export class LaunchRequest extends jspb.Message { 

            hasOptions(): boolean;
            clearOptions(): void;
            getOptions(): Caked.VMRequest.CommonBuildRequest | undefined;
            setOptions(value?: Caked.VMRequest.CommonBuildRequest): LaunchRequest;

            hasWaitiptimeout(): boolean;
            clearWaitiptimeout(): void;
            getWaitiptimeout(): number | undefined;
            setWaitiptimeout(value: number): LaunchRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): LaunchRequest.AsObject;
            static toObject(includeInstance: boolean, msg: LaunchRequest): LaunchRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: LaunchRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): LaunchRequest;
            static deserializeBinaryFromReader(message: LaunchRequest, reader: jspb.BinaryReader): LaunchRequest;
        }

        export namespace LaunchRequest {
            export type AsObject = {
                options?: Caked.VMRequest.CommonBuildRequest.AsObject,
                waitiptimeout?: number,
            }
        }

        export class ConfigureRequest extends jspb.Message { 
            getName(): string;
            setName(value: string): ConfigureRequest;

            hasCpu(): boolean;
            clearCpu(): void;
            getCpu(): number | undefined;
            setCpu(value: number): ConfigureRequest;

            hasMemory(): boolean;
            clearMemory(): void;
            getMemory(): number | undefined;
            setMemory(value: number): ConfigureRequest;

            hasDisksize(): boolean;
            clearDisksize(): void;
            getDisksize(): number | undefined;
            setDisksize(value: number): ConfigureRequest;

            hasDisplayrefit(): boolean;
            clearDisplayrefit(): void;
            getDisplayrefit(): boolean | undefined;
            setDisplayrefit(value: boolean): ConfigureRequest;

            hasAutostart(): boolean;
            clearAutostart(): void;
            getAutostart(): boolean | undefined;
            setAutostart(value: boolean): ConfigureRequest;

            hasNested(): boolean;
            clearNested(): void;
            getNested(): boolean | undefined;
            setNested(value: boolean): ConfigureRequest;

            hasMounts(): boolean;
            clearMounts(): void;
            getMounts(): string | undefined;
            setMounts(value: string): ConfigureRequest;

            hasNetworks(): boolean;
            clearNetworks(): void;
            getNetworks(): string | undefined;
            setNetworks(value: string): ConfigureRequest;

            hasSockets(): boolean;
            clearSockets(): void;
            getSockets(): string | undefined;
            setSockets(value: string): ConfigureRequest;

            hasConsole(): boolean;
            clearConsole(): void;
            getConsole(): string | undefined;
            setConsole(value: string): ConfigureRequest;

            hasRandommac(): boolean;
            clearRandommac(): void;
            getRandommac(): boolean | undefined;
            setRandommac(value: boolean): ConfigureRequest;

            hasForwardedport(): boolean;
            clearForwardedport(): void;
            getForwardedport(): string | undefined;
            setForwardedport(value: string): ConfigureRequest;

            hasAttacheddisks(): boolean;
            clearAttacheddisks(): void;
            getAttacheddisks(): string | undefined;
            setAttacheddisks(value: string): ConfigureRequest;

            hasDynamicportforwarding(): boolean;
            clearDynamicportforwarding(): void;
            getDynamicportforwarding(): boolean | undefined;
            setDynamicportforwarding(value: boolean): ConfigureRequest;

            hasSuspendable(): boolean;
            clearSuspendable(): void;
            getSuspendable(): boolean | undefined;
            setSuspendable(value: boolean): ConfigureRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): ConfigureRequest.AsObject;
            static toObject(includeInstance: boolean, msg: ConfigureRequest): ConfigureRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: ConfigureRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): ConfigureRequest;
            static deserializeBinaryFromReader(message: ConfigureRequest, reader: jspb.BinaryReader): ConfigureRequest;
        }

        export namespace ConfigureRequest {
            export type AsObject = {
                name: string,
                cpu?: number,
                memory?: number,
                disksize?: number,
                displayrefit?: boolean,
                autostart?: boolean,
                nested?: boolean,
                mounts?: string,
                networks?: string,
                sockets?: string,
                console?: string,
                randommac?: boolean,
                forwardedport?: string,
                attacheddisks?: string,
                dynamicportforwarding?: boolean,
                suspendable?: boolean,
            }
        }

        export class WaitIPRequest extends jspb.Message { 
            getName(): string;
            setName(value: string): WaitIPRequest;
            getTimeout(): number;
            setTimeout(value: number): WaitIPRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): WaitIPRequest.AsObject;
            static toObject(includeInstance: boolean, msg: WaitIPRequest): WaitIPRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: WaitIPRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): WaitIPRequest;
            static deserializeBinaryFromReader(message: WaitIPRequest, reader: jspb.BinaryReader): WaitIPRequest;
        }

        export namespace WaitIPRequest {
            export type AsObject = {
                name: string,
                timeout: number,
            }
        }

        export class StopRequest extends jspb.Message { 
            getForce(): boolean;
            setForce(value: boolean): StopRequest;

            hasAll(): boolean;
            clearAll(): void;
            getAll(): boolean;
            setAll(value: boolean): StopRequest;

            hasNames(): boolean;
            clearNames(): void;
            getNames(): Caked.VMRequest.StopRequest.VMNames | undefined;
            setNames(value?: Caked.VMRequest.StopRequest.VMNames): StopRequest;

            getStopCase(): StopRequest.StopCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): StopRequest.AsObject;
            static toObject(includeInstance: boolean, msg: StopRequest): StopRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: StopRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): StopRequest;
            static deserializeBinaryFromReader(message: StopRequest, reader: jspb.BinaryReader): StopRequest;
        }

        export namespace StopRequest {
            export type AsObject = {
                force: boolean,
                all: boolean,
                names?: Caked.VMRequest.StopRequest.VMNames.AsObject,
            }


            export class VMNames extends jspb.Message { 
                clearListList(): void;
                getListList(): Array<string>;
                setListList(value: Array<string>): VMNames;
                addList(value: string, index?: number): string;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): VMNames.AsObject;
                static toObject(includeInstance: boolean, msg: VMNames): VMNames.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: VMNames, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): VMNames;
                static deserializeBinaryFromReader(message: VMNames, reader: jspb.BinaryReader): VMNames;
            }

            export namespace VMNames {
                export type AsObject = {
                    listList: Array<string>,
                }
            }


            export enum StopCase {
                STOP_NOT_SET = 0,
                ALL = 2,
                NAMES = 3,
            }

        }

        export class DeleteRequest extends jspb.Message { 

            hasAll(): boolean;
            clearAll(): void;
            getAll(): boolean;
            setAll(value: boolean): DeleteRequest;

            hasNames(): boolean;
            clearNames(): void;
            getNames(): Caked.VMRequest.DeleteRequest.VMNames | undefined;
            setNames(value?: Caked.VMRequest.DeleteRequest.VMNames): DeleteRequest;

            getDeleteCase(): DeleteRequest.DeleteCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): DeleteRequest.AsObject;
            static toObject(includeInstance: boolean, msg: DeleteRequest): DeleteRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: DeleteRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): DeleteRequest;
            static deserializeBinaryFromReader(message: DeleteRequest, reader: jspb.BinaryReader): DeleteRequest;
        }

        export namespace DeleteRequest {
            export type AsObject = {
                all: boolean,
                names?: Caked.VMRequest.DeleteRequest.VMNames.AsObject,
            }


            export class VMNames extends jspb.Message { 
                clearListList(): void;
                getListList(): Array<string>;
                setListList(value: Array<string>): VMNames;
                addList(value: string, index?: number): string;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): VMNames.AsObject;
                static toObject(includeInstance: boolean, msg: VMNames): VMNames.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: VMNames, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): VMNames;
                static deserializeBinaryFromReader(message: VMNames, reader: jspb.BinaryReader): VMNames;
            }

            export namespace VMNames {
                export type AsObject = {
                    listList: Array<string>,
                }
            }


            export enum DeleteCase {
                DELETE_NOT_SET = 0,
                ALL = 2,
                NAMES = 3,
            }

        }

        export class ListRequest extends jspb.Message { 
            getVmonly(): boolean;
            setVmonly(value: boolean): ListRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): ListRequest.AsObject;
            static toObject(includeInstance: boolean, msg: ListRequest): ListRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: ListRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): ListRequest;
            static deserializeBinaryFromReader(message: ListRequest, reader: jspb.BinaryReader): ListRequest;
        }

        export namespace ListRequest {
            export type AsObject = {
                vmonly: boolean,
            }
        }

        export class InfoRequest extends jspb.Message { 
            getName(): string;
            setName(value: string): InfoRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): InfoRequest.AsObject;
            static toObject(includeInstance: boolean, msg: InfoRequest): InfoRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: InfoRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): InfoRequest;
            static deserializeBinaryFromReader(message: InfoRequest, reader: jspb.BinaryReader): InfoRequest;
        }

        export namespace InfoRequest {
            export type AsObject = {
                name: string,
            }
        }

        export class RenameRequest extends jspb.Message { 
            getOldname(): string;
            setOldname(value: string): RenameRequest;
            getNewname(): string;
            setNewname(value: string): RenameRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): RenameRequest.AsObject;
            static toObject(includeInstance: boolean, msg: RenameRequest): RenameRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: RenameRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): RenameRequest;
            static deserializeBinaryFromReader(message: RenameRequest, reader: jspb.BinaryReader): RenameRequest;
        }

        export namespace RenameRequest {
            export type AsObject = {
                oldname: string,
                newname: string,
            }
        }

        export class TemplateRequest extends jspb.Message { 
            getCommand(): Caked.VMRequest.TemplateRequest.TemplateCommand;
            setCommand(value: Caked.VMRequest.TemplateRequest.TemplateCommand): TemplateRequest;

            hasCreaterequest(): boolean;
            clearCreaterequest(): void;
            getCreaterequest(): Caked.VMRequest.TemplateRequest.TemplateRequestAdd | undefined;
            setCreaterequest(value?: Caked.VMRequest.TemplateRequest.TemplateRequestAdd): TemplateRequest;

            hasDeleterequest(): boolean;
            clearDeleterequest(): void;
            getDeleterequest(): string;
            setDeleterequest(value: string): TemplateRequest;

            getTemplateCase(): TemplateRequest.TemplateCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): TemplateRequest.AsObject;
            static toObject(includeInstance: boolean, msg: TemplateRequest): TemplateRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: TemplateRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): TemplateRequest;
            static deserializeBinaryFromReader(message: TemplateRequest, reader: jspb.BinaryReader): TemplateRequest;
        }

        export namespace TemplateRequest {
            export type AsObject = {
                command: Caked.VMRequest.TemplateRequest.TemplateCommand,
                createrequest?: Caked.VMRequest.TemplateRequest.TemplateRequestAdd.AsObject,
                deleterequest: string,
            }


            export class TemplateRequestAdd extends jspb.Message { 
                getSourcename(): string;
                setSourcename(value: string): TemplateRequestAdd;
                getTemplatename(): string;
                setTemplatename(value: string): TemplateRequestAdd;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): TemplateRequestAdd.AsObject;
                static toObject(includeInstance: boolean, msg: TemplateRequestAdd): TemplateRequestAdd.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: TemplateRequestAdd, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): TemplateRequestAdd;
                static deserializeBinaryFromReader(message: TemplateRequestAdd, reader: jspb.BinaryReader): TemplateRequestAdd;
            }

            export namespace TemplateRequestAdd {
                export type AsObject = {
                    sourcename: string,
                    templatename: string,
                }
            }


            export enum TemplateCommand {
    NONE = 0,
    ADD = 1,
    DELETE = 2,
    LIST = 3,
            }


            export enum TemplateCase {
                TEMPLATE_NOT_SET = 0,
                CREATEREQUEST = 2,
                DELETEREQUEST = 3,
            }

        }

        export class RunCommand extends jspb.Message { 
            getVmname(): string;
            setVmname(value: string): RunCommand;
            getCommand(): string;
            setCommand(value: string): RunCommand;
            clearArgsList(): void;
            getArgsList(): Array<string>;
            setArgsList(value: Array<string>): RunCommand;
            addArgs(value: string, index?: number): string;

            hasInput(): boolean;
            clearInput(): void;
            getInput(): Uint8Array | string;
            getInput_asU8(): Uint8Array;
            getInput_asB64(): string;
            setInput(value: Uint8Array | string): RunCommand;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): RunCommand.AsObject;
            static toObject(includeInstance: boolean, msg: RunCommand): RunCommand.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: RunCommand, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): RunCommand;
            static deserializeBinaryFromReader(message: RunCommand, reader: jspb.BinaryReader): RunCommand;
        }

        export namespace RunCommand {
            export type AsObject = {
                vmname: string,
                command: string,
                argsList: Array<string>,
                input: Uint8Array | string,
            }
        }

        export class ExecuteResponse extends jspb.Message { 

            hasExitcode(): boolean;
            clearExitcode(): void;
            getExitcode(): number;
            setExitcode(value: number): ExecuteResponse;

            hasStdout(): boolean;
            clearStdout(): void;
            getStdout(): Uint8Array | string;
            getStdout_asU8(): Uint8Array;
            getStdout_asB64(): string;
            setStdout(value: Uint8Array | string): ExecuteResponse;

            hasStderr(): boolean;
            clearStderr(): void;
            getStderr(): Uint8Array | string;
            getStderr_asU8(): Uint8Array;
            getStderr_asB64(): string;
            setStderr(value: Uint8Array | string): ExecuteResponse;

            hasFailure(): boolean;
            clearFailure(): void;
            getFailure(): string;
            setFailure(value: string): ExecuteResponse;

            hasEstablished(): boolean;
            clearEstablished(): void;
            getEstablished(): boolean;
            setEstablished(value: boolean): ExecuteResponse;

            getResponseCase(): ExecuteResponse.ResponseCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): ExecuteResponse.AsObject;
            static toObject(includeInstance: boolean, msg: ExecuteResponse): ExecuteResponse.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: ExecuteResponse, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): ExecuteResponse;
            static deserializeBinaryFromReader(message: ExecuteResponse, reader: jspb.BinaryReader): ExecuteResponse;
        }

        export namespace ExecuteResponse {
            export type AsObject = {
                exitcode: number,
                stdout: Uint8Array | string,
                stderr: Uint8Array | string,
                failure: string,
                established: boolean,
            }

            export enum ResponseCase {
                RESPONSE_NOT_SET = 0,
                EXITCODE = 1,
                STDOUT = 2,
                STDERR = 3,
                FAILURE = 4,
                ESTABLISHED = 5,
            }

        }

        export class ExecuteRequest extends jspb.Message { 

            hasCommand(): boolean;
            clearCommand(): void;
            getCommand(): Caked.VMRequest.ExecuteRequest.ExecuteCommand | undefined;
            setCommand(value?: Caked.VMRequest.ExecuteRequest.ExecuteCommand): ExecuteRequest;

            hasInput(): boolean;
            clearInput(): void;
            getInput(): Uint8Array | string;
            getInput_asU8(): Uint8Array;
            getInput_asB64(): string;
            setInput(value: Uint8Array | string): ExecuteRequest;

            hasSize(): boolean;
            clearSize(): void;
            getSize(): Caked.VMRequest.ExecuteRequest.TerminalSize | undefined;
            setSize(value?: Caked.VMRequest.ExecuteRequest.TerminalSize): ExecuteRequest;

            hasEof(): boolean;
            clearEof(): void;
            getEof(): boolean;
            setEof(value: boolean): ExecuteRequest;

            getExecuteCase(): ExecuteRequest.ExecuteCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): ExecuteRequest.AsObject;
            static toObject(includeInstance: boolean, msg: ExecuteRequest): ExecuteRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: ExecuteRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): ExecuteRequest;
            static deserializeBinaryFromReader(message: ExecuteRequest, reader: jspb.BinaryReader): ExecuteRequest;
        }

        export namespace ExecuteRequest {
            export type AsObject = {
                command?: Caked.VMRequest.ExecuteRequest.ExecuteCommand.AsObject,
                input: Uint8Array | string,
                size?: Caked.VMRequest.ExecuteRequest.TerminalSize.AsObject,
                eof: boolean,
            }


            export class ExecuteCommand extends jspb.Message { 

                hasCommand(): boolean;
                clearCommand(): void;
                getCommand(): Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command | undefined;
                setCommand(value?: Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command): ExecuteCommand;

                hasShell(): boolean;
                clearShell(): void;
                getShell(): boolean;
                setShell(value: boolean): ExecuteCommand;

                getExecuteCase(): ExecuteCommand.ExecuteCase;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): ExecuteCommand.AsObject;
                static toObject(includeInstance: boolean, msg: ExecuteCommand): ExecuteCommand.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: ExecuteCommand, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): ExecuteCommand;
                static deserializeBinaryFromReader(message: ExecuteCommand, reader: jspb.BinaryReader): ExecuteCommand;
            }

            export namespace ExecuteCommand {
                export type AsObject = {
                    command?: Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command.AsObject,
                    shell: boolean,
                }


                export class Command extends jspb.Message { 
                    getCommand(): string;
                    setCommand(value: string): Command;
                    clearArgsList(): void;
                    getArgsList(): Array<string>;
                    setArgsList(value: Array<string>): Command;
                    addArgs(value: string, index?: number): string;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): Command.AsObject;
                    static toObject(includeInstance: boolean, msg: Command): Command.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: Command, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): Command;
                    static deserializeBinaryFromReader(message: Command, reader: jspb.BinaryReader): Command;
                }

                export namespace Command {
                    export type AsObject = {
                        command: string,
                        argsList: Array<string>,
                    }
                }


                export enum ExecuteCase {
                    EXECUTE_NOT_SET = 0,
                    COMMAND = 1,
                    SHELL = 2,
                }

            }

            export class TerminalSize extends jspb.Message { 
                getRows(): number;
                setRows(value: number): TerminalSize;
                getCols(): number;
                setCols(value: number): TerminalSize;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): TerminalSize.AsObject;
                static toObject(includeInstance: boolean, msg: TerminalSize): TerminalSize.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: TerminalSize, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): TerminalSize;
                static deserializeBinaryFromReader(message: TerminalSize, reader: jspb.BinaryReader): TerminalSize;
            }

            export namespace TerminalSize {
                export type AsObject = {
                    rows: number,
                    cols: number,
                }
            }


            export enum ExecuteCase {
                EXECUTE_NOT_SET = 0,
                COMMAND = 1,
                INPUT = 2,
                SIZE = 3,
                EOF = 4,
            }

        }

    }

    export class Reply extends jspb.Message { 

        hasError(): boolean;
        clearError(): void;
        getError(): Caked.Reply.Error | undefined;
        setError(value?: Caked.Reply.Error): Reply;

        hasVms(): boolean;
        clearVms(): void;
        getVms(): Caked.Reply.VirtualMachineReply | undefined;
        setVms(value?: Caked.Reply.VirtualMachineReply): Reply;

        hasImages(): boolean;
        clearImages(): void;
        getImages(): Caked.Reply.ImageReply | undefined;
        setImages(value?: Caked.Reply.ImageReply): Reply;

        hasNetworks(): boolean;
        clearNetworks(): void;
        getNetworks(): Caked.Reply.NetworksReply | undefined;
        setNetworks(value?: Caked.Reply.NetworksReply): Reply;

        hasRemotes(): boolean;
        clearRemotes(): void;
        getRemotes(): Caked.Reply.RemoteReply | undefined;
        setRemotes(value?: Caked.Reply.RemoteReply): Reply;

        hasTemplates(): boolean;
        clearTemplates(): void;
        getTemplates(): Caked.Reply.TemplateReply | undefined;
        setTemplates(value?: Caked.Reply.TemplateReply): Reply;

        hasRun(): boolean;
        clearRun(): void;
        getRun(): Caked.Reply.RunReply | undefined;
        setRun(value?: Caked.Reply.RunReply): Reply;

        hasMounts(): boolean;
        clearMounts(): void;
        getMounts(): Caked.Reply.MountReply | undefined;
        setMounts(value?: Caked.Reply.MountReply): Reply;

        hasTart(): boolean;
        clearTart(): void;
        getTart(): Caked.Reply.TartReply | undefined;
        setTart(value?: Caked.Reply.TartReply): Reply;

        getResponseCase(): Reply.ResponseCase;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): Reply.AsObject;
        static toObject(includeInstance: boolean, msg: Reply): Reply.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: Reply, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): Reply;
        static deserializeBinaryFromReader(message: Reply, reader: jspb.BinaryReader): Reply;
    }

    export namespace Reply {
        export type AsObject = {
            error?: Caked.Reply.Error.AsObject,
            vms?: Caked.Reply.VirtualMachineReply.AsObject,
            images?: Caked.Reply.ImageReply.AsObject,
            networks?: Caked.Reply.NetworksReply.AsObject,
            remotes?: Caked.Reply.RemoteReply.AsObject,
            templates?: Caked.Reply.TemplateReply.AsObject,
            run?: Caked.Reply.RunReply.AsObject,
            mounts?: Caked.Reply.MountReply.AsObject,
            tart?: Caked.Reply.TartReply.AsObject,
        }


        export class Error extends jspb.Message { 
            getCode(): number;
            setCode(value: number): Error;
            getReason(): string;
            setReason(value: string): Error;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): Error.AsObject;
            static toObject(includeInstance: boolean, msg: Error): Error.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: Error, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): Error;
            static deserializeBinaryFromReader(message: Error, reader: jspb.BinaryReader): Error;
        }

        export namespace Error {
            export type AsObject = {
                code: number,
                reason: string,
            }
        }

        export class VirtualMachineReply extends jspb.Message { 

            hasList(): boolean;
            clearList(): void;
            getList(): Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply | undefined;
            setList(value?: Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply): VirtualMachineReply;

            hasDelete(): boolean;
            clearDelete(): void;
            getDelete(): Caked.Reply.VirtualMachineReply.DeleteReply | undefined;
            setDelete(value?: Caked.Reply.VirtualMachineReply.DeleteReply): VirtualMachineReply;

            hasStop(): boolean;
            clearStop(): void;
            getStop(): Caked.Reply.VirtualMachineReply.StopReply | undefined;
            setStop(value?: Caked.Reply.VirtualMachineReply.StopReply): VirtualMachineReply;

            hasInfos(): boolean;
            clearInfos(): void;
            getInfos(): Caked.Reply.VirtualMachineReply.InfoReply | undefined;
            setInfos(value?: Caked.Reply.VirtualMachineReply.InfoReply): VirtualMachineReply;

            hasMessage(): boolean;
            clearMessage(): void;
            getMessage(): string;
            setMessage(value: string): VirtualMachineReply;

            getResponseCase(): VirtualMachineReply.ResponseCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): VirtualMachineReply.AsObject;
            static toObject(includeInstance: boolean, msg: VirtualMachineReply): VirtualMachineReply.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: VirtualMachineReply, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): VirtualMachineReply;
            static deserializeBinaryFromReader(message: VirtualMachineReply, reader: jspb.BinaryReader): VirtualMachineReply;
        }

        export namespace VirtualMachineReply {
            export type AsObject = {
                list?: Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.AsObject,
                pb_delete?: Caked.Reply.VirtualMachineReply.DeleteReply.AsObject,
                stop?: Caked.Reply.VirtualMachineReply.StopReply.AsObject,
                infos?: Caked.Reply.VirtualMachineReply.InfoReply.AsObject,
                message: string,
            }


            export class VirtualMachineInfoReply extends jspb.Message { 
                clearInfosList(): void;
                getInfosList(): Array<Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo>;
                setInfosList(value: Array<Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo>): VirtualMachineInfoReply;
                addInfos(value?: Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo, index?: number): Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): VirtualMachineInfoReply.AsObject;
                static toObject(includeInstance: boolean, msg: VirtualMachineInfoReply): VirtualMachineInfoReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: VirtualMachineInfoReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): VirtualMachineInfoReply;
                static deserializeBinaryFromReader(message: VirtualMachineInfoReply, reader: jspb.BinaryReader): VirtualMachineInfoReply;
            }

            export namespace VirtualMachineInfoReply {
                export type AsObject = {
                    infosList: Array<Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo.AsObject>,
                }


                export class VirtualMachineInfo extends jspb.Message { 
                    getType(): string;
                    setType(value: string): VirtualMachineInfo;
                    getSource(): string;
                    setSource(value: string): VirtualMachineInfo;
                    getName(): string;
                    setName(value: string): VirtualMachineInfo;
                    clearFqnList(): void;
                    getFqnList(): Array<string>;
                    setFqnList(value: Array<string>): VirtualMachineInfo;
                    addFqn(value: string, index?: number): string;

                    hasInstanceid(): boolean;
                    clearInstanceid(): void;
                    getInstanceid(): string | undefined;
                    setInstanceid(value: string): VirtualMachineInfo;
                    getDisksize(): number;
                    setDisksize(value: number): VirtualMachineInfo;
                    getTotalsize(): number;
                    setTotalsize(value: number): VirtualMachineInfo;
                    getState(): string;
                    setState(value: string): VirtualMachineInfo;

                    hasIp(): boolean;
                    clearIp(): void;
                    getIp(): string | undefined;
                    setIp(value: string): VirtualMachineInfo;

                    hasFingerprint(): boolean;
                    clearFingerprint(): void;
                    getFingerprint(): string | undefined;
                    setFingerprint(value: string): VirtualMachineInfo;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): VirtualMachineInfo.AsObject;
                    static toObject(includeInstance: boolean, msg: VirtualMachineInfo): VirtualMachineInfo.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: VirtualMachineInfo, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): VirtualMachineInfo;
                    static deserializeBinaryFromReader(message: VirtualMachineInfo, reader: jspb.BinaryReader): VirtualMachineInfo;
                }

                export namespace VirtualMachineInfo {
                    export type AsObject = {
                        type: string,
                        source: string,
                        name: string,
                        fqnList: Array<string>,
                        instanceid?: string,
                        disksize: number,
                        totalsize: number,
                        state: string,
                        ip?: string,
                        fingerprint?: string,
                    }
                }

            }

            export class DeleteReply extends jspb.Message { 
                clearObjectsList(): void;
                getObjectsList(): Array<Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject>;
                setObjectsList(value: Array<Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject>): DeleteReply;
                addObjects(value?: Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject, index?: number): Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): DeleteReply.AsObject;
                static toObject(includeInstance: boolean, msg: DeleteReply): DeleteReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: DeleteReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): DeleteReply;
                static deserializeBinaryFromReader(message: DeleteReply, reader: jspb.BinaryReader): DeleteReply;
            }

            export namespace DeleteReply {
                export type AsObject = {
                    objectsList: Array<Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject.AsObject>,
                }


                export class DeletedObject extends jspb.Message { 
                    getSource(): string;
                    setSource(value: string): DeletedObject;
                    getName(): string;
                    setName(value: string): DeletedObject;
                    getDeleted(): boolean;
                    setDeleted(value: boolean): DeletedObject;
                    getReason(): string;
                    setReason(value: string): DeletedObject;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): DeletedObject.AsObject;
                    static toObject(includeInstance: boolean, msg: DeletedObject): DeletedObject.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: DeletedObject, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): DeletedObject;
                    static deserializeBinaryFromReader(message: DeletedObject, reader: jspb.BinaryReader): DeletedObject;
                }

                export namespace DeletedObject {
                    export type AsObject = {
                        source: string,
                        name: string,
                        deleted: boolean,
                        reason: string,
                    }
                }

            }

            export class StopReply extends jspb.Message { 
                clearObjectsList(): void;
                getObjectsList(): Array<Caked.Reply.VirtualMachineReply.StopReply.StoppedObject>;
                setObjectsList(value: Array<Caked.Reply.VirtualMachineReply.StopReply.StoppedObject>): StopReply;
                addObjects(value?: Caked.Reply.VirtualMachineReply.StopReply.StoppedObject, index?: number): Caked.Reply.VirtualMachineReply.StopReply.StoppedObject;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): StopReply.AsObject;
                static toObject(includeInstance: boolean, msg: StopReply): StopReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: StopReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): StopReply;
                static deserializeBinaryFromReader(message: StopReply, reader: jspb.BinaryReader): StopReply;
            }

            export namespace StopReply {
                export type AsObject = {
                    objectsList: Array<Caked.Reply.VirtualMachineReply.StopReply.StoppedObject.AsObject>,
                }


                export class StoppedObject extends jspb.Message { 
                    getName(): string;
                    setName(value: string): StoppedObject;
                    getStatus(): string;
                    setStatus(value: string): StoppedObject;
                    getStopped(): boolean;
                    setStopped(value: boolean): StoppedObject;
                    getReason(): string;
                    setReason(value: string): StoppedObject;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): StoppedObject.AsObject;
                    static toObject(includeInstance: boolean, msg: StoppedObject): StoppedObject.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: StoppedObject, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): StoppedObject;
                    static deserializeBinaryFromReader(message: StoppedObject, reader: jspb.BinaryReader): StoppedObject;
                }

                export namespace StoppedObject {
                    export type AsObject = {
                        name: string,
                        status: string,
                        stopped: boolean,
                        reason: string,
                    }
                }

            }

            export class InfoReply extends jspb.Message { 

                hasVersion(): boolean;
                clearVersion(): void;
                getVersion(): string | undefined;
                setVersion(value: string): InfoReply;

                hasUptime(): boolean;
                clearUptime(): void;
                getUptime(): number | undefined;
                setUptime(value: number): InfoReply;

                hasMemory(): boolean;
                clearMemory(): void;
                getMemory(): Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo | undefined;
                setMemory(value?: Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo): InfoReply;
                getCpucount(): number;
                setCpucount(value: number): InfoReply;
                clearDiskinfosList(): void;
                getDiskinfosList(): Array<Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo>;
                setDiskinfosList(value: Array<Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo>): InfoReply;
                addDiskinfos(value?: Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo, index?: number): Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo;
                clearIpaddressesList(): void;
                getIpaddressesList(): Array<string>;
                setIpaddressesList(value: Array<string>): InfoReply;
                addIpaddresses(value: string, index?: number): string;
                getOsname(): string;
                setOsname(value: string): InfoReply;

                hasHostname(): boolean;
                clearHostname(): void;
                getHostname(): string | undefined;
                setHostname(value: string): InfoReply;

                hasRelease(): boolean;
                clearRelease(): void;
                getRelease(): string | undefined;
                setRelease(value: string): InfoReply;
                getStatus(): string;
                setStatus(value: string): InfoReply;
                clearMountsList(): void;
                getMountsList(): Array<string>;
                setMountsList(value: Array<string>): InfoReply;
                addMounts(value: string, index?: number): string;
                getName(): string;
                setName(value: string): InfoReply;
                clearNetworksList(): void;
                getNetworksList(): Array<Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork>;
                setNetworksList(value: Array<Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork>): InfoReply;
                addNetworks(value?: Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork, index?: number): Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork;
                clearTunnelsList(): void;
                getTunnelsList(): Array<Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo>;
                setTunnelsList(value: Array<Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo>): InfoReply;
                addTunnels(value?: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo, index?: number): Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo;
                clearSocketsList(): void;
                getSocketsList(): Array<Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo>;
                setSocketsList(value: Array<Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo>): InfoReply;
                addSockets(value?: Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo, index?: number): Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): InfoReply.AsObject;
                static toObject(includeInstance: boolean, msg: InfoReply): InfoReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: InfoReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): InfoReply;
                static deserializeBinaryFromReader(message: InfoReply, reader: jspb.BinaryReader): InfoReply;
            }

            export namespace InfoReply {
                export type AsObject = {
                    version?: string,
                    uptime?: number,
                    memory?: Caked.Reply.VirtualMachineReply.InfoReply.MemoryInfo.AsObject,
                    cpucount: number,
                    diskinfosList: Array<Caked.Reply.VirtualMachineReply.InfoReply.DiskInfo.AsObject>,
                    ipaddressesList: Array<string>,
                    osname: string,
                    hostname?: string,
                    release?: string,
                    status: string,
                    mountsList: Array<string>,
                    name: string,
                    networksList: Array<Caked.Reply.VirtualMachineReply.InfoReply.AttachedNetwork.AsObject>,
                    tunnelsList: Array<Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.AsObject>,
                    socketsList: Array<Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.AsObject>,
                }


                export class MemoryInfo extends jspb.Message { 
                    getTotal(): number;
                    setTotal(value: number): MemoryInfo;

                    hasFree(): boolean;
                    clearFree(): void;
                    getFree(): number | undefined;
                    setFree(value: number): MemoryInfo;

                    hasUsed(): boolean;
                    clearUsed(): void;
                    getUsed(): number | undefined;
                    setUsed(value: number): MemoryInfo;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): MemoryInfo.AsObject;
                    static toObject(includeInstance: boolean, msg: MemoryInfo): MemoryInfo.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: MemoryInfo, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): MemoryInfo;
                    static deserializeBinaryFromReader(message: MemoryInfo, reader: jspb.BinaryReader): MemoryInfo;
                }

                export namespace MemoryInfo {
                    export type AsObject = {
                        total: number,
                        free?: number,
                        used?: number,
                    }
                }

                export class DiskInfo extends jspb.Message { 
                    getDevice(): string;
                    setDevice(value: string): DiskInfo;
                    getMount(): string;
                    setMount(value: string): DiskInfo;
                    getFstype(): string;
                    setFstype(value: string): DiskInfo;
                    getSize(): number;
                    setSize(value: number): DiskInfo;
                    getUsed(): number;
                    setUsed(value: number): DiskInfo;
                    getFree(): number;
                    setFree(value: number): DiskInfo;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): DiskInfo.AsObject;
                    static toObject(includeInstance: boolean, msg: DiskInfo): DiskInfo.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: DiskInfo, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): DiskInfo;
                    static deserializeBinaryFromReader(message: DiskInfo, reader: jspb.BinaryReader): DiskInfo;
                }

                export namespace DiskInfo {
                    export type AsObject = {
                        device: string,
                        mount: string,
                        fstype: string,
                        size: number,
                        used: number,
                        free: number,
                    }
                }

                export class AttachedNetwork extends jspb.Message { 
                    getNetwork(): string;
                    setNetwork(value: string): AttachedNetwork;

                    hasMode(): boolean;
                    clearMode(): void;
                    getMode(): string | undefined;
                    setMode(value: string): AttachedNetwork;

                    hasMacaddress(): boolean;
                    clearMacaddress(): void;
                    getMacaddress(): string | undefined;
                    setMacaddress(value: string): AttachedNetwork;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): AttachedNetwork.AsObject;
                    static toObject(includeInstance: boolean, msg: AttachedNetwork): AttachedNetwork.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: AttachedNetwork, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): AttachedNetwork;
                    static deserializeBinaryFromReader(message: AttachedNetwork, reader: jspb.BinaryReader): AttachedNetwork;
                }

                export namespace AttachedNetwork {
                    export type AsObject = {
                        network: string,
                        mode?: string,
                        macaddress?: string,
                    }
                }

                export class TunnelInfo extends jspb.Message { 

                    hasForward(): boolean;
                    clearForward(): void;
                    getForward(): Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort | undefined;
                    setForward(value?: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort): TunnelInfo;

                    hasUnixdomain(): boolean;
                    clearUnixdomain(): void;
                    getUnixdomain(): Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel | undefined;
                    setUnixdomain(value?: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel): TunnelInfo;

                    getTunnelCase(): TunnelInfo.TunnelCase;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): TunnelInfo.AsObject;
                    static toObject(includeInstance: boolean, msg: TunnelInfo): TunnelInfo.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: TunnelInfo, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): TunnelInfo;
                    static deserializeBinaryFromReader(message: TunnelInfo, reader: jspb.BinaryReader): TunnelInfo;
                }

                export namespace TunnelInfo {
                    export type AsObject = {
                        forward?: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.ForwardedPort.AsObject,
                        unixdomain?: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Tunnel.AsObject,
                    }


                    export class ForwardedPort extends jspb.Message { 
                        getProtocol(): Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol;
                        setProtocol(value: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol): ForwardedPort;
                        getHost(): number;
                        setHost(value: number): ForwardedPort;
                        getGuest(): number;
                        setGuest(value: number): ForwardedPort;

                        serializeBinary(): Uint8Array;
                        toObject(includeInstance?: boolean): ForwardedPort.AsObject;
                        static toObject(includeInstance: boolean, msg: ForwardedPort): ForwardedPort.AsObject;
                        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                        static serializeBinaryToWriter(message: ForwardedPort, writer: jspb.BinaryWriter): void;
                        static deserializeBinary(bytes: Uint8Array): ForwardedPort;
                        static deserializeBinaryFromReader(message: ForwardedPort, reader: jspb.BinaryReader): ForwardedPort;
                    }

                    export namespace ForwardedPort {
                        export type AsObject = {
                            protocol: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol,
                            host: number,
                            guest: number,
                        }
                    }

                    export class Tunnel extends jspb.Message { 
                        getProtocol(): Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol;
                        setProtocol(value: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol): Tunnel;
                        getHost(): string;
                        setHost(value: string): Tunnel;
                        getGuest(): string;
                        setGuest(value: string): Tunnel;

                        serializeBinary(): Uint8Array;
                        toObject(includeInstance?: boolean): Tunnel.AsObject;
                        static toObject(includeInstance: boolean, msg: Tunnel): Tunnel.AsObject;
                        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                        static serializeBinaryToWriter(message: Tunnel, writer: jspb.BinaryWriter): void;
                        static deserializeBinary(bytes: Uint8Array): Tunnel;
                        static deserializeBinaryFromReader(message: Tunnel, reader: jspb.BinaryReader): Tunnel;
                    }

                    export namespace Tunnel {
                        export type AsObject = {
                            protocol: Caked.Reply.VirtualMachineReply.InfoReply.TunnelInfo.Protocol,
                            host: string,
                            guest: string,
                        }
                    }


                    export enum Protocol {
    TCP = 0,
    UDP = 1,
                    }


                    export enum TunnelCase {
                        TUNNEL_NOT_SET = 0,
                        FORWARD = 1,
                        UNIXDOMAIN = 2,
                    }

                }

                export class SocketInfo extends jspb.Message { 
                    getMode(): Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode;
                    setMode(value: Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode): SocketInfo;
                    getHost(): string;
                    setHost(value: string): SocketInfo;
                    getPort(): number;
                    setPort(value: number): SocketInfo;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): SocketInfo.AsObject;
                    static toObject(includeInstance: boolean, msg: SocketInfo): SocketInfo.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: SocketInfo, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): SocketInfo;
                    static deserializeBinaryFromReader(message: SocketInfo, reader: jspb.BinaryReader): SocketInfo;
                }

                export namespace SocketInfo {
                    export type AsObject = {
                        mode: Caked.Reply.VirtualMachineReply.InfoReply.SocketInfo.Mode,
                        host: string,
                        port: number,
                    }

                    export enum Mode {
    BIND = 0,
    CONNECT = 1,
    TCP = 2,
    UDP = 3,
                    }

                }

            }


            export enum ResponseCase {
                RESPONSE_NOT_SET = 0,
                LIST = 1,
                DELETE = 2,
                STOP = 3,
                INFOS = 4,
                MESSAGE = 5,
            }

        }

        export class ImageReply extends jspb.Message { 

            hasInfos(): boolean;
            clearInfos(): void;
            getInfos(): Caked.Reply.ImageReply.ImageInfo | undefined;
            setInfos(value?: Caked.Reply.ImageReply.ImageInfo): ImageReply;

            hasPull(): boolean;
            clearPull(): void;
            getPull(): Caked.Reply.ImageReply.PulledImageInfo | undefined;
            setPull(value?: Caked.Reply.ImageReply.PulledImageInfo): ImageReply;

            hasList(): boolean;
            clearList(): void;
            getList(): Caked.Reply.ImageReply.ListImagesInfoReply | undefined;
            setList(value?: Caked.Reply.ImageReply.ListImagesInfoReply): ImageReply;

            getResponseCase(): ImageReply.ResponseCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): ImageReply.AsObject;
            static toObject(includeInstance: boolean, msg: ImageReply): ImageReply.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: ImageReply, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): ImageReply;
            static deserializeBinaryFromReader(message: ImageReply, reader: jspb.BinaryReader): ImageReply;
        }

        export namespace ImageReply {
            export type AsObject = {
                infos?: Caked.Reply.ImageReply.ImageInfo.AsObject,
                pull?: Caked.Reply.ImageReply.PulledImageInfo.AsObject,
                list?: Caked.Reply.ImageReply.ListImagesInfoReply.AsObject,
            }


            export class ListImagesInfoReply extends jspb.Message { 
                clearInfosList(): void;
                getInfosList(): Array<Caked.Reply.ImageReply.ImageInfo>;
                setInfosList(value: Array<Caked.Reply.ImageReply.ImageInfo>): ListImagesInfoReply;
                addInfos(value?: Caked.Reply.ImageReply.ImageInfo, index?: number): Caked.Reply.ImageReply.ImageInfo;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): ListImagesInfoReply.AsObject;
                static toObject(includeInstance: boolean, msg: ListImagesInfoReply): ListImagesInfoReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: ListImagesInfoReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): ListImagesInfoReply;
                static deserializeBinaryFromReader(message: ListImagesInfoReply, reader: jspb.BinaryReader): ListImagesInfoReply;
            }

            export namespace ListImagesInfoReply {
                export type AsObject = {
                    infosList: Array<Caked.Reply.ImageReply.ImageInfo.AsObject>,
                }
            }

            export class ImageInfo extends jspb.Message { 
                clearAliasesList(): void;
                getAliasesList(): Array<string>;
                setAliasesList(value: Array<string>): ImageInfo;
                addAliases(value: string, index?: number): string;
                getArchitecture(): string;
                setArchitecture(value: string): ImageInfo;
                getPub(): boolean;
                setPub(value: boolean): ImageInfo;
                getFilename(): string;
                setFilename(value: string): ImageInfo;
                getFingerprint(): string;
                setFingerprint(value: string): ImageInfo;
                getSize(): number;
                setSize(value: number): ImageInfo;
                getType(): string;
                setType(value: string): ImageInfo;

                hasCreated(): boolean;
                clearCreated(): void;
                getCreated(): string | undefined;
                setCreated(value: string): ImageInfo;

                hasExpires(): boolean;
                clearExpires(): void;
                getExpires(): string | undefined;
                setExpires(value: string): ImageInfo;

                hasUploaded(): boolean;
                clearUploaded(): void;
                getUploaded(): string | undefined;
                setUploaded(value: string): ImageInfo;

                getPropertiesMap(): jspb.Map<string, string>;
                clearPropertiesMap(): void;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): ImageInfo.AsObject;
                static toObject(includeInstance: boolean, msg: ImageInfo): ImageInfo.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: ImageInfo, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): ImageInfo;
                static deserializeBinaryFromReader(message: ImageInfo, reader: jspb.BinaryReader): ImageInfo;
            }

            export namespace ImageInfo {
                export type AsObject = {
                    aliasesList: Array<string>,
                    architecture: string,
                    pub: boolean,
                    filename: string,
                    fingerprint: string,
                    size: number,
                    type: string,
                    created?: string,
                    expires?: string,
                    uploaded?: string,

                    propertiesMap: Array<[string, string]>,
                }
            }

            export class PulledImageInfo extends jspb.Message { 

                hasAlias(): boolean;
                clearAlias(): void;
                getAlias(): string | undefined;
                setAlias(value: string): PulledImageInfo;
                getPath(): string;
                setPath(value: string): PulledImageInfo;
                getSize(): number;
                setSize(value: number): PulledImageInfo;
                getFingerprint(): string;
                setFingerprint(value: string): PulledImageInfo;
                getRemotename(): string;
                setRemotename(value: string): PulledImageInfo;
                getDescription(): string;
                setDescription(value: string): PulledImageInfo;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): PulledImageInfo.AsObject;
                static toObject(includeInstance: boolean, msg: PulledImageInfo): PulledImageInfo.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: PulledImageInfo, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): PulledImageInfo;
                static deserializeBinaryFromReader(message: PulledImageInfo, reader: jspb.BinaryReader): PulledImageInfo;
            }

            export namespace PulledImageInfo {
                export type AsObject = {
                    alias?: string,
                    path: string,
                    size: number,
                    fingerprint: string,
                    remotename: string,
                    description: string,
                }
            }


            export enum ResponseCase {
                RESPONSE_NOT_SET = 0,
                INFOS = 1,
                PULL = 2,
                LIST = 3,
            }

        }

        export class NetworksReply extends jspb.Message { 

            hasList(): boolean;
            clearList(): void;
            getList(): Caked.Reply.NetworksReply.ListNetworksReply | undefined;
            setList(value?: Caked.Reply.NetworksReply.ListNetworksReply): NetworksReply;

            hasStatus(): boolean;
            clearStatus(): void;
            getStatus(): Caked.Reply.NetworksReply.NetworkInfo | undefined;
            setStatus(value?: Caked.Reply.NetworksReply.NetworkInfo): NetworksReply;

            hasMessage(): boolean;
            clearMessage(): void;
            getMessage(): string;
            setMessage(value: string): NetworksReply;

            getResponseCase(): NetworksReply.ResponseCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): NetworksReply.AsObject;
            static toObject(includeInstance: boolean, msg: NetworksReply): NetworksReply.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: NetworksReply, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): NetworksReply;
            static deserializeBinaryFromReader(message: NetworksReply, reader: jspb.BinaryReader): NetworksReply;
        }

        export namespace NetworksReply {
            export type AsObject = {
                list?: Caked.Reply.NetworksReply.ListNetworksReply.AsObject,
                status?: Caked.Reply.NetworksReply.NetworkInfo.AsObject,
                message: string,
            }


            export class NetworkInfo extends jspb.Message { 
                getName(): string;
                setName(value: string): NetworkInfo;
                getMode(): string;
                setMode(value: string): NetworkInfo;
                getDescription(): string;
                setDescription(value: string): NetworkInfo;
                getGateway(): string;
                setGateway(value: string): NetworkInfo;
                getDhcpend(): string;
                setDhcpend(value: string): NetworkInfo;
                getNetmask(): string;
                setNetmask(value: string): NetworkInfo;
                getInterfaceid(): string;
                setInterfaceid(value: string): NetworkInfo;
                getEndpoint(): string;
                setEndpoint(value: string): NetworkInfo;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): NetworkInfo.AsObject;
                static toObject(includeInstance: boolean, msg: NetworkInfo): NetworkInfo.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: NetworkInfo, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): NetworkInfo;
                static deserializeBinaryFromReader(message: NetworkInfo, reader: jspb.BinaryReader): NetworkInfo;
            }

            export namespace NetworkInfo {
                export type AsObject = {
                    name: string,
                    mode: string,
                    description: string,
                    gateway: string,
                    dhcpend: string,
                    netmask: string,
                    interfaceid: string,
                    endpoint: string,
                }
            }

            export class ListNetworksReply extends jspb.Message { 
                clearNetworksList(): void;
                getNetworksList(): Array<Caked.Reply.NetworksReply.NetworkInfo>;
                setNetworksList(value: Array<Caked.Reply.NetworksReply.NetworkInfo>): ListNetworksReply;
                addNetworks(value?: Caked.Reply.NetworksReply.NetworkInfo, index?: number): Caked.Reply.NetworksReply.NetworkInfo;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): ListNetworksReply.AsObject;
                static toObject(includeInstance: boolean, msg: ListNetworksReply): ListNetworksReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: ListNetworksReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): ListNetworksReply;
                static deserializeBinaryFromReader(message: ListNetworksReply, reader: jspb.BinaryReader): ListNetworksReply;
            }

            export namespace ListNetworksReply {
                export type AsObject = {
                    networksList: Array<Caked.Reply.NetworksReply.NetworkInfo.AsObject>,
                }
            }


            export enum ResponseCase {
                RESPONSE_NOT_SET = 0,
                LIST = 1,
                STATUS = 2,
                MESSAGE = 3,
            }

        }

        export class RemoteReply extends jspb.Message { 

            hasList(): boolean;
            clearList(): void;
            getList(): Caked.Reply.RemoteReply.ListRemoteReply | undefined;
            setList(value?: Caked.Reply.RemoteReply.ListRemoteReply): RemoteReply;

            hasMessage(): boolean;
            clearMessage(): void;
            getMessage(): string;
            setMessage(value: string): RemoteReply;

            getResponseCase(): RemoteReply.ResponseCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): RemoteReply.AsObject;
            static toObject(includeInstance: boolean, msg: RemoteReply): RemoteReply.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: RemoteReply, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): RemoteReply;
            static deserializeBinaryFromReader(message: RemoteReply, reader: jspb.BinaryReader): RemoteReply;
        }

        export namespace RemoteReply {
            export type AsObject = {
                list?: Caked.Reply.RemoteReply.ListRemoteReply.AsObject,
                message: string,
            }


            export class ListRemoteReply extends jspb.Message { 
                clearRemotesList(): void;
                getRemotesList(): Array<Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry>;
                setRemotesList(value: Array<Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry>): ListRemoteReply;
                addRemotes(value?: Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry, index?: number): Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): ListRemoteReply.AsObject;
                static toObject(includeInstance: boolean, msg: ListRemoteReply): ListRemoteReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: ListRemoteReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): ListRemoteReply;
                static deserializeBinaryFromReader(message: ListRemoteReply, reader: jspb.BinaryReader): ListRemoteReply;
            }

            export namespace ListRemoteReply {
                export type AsObject = {
                    remotesList: Array<Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry.AsObject>,
                }


                export class RemoteEntry extends jspb.Message { 
                    getName(): string;
                    setName(value: string): RemoteEntry;
                    getUrl(): string;
                    setUrl(value: string): RemoteEntry;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): RemoteEntry.AsObject;
                    static toObject(includeInstance: boolean, msg: RemoteEntry): RemoteEntry.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: RemoteEntry, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): RemoteEntry;
                    static deserializeBinaryFromReader(message: RemoteEntry, reader: jspb.BinaryReader): RemoteEntry;
                }

                export namespace RemoteEntry {
                    export type AsObject = {
                        name: string,
                        url: string,
                    }
                }

            }


            export enum ResponseCase {
                RESPONSE_NOT_SET = 0,
                LIST = 1,
                MESSAGE = 2,
            }

        }

        export class TemplateReply extends jspb.Message { 

            hasList(): boolean;
            clearList(): void;
            getList(): Caked.Reply.TemplateReply.ListTemplatesReply | undefined;
            setList(value?: Caked.Reply.TemplateReply.ListTemplatesReply): TemplateReply;

            hasCreate(): boolean;
            clearCreate(): void;
            getCreate(): Caked.Reply.TemplateReply.CreateTemplateReply | undefined;
            setCreate(value?: Caked.Reply.TemplateReply.CreateTemplateReply): TemplateReply;

            hasDelete(): boolean;
            clearDelete(): void;
            getDelete(): Caked.Reply.TemplateReply.DeleteTemplateReply | undefined;
            setDelete(value?: Caked.Reply.TemplateReply.DeleteTemplateReply): TemplateReply;

            getResponseCase(): TemplateReply.ResponseCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): TemplateReply.AsObject;
            static toObject(includeInstance: boolean, msg: TemplateReply): TemplateReply.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: TemplateReply, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): TemplateReply;
            static deserializeBinaryFromReader(message: TemplateReply, reader: jspb.BinaryReader): TemplateReply;
        }

        export namespace TemplateReply {
            export type AsObject = {
                list?: Caked.Reply.TemplateReply.ListTemplatesReply.AsObject,
                create?: Caked.Reply.TemplateReply.CreateTemplateReply.AsObject,
                pb_delete?: Caked.Reply.TemplateReply.DeleteTemplateReply.AsObject,
            }


            export class ListTemplatesReply extends jspb.Message { 
                clearTemplatesList(): void;
                getTemplatesList(): Array<Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry>;
                setTemplatesList(value: Array<Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry>): ListTemplatesReply;
                addTemplates(value?: Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry, index?: number): Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): ListTemplatesReply.AsObject;
                static toObject(includeInstance: boolean, msg: ListTemplatesReply): ListTemplatesReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: ListTemplatesReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): ListTemplatesReply;
                static deserializeBinaryFromReader(message: ListTemplatesReply, reader: jspb.BinaryReader): ListTemplatesReply;
            }

            export namespace ListTemplatesReply {
                export type AsObject = {
                    templatesList: Array<Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry.AsObject>,
                }


                export class TemplateEntry extends jspb.Message { 
                    getName(): string;
                    setName(value: string): TemplateEntry;
                    getFqn(): string;
                    setFqn(value: string): TemplateEntry;
                    getDisksize(): number;
                    setDisksize(value: number): TemplateEntry;
                    getTotalsize(): number;
                    setTotalsize(value: number): TemplateEntry;

                    serializeBinary(): Uint8Array;
                    toObject(includeInstance?: boolean): TemplateEntry.AsObject;
                    static toObject(includeInstance: boolean, msg: TemplateEntry): TemplateEntry.AsObject;
                    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                    static serializeBinaryToWriter(message: TemplateEntry, writer: jspb.BinaryWriter): void;
                    static deserializeBinary(bytes: Uint8Array): TemplateEntry;
                    static deserializeBinaryFromReader(message: TemplateEntry, reader: jspb.BinaryReader): TemplateEntry;
                }

                export namespace TemplateEntry {
                    export type AsObject = {
                        name: string,
                        fqn: string,
                        disksize: number,
                        totalsize: number,
                    }
                }

            }

            export class CreateTemplateReply extends jspb.Message { 
                getName(): string;
                setName(value: string): CreateTemplateReply;
                getCreated(): boolean;
                setCreated(value: boolean): CreateTemplateReply;

                hasReason(): boolean;
                clearReason(): void;
                getReason(): string | undefined;
                setReason(value: string): CreateTemplateReply;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): CreateTemplateReply.AsObject;
                static toObject(includeInstance: boolean, msg: CreateTemplateReply): CreateTemplateReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: CreateTemplateReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): CreateTemplateReply;
                static deserializeBinaryFromReader(message: CreateTemplateReply, reader: jspb.BinaryReader): CreateTemplateReply;
            }

            export namespace CreateTemplateReply {
                export type AsObject = {
                    name: string,
                    created: boolean,
                    reason?: string,
                }
            }

            export class DeleteTemplateReply extends jspb.Message { 
                getName(): string;
                setName(value: string): DeleteTemplateReply;
                getDeleted(): boolean;
                setDeleted(value: boolean): DeleteTemplateReply;

                hasReason(): boolean;
                clearReason(): void;
                getReason(): string | undefined;
                setReason(value: string): DeleteTemplateReply;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): DeleteTemplateReply.AsObject;
                static toObject(includeInstance: boolean, msg: DeleteTemplateReply): DeleteTemplateReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: DeleteTemplateReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): DeleteTemplateReply;
                static deserializeBinaryFromReader(message: DeleteTemplateReply, reader: jspb.BinaryReader): DeleteTemplateReply;
            }

            export namespace DeleteTemplateReply {
                export type AsObject = {
                    name: string,
                    deleted: boolean,
                    reason?: string,
                }
            }


            export enum ResponseCase {
                RESPONSE_NOT_SET = 0,
                LIST = 1,
                CREATE = 2,
                DELETE = 3,
            }

        }

        export class RunReply extends jspb.Message { 
            getExitcode(): number;
            setExitcode(value: number): RunReply;
            getStdout(): Uint8Array | string;
            getStdout_asU8(): Uint8Array;
            getStdout_asB64(): string;
            setStdout(value: Uint8Array | string): RunReply;
            getStderr(): Uint8Array | string;
            getStderr_asU8(): Uint8Array;
            getStderr_asB64(): string;
            setStderr(value: Uint8Array | string): RunReply;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): RunReply.AsObject;
            static toObject(includeInstance: boolean, msg: RunReply): RunReply.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: RunReply, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): RunReply;
            static deserializeBinaryFromReader(message: RunReply, reader: jspb.BinaryReader): RunReply;
        }

        export namespace RunReply {
            export type AsObject = {
                exitcode: number,
                stdout: Uint8Array | string,
                stderr: Uint8Array | string,
            }
        }

        export class MountReply extends jspb.Message { 
            clearMountsList(): void;
            getMountsList(): Array<Caked.Reply.MountReply.MountVirtioFSReply>;
            setMountsList(value: Array<Caked.Reply.MountReply.MountVirtioFSReply>): MountReply;
            addMounts(value?: Caked.Reply.MountReply.MountVirtioFSReply, index?: number): Caked.Reply.MountReply.MountVirtioFSReply;

            hasError(): boolean;
            clearError(): void;
            getError(): string;
            setError(value: string): MountReply;

            hasSuccess(): boolean;
            clearSuccess(): void;
            getSuccess(): boolean;
            setSuccess(value: boolean): MountReply;

            getResponseCase(): MountReply.ResponseCase;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): MountReply.AsObject;
            static toObject(includeInstance: boolean, msg: MountReply): MountReply.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: MountReply, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): MountReply;
            static deserializeBinaryFromReader(message: MountReply, reader: jspb.BinaryReader): MountReply;
        }

        export namespace MountReply {
            export type AsObject = {
                mountsList: Array<Caked.Reply.MountReply.MountVirtioFSReply.AsObject>,
                error: string,
                success: boolean,
            }


            export class MountVirtioFSReply extends jspb.Message { 
                getName(): string;
                setName(value: string): MountVirtioFSReply;
                getPath(): string;
                setPath(value: string): MountVirtioFSReply;

                hasError(): boolean;
                clearError(): void;
                getError(): string;
                setError(value: string): MountVirtioFSReply;

                hasSuccess(): boolean;
                clearSuccess(): void;
                getSuccess(): boolean;
                setSuccess(value: boolean): MountVirtioFSReply;

                getResponseCase(): MountVirtioFSReply.ResponseCase;

                serializeBinary(): Uint8Array;
                toObject(includeInstance?: boolean): MountVirtioFSReply.AsObject;
                static toObject(includeInstance: boolean, msg: MountVirtioFSReply): MountVirtioFSReply.AsObject;
                static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
                static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
                static serializeBinaryToWriter(message: MountVirtioFSReply, writer: jspb.BinaryWriter): void;
                static deserializeBinary(bytes: Uint8Array): MountVirtioFSReply;
                static deserializeBinaryFromReader(message: MountVirtioFSReply, reader: jspb.BinaryReader): MountVirtioFSReply;
            }

            export namespace MountVirtioFSReply {
                export type AsObject = {
                    name: string,
                    path: string,
                    error: string,
                    success: boolean,
                }

                export enum ResponseCase {
                    RESPONSE_NOT_SET = 0,
                    ERROR = 3,
                    SUCCESS = 4,
                }

            }


            export enum ResponseCase {
                RESPONSE_NOT_SET = 0,
                ERROR = 2,
                SUCCESS = 3,
            }

        }

        export class TartReply extends jspb.Message { 
            getMessage(): string;
            setMessage(value: string): TartReply;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): TartReply.AsObject;
            static toObject(includeInstance: boolean, msg: TartReply): TartReply.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: TartReply, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): TartReply;
            static deserializeBinaryFromReader(message: TartReply, reader: jspb.BinaryReader): TartReply;
        }

        export namespace TartReply {
            export type AsObject = {
                message: string,
            }
        }


        export enum ResponseCase {
            RESPONSE_NOT_SET = 0,
            ERROR = 1,
            VMS = 3,
            IMAGES = 4,
            NETWORKS = 5,
            REMOTES = 6,
            TEMPLATES = 7,
            RUN = 8,
            MOUNTS = 9,
            TART = 10,
        }

    }

    export class NetworkRequest extends jspb.Message { 
        getCommand(): Caked.NetworkRequest.NetworkCommand;
        setCommand(value: Caked.NetworkRequest.NetworkCommand): NetworkRequest;

        hasName(): boolean;
        clearName(): void;
        getName(): string;
        setName(value: string): NetworkRequest;

        hasCreate(): boolean;
        clearCreate(): void;
        getCreate(): Caked.NetworkRequest.CreateNetworkRequest | undefined;
        setCreate(value?: Caked.NetworkRequest.CreateNetworkRequest): NetworkRequest;

        hasConfigure(): boolean;
        clearConfigure(): void;
        getConfigure(): Caked.NetworkRequest.ConfigureNetworkRequest | undefined;
        setConfigure(value?: Caked.NetworkRequest.ConfigureNetworkRequest): NetworkRequest;

        getNetworkCase(): NetworkRequest.NetworkCase;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): NetworkRequest.AsObject;
        static toObject(includeInstance: boolean, msg: NetworkRequest): NetworkRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: NetworkRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): NetworkRequest;
        static deserializeBinaryFromReader(message: NetworkRequest, reader: jspb.BinaryReader): NetworkRequest;
    }

    export namespace NetworkRequest {
        export type AsObject = {
            command: Caked.NetworkRequest.NetworkCommand,
            name: string,
            create?: Caked.NetworkRequest.CreateNetworkRequest.AsObject,
            configure?: Caked.NetworkRequest.ConfigureNetworkRequest.AsObject,
        }


        export class ConfigureNetworkRequest extends jspb.Message { 
            getName(): string;
            setName(value: string): ConfigureNetworkRequest;

            hasGateway(): boolean;
            clearGateway(): void;
            getGateway(): string | undefined;
            setGateway(value: string): ConfigureNetworkRequest;

            hasDhcpend(): boolean;
            clearDhcpend(): void;
            getDhcpend(): string | undefined;
            setDhcpend(value: string): ConfigureNetworkRequest;

            hasNetmask(): boolean;
            clearNetmask(): void;
            getNetmask(): string | undefined;
            setNetmask(value: string): ConfigureNetworkRequest;

            hasUuid(): boolean;
            clearUuid(): void;
            getUuid(): string | undefined;
            setUuid(value: string): ConfigureNetworkRequest;

            hasNat66prefix(): boolean;
            clearNat66prefix(): void;
            getNat66prefix(): string | undefined;
            setNat66prefix(value: string): ConfigureNetworkRequest;

            hasDhcplease(): boolean;
            clearDhcplease(): void;
            getDhcplease(): number | undefined;
            setDhcplease(value: number): ConfigureNetworkRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): ConfigureNetworkRequest.AsObject;
            static toObject(includeInstance: boolean, msg: ConfigureNetworkRequest): ConfigureNetworkRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: ConfigureNetworkRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): ConfigureNetworkRequest;
            static deserializeBinaryFromReader(message: ConfigureNetworkRequest, reader: jspb.BinaryReader): ConfigureNetworkRequest;
        }

        export namespace ConfigureNetworkRequest {
            export type AsObject = {
                name: string,
                gateway?: string,
                dhcpend?: string,
                netmask?: string,
                uuid?: string,
                nat66prefix?: string,
                dhcplease?: number,
            }
        }

        export class CreateNetworkRequest extends jspb.Message { 
            getMode(): Caked.NetworkRequest.NetworkMode;
            setMode(value: Caked.NetworkRequest.NetworkMode): CreateNetworkRequest;
            getName(): string;
            setName(value: string): CreateNetworkRequest;
            getGateway(): string;
            setGateway(value: string): CreateNetworkRequest;
            getDhcpend(): string;
            setDhcpend(value: string): CreateNetworkRequest;
            getNetmask(): string;
            setNetmask(value: string): CreateNetworkRequest;

            hasUuid(): boolean;
            clearUuid(): void;
            getUuid(): string | undefined;
            setUuid(value: string): CreateNetworkRequest;

            hasNat66prefix(): boolean;
            clearNat66prefix(): void;
            getNat66prefix(): string | undefined;
            setNat66prefix(value: string): CreateNetworkRequest;

            hasDhcplease(): boolean;
            clearDhcplease(): void;
            getDhcplease(): number | undefined;
            setDhcplease(value: number): CreateNetworkRequest;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): CreateNetworkRequest.AsObject;
            static toObject(includeInstance: boolean, msg: CreateNetworkRequest): CreateNetworkRequest.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: CreateNetworkRequest, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): CreateNetworkRequest;
            static deserializeBinaryFromReader(message: CreateNetworkRequest, reader: jspb.BinaryReader): CreateNetworkRequest;
        }

        export namespace CreateNetworkRequest {
            export type AsObject = {
                mode: Caked.NetworkRequest.NetworkMode,
                name: string,
                gateway: string,
                dhcpend: string,
                netmask: string,
                uuid?: string,
                nat66prefix?: string,
                dhcplease?: number,
            }
        }


        export enum NetworkMode {
    SHARED = 0,
    HOST = 1,
        }

        export enum NetworkCommand {
    INFOS = 0,
    NEW = 1,
    SET = 2,
    START = 3,
    SHUTDOWN = 4,
    REMOVE = 5,
    STATUS = 6,
        }


        export enum NetworkCase {
            NETWORK_NOT_SET = 0,
            NAME = 2,
            CREATE = 3,
            CONFIGURE = 4,
        }

    }

    export class ImageRequest extends jspb.Message { 
        getCommand(): Caked.ImageRequest.ImageCommand;
        setCommand(value: Caked.ImageRequest.ImageCommand): ImageRequest;
        getName(): string;
        setName(value: string): ImageRequest;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): ImageRequest.AsObject;
        static toObject(includeInstance: boolean, msg: ImageRequest): ImageRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: ImageRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): ImageRequest;
        static deserializeBinaryFromReader(message: ImageRequest, reader: jspb.BinaryReader): ImageRequest;
    }

    export namespace ImageRequest {
        export type AsObject = {
            command: Caked.ImageRequest.ImageCommand,
            name: string,
        }

        export enum ImageCommand {
    NONE = 0,
    INFO = 1,
    PULL = 2,
    LIST = 3,
        }

    }

    export class RemoteRequest extends jspb.Message { 
        getCommand(): Caked.RemoteRequest.RemoteCommand;
        setCommand(value: Caked.RemoteRequest.RemoteCommand): RemoteRequest;

        hasAddrequest(): boolean;
        clearAddrequest(): void;
        getAddrequest(): Caked.RemoteRequest.RemoteRequestAdd | undefined;
        setAddrequest(value?: Caked.RemoteRequest.RemoteRequestAdd): RemoteRequest;

        hasDeleterequest(): boolean;
        clearDeleterequest(): void;
        getDeleterequest(): string;
        setDeleterequest(value: string): RemoteRequest;

        getRemoteCase(): RemoteRequest.RemoteCase;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): RemoteRequest.AsObject;
        static toObject(includeInstance: boolean, msg: RemoteRequest): RemoteRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: RemoteRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): RemoteRequest;
        static deserializeBinaryFromReader(message: RemoteRequest, reader: jspb.BinaryReader): RemoteRequest;
    }

    export namespace RemoteRequest {
        export type AsObject = {
            command: Caked.RemoteRequest.RemoteCommand,
            addrequest?: Caked.RemoteRequest.RemoteRequestAdd.AsObject,
            deleterequest: string,
        }


        export class RemoteRequestAdd extends jspb.Message { 
            getName(): string;
            setName(value: string): RemoteRequestAdd;
            getUrl(): string;
            setUrl(value: string): RemoteRequestAdd;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): RemoteRequestAdd.AsObject;
            static toObject(includeInstance: boolean, msg: RemoteRequestAdd): RemoteRequestAdd.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: RemoteRequestAdd, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): RemoteRequestAdd;
            static deserializeBinaryFromReader(message: RemoteRequestAdd, reader: jspb.BinaryReader): RemoteRequestAdd;
        }

        export namespace RemoteRequestAdd {
            export type AsObject = {
                name: string,
                url: string,
            }
        }


        export enum RemoteCommand {
    NONE = 0,
    LIST = 1,
    ADD = 2,
    DELETE = 3,
        }


        export enum RemoteCase {
            REMOTE_NOT_SET = 0,
            ADDREQUEST = 2,
            DELETEREQUEST = 3,
        }

    }

    export class CakedCommandRequest extends jspb.Message { 
        getCommand(): string;
        setCommand(value: string): CakedCommandRequest;
        clearArgumentsList(): void;
        getArgumentsList(): Array<string>;
        setArgumentsList(value: Array<string>): CakedCommandRequest;
        addArguments(value: string, index?: number): string;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): CakedCommandRequest.AsObject;
        static toObject(includeInstance: boolean, msg: CakedCommandRequest): CakedCommandRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: CakedCommandRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): CakedCommandRequest;
        static deserializeBinaryFromReader(message: CakedCommandRequest, reader: jspb.BinaryReader): CakedCommandRequest;
    }

    export namespace CakedCommandRequest {
        export type AsObject = {
            command: string,
            argumentsList: Array<string>,
        }
    }

    export class PurgeRequest extends jspb.Message { 

        hasEntries(): boolean;
        clearEntries(): void;
        getEntries(): string | undefined;
        setEntries(value: string): PurgeRequest;

        hasOlderthan(): boolean;
        clearOlderthan(): void;
        getOlderthan(): number | undefined;
        setOlderthan(value: number): PurgeRequest;

        hasSpacebudget(): boolean;
        clearSpacebudget(): void;
        getSpacebudget(): number | undefined;
        setSpacebudget(value: number): PurgeRequest;

        hasGc(): boolean;
        clearGc(): void;
        getGc(): boolean | undefined;
        setGc(value: boolean): PurgeRequest;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): PurgeRequest.AsObject;
        static toObject(includeInstance: boolean, msg: PurgeRequest): PurgeRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: PurgeRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): PurgeRequest;
        static deserializeBinaryFromReader(message: PurgeRequest, reader: jspb.BinaryReader): PurgeRequest;
    }

    export namespace PurgeRequest {
        export type AsObject = {
            entries?: string,
            olderthan?: number,
            spacebudget?: number,
            gc?: boolean,
        }
    }

    export class LogoutRequest extends jspb.Message { 
        getHost(): string;
        setHost(value: string): LogoutRequest;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): LogoutRequest.AsObject;
        static toObject(includeInstance: boolean, msg: LogoutRequest): LogoutRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: LogoutRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): LogoutRequest;
        static deserializeBinaryFromReader(message: LogoutRequest, reader: jspb.BinaryReader): LogoutRequest;
    }

    export namespace LogoutRequest {
        export type AsObject = {
            host: string,
        }
    }

    export class LoginRequest extends jspb.Message { 
        getHost(): string;
        setHost(value: string): LoginRequest;
        getUsername(): string;
        setUsername(value: string): LoginRequest;
        getPassword(): string;
        setPassword(value: string): LoginRequest;
        getInsecure(): boolean;
        setInsecure(value: boolean): LoginRequest;
        getNovalidate(): boolean;
        setNovalidate(value: boolean): LoginRequest;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): LoginRequest.AsObject;
        static toObject(includeInstance: boolean, msg: LoginRequest): LoginRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: LoginRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): LoginRequest;
        static deserializeBinaryFromReader(message: LoginRequest, reader: jspb.BinaryReader): LoginRequest;
    }

    export namespace LoginRequest {
        export type AsObject = {
            host: string,
            username: string,
            password: string,
            insecure: boolean,
            novalidate: boolean,
        }
    }

    export class MountRequest extends jspb.Message { 
        getCommand(): Caked.MountRequest.MountCommand;
        setCommand(value: Caked.MountRequest.MountCommand): MountRequest;
        getName(): string;
        setName(value: string): MountRequest;
        clearMountsList(): void;
        getMountsList(): Array<Caked.MountRequest.MountVirtioFS>;
        setMountsList(value: Array<Caked.MountRequest.MountVirtioFS>): MountRequest;
        addMounts(value?: Caked.MountRequest.MountVirtioFS, index?: number): Caked.MountRequest.MountVirtioFS;

        serializeBinary(): Uint8Array;
        toObject(includeInstance?: boolean): MountRequest.AsObject;
        static toObject(includeInstance: boolean, msg: MountRequest): MountRequest.AsObject;
        static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
        static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
        static serializeBinaryToWriter(message: MountRequest, writer: jspb.BinaryWriter): void;
        static deserializeBinary(bytes: Uint8Array): MountRequest;
        static deserializeBinaryFromReader(message: MountRequest, reader: jspb.BinaryReader): MountRequest;
    }

    export namespace MountRequest {
        export type AsObject = {
            command: Caked.MountRequest.MountCommand,
            name: string,
            mountsList: Array<Caked.MountRequest.MountVirtioFS.AsObject>,
        }


        export class MountVirtioFS extends jspb.Message { 
            getSource(): string;
            setSource(value: string): MountVirtioFS;

            hasTarget(): boolean;
            clearTarget(): void;
            getTarget(): string | undefined;
            setTarget(value: string): MountVirtioFS;

            hasName(): boolean;
            clearName(): void;
            getName(): string | undefined;
            setName(value: string): MountVirtioFS;

            hasUid(): boolean;
            clearUid(): void;
            getUid(): number | undefined;
            setUid(value: number): MountVirtioFS;

            hasGid(): boolean;
            clearGid(): void;
            getGid(): number | undefined;
            setGid(value: number): MountVirtioFS;
            getReadonly(): boolean;
            setReadonly(value: boolean): MountVirtioFS;

            serializeBinary(): Uint8Array;
            toObject(includeInstance?: boolean): MountVirtioFS.AsObject;
            static toObject(includeInstance: boolean, msg: MountVirtioFS): MountVirtioFS.AsObject;
            static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
            static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
            static serializeBinaryToWriter(message: MountVirtioFS, writer: jspb.BinaryWriter): void;
            static deserializeBinary(bytes: Uint8Array): MountVirtioFS;
            static deserializeBinaryFromReader(message: MountVirtioFS, reader: jspb.BinaryReader): MountVirtioFS;
        }

        export namespace MountVirtioFS {
            export type AsObject = {
                source: string,
                target?: string,
                name?: string,
                uid?: number,
                gid?: number,
                readonly: boolean,
            }
        }


        export enum MountCommand {
    NONE = 0,
    MOUNT = 1,
    UMOUNT = 2,
        }

    }

}
