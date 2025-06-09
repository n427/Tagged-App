import SwiftUI

struct YearbookView: View {
    let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
    // Dummy data grouped into chunks of 9
    let photoChunks: [[Int]] = stride(from: 0, to: 30, by: 9).map { start in
        Array(start..<min(start + 9, 30))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Yearbook")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 5)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(photoChunks.indices, id: \.self) { chunkIndex in
                        VStack(alignment: .leading, spacing: 12) {
                            // Optional: Subtitle for the section
                            Text("Section \(chunkIndex + 1)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 10)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(photoChunks[chunkIndex], id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 30)
                                                .foregroundColor(.gray.opacity(0.5))
                                        )
                                }
                            }
                            .padding(.horizontal, 8)

                            Divider()
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 15)
        .refreshable{}
    }
}

#Preview {
    YearbookView()
}
