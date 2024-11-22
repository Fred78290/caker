import Foundation

struct Utils {
  static func getTartHome(asSystem: Bool) throws -> URL {
    if asSystem {
      let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .systemDomainMask, true)
      var applicationSupportDirectory = URL(fileURLWithPath: paths.first!, isDirectory: true)
      
      applicationSupportDirectory = URL(fileURLWithPath: tartDSignature,
                                        isDirectory: true,
                                        relativeTo: applicationSupportDirectory)
      try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
      
      return applicationSupportDirectory
    }
    
    return try Config().tartHomeDir
  }
  
  static func getOutputLog(asSystem: Bool) -> String {
    if asSystem {
      return "/Library/Logs/tartd.log"
    }
    
    return URL(fileURLWithPath: "tartd.log", relativeTo: try? Config().tartHomeDir).absoluteURL.path()
  }
  
  static func getListenAddress(asSystem: Bool) throws -> String {
    if let tartdListenAddress = ProcessInfo.processInfo.environment["TARTD_LISTEN_ADDRESS"] {
      return tartdListenAddress
    } else {
      var home = try Self.getTartHome(asSystem: asSystem)
      
      home.append(path: "tard.sock")
      
      return "unix://\(home.absoluteURL.path())"
    }
  }

  static func createCertificats(asSystem: Bool) throws -> Dictionary<String, URL> {
    let certHome: URL = URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getTartHome(asSystem: asSystem))
    let caCertURL = URL(fileURLWithPath: "ca.pem", relativeTo: certHome)
    let caKeyURL = URL(fileURLWithPath: "ca.key", relativeTo: certHome)
    let clientKeyURL: URL = URL(fileURLWithPath: "client.key", relativeTo: certHome)
    let clientCertURL = URL(fileURLWithPath: "client.pem", relativeTo: certHome)
    let serverKeyURL = URL(fileURLWithPath: "server.key", relativeTo: certHome)
    let serverCertURL = URL(fileURLWithPath: "server.pem", relativeTo: certHome)

    if FileManager.default.fileExists(atPath: serverKeyURL.path()) == false {
      try FileManager.default.createDirectory(at: certHome, withIntermediateDirectories: true)
      try CypherKeyGenerator.generateClientServerCertificate(subject: "Tart daemon", numberOfYears: 1,
                                  caKeyURL: caKeyURL, caCertURL: caCertURL,
                                  serverKeyURL: serverKeyURL, serverCertURL: serverCertURL,
                                  clientKeyURL: clientKeyURL, clientCertURL: clientCertURL)
    }

    return [
      "ca.pem": caCertURL,
      "ca.key": caKeyURL,
      "client.key": clientKeyURL,
      "client.pem": clientCertURL,
      "server.key": serverKeyURL,
      "server.pem": serverCertURL,
    ]
  }
}