//
//  MenuBarLabel.swift
//  NetworkStatusBar
//

import SwiftUI

/// The menu bar item: upload over download, right-aligned so the figures line
/// up on their last digit.
struct MenuBarLabel: View {
  let model: TrafficModel

  var body: some View {
    VStack(alignment: .trailing, spacing: 1) {
      Text("\(formatRate(model.total.outbounds)) ▲")
      Text("\(formatRate(model.total.inbounds)) ▼")
    }
    .font(.system(size: 9, weight: .medium, design: .monospaced))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
  }
}
