//
//  InlineTextDiff.swift
//  GrammarPolice
//
//  Word-level insert/delete markup for toast + Explore. Whitespace-split
//  so Slack markers stay attached to their tokens.
//

import AppKit
import Foundation
import SwiftUI

enum InlineTextDiff {
    static func nsAttributed(
        from original: String,
        to updated: String,
        baseFont: NSFont,
        baseColor: NSColor,
        insertColor: NSColor,
        deleteColor: NSColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let oldTokens = tokens(original)
        let newTokens = tokens(updated)

        if oldTokens == newTokens {
            result.append(NSAttributedString(string: updated, attributes: [
                .font: baseFont,
                .foregroundColor: baseColor
            ]))
            return result
        }

        let difference = newTokens.difference(from: oldTokens)
        var insertions: [Int: String] = [:]
        var removals: Set<Int> = []
        for change in difference {
            switch change {
            case .insert(let offset, let element, _):
                insertions[offset] = element
            case .remove(let offset, _, _):
                removals.insert(offset)
            }
        }

        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldTokens.count || newIndex < newTokens.count {
            if let inserted = insertions[newIndex] {
                if result.length > 0 { result.append(space(baseFont, baseColor)) }
                result.append(NSAttributedString(string: inserted, attributes: [
                    .font: baseFont,
                    .foregroundColor: insertColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]))
                newIndex += 1
                continue
            }
            if oldIndex < oldTokens.count, removals.contains(oldIndex) {
                if result.length > 0 { result.append(space(baseFont, baseColor)) }
                result.append(NSAttributedString(string: oldTokens[oldIndex], attributes: [
                    .font: baseFont,
                    .foregroundColor: deleteColor,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ]))
                oldIndex += 1
                continue
            }
            if oldIndex < oldTokens.count, newIndex < newTokens.count {
                if result.length > 0 { result.append(space(baseFont, baseColor)) }
                result.append(NSAttributedString(string: newTokens[newIndex], attributes: [
                    .font: baseFont,
                    .foregroundColor: baseColor
                ]))
                oldIndex += 1
                newIndex += 1
                continue
            }
            break
        }

        return result
    }

    static func attributed(from original: String, to updated: String) -> AttributedString {
        let ns = nsAttributed(
            from: original,
            to: updated,
            baseFont: NSFont.systemFont(ofSize: 13),
            baseColor: NSColor.labelColor,
            insertColor: NSColor.systemGreen,
            deleteColor: NSColor.systemRed
        )
        return AttributedString(ns)
    }

    static func hasChanges(from original: String, to updated: String) -> Bool {
        tokens(original) != tokens(updated)
    }

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private static func space(_ font: NSFont, _ color: NSColor) -> NSAttributedString {
        NSAttributedString(string: " ", attributes: [
            .font: font,
            .foregroundColor: color
        ])
    }
}
