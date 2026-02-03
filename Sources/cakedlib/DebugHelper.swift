//
//  DebugHelper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 16/01/2026.
//

import Foundation

@_silgen_name("SPBGetSharedPtrRawPointer")
func SPBGetSharedPtrRawPointer(_ sharedPtrObjectAddr: UnsafePointer<UInt8>?) -> UnsafeRawPointer?

@_silgen_name("SPBGetSharedPtrUseCount")
func SPBGetSharedPtrUseCount(_ sharedPtrObjectAddr: UnsafePointer<UInt8>?) -> Int

public typealias Ivars = [String: Ivar]

extension Ivar {
	public var name: String {
		guard let name = ivar_getName(self) else {
			return "<unknown>"
		}

		return String(cString: name)
	}
}

extension NSObject {
	public func getIvar(name: String) -> Any? {
		guard let field = class_getInstanceVariable(type(of: self), name) else {
			return nil
		}

		return object_getIvar(self, field)
	}

	public func setIvar(name: String, value: Any?) {
		guard let field = class_getInstanceVariable(type(of: self), name) else {
			return
		}

		object_setIvar(self, field, value)
	}

	public func getIvar<T>(_ name: String) -> T? {
		guard let field = class_getInstanceVariable(type(of: self), name) else {
			return nil
		}

		guard let value = object_getIvar(self, field) as? T else {
			return nil
		}

		return value
	}

	public func setIvar<T>(_ name: String, value: T) {
		self.setIvar(name: name, value: value)
	}

	public var ivars: Ivars {
		var count: UInt32 = 0
		var ivars: Ivars = [:]

		if let list = class_copyIvarList(type(of: self), &count) {
			for index in 0..<Int(count) {
				let ivar = list[index]

				if let name = ivar_getName(ivar) {
					ivars[String(cString: name)] = ivar
				}
			}
		}

		return ivars
	}
	
	public var ivarNames: [String] {
		self.ivars.keys.map {
			String($0)
		}
	}

	public var properties: [objc_property_t] {
		var count: UInt32 = 0
		var props: [objc_property_t] = []

		if let list = class_copyPropertyList(type(of: self), &count) {
			for i in 0..<Int(count) {
				props.append(list[i])
			}
		}

		return props
	}

	public var propertyNames: [String] {
		return properties.compactMap { prop in
			return String(cString: property_getName(prop))
		}
	}

	public var methods: [Method] {
		var count: UInt32 = 0
		var methods: [Method] = []

		if let methodList = class_copyMethodList(type(of: self), &count) {
			for i in 0..<Int(count) {
				methods.append(methodList[i])
			}
		}

		return methods
	}

	public var methodNames: [String] {
		return methods.compactMap { method in
			return NSStringFromSelector(method_getName(method))
		}
	}

	public var protocols: [Protocol] {
		var count: UInt32 = 0
		var protocols: [Protocol] = []

		if let protocolList = class_copyProtocolList(type(of: self), &count) {
			for i in 0..<Int(count) {
				protocols.append(protocolList[i])
			}
		}

		return protocols
	}

	public var protocolNames: [String] {
		return protocols.compactMap {
			String(cString: protocol_getName($0))
		}
	}

	public static func swizzleMethod(sourceClass:AnyClass, originalSelector: Selector, targetClass: AnyClass, swizzledSelector: Selector) {
		guard let originalMethod = class_getInstanceMethod(sourceClass, originalSelector), let swizzledMethod = class_getInstanceMethod(targetClass, swizzledSelector) else {
			return
		}
		
		method_exchangeImplementations(originalMethod, swizzledMethod)
	}

	public func swizzleMethod(originalSelector: Selector, swizzledSelector: Selector) {
		let cls: AnyClass = type(of: self)
		
		Self.swizzleMethod(sourceClass: cls, originalSelector: originalSelector, targetClass: cls, swizzledSelector: swizzledSelector)
	}
}
