//
//  SettingsView.swift
//  NetworkStatusBar
//
//  Settings window for configuring refresh rate, blacklist, etc.
//

import SwiftUI

struct SettingsView: View {
  @ObservedObject var settings = AppSettings.shared
  @State private var selectedProcess: String = ""
  var seenProcessNames: Set<String> = []

  private var availableProcesses: [String] {
    let existing = Set(settings.blacklist)
    return seenProcessNames.subtracting(existing).sorted()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Section 1: Refresh interval
      GroupBox(label: Label(
        NSLocalizedString("refresh_interval", comment: ""),
        systemImage: "clock"
      )) {
        Picker("", selection: $settings.refreshInterval) {
          Text("1s").tag(1)
          Text("2s").tag(2)
          Text("3s").tag(3)
          Text("5s").tag(5)
          Text("10s").tag(10)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.top, 4)
      }

      // Section 2: Traffic threshold
      GroupBox(label: Label(
        NSLocalizedString("min_threshold", comment: ""),
        systemImage: "speedometer"
      )) {
        Picker("", selection: $settings.minTrafficThreshold) {
          Text(NSLocalizedString("show_all", comment: "")).tag(0)
          Text("1 KB/s").tag(1024)
          Text("10 KB/s").tag(10240)
          Text("100 KB/s").tag(102400)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.top, 4)
      }

      // Section 3: Process Blacklist
      GroupBox(label: Label(
        NSLocalizedString("blacklist", comment: ""),
        systemImage: "nosign"
      )) {
        VStack(alignment: .leading, spacing: 8) {
          // Pick from seen processes
          if !availableProcesses.isEmpty {
            Picker(NSLocalizedString("select_process", comment: ""), selection: $selectedProcess) {
              Text("—").tag("")
              ForEach(availableProcesses, id: \.self) { name in
                Text(name).tag(name)
              }
            }
            .onChange(of: selectedProcess) { value in
              guard !value.isEmpty else { return }
              settings.addToBlacklist(value)
              selectedProcess = ""
            }
          }

          // Blacklist items
          if settings.blacklist.isEmpty {
            Text(NSLocalizedString("blacklist_empty", comment: ""))
              .foregroundColor(.secondary)
              .italic()
              .padding(.vertical, 2)
          } else {
            VStack(spacing: 2) {
              ForEach(settings.blacklist, id: \.self) { name in
                HStack {
                  Text(name)
                    .lineLimit(1)
                  Spacer()
                  Button(action: { settings.removeFromBlacklist(name) }) {
                    Image(systemName: "xmark.circle.fill")
                      .foregroundColor(.secondary)
                  }
                  .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(4)
              }
            }
          }
        }
        .padding(.top, 4)
      }
    }
    .padding(20)
    .frame(width: 360)
    .fixedSize()
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView(seenProcessNames: ["Chrome", "Slack", "Terminal", "ClashX", "Surge", "Safari"])
  }
}
