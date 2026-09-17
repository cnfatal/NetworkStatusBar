//
//  TrafficPanel.swift
//  NetworkStatusBar
//
//  The panel shown when the menu bar item is clicked.
//

import SwiftUI

struct TrafficPanel: View {
  let model: TrafficModel
  let onOpenSettings: () -> Void

  private var activeInterfaces: [InterfaceRate] {
    model.interfaces.activeInterfaces
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // The heading and the chart are always present and sit above the
      // per-interface rows, so the chart keeps a fixed position even as the
      // rows below it come and go with the traffic.
      VStack(alignment: .leading, spacing: 6) {
        Text(NSLocalizedString("network_traffic", comment: "Network Traffic"))
          .font(.system(size: 13, weight: .semibold))

        TrafficChart(samples: model.history, capacity: TrafficModel.historyCapacity)

        // One row per interface actually carrying traffic, busiest first. An
        // idle interface simply is not listed rather than sitting there reading
        // zero, and with none to list the rows collapse.
        if !activeInterfaces.isEmpty {
          VStack(alignment: .leading, spacing: 2) {
            ForEach(activeInterfaces) { entry in
              RateRow(title: entry.name, counters: entry.counters)
            }
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      Divider()
        .padding(.horizontal, 8)

      ProcessList(processes: model.processes)

      Divider()
        .padding(.horizontal, 8)

      HStack {
        PanelButton(
          title: NSLocalizedString("settings", comment: "Settings"),
          systemImage: "gearshape"
        ) {
          onOpenSettings()
        }
        Spacer()
        PanelButton(
          title: NSLocalizedString("quit", comment: "quit the application"),
          systemImage: "power"
        ) {
          NSApp.terminate(nil)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .frame(width: 280)
  }
}

/// One interface's up/down rates, with the interface name leading.
struct RateRow: View {
  let title: String
  let counters: TrafficCounters

  var body: some View {
    HStack(spacing: 16) {
      Text(title)
        .font(.system(size: 11))
        .frame(width: 56, alignment: .leading)

      Label {
        Text(formatRate(counters.outbounds))
          .font(.system(size: 11, weight: .medium, design: .monospaced))
      } icon: {
        Image(systemName: "arrow.up")
          .font(.system(size: 9, weight: .semibold))
          .foregroundColor(.orange)
      }

      Label {
        Text(formatRate(counters.inbounds))
          .font(.system(size: 11, weight: .medium, design: .monospaced))
      } icon: {
        Image(systemName: "arrow.down")
          .font(.system(size: 9, weight: .semibold))
          .foregroundColor(.cyan)
      }
    }
  }
}

/// The scrollable per-process list.
struct ProcessList: View {
  let processes: [ProcessTraffic]

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        if processes.isEmpty {
          Text(NSLocalizedString("no_activity", comment: "No network activity"))
            .foregroundColor(.secondary)
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
        } else {
          ForEach(processes) { process in
            ProcessRow(process: process)
          }
        }
      }
    }
    .frame(minHeight: 160, maxHeight: 440)
  }
}

struct ProcessRow: View {
  let process: ProcessTraffic

  var body: some View {
    HStack {
      Text(process.name)
        .font(.system(size: 11))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(process.name)

      VStack(alignment: .trailing, spacing: 1) {
        rate(formatRate(process.outbounds), "arrow.up", .orange)
        rate(formatRate(process.inbounds), "arrow.down", .cyan)
      }
      .fixedSize()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 5)
    // Rows that stopped being reported fade out rather than disappearing, so
    // the list reads as settling instead of flickering.
    .opacity(process.isStale ? 0.35 : 1)
  }

  private func rate(_ text: String, _ symbol: String, _ color: Color) -> some View {
    HStack(spacing: 2) {
      Image(systemName: symbol)
        .font(.system(size: 7, weight: .medium))
        .foregroundColor(color)
      Text(text)
        .font(.system(size: 9, weight: .medium, design: .monospaced))
    }
  }
}

/// A footer action, styled to read like a menu row.
struct PanelButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.system(size: 12))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
          RoundedRectangle(cornerRadius: 5)
            .fill(Color.primary.opacity(hovering ? 0.1 : 0)))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}
