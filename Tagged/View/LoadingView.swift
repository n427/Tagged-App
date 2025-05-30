//
//  LoadingView.swift
//  Tagged
//
//  Created by Nicole Zhang on 2025-05-24.
//

import SwiftUI

struct LoadingView: View {
    @Binding var show: Bool
    var body: some View {
        ZStack {
            if show {
                Group {
                    ProgressView()
                        .padding(15)
                        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundColor(Color.accentColor)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: show)
    }
}
