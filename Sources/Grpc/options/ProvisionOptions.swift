//
//  ProvisionOptions.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/08/2026.
//
import Foundation
import ArgumentParser

public struct ProvisionOptions: ParsableArguments {
	private static let cakedRunning: Bool = (ProcessInfo.processInfo.processName == "caked")
	
	public static let configuration = CommandConfiguration(commandName: "provision",
														   abstract: String(localized: "Drive a macOS or Linux VM's Setup Assistant unattended via PackerLite"),
														   discussion: String(localized: "Re-runs the same unattended Setup Assistant automation that `build`/`create` drive automatically for .ipsw or .iso sources with --autoinstall — for a VM that skipped it at build time. Uses the VM's stored macOS version and account credentials; fails if the VM is currently running, or has already been provisioned."))
	
	@Flag(help: ArgumentHelp(String(localized: "Launch vm in foreground"), discussion: String(localized: "This option allows display window of running vm to debug it")))
	public var foreground: Bool = false
	
	@Option(help: ArgumentHelp(String(localized: "Provisioning template (YAML) to use, overriding the VM's default built-in template (by stored macOS version or Linux platform); required if the VM's platform has no built-in template"), valueName: "path"))
	public var template: String?
	
	@Option(name: [.customLong("macos-version")], help: ArgumentHelp(String(localized: "macOS version to use for picking the built-in template, overriding the VM's stored osName"), valueName: "version"))
	public var macosVersion: MacOSVersion?
	
	@Option(name: [.customLong("var")], help: ArgumentHelp(String(localized: "Set a provisioning template variable (key=value), may be repeated"), valueName: "key=value"))
	public var vars: [String] = []
	
	@Argument(help: ArgumentHelp(String(localized: cakedRunning ? "Path to the VM disk.img or its name" : "VM name")))
	public var name: String
	
	public init() {
	}

}

