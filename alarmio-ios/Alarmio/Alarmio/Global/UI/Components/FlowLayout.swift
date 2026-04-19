//
//  FlowLayout.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/19/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

/// A simple horizontal-wrapping layout — places children left-to-right and
/// moves to a new row when the next child would overflow. Each row is
/// centered independently within the available width, so partial rows
/// feel balanced rather than left-stuck.
struct FlowLayout: Layout {

    // MARK: - Constants

    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    // MARK: - Layout

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for size in sizes {
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + rowSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: totalWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        var rows: [[Int]] = [[]]
        var rowWidths: [CGFloat] = [0]
        var rowHeights: [CGFloat] = [0]
        var cursorX: CGFloat = 0

        for (index, size) in sizes.enumerated() {
            let additional = rows[rows.count - 1].isEmpty ? size.width : size.width + spacing
            if cursorX + additional > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidths.append(0)
                rowHeights.append(0)
                cursorX = 0
            }
            let isFirstInRow = rows[rows.count - 1].isEmpty
            rows[rows.count - 1].append(index)
            cursorX += isFirstInRow ? size.width : size.width + spacing
            rowWidths[rowWidths.count - 1] = cursorX
            rowHeights[rowHeights.count - 1] = max(rowHeights.last ?? 0, size.height)
        }

        var y = bounds.minY
        for (rowIndex, indices) in rows.enumerated() {
            let rowWidth = rowWidths[rowIndex]
            var x = bounds.minX + (maxWidth - rowWidth) / 2
            for (positionInRow, subviewIndex) in indices.enumerated() {
                let size = sizes[subviewIndex]
                if positionInRow > 0 { x += spacing }
                subviews[subviewIndex].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width
            }
            y += rowHeights[rowIndex] + rowSpacing
        }
    }
}

// MARK: - Previews

#Preview("Flowing Chips") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        FlowLayout(spacing: 8, rowSpacing: 8) {
            ForEach(["Short", "Punchy", "Wake me up gently", "Morning", "Include humor", "Mention the weather", "Affirmation"], id: \.self) { text in
                Text(text)
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
    }
}
