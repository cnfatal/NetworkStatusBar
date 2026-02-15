//
//  SettingsView.swift
//  NetworkStatusBar
//
//  Settings window for configuring refresh rate, blacklist, etc.
//

import SwiftUI

struct SettingsView: View {
  @ObservedObject var settings = AppSettings.shared
  @State private var newBlacklistItem: String = ""

  var body: some View {
    Form {
      Section {
        Picker(
          NSLocalizedString("refresh_interval", comment: "Refresh Interval"),
          selection: $settings.refreshInterval
        ) {
          Text("1s").tag(1)
          Text("2s").tag(2)
          Text("3s").tag(3)
          Text("5s").tag(5)
          Text("10s").tag(10)
        }
        .pickerStyle(.segmented)
      } header: {
        Text(NSLocalizedString("refresh_interval", comment: "Refresh Interval"))
      }

      Section {
        Picker(
          NSLocalizedString("min_threshold", comment: "Minimum Traffic Threshold"),
          selection: $settings.minTrafficThreshold
        ) {
          Text(NSLocalizedString("show_all", comment: "Show All")).tag(0)
          Text("1 KB/s").tag(1024)
          Text("10 KB/s").tag(10240)
          Text("100 KB/s").tag(102400)
        }
        .pickerStyle(.segmented)
      } header: {
        Text(NSLocalizedString("min_threshold", comment: "Minimum Traffic Threshold"))
      }

      Section {
        Text(NSLocalizedString("blacklist_desc", comment: "Blacklist description"))
          .font(.callout)
          .foregroundColor(.secondary)

        HStack {
          TextField(
            NSLocalizedString("app_name_placeholder", comment: "App name placeholder"),
            text: $newBlacklistItem
          )
          .textFieldStyle(.roundedBorder)
          .onSubmit { addBlacklistItem() }

          Button(action: addBlacklistItem) {
            Image(systemName: "plus.circle.fill")
          }
          .disabled(newBlacklistItem.trimmingCharacters(in: .whitespaces).isEmpty)
        }

        if settings.blacklist.isEmpty {
          Text(NSLocalizedString("blacklist_empty", comment: "No blacklisted apps"))
            .foregroundColor(.secondary)
            .italic()
        } else {
          List {
            ForEach(settings.blacklist, id: \.self) { name in
              HStack {
                Text(name)
                Spacer()
                Button(action: { settings.removeFromBlacklist(name) }) {
                  Image(systemName: "trash")
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
              }
            }
          }
          .frame(minHeight: 60, maxHeight: 160)
        }
      } header: {
        Text(NSLocalizedString("blacklist", comment: "App Blacklist"))
      }
    }
    .navigationTitle(NSLocalizedString("settings", comment: "Settings"))
    .frame(width: 400, height: 420)
    .fixedSize()
  }

  private func addBlacklistItem() {
    let trimmed = newBlacklistItem.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    settings.addToBlacklist(trimmed)
    newBlacklistItem = ""
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
