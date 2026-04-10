//
//  TaskCompletionGraphView.swift
//  ai_anti_doomscroll
//
//  Month-by-month line graph of tasks completed per day.
//

import SwiftUI
import Charts

struct TaskCompletionGraphView: View {
    let completedTodos: [Todo]

    @State private var currentMonthOffset: Int = 0
    @Environment(\.systemColorScheme) private var colorScheme

    private let calendar = Calendar.current

    // MARK: - Month helpers

    private var currentMonthStart: Date {
        let now = Date()
        let comps = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: comps)!
    }

    private var displayedMonthStart: Date {
        calendar.date(byAdding: .month, value: currentMonthOffset, to: currentMonthStart)!
    }

    private var earliestMonthStart: Date {
        let dates = completedTodos.compactMap { $0.completedAt ?? $0.createdAt }
        guard let earliest = dates.min() else { return currentMonthStart }
        let comps = calendar.dateComponents([.year, .month], from: earliest)
        return calendar.date(from: comps)!
    }

    private var canGoBack: Bool { displayedMonthStart > earliestMonthStart }
    private var canGoForward: Bool { currentMonthOffset < 0 }

    // MARK: - Data

    private struct DayPoint: Identifiable {
        let id: Int  // day number 1...31
        let count: Int
    }

    private var dataPoints: [DayPoint] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonthStart) else { return [] }

        var countByDay: [Int: Int] = [:]
        for todo in completedTodos {
            let date = todo.completedAt ?? todo.createdAt
            guard calendar.isDate(date, equalTo: displayedMonthStart, toGranularity: .month) else { continue }
            let day = calendar.component(.day, from: date)
            countByDay[day, default: 0] += 1
        }

        return range.map { day in DayPoint(id: day, count: countByDay[day] ?? 0) }
    }

    private var totalThisMonth: Int { dataPoints.reduce(0) { $0 + $1.count } }

    private var maxCount: Int { max(dataPoints.map(\.count).max() ?? 0, 3) }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonthStart)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Productivity")
                        .font(.headline)
                    Text("Tasks completed this month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(totalThisMonth) done")
                    .font(.caption).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.13))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            }

            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { currentMonthOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                        .foregroundColor(canGoBack ? .primary : Color.secondary.opacity(0.25))
                        .frame(width: 32, height: 32)
                }
                .disabled(!canGoBack)

                Spacer()

                Text(monthLabel)
                    .font(.subheadline).bold()
                    .id(monthLabel)
                    .transition(.opacity)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { currentMonthOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundColor(canGoForward ? .primary : Color.secondary.opacity(0.25))
                        .frame(width: 32, height: 32)
                }
                .disabled(!canGoForward)
            }

            // Line graph
            Chart(dataPoints) { point in
                // Shaded area under the line
                AreaMark(
                    x: .value("Day", point.id),
                    y: .value("Tasks", point.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green.opacity(0.22), Color.green.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // Line
                LineMark(
                    x: .value("Day", point.id),
                    y: .value("Tasks", point.count)
                )
                .foregroundStyle(Color.green.opacity(0.85))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                // Dots only where count > 0
                if point.count > 0 {
                    PointMark(
                        x: .value("Day", point.id),
                        y: .value("Tasks", point.count)
                    )
                    .foregroundStyle(Color.green)
                    .symbolSize(28)
                }
            }
            .chartXAxis {
                AxisMarks(values: stride(from: 1, through: dataPoints.count, by: 7).map { $0 }) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                        .foregroundStyle(Color.secondary.opacity(0.18))
                    AxisValueLabel {
                        if let day = value.as(Int.self) {
                            Text("\(day)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                        .foregroundStyle(Color.secondary.opacity(0.18))
                    AxisValueLabel {
                        if let n = value.as(Int.self) {
                            Text("\(n)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...maxCount)
            .frame(height: 150)
            .animation(.easeInOut(duration: 0.22), value: currentMonthOffset)
        }
        .padding(16)
        .background(AppTheme.cardBg(for: colorScheme))
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }
}
