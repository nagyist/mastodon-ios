// Copyright © 2025 Mastodon gGmbH. All rights reserved.
//
//  InlinePostPreview.swift
//  Design
//
//  Created by Sam on 2024-05-08.
//

import MastodonSDK
import SwiftUI

struct InlinePostPreview: View {
    let viewModel: Mastodon.Entity.Status.ViewModel

    var body: some View {
        VStack(alignment: .leading) {
            header()
            if let content = viewModel.content {
                Text(content)
                    .lineLimit(3)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .stroke(.separator)
        }
    }

    private let tinyAvatarSize: CGFloat = 16
    private let avatarShape = RoundedRectangle(cornerRadius: 4)

    @ViewBuilder func header() -> some View {
        HStack(spacing: 4) {
            if viewModel.needsUserAttribution {
                if let url = viewModel.accountAvatarUrl {
                    AsyncImage(
                        url: url,
                        content: { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(avatarShape)
                        },
                        placeholder: {
                            avatarShape
                                .foregroundStyle(
                                    Color(UIColor.secondarySystemFill))
                        }
                    )
                    .frame(width: tinyAvatarSize, height: tinyAvatarSize)
                }
                Text(viewModel.accountDisplayName ?? "")
                    .bold()
                Text(viewModel.accountFullName ?? "")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else if viewModel.isPinned {
                //  This *should* be a Label but it acts funky when this is in a List
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
    }
}
