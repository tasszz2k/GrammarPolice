//
//  UsageTracker.swift
//  GrammarPolice
//
//  Tracks monthly OpenAI token spend in USD against a soft cap.
//

import Foundation
import Combine

@MainActor
final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    @Published private(set) var monthlySpendUSD: Double = 0.0
    @Published private(set) var periodKey: String = ""

    private let defaults = UserDefaults.standard
    private let spendKey = "GrammarPoliceMonthlySpendUSD"
    private let periodStorageKey = "GrammarPoliceMonthlySpendPeriod"

    // Per 1M tokens, USD. Public OpenAI list prices; update when prices change.
    private struct ModelPricing {
        let inputPer1M: Double
        let outputPer1M: Double
    }

    private static let pricing: [String: ModelPricing] = [
        "gpt-5":           ModelPricing(inputPer1M: 1.25,  outputPer1M: 10.00),
        "gpt-5-mini":      ModelPricing(inputPer1M: 0.25,  outputPer1M: 2.00),
        "gpt-5-nano":      ModelPricing(inputPer1M: 0.05,  outputPer1M: 0.40),
        "gpt-4o":          ModelPricing(inputPer1M: 2.50,  outputPer1M: 10.00),
        "gpt-4o-mini":     ModelPricing(inputPer1M: 0.15,  outputPer1M: 0.60),
        "gpt-4.1":         ModelPricing(inputPer1M: 2.00,  outputPer1M: 8.00),
        "gpt-4.1-mini":    ModelPricing(inputPer1M: 0.40,  outputPer1M: 1.60),
        "gpt-4.1-nano":    ModelPricing(inputPer1M: 0.10,  outputPer1M: 0.40),
        "gpt-4-turbo":     ModelPricing(inputPer1M: 10.00, outputPer1M: 30.00),
        "gpt-4":           ModelPricing(inputPer1M: 30.00, outputPer1M: 60.00),
        "gpt-3.5-turbo":   ModelPricing(inputPer1M: 0.50,  outputPer1M: 1.50)
    ]

    private init() {
        let current = Self.currentPeriodKey()
        let storedPeriod = defaults.string(forKey: periodStorageKey) ?? current

        if storedPeriod == current {
            monthlySpendUSD = defaults.double(forKey: spendKey)
            periodKey = storedPeriod
        } else {
            monthlySpendUSD = 0.0
            periodKey = current
            defaults.set(0.0, forKey: spendKey)
            defaults.set(current, forKey: periodStorageKey)
        }
    }

    // MARK: - Recording

    func record(model: String, promptTokens: Int, completionTokens: Int) {
        rolloverIfNeeded()

        guard let price = Self.pricing[model] else {
            LoggingService.shared.log("UsageTracker: no pricing for model '\(model)', spend not updated", level: .debug)
            return
        }

        let cost = (Double(promptTokens) / 1_000_000.0) * price.inputPer1M
                 + (Double(completionTokens) / 1_000_000.0) * price.outputPer1M

        monthlySpendUSD += cost
        defaults.set(monthlySpendUSD, forKey: spendKey)

        LoggingService.shared.log(
            "UsageTracker: +$\(String(format: "%.5f", cost)) (model=\(model), in=\(promptTokens), out=\(completionTokens)), monthTotal=$\(String(format: "%.4f", monthlySpendUSD))",
            level: .debug
        )
    }

    func resetMonth() {
        monthlySpendUSD = 0.0
        periodKey = Self.currentPeriodKey()
        defaults.set(0.0, forKey: spendKey)
        defaults.set(periodKey, forKey: periodStorageKey)
    }

    // MARK: - Helpers

    func progressFraction(cap: Double) -> Double {
        guard cap > 0 else { return 0 }
        return min(max(monthlySpendUSD / cap, 0), 1)
    }

    func isOverCap(_ cap: Double) -> Bool {
        return cap > 0 && monthlySpendUSD >= cap
    }

    private func rolloverIfNeeded() {
        let current = Self.currentPeriodKey()
        if current != periodKey {
            monthlySpendUSD = 0.0
            periodKey = current
            defaults.set(0.0, forKey: spendKey)
            defaults.set(current, forKey: periodStorageKey)
        }
    }

    private static func currentPeriodKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}
