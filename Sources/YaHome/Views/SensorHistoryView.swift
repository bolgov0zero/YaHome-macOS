import SwiftUI

struct SensorHistoryView: View {
    let device: Device
    var singleProperty: String? = nil

    @State private var entries: [SensorHistoryEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История показаний (7 дней)")
                .font(.subheadline).foregroundStyle(.secondary)

            let tempData = singleProperty == "humidity" ? [] : entries.filter { $0.temperature != nil }
            let humData  = singleProperty == "temperature" ? [] : entries.filter { $0.humidity != nil }

            if tempData.count < 2 && humData.count < 2 {
                Text("Нет данных. Появятся после следующего обновления.")
                    .foregroundStyle(.secondary).font(.callout)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ChartView(tempEntries: tempData, humEntries: humData)
                    .frame(height: 220)
            }
        }
        .onAppear { entries = HistoryService.shared.entries(for: device.id) }
    }
}

// MARK: - Chart

private struct ChartView: View {
    let tempEntries: [SensorHistoryEntry]
    let humEntries:  [SensorHistoryEntry]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad = EdgeInsets(top: 24, leading: 40, bottom: 32, trailing: 28)
            let cw = w - pad.leading - pad.trailing
            let ch = h - pad.top - pad.bottom

            let allTs = (tempEntries.map(\.ts) + humEntries.map(\.ts))
            let minTs = allTs.min() ?? 0
            let maxTs = allTs.max() ?? 1
            let tsRange = max(maxTs - minTs, 1)
            let toX = { (ts: Double) in pad.leading + CGFloat((ts - minTs) / tsRange) * cw }

            let tempVals = tempEntries.compactMap(\.temperature)
            let humVals  = humEntries.compactMap(\.humidity)

            let tempRange = makeRange(tempVals, pad: 0.15, minPad: 0.5)
            let humRange  = makeRange(humVals,  pad: 0.15, minPad: 2.0)

            let toTempY = { (v: Double) in pad.top + CGFloat(1 - (v - tempRange.lo) / tempRange.span) * ch }
            let toHumY  = { (v: Double) in pad.top + CGFloat(1 - (v - humRange.lo) / humRange.span) * ch }

            ZStack(alignment: .topLeading) {
                // Grid
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { f in
                    let y = pad.top + f * ch
                    Path { p in
                        p.move(to: CGPoint(x: pad.leading, y: y))
                        p.addLine(to: CGPoint(x: pad.leading + cw, y: y))
                    }
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                }

                // Temperature series
                if tempEntries.count >= 2 {
                    let pts = bucket(tempEntries, getValue: { $0.temperature! }, toX: toX, toY: toTempY)
                    SeriesView(points: pts, color: .orange, bottomY: pad.top + ch)
                }

                // Humidity series
                if humEntries.count >= 2 {
                    let pts = bucket(humEntries, getValue: { $0.humidity! }, toX: toX, toY: toHumY)
                    SeriesView(points: pts, color: .blue, bottomY: pad.top + ch)
                }

                // X labels
                let labelTs = xLabels(allTs: allTs.sorted(), count: 5)
                ForEach(labelTs, id: \.self) { ts in
                    Text(formatHHMM(ts))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .position(x: toX(ts), y: h - pad.bottom + 12)
                }

                // Y labels - temp
                if !tempVals.isEmpty {
                    Text(String(format: "%.1f°", tempVals.max()!))
                        .font(.system(size: 9)).foregroundStyle(.orange)
                        .position(x: pad.leading - 18, y: pad.top)
                    Text(String(format: "%.1f°", tempVals.min()!))
                        .font(.system(size: 9)).foregroundStyle(.orange)
                        .position(x: pad.leading - 18, y: pad.top + ch)
                }

                // Y labels - humidity
                if !humVals.isEmpty {
                    Text(String(format: "%.0f%%", humVals.max()!))
                        .font(.system(size: 9)).foregroundStyle(.blue)
                        .position(x: w - pad.trailing + 14, y: pad.top)
                    Text(String(format: "%.0f%%", humVals.min()!))
                        .font(.system(size: 9)).foregroundStyle(.blue)
                        .position(x: w - pad.trailing + 14, y: pad.top + ch)
                }
            }
            .frame(width: w, height: h)
        }
    }

    private func makeRange(_ vals: [Double], pad: Double, minPad: Double) -> (lo: Double, span: Double) {
        guard !vals.isEmpty else { return (0, 1) }
        let lo = vals.min()!, hi = vals.max()!
        let p = max((hi - lo) * pad, minPad)
        let span = max((hi + p) - (lo - p), 0.001)
        return (lo - p, span)
    }

    private func bucket(_ entries: [SensorHistoryEntry], getValue: (SensorHistoryEntry) -> Double,
                        toX: (Double) -> CGFloat, toY: (Double) -> CGFloat, maxBuckets: Int = 30) -> [CGPoint] {
        let src = entries.map { (ts: $0.ts, value: getValue($0)) }
        let reduced: [(ts: Double, value: Double)]
        if src.count <= maxBuckets {
            reduced = src
        } else {
            let minTs = src.first!.ts, maxTs = src.last!.ts
            let size = (maxTs - minTs) / Double(maxBuckets)
            reduced = (0..<maxBuckets).compactMap { i in
                let from = minTs + Double(i) * size
                let to = i == maxBuckets - 1 ? maxTs + 1 : from + size
                let bucket = src.filter { $0.ts >= from && $0.ts < to }
                guard !bucket.isEmpty else { return nil }
                return (ts: bucket.map(\.ts).reduce(0,+) / Double(bucket.count),
                        value: bucket.map(\.value).reduce(0,+) / Double(bucket.count))
            }
        }
        return reduced.map { CGPoint(x: toX($0.ts), y: toY($0.value)) }
    }

    private func xLabels(allTs: [Double], count: Int) -> [Double] {
        guard !allTs.isEmpty else { return [] }
        return (0..<count).map { i in
            let idx = Int((Double(i) / Double(count - 1)) * Double(allTs.count - 1))
            return allTs[min(idx, allTs.count - 1)]
        }
    }

    private func formatHHMM(_ ts: Double) -> String {
        let d = Date(timeIntervalSince1970: ts / 1000)
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

// MARK: - Series renderer

private struct SeriesView: View {
    let points: [CGPoint]
    let color: Color
    let bottomY: CGFloat

    var body: some View {
        ZStack {
            // Gradient fill
            if let area = areaPath() {
                area.fill(LinearGradient(
                    colors: [color.opacity(0.35), color.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            // Line
            if let line = linePath() {
                line.stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            // Dots
            ForEach(points.indices, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .position(points[i])
            }
        }
    }

    private func linePath() -> Path? {
        guard points.count >= 2 else { return nil }
        var p = Path()
        p.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(points.count - 1, i + 2)]
            let t = 0.4
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) * t, y: p1.y + (p2.y - p0.y) * t)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) * t, y: p2.y - (p3.y - p1.y) * t)
            p.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return p
    }

    private func areaPath() -> Path? {
        guard var p = linePath(), let first = points.first, let last = points.last else { return nil }
        p.addLine(to: CGPoint(x: last.x, y: bottomY))
        p.addLine(to: CGPoint(x: first.x, y: bottomY))
        p.closeSubpath()
        return p
    }
}
