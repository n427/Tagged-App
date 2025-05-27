//
//  ReusableProfileContent.swift
//  Tagged
//
//  Created by Nicole Zhang on 2025-05-26.
//

import SwiftUI
import SDWebImageSwiftUI

struct ReusableProfileContent: View {
    var user: User
    var isMyProfile: Bool
    
    var logOutAction: (() -> Void)? = nil
    var deleteAccountAction: (() -> Void)? = nil
    
    @State private var showSettings = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Profile header
                
                HStack {
                    Text(user.username)
                        .font(.system(size: 30))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, -5)
                
                HStack(alignment: .top, spacing: 12) {
                    // Profile Image
                    WebImage(url: user.userProfileURL)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                    // Username, Name, Streak
                    VStack(alignment: .leading, spacing: 4) {

                        Text(user.name)
                            .foregroundColor(.black)
                            .padding(.top, 15)
                            .fontWeight(.bold)

                        HStack(spacing: 0) {
                            Text("4-week")
                                .foregroundColor(.accentColor)
                                .fontWeight(.bold)
                            Text(" streak")
                                .foregroundColor(.black)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.horizontal, 10)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 5)
                .padding(.bottom, 5)

                // Bio (full width, left-aligned under everything)
                HStack {
                    Text(user.userBio)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                // Stats
                HStack(spacing: 0) {
                    VStack {
                        Text("3").bold()
                        Text("posts")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack {
                        Text("80").bold()
                        Text("likes")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack {
                        Text("#4").bold()
                        Text("rank")
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)
                
                if isMyProfile {
                    // Buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            // Edit profile action
                        }) {
                            Text("Edit Profile")
                                .fontWeight(.semibold)
                                .frame(maxWidth: 150)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.accentColor, lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            showSettings.toggle()
                        }) {
                            Text("Settings")
                                .fontWeight(.semibold)
                                .frame(maxWidth: 150)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.accentColor, lineWidth: 1)
                                )
                                
                        }
                        .padding(.bottom, 5)
                        .confirmationDialog("Settings", isPresented: $showSettings, titleVisibility: .visible) {
                            Button(role: .none) {
                                logOutAction?()
                            } label: {
                                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            
                            Button(role: .destructive) {
                                deleteAccountAction?()
                            } label: {
                                Label("Delete Account", systemImage: "trash")
                            }
                        }
                    }
                }

                Divider()

                // Grid of images
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Array(0..<30), id: \.self) { index in
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(8)
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 30) // Avoid scrolling under tab bar
        }
    }
}
