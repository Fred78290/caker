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
	@StateObject var document: VirtualMachineDocument

	var automaticallyReconfiguresDisplay: Bool
	var callback: VMView.CallbackWindow?

	var body: some View {
		VMView(automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay, vm: document.virtualMachine, virtualMachine: document.virtualMachine.virtualMachine, callback: callback)
	}

}
