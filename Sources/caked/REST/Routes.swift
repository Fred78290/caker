//
//  Routes.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakedLib
import GRPCLib
import Vapor

func registerLXDRoutes(_ app: Application, runMode: Utils.RunMode) throws {
	try app.register(collection: LXDRootController(runMode: runMode))
	try app.register(collection: LXDInstancesController(runMode: runMode))
	try app.register(collection: LXDNetworksController(runMode: runMode))
	try app.register(collection: LXDOperationsController())
	try app.register(collection: LXDImagesController(runMode: runMode))
}
