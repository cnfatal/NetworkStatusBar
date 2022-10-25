//
//  NetworkStatus.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

import Foundation
import TabularData

struct NetworkStates {
  var Total: NetworkState = NetworkState()
  var Items: [NetworkState] = []
}

struct NetworkState {
  var pid: Int = 0
  var name: String = ""
  var inbounds: Int = 0
  var outbounds: Int = 0
  var total: Int = 0
}

open class NetworkDetails {
  var callback: (NetworkStates) -> Void = { _ in }

  var laststate: DataFrame = DataFrame()
  var process: Process = Process()

  init() {
    self.prepare()
  }

  let ColumnName = "name"
  let ColumnBytesIn = "bytes_in"
  let ColumnBytesOut = "bytes_out"
  let ColumnBytesTotal = "bytes_total"
  let Columns = ["", "bytes_in", "bytes_out"]

  func prepare() {
    process.executableURL = URL.init(fileURLWithPath: "/usr/bin/nettop")
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    process.standardInput = Pipe()
    Task {
      var data = Data()
      for try await line in pipe.fileHandleForReading.bytes.lines {
        if line.hasPrefix("time") {
          self.update(data: data)
          data = Data()
        }
        data.append(contentsOf: (line + "\n").utf8)
      }
    }
  }

  func run(refreshSeconds: Int = 1) {
    if process.isRunning {
      process.terminate()
    }
    process.arguments = ["-P", "-L", "0", "-s", "\(refreshSeconds)"]
    try? process.run()
    process.waitUntilExit()
  }

  func update(data: Data) {
    if data.isEmpty {
      return
    }
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
      Total: NetworkState(inbounds: totalin, outbounds: totalout),
      Items: items)

    self.callback(ret)
  }
}
