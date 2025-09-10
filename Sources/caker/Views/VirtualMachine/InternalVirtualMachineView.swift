//
//  InternalVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/07/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

struct InternalVirtualMachineView: View {
	private var virtualMachine: VirtualMachine
	private var automaticallyReconfiguresDisplay: Bool

	init(virtualMachine: VirtualMachine, automaticallyReconfiguresDisplay: Bool) {
		self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
		self.virtualMachine = virtualMachine
	}

	var body: some View {
		VMView(automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay, vm: self.virtualMachine, virtualMachine: self.virtualMachine.virtualMachine, callback: nil)
	}

}
