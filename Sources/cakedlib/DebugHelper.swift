//
//  DebugHelper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 16/01/2026.
//

import Foundation

extension NSObject {
	public var ivars: [Ivar] {
		var count: UInt32 = 0
		var ivars: [Ivar] = []
		let result = class_copyIvarList(type(of: self), &count)

		for index in 0..<Int(count) {
			if let ivar = result?[index] {
				ivars.append(ivar)
			}
		}

		return ivars
	}
	
	public var ivarNames: [String] {
		return self.ivars.compactMap {
			guard let value = ivar_getName($0) else {
				return nil
			}

			return String(cString: value)
		}
	}

	public var properties: [objc_property_t] {
		var count: UInt32 = 0
		var props: [objc_property_t] = []
		if let list = class_copyPropertyList(type(of: self), &count) {
			for i in 0..<Int(count) {
				let p = list[i]
				props.append(p)
			}
			free(list)
		}
		return props
	}

	public var propertyNames: [String] {
		return properties.compactMap { prop in
			let cname = property_getName(prop)
			return String(cString: cname)
		}
	}

	public var methods: [Method] {
		var count: UInt32 = 0
		var methods: [Method] = []

		if let methodList = class_copyMethodList(type(of: self), &count) {
			for i in 0..<Int(count) {
				let m = methodList[i]

				methods.append(m)
			}

			//free(methodList)
		}

		return methods
	}

	public var methodNames: [String] {
		return methods.compactMap { method in
			let sel = method_getName(method)
			return NSStringFromSelector(sel)
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
