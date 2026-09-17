//
//  NetworkStatus.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

import Foundation
import TabularData

struct NetworkStates {
  var total: NetworkState = NetworkState()
  var items: [NetworkState] = []
}

struct NetworkState: Identifiable {
  var id: String { "\(pid).\(name)" }
  var pid: Int = 0
  var name: String = ""
  var inbounds: Int = 0
  var outbounds: Int = 0
  var total: Int = 0
}

open class NetworkDetails {
  var callback: (NetworkStates) -> Void = { _ in }

  var laststate: DataFrame = DataFrame()
  var process: Process?
  private let lock = NSLock()

  let ColumnName = "name"
  let ColumnBytesIn = "bytes_in"
  let ColumnBytesOut = "bytes_out"
  let ColumnBytesTotal = "bytes_total"
  let Columns = ["", "bytes_in", "bytes_out"]

  func run(refreshSeconds: Int = 1) {
    stop()

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
    proc.arguments = ["-P", "-L", "0", "-s", "\(refreshSeconds)"]

    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe
    proc.standardInput = Pipe()

    Task { [weak self] in
      var data = Data()
      for try await line in pipe.fileHandleForReading.bytes.lines {
        if line.hasPrefix("time") {
          self?.update(data: data)
          data = Data()
        }
        data.append(contentsOf: (line + "\n").utf8)
      }
    }

    self.process = proc
    try? proc.run()
    proc.waitUntilExit()
  }

  func stop() {
    if let proc = process, proc.isRunning {
      proc.terminate()
      proc.waitUntilExit()
    }
    process = nil
  }

  /// nettop can be terminated mid-row, leaving a truncated line that makes the
  /// CSV parser reject the entire sample. Drop any row whose field count does
  /// not match the header's, so a single bad line cannot take out the sample.
  private func sanitize(_ data: Data) -> Data {
    guard let text = String(data: data, encoding: .utf8) else { return data }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
    guard let header = lines.first else { return data }
    let expected = header.split(separator: ",", omittingEmptySubsequences: false).count
    let kept = lines.filter {
      $0.split(separator: ",", omittingEmptySubsequences: false).count == expected
    }
    return Data(kept.joined(separator: "\n").utf8)
  }

  func update(data: Data) {
    if data.isEmpty {
      return
    }
    lock.lock()
    defer { lock.unlock() }

    var dataframe = (try? DataFrame(csvData: sanitize(data), columns: Columns)) ?? DataFrame.init()

    // Bail out before renaming: `renameColumn` traps when the column is absent,
    // which would turn a malformed sample into a crash.
    guard !dataframe.columns.isEmpty else {
      return
    }
    // The process column is the unnamed one requested in `Columns`; read back
    // the name the parser actually gave it instead of assuming the default.
    dataframe.renameColumn(dataframe.columns[0].name, to: ColumnName)

    if laststate.isEmpty {
      laststate = dataframe
    }
    defer {
      laststate = dataframe
    }

    // A full outer join keeps processes that appeared since the last sample.
    // nettop keeps listing idle processes, so a name missing from `dataframe`
    // means the process exited. Deltas are clamped at zero: an exiting process
    // or a reset counter must never subtract from the total.
    var joined = dataframe.joined(laststate, on: ColumnName, kind: JoinKind.full)
    joined.combineColumns("left.bytes_in", "right.bytes_in", into: ColumnBytesIn) {
      max(0, ($0 ?? 0) - ($1 ?? 0))
    }
    joined.combineColumns("left.bytes_out", "right.bytes_out", into: ColumnBytesOut) {
      max(0, ($0 ?? 0) - ($1 ?? 0))
    }

    let live = Set(dataframe[ColumnName].compactMap { $0 as? String })
    var items = joined.rows
      .filter { live.contains($0[ColumnName] as? String ?? "") }
      .map { r -> NetworkState in
        var state = NetworkState()
        // nettop emits "<name>.<pid>" and the name itself may contain dots,
        // so split on the last one rather than the first.
        let raw = r[ColumnName] as? String ?? ""
        if let dot = raw.lastIndex(of: ".") {
          state.name = String(raw[raw.startIndex..<dot])
          state.pid = Int(raw[raw.index(after: dot)...]) ?? 0
        } else {
          state.name = raw
        }
        state.inbounds = r[ColumnBytesIn] as? Int ?? 0
        state.outbounds = r[ColumnBytesOut] as? Int ?? 0
        state.total = state.inbounds + state.outbounds
        return state
      }

    items.sort { $0.total > $1.total }
    let ret = NetworkStates(
      total: NetworkState(
        inbounds: items.reduce(0) { $0 + $1.inbounds },
        outbounds: items.reduce(0) { $0 + $1.outbounds }),
      items: items)

    self.callback(ret)
  }
}
