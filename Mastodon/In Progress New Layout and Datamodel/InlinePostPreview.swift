// Copyright © 2025 Mastodon gGmbH. All rights reserved.
//
//  InlinePostPreview.swift
//  Design
//
//  Created by Sam on 2024-05-08.
//

import SwiftUI
import MastodonSDK

struct InlinePostPreview: View {
    let viewModel: Mastodon.Entity.Status.ViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                if viewModel.needsUserAttribution {
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 16, height: 16)
                    Text(viewModel.accountDisplayName ?? "")
                        .bold()
                    Text(viewModel.accountFullName ?? "")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else if viewModel.isPinned {
//                    This *should* be a Label but it acts funky when this is in a List (i.e. in UserList)
                    Group {
                        Image(systemName: "pin.fill")
                        Text("Pinned")
                    }
                    .bold()
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                }
            }
            .lineLimit(1)
            .font(.subheadline)
            if let content = viewModel.content {
                Text(content)
                    .lineLimit(3)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .stroke(.separator)
        }
    }
}


//#Preview {
//    VStack {
//        InlinePostPreview(post: SampleData.samplePost)
//        InlinePostPreview(post: SampleData.samplePost, needsUserAttribution: false, isPinned: true)
//    }
//    .padding()
//}
