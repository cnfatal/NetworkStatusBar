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

  func update(data: Data) {
    if data.isEmpty {
      return
    }
    lock.lock()
    defer { lock.unlock() }

    var dataframe = (try? DataFrame(csvData: data, columns: Columns)) ?? DataFrame.init()
    if #available(macOS 13.0, *) {
      dataframe.renameColumn("Column 0", to: ColumnName)
    } else {
      dataframe.renameColumn("", to: ColumnName)
    }
    if laststate.isEmpty {
      laststate = dataframe
    }
    defer {
      laststate = dataframe
    }

    var joined = dataframe.joined(laststate, on: ColumnName, kind: JoinKind.right)
    joined.combineColumns("left.bytes_in", "right.bytes_in", into: ColumnBytesIn) {
      ($0 ?? 0) - ($1 ?? 0)
    }
    joined.combineColumns("left.bytes_out", "right.bytes_out", into: ColumnBytesOut) {
      ($0 ?? 0) - ($1 ?? 0)
    }

    // 0:"name",1:"bytes_in",2:"bytes_out"
    let totalin = joined.columns[1].reduce(
      0,
      { x, y in
        x + (y as? Int ?? 0)
      })
    let totalout = joined.columns[2].reduce(
      0,
      { x, y in
        x + (y as? Int ?? 0)
      })
    var items = joined.rows.map { r -> NetworkState in
      var state = NetworkState()
      let splits = (r[ColumnName] as? String ?? "").split(separator: ".", maxSplits: 1)
      state.name = String(splits.first ?? "")
      state.pid = Int(splits.last ?? "") ?? 0
      state.inbounds = r[ColumnBytesIn] as? Int ?? 0
      state.outbounds = r[ColumnBytesOut] as? Int ?? 0
      state.total = state.inbounds + state.outbounds
      return state
    }

    items.sort { $0.total > $1.total }
    let ret = NetworkStates(
      total: NetworkState(inbounds: totalin, outbounds: totalout),
      items: items)

    self.callback(ret)
  }
}
