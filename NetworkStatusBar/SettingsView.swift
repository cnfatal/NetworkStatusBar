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
    VStack(alignment: .leading, spacing: 0) {
      // Title
      Text(NSLocalizedString("settings", comment: "Settings"))
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)

      Divider()
        .padding(.horizontal, 8)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          // Refresh interval
          VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("refresh_interval", comment: "Refresh Interval"))
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.secondary)

            HStack(spacing: 8) {
              Picker("", selection: $settings.refreshInterval) {
                Text("1s").tag(1)
                Text("2s").tag(2)
                Text("3s").tag(3)
                Text("5s").tag(5)
                Text("10s").tag(10)
              }
              .pickerStyle(.segmented)
              .frame(width: 220)
            }
          }

          Divider()

          // Traffic threshold
          VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("min_threshold", comment: "Minimum Traffic Threshold"))
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.secondary)

            Picker("", selection: $settings.minTrafficThreshold) {
              Text(NSLocalizedString("show_all", comment: "Show All")).tag(0)
              Text("1 KB/s").tag(1024)
              Text("10 KB/s").tag(10240)
              Text("100 KB/s").tag(102400)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
          }

          Divider()

          // Blacklist section
          VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("blacklist", comment: "App Blacklist"))
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.secondary)

            Text(NSLocalizedString("blacklist_desc", comment: "Blacklist description"))
              .font(.system(size: 10))
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            // Add new item
            HStack(spacing: 4) {
              TextField(
                NSLocalizedString("app_name_placeholder", comment: "App name placeholder"),
                text: $newBlacklistItem
              )
              .textFieldStyle(.roundedBorder)
              .font(.system(size: 11))
              .onSubmit { addBlacklistItem() }

              Button(action: addBlacklistItem) {
                Image(systemName: "plus.circle.fill")
                  .foregroundColor(.accentColor)
              }
              .buttonStyle(.plain)
              .disabled(newBlacklistItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Blacklist items
            if settings.blacklist.isEmpty {
              Text(NSLocalizedString("blacklist_empty", comment: "No blacklisted apps"))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .italic()
                .padding(.vertical, 4)
            } else {
              VStack(spacing: 2) {
                ForEach(settings.blacklist, id: \.self) { name in
                  HStack {
                    Text(name)
                      .font(.system(size: 11))
                      .lineLimit(1)
                    Spacer()
                    Button(action: { settings.removeFromBlacklist(name) }) {
                      Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                  }
                  .padding(.horizontal, 6)
                  .padding(.vertical, 3)
                  .background(Color.primary.opacity(0.05))
                  .cornerRadius(4)
                }
              }
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
    }
    .frame(width: 280)
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
