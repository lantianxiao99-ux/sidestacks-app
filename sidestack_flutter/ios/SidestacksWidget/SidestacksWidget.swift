import WidgetKit
import SwiftUI

// ─── Shared data model ────────────────────────────────────────────────────────

struct WidgetData {
  var monthIncome: Double
  var monthProfit: Double
  var monthExpenses: Double
  var currencySymbol: String
  var monthLabel: String
  var topStackName: String?
  var stackCount: Int

  static var empty: WidgetData {
    WidgetData(
      monthIncome: 0,
      monthProfit: 0,
      monthExpenses: 0,
      currencySymbol: "$",
      monthLabel: "–",
      topStackName: nil,
      stackCount: 0
    )
  }

  static func fromDefaults() -> WidgetData {
    guard let shared = UserDefaults(suiteName: "group.com.sidestacks.app") else {
      return .empty
    }
    return WidgetData(
      monthIncome: shared.double(forKey: "monthIncome"),
      monthProfit: shared.double(forKey: "monthProfit"),
      monthExpenses: shared.double(forKey: "monthExpenses"),
      currencySymbol: shared.string(forKey: "currencySymbol") ?? "$",
      monthLabel: shared.string(forKey: "monthLabel") ?? "–",
      topStackName: shared.string(forKey: "topStackName"),
      stackCount: shared.integer(forKey: "stackCount")
    )
  }

  func formattedIncome() -> String {
    formatAmount(monthIncome)
  }

  func formattedProfit() -> String {
    let prefix = monthProfit < 0 ? "−" : ""
    return "\(prefix)\(formatAmount(abs(monthProfit)))"
  }

  func formattedExpenses() -> String {
    formatAmount(monthExpenses)
  }

  private func formatAmount(_ value: Double) -> String {
    let absVal = abs(value)
    if absVal >= 1_000_000 {
      return "\(currencySymbol)\(String(format: "%.1fM", absVal / 1_000_000))"
    } else if absVal >= 10_000 {
      return "\(currencySymbol)\(String(format: "%.0fK", absVal / 1_000))"
    } else {
      return "\(currencySymbol)\(String(format: "%.0f", absVal))"
    }
  }

  var profitColor: Color {
    monthProfit >= 0 ? Color(hex: "0D9488") : Color(hex: "64748B")
  }
}

// ─── Timeline provider ────────────────────────────────────────────────────────

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), data: .empty)
  }

  func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
    completion(SimpleEntry(date: Date(), data: .fromDefaults()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
    let entry = SimpleEntry(date: Date(), data: .fromDefaults())
    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
    completion(timeline)
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let data: WidgetData
}

// ─── Small widget view ────────────────────────────────────────────────────────

struct SmallWidgetView: View {
  let data: WidgetData

  var body: some View {
    ZStack {
      Color("WidgetBackground")
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 4) {
          Circle()
            .fill(Color(hex: "0D9488"))
            .frame(width: 6, height: 6)
          Text("SideStacks")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: "94A3B8"))
          Spacer()
        }
        .padding(.bottom, 8)

        Text(data.monthLabel)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(Color(hex: "94A3B8"))

        Text(data.formattedIncome())
          .font(.system(size: 22, weight: .bold))
          .minimumScaleFactor(0.6)
          .foregroundColor(.primary)
          .padding(.top, 1)

        Spacer()

        HStack(spacing: 3) {
          Image(systemName: data.monthProfit >= 0 ? "arrow.up" : "arrow.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(data.profitColor)
          Text(data.formattedProfit())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(data.profitColor)
          Text("profit")
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(Color(hex: "94A3B8"))
        }

        if data.stackCount > 0 {
          Text("\(data.stackCount) stack\(data.stackCount == 1 ? "" : "s")")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(Color(hex: "CBD5E1"))
            .padding(.top, 2)
        }
      }
      .padding(14)
    }
  }
}

// ─── Medium widget view ───────────────────────────────────────────────────────

struct MediumWidgetView: View {
  let data: WidgetData

  var body: some View {
    ZStack {
      Color("WidgetBackground")
        .ignoresSafeArea()

      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 5) {
            Circle()
              .fill(Color(hex: "0D9488"))
              .frame(width: 6, height: 6)
            Text("SideStacks")
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(Color(hex: "94A3B8"))
          }
          Spacer()
          Text(data.monthLabel + " income")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color(hex: "94A3B8"))
          Text(data.formattedIncome())
            .font(.system(size: 24, weight: .bold))
            .minimumScaleFactor(0.5)
            .foregroundColor(.primary)
            .padding(.top, 1)
          HStack(spacing: 4) {
            Image(systemName: data.monthProfit >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
              .font(.system(size: 11))
              .foregroundColor(data.profitColor)
            Text("\(data.formattedProfit()) profit")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(data.profitColor)
          }
          .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        Rectangle()
          .fill(Color(hex: "1E293B").opacity(0.4))
          .frame(width: 1)
          .padding(.vertical, 10)

        VStack(alignment: .leading, spacing: 10) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Expenses")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(Color(hex: "94A3B8"))
            Text(data.formattedExpenses())
              .font(.system(size: 16, weight: .bold))
              .foregroundColor(Color(hex: "64748B"))
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(hex: "0F172A").opacity(0.5))
          .cornerRadius(10)

          if let name = data.topStackName {
            VStack(alignment: .leading, spacing: 2) {
              Text("Top stack")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "94A3B8"))
              Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "0F172A").opacity(0.5))
            .cornerRadius(10)
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
    }
  }
}

// ─── Entry view ───────────────────────────────────────────────────────────────

struct SidestacksWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: Provider.Entry

  var body: some View {
    switch family {
    case .systemSmall:
      SmallWidgetView(data: entry.data)
    case .systemMedium:
      MediumWidgetView(data: entry.data)
    default:
      SmallWidgetView(data: entry.data)
    }
  }
}

// ─── Widget declaration ───────────────────────────────────────────────────────

struct SidestacksWidget: Widget {
  let kind: String = "SidestacksWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      if #available(iOS 17.0, *) {
        SidestacksWidgetEntryView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      } else {
        SidestacksWidgetEntryView(entry: entry)
      }
    }
    .configurationDisplayName("SideStacks")
    .description("Your monthly income at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// ─── Preview ─────────────────────────────────────────────────────────────────

#Preview(as: .systemSmall) {
  SidestacksWidget()
} timeline: {
  SimpleEntry(date: .now, data: WidgetData(
    monthIncome: 3240,
    monthProfit: 2180,
    monthExpenses: 1060,
    currencySymbol: "A$",
    monthLabel: "May",
    topStackName: "Photography",
    stackCount: 3
  ))
}

// ─── Color hex helper ─────────────────────────────────────────────────────────

extension Color {
  init(hex: String) {
    let scanner = Scanner(string: hex)
    _ = scanner.scanString("#")
    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255
    let g = Double((rgb >> 8) & 0xFF) / 255
    let b = Double(rgb & 0xFF) / 255
    self.init(red: r, green: g, blue: b)
  }
}
