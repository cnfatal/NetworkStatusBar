//
//  StatusBarDetailsView.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

import SwiftUI

struct StatusBarDetailsView: View {
  @ObservedObject var iostates = IOStates()
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header: Total traffic summary
      VStack(alignment: .leading, spacing: 6) {
        Text(NSLocalizedString("network_traffic", comment: "Network Traffic"))
          .font(.system(size: 13, weight: .semibold))
        HStack(spacing: 16) {
          Label {
            Text(formatbytes(iostates.total.outbounds))
              .font(.system(size: 11, weight: .medium, design: .monospaced))
          } icon: {
            Image(systemName: "arrow.up")
              .font(.system(size: 9, weight: .semibold))
              .foregroundColor(.orange)
          }
          Label {
            Text(formatbytes(iostates.total.inbounds))
              .font(.system(size: 11, weight: .medium, design: .monospaced))
          } icon: {
            Image(systemName: "arrow.down")
              .font(.system(size: 9, weight: .semibold))
              .foregroundColor(.cyan)
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      Divider()
        .padding(.horizontal, 8)

      // Process list
      ScrollView {
        VStack(spacing: 0) {
          if iostates.items.isEmpty {
            Text(NSLocalizedString("no_activity", comment: "No network activity"))
              .foregroundColor(.secondary)
              .font(.system(size: 11))
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.vertical, 20)
          } else {
            ForEach(iostates.items) { item in
              StatusBarDetailsItemView(state: item)
            }
          }
        }
      }
      .frame(minHeight: 120, maxHeight: 260)
    }
    .frame(width: 280)
  }
}

struct StatusBarDetailsItemView: View {
  var state: NetworkState = NetworkState()

  var body: some View {
    HStack {
      Text(state.name)
        .font(.system(size: 11))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(state.name)

      VStack(alignment: .trailing, spacing: 1) {
        HStack(spacing: 2) {
          Image(systemName: "arrow.up")
            .font(.system(size: 7, weight: .medium))
            .foregroundColor(.orange)
          Text(formatbytes(state.outbounds))
            .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        HStack(spacing: 2) {
          Image(systemName: "arrow.down")
            .font(.system(size: 7, weight: .medium))
            .foregroundColor(.cyan)
          Text(formatbytes(state.inbounds))
            .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
      }
      .fixedSize()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 5)
  }
}

struct StatusBarMenuView_Previews: PreviewProvider {
  static let data = { () -> IOStates in
    let ret = IOStates()
    ret.total = NetworkState(pid: 0, name: "total", inbounds: 10240, outbounds: 2048)
    ret.items = [
      NetworkState(pid: 1, name: "Chrome", inbounds: 5120, outbounds: 1024),
      NetworkState(pid: 2, name: "Slack", inbounds: 2048, outbounds: 512),
      NetworkState(pid: 3, name: "Terminal", inbounds: 1024, outbounds: 256),
    ]
    return ret
  }()
  static var previews: some View {
    StatusBarDetailsView(iostates: data)
  }
}

struct StatusBarDetailsItemView_Previews: PreviewProvider {
  static var previews: some View {
    StatusBarDetailsItemView(state: NetworkState(pid: 1, name: "Chrome", inbounds: 10240, outbounds: 2048))
      .frame(width: 280)
  }
}
