//
//  StatusBarView.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

import SwiftUI

class IOStates: ObservableObject {
  @Published var total: NetworkState = NetworkState()
  @Published var items: [NetworkState] = []
}

struct StatusBarView: View {
  @ObservedObject var iostates = IOStates()
  var body: some View {
    VStack(alignment: .trailing) {
      Text(String(format: "%@ ▲", arguments: [formatbytes(iostates.total.outbounds)]))
      Text(String(format: "%@ ▼", arguments: [formatbytes(iostates.total.inbounds)]))
    }
    .font(.system(size: 9, weight: .medium))
  }
}

struct StatusBarView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      StatusBarView()
    }
  }
}

let formatter = { () -> ByteCountFormatter in
  var formatter = ByteCountFormatter.init()
  formatter.allowsNonnumericFormatting = false
  formatter.countStyle = .binary
  return formatter
}()

func formatbytes(_ bytes: Int) -> String {
  if bytes < 1024 {
    return "0KB/s"
  }
  return String(
    format: "%@/s",
    arguments: [
      formatter.string(fromByteCount: Int64(bytes))
    ])
}
