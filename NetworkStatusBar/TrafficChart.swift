//
//  TrafficChart.swift
//  NetworkStatusBar
//
//  A fixed-window chart of recent rates.
//

import Charts
import SwiftUI

/// Plots a rolling window of rates as two overlapping areas, with a
/// per-interface readout on hover.
///
/// The x axis is pinned to `capacity` slots rather than scaled to however many
/// samples exist, so the chart keeps a constant scale as it fills instead of
/// stretching three points across the full width on launch. Samples are oldest
/// first and occupy the rightmost slots — the newest against the right edge —
/// and the slots to their left simply have no data.
struct TrafficChart: View {
  let samples: [TrafficSample]
  let capacity: Int

  /// How many interfaces the hover readout lists before collapsing the rest
  /// into a count. The chart is short, so the box has to stay short too.
  private let hoverRows = 3

  @State private var selectedSlot: Int?

  /// One sample placed at its absolute slot.
  private struct Point: Identifiable {
    var id: Int { slot }
    let slot: Int
    let sample: TrafficSample
  }

  private var points: [Point] {
    let visible = samples.suffix(capacity)
    let leading = max(0, capacity - visible.count)
    return visible.enumerated().map { Point(slot: leading + $0.offset, sample: $0.element) }
  }

  private var peak: Int {
    samples.suffix(capacity).reduce(0) {
      max($0, max($1.total.inbounds, $1.total.outbounds))
    }
  }

  var body: some View {
    Chart {
      ForEach(points) { point in
        series(.down, point, \.total.inbounds, .cyan)
        series(.up, point, \.total.outbounds, .orange)
      }
    }
    // A line needs two points; an all-zero window has nothing to scale to.
    .chartYScale(domain: 0...max(peak, 1))
    .chartXScale(domain: 0...max(capacity - 1, 1))
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartPlotStyle { $0.clipped() }
    .chartXSelection(value: $selectedSlot)
    .chartOverlay { proxy in
      readout(proxy: proxy)
    }
    .frame(height: 62)
  }

  private enum Series: String {
    case down = "down"
    case up = "up"
  }

  /// One direction's filled area and its top edge. Both directions and both
  /// kinds are separate marks, and the areas are explicitly unstacked so they
  /// overlay rather than accumulate.
  @ChartContentBuilder
  private func series(
    _ kind: Series,
    _ point: Point,
    _ value: KeyPath<TrafficSample, Int>,
    _ color: Color
  ) -> some ChartContent {
    AreaMark(
      x: .value("Slot", point.slot),
      y: .value("Rate", point.sample[keyPath: value]),
      series: .value("Series", "\(kind.rawValue)-area"),
      stacking: .unstacked
    )
    .foregroundStyle(color.opacity(0.18))

    LineMark(
      x: .value("Slot", point.slot),
      y: .value("Rate", point.sample[keyPath: value]),
      series: .value("Series", "\(kind.rawValue)-line")
    )
    .foregroundStyle(color)
    .lineStyle(StrokeStyle(lineWidth: 1))
  }

  /// The vertical marker and the per-interface box that follow the pointer.
  @ViewBuilder
  private func readout(proxy: ChartProxy) -> some View {
    GeometryReader { geometry in
      if let slot = selectedSlot,
        let frame = proxy.plotFrame,
        let x = proxy.position(forX: slot)
      {
        let plot = geometry[frame]
        let originX = plot.origin.x + x

        Path { path in
          path.move(to: CGPoint(x: originX, y: 0))
          path.addLine(to: CGPoint(x: originX, y: plot.height))
        }
        .stroke(Color.primary.opacity(0.3), lineWidth: 1)

        if let sample = sample(at: slot) {
          box(for: sample)
            .position(x: boxCentre(originX: originX, width: plot.width), y: plot.height / 2)
        }
      }
    }
  }

  private func sample(at slot: Int) -> TrafficSample? {
    points.first { $0.slot == slot }?.sample
  }

  /// Keeps the box inside the plot, preferring the side the pointer is not on
  /// so it does not sit under the cursor.
  private func boxCentre(originX: CGFloat, width: CGFloat) -> CGFloat {
    let half: CGFloat = 70
    let preferred = originX + half + 6
    if preferred + half > width {
      return max(half, originX - half - 6)
    }
    return preferred
  }

  /// The per-interface breakdown at one instant.
  ///
  /// The total is deliberately absent: it is what the curves already show, and
  /// nettop's per-connection counters do not add up to it exactly, so listing
  /// both would look like a mistake.
  private func box(for sample: TrafficSample) -> some View {
    let rates = sample.interfaces.activeInterfaces
    var lines = rates.prefix(hoverRows).map {
      "\($0.name) ▲\(formatRate($0.counters.outbounds)) ▼\(formatRate($0.counters.inbounds))"
    }
    if rates.count > hoverRows {
      lines.append("+\(rates.count - hoverRows)")
    }
    return VStack(alignment: .leading, spacing: 1) {
      ForEach(lines, id: \.self) { line in
        Text(line)
      }
    }
    .font(.system(size: 9, design: .monospaced))
    .foregroundStyle(.white)
    .padding(4)
    .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.75)))
    .fixedSize()
  }
}
