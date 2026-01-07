//
//  TunnelAttachement.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/05/2025.
//
import Foundation
import NIOPortForwarding
import ArgumentParser
import CakeAgentLib

extension ForwardedPort: Validatable {
	public func validate() -> Bool {
		if proto == .none || host < 0 || guest <= 0 {
			return false
		}

		return true
	}
}

extension TunnelAttachement: Validatable {
	public func validate() -> Bool {
		switch self.oneOf {
		case .none:
			return false
		case .forward(let value):
			return value.validate()
		case .unixDomain(let value):
			return value.validate()
		}
	}
}

extension TunnelAttachement.ForwardUnixDomainSocket: Validatable {
	public func validate() -> Bool {
		if proto == .none || host.isEmpty || guest.isEmpty {
			return false
		}

		return true
	}
}
