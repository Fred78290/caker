//
//  Routes.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakedLib
import GRPCLib
import Vapor

func registerLXDRoutes(_ app: Application, group: EventLoopGroup, runMode: Utils.RunMode) throws {
	try app.register(collection: LXDRootController(group: group, runMode: runMode))
	try app.register(collection: LXDInstancesController(group: group, runMode: runMode))
	try app.register(collection: LXDNetworksController(group: group, runMode: runMode))
	try app.register(collection: LXDOperationsController(group: group, runMode: runMode))
	try app.register(collection: LXDImagesController(group: group, runMode: runMode))
	try app.register(collection: LXDAuthGroupsController(group: group, runMode: runMode))
	try app.register(collection: LXDIdentitiesController(group: group, runMode: runMode))
	try app.register(collection: LXDCertificatesController(group: group, runMode: runMode))
}
