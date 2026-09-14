#!/usr/bin/env swift
import Foundation

/// Reads simctl JSON. No hardcoded iPhone model or simulator UUID is required.
struct DeviceList: Decodable { let devices: [String: [Device]] }
struct Device: Decodable {
    let name: String
    let udid: String
    let state: String
    let isAvailable: Bool?
}
struct Candidate {
    let device: Device
    let version: [Int]
}
func stop(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
guard CommandLine.arguments.count == 2 else { stop("Usage: choose-simulator.swift devices.json") }
do {
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let list = try JSONDecoder().decode(DeviceList.self, from: data)
    let candidates: [Candidate] = list.devices.flatMap { runtime, devices in
        guard let marker = runtime.range(of: ".iOS-") else { return [Candidate]() }
        let version = runtime[marker.upperBound...].split(separator: "-").compactMap { Int($0) }
        guard (version.first ?? 0) >= 17 else { return [] }
        return devices.filter { $0.name.hasPrefix("iPhone") && $0.isAvailable != false }
            .map { Candidate(device: $0, version: version) }
    }
    if let requested = ProcessInfo.processInfo.environment["SHELF_SIMULATOR_UDID"], !requested.isEmpty {
        guard candidates.contains(where: { $0.device.udid == requested }) else {
            stop("SHELF_SIMULATOR_UDID is not an available iPhone on iOS 17 or later.")
        }
        print(requested)
    } else {
        let ordered = candidates.sorted {
            let leftBooted = $0.device.state == "Booted"
            let rightBooted = $1.device.state == "Booted"
            if leftBooted != rightBooted { return leftBooted }
            if $0.version != $1.version { return $1.version.lexicographicallyPrecedes($0.version) }
            return $0.device.name.localizedStandardCompare($1.device.name) == .orderedDescending
        }
        guard let chosen = ordered.first else { stop("No available iPhone simulator with iOS 17 or later.") }
        print(chosen.device.udid)
    }
} catch { stop("Could not read simulator inventory: \(error.localizedDescription)") }
