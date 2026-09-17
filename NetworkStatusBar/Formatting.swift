//
//  Formatting.swift
//  NetworkStatusBar
//

import Foundation

private let byteFormatter: ByteCountFormatter = {
  let formatter = ByteCountFormatter()
  formatter.allowsNonnumericFormatting = false
  formatter.countStyle = .binary
  return formatter
}()

/// A rate, e.g. "12.5KB/s".
///
/// Anything under a kilobyte reads as zero: at that scale the unit suffix
/// dominates the number and the column stops being scannable.
func formatRate(_ bytesPerSecond: Int) -> String {
  guard bytesPerSecond >= 1024 else {
    return "0KB/s"
  }
  // ByteCountFormatter already separates the number from its unit with a space,
  // which is what makes "112.5 MB/s" readable rather than a run of characters.
  return "\(byteFormatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
}
