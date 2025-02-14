//
//  AuthorHeader.swift
//  Design
//
//  Created by Sam on 2024-03-27.
//

import SwiftUI

extension TimelinePostCell {

    struct AuthorHeader: View {
        let displayName: String
        let fullAccountName: String
        
        var body: some View {
            HStack(spacing: 4) {
                Text(displayName)
                    .bold()
                    .foregroundStyle(.primary)
                Text(verbatim: fullAccountName)
                Spacer()
                Text("5m")
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .font(.callout)
        }
    }
}

//#Preview {
//    TimelinePostCell.AuthorHeader()
//}
