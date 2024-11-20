import ArgumentParser
import Foundation

enum Format: String, ExpressibleByArgument, CaseIterable {
  case text, json

  private(set) static var allValueStrings: [String] = Format.allCases.map { "\($0)"}
}