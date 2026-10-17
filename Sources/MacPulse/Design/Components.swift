import SwiftUI

// MARK: - Card

/// Flat editorial container: 1px hairline border, generous padding, no shadow.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Space.l
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - Divider

struct Hairline: View {
    var vertical = false
    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

// MARK: - Metric readout

/// Large tabular numeral with a unit and micro-label caption.
struct Metric: View {
    let label: String
    let value: String
    var unit: String? = nil
    var tint: Color = Theme.ink
    var size: CGFloat = 26
    var align: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: align, spacing: 3) {
            MicroLabel(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Theme.Typeface.numeric(size))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(Theme.Typeface.caption(10))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
    }
}

// MARK: - Thin capacity bar

struct MeterBar: View {
    let ratio: Double
    var tint: Color = Theme.ink
    var height: CGFloat = 4

    private var clamped: Double { min(max(ratio, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * clamped))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Segmented stacked bar

/// Shows composition (e.g. memory breakdown) as proportional segments.
struct SegmentedBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let value: Double
        let color: Color
        let label: String
    }

    let segments: [Segment]
    var height: CGFloat = 6

    private var total: Double { max(segments.reduce(0) { $0 + $1.value }, 0.0001) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(segments) { seg in
                    Rectangle()
                        .fill(seg.color)
                        .frame(width: max(0, geo.size.width * (seg.value / total) - 1))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .background(Theme.border.opacity(0.5), in: Capsule())
    }
}

// MARK: - Legend row

struct LegendItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(Theme.Typeface.caption(11))
                .foregroundStyle(Theme.inkSecondary)
            Spacer(minLength: Theme.Space.s)
            Text(value)
                .font(Theme.Typeface.numeric(11, weight: .medium))
                .foregroundStyle(Theme.ink)
        }
    }
}

// MARK: - Status chip

struct StatusChip: View {
    let text: String
    var fg: Color
    var bg: Color

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Typeface.mono(8, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(bg, in: Capsule())
    }
}

// MARK: - Sparkline chart

/// Hairline sparkline with a soft filled underlay and a live end dot.
struct Sparkline: View {
    let values: [Double]
    var tint: Color = Theme.ink
    var capacity: Double = 1.0
    var showBaseline = false

    private var normalized: [Double] {
        guard !values.isEmpty else { return [] }
        let cap = max(capacity, 0.0001)
        return values.map { min(max($0 / cap, 0), 1) }
    }

    var body: some View {
        GeometryReader { geo in
            let pts = normalized
            let w = geo.size.width
            let h = geo.size.height

            if pts.count >= 2 {
                let stepX = w / CGFloat(pts.count - 1)
                let coords = pts.enumerated().map { i, v in
                    CGPoint(x: CGFloat(i) * stepX,
                            y: h - CGFloat(v) * (h - 4) - 2)
                }

                // Filled underlay
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: coords[0])
                    for c in coords.dropFirst() { p.addLine(to: c) }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.14), tint.opacity(0.01)],
                                     startPoint: .top, endPoint: .bottom))

                // Line
                Path { p in
                    p.move(to: coords[0])
                    for c in coords.dropFirst() { p.addLine(to: c) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

                // Live endpoint
                if let last = coords.last {
                    Circle()
                        .fill(tint)
                        .frame(width: 4, height: 4)
                        .position(last)
                }
            } else {
                Hairline()
                    .frame(height: 1)
                    .position(x: w / 2, y: h / 2)
            }
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.Typeface.title(13))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let trailing {
                MicroLabel(text: trailing)
            }
        }
    }
}

// MARK: - Key/value row

struct StatRow: View {
    let key: String
    let value: String
    var valueColor: Color = Theme.ink

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Text(key)
                .font(Theme.Typeface.caption(11))
                .foregroundStyle(Theme.inkSecondary)
            Spacer(minLength: Theme.Space.m)
            Text(value)
                .font(Theme.Typeface.numeric(11, weight: .medium))
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let message: String
    var body: some View {
        Text(message)
            .font(Theme.Typeface.caption(11))
            .foregroundStyle(Theme.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, Theme.Space.xl)
    }
}
