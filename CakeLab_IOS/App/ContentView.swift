//
//  ContentView.swift
//  CakeLab_IOS
//
//  Created by Vihanga Madushamini on 2026-04-03.
//

import SwiftUI

// MARK: - Wrapper for navigation
struct ContentViewWrapper: View {
    let user: AppUser
    
    var body: some View {
        if user.role == .customer {
            CustomerHomeView(user: user)
        } else if user.role == .baker {
            CrafterHomeView(user: user)
        } else {
            Text("Unknown role")
        }
    }
}

struct ContentView: View {
    @State private var currentUser: AppUser?
    @State private var isLoading = true
    @State private var showOnboarding = true
    
    var body: some View {
        if showOnboarding {
            OnboardingView()
        } else if let user = currentUser {
            // Show role-based home screen
            ContentViewWrapper(user: user)
        } else {
            // Show onboarding if no user
            OnboardingView()
        }
    }
}

// MARK: - Customer Home View
struct CustomerHomeView: View {
    let user: AppUser
    @State private var showLogout = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome, \(user.name.isEmpty ? "Customer" : user.name)")
                        .font(.urbanistBold(24))
                        .foregroundColor(.cakeBrown)
                    
                    Text("Browse delicious cakes")
                        .font(.urbanistRegular(14))
                        .foregroundColor(.cakeGrey)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                
                // Customer-specific content
                ScrollView {
                    VStack(spacing: 16) {
                        // Featured cakes section
                        VStack(alignment: .leading) {
                            Text("Featured Cakes")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakeBrown)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        VStack(spacing: 8) {
                                            Rectangle()
                                                .fill(Color.cakeGrey.opacity(0.2))
                                                .frame(height: 120)
                                                .cornerRadius(12)
                                            
                                            Text("Delicious Cake")
                                                .font(.urbanistSemiBold(12))
                                                .foregroundColor(.cakeBrown)
                                        }
                                        .frame(width: 100)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Categories
                        VStack(alignment: .leading) {
                            Text("Categories")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakeBrown)
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 12) {
                                ForEach(["Chocolates", "Vanilla", "Fruits"], id: \.self) { cat in
                                    Button {
                                        print("Tapped: \(cat)")
                                    } label: {
                                        Text(cat)
                                            .font(.urbanistSemiBold(12))
                                            .foregroundColor(.cakeBrown)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.cakeBrown.opacity(0.1))
                                            .cornerRadius(20)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                }
                
                Spacer()
                
                // Logout button
                Button {
                    showLogout = true
                } label: {
                    Text("Logout")
                        .font(.urbanistSemiBold(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.cakeBrown)
                        .cornerRadius(16)
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Crafter/Baker Home View
struct CrafterHomeView: View {
    let user: AppUser
    @State private var showLogout = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome, Baker \(user.name.isEmpty ? "" : user.name)")
                        .font(.urbanistBold(24))
                        .foregroundColor(.cakeBrown)
                    
                    Text("Manage your cakes and orders")
                        .font(.urbanistRegular(14))
                        .foregroundColor(.cakeGrey)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                
                // Crafter-specific content
                ScrollView {
                    VStack(spacing: 16) {
                        // Stats section
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                // Pending Orders
                                VStack(spacing: 8) {
                                    Text("3")
                                        .font(.urbanistBold(24))
                                        .foregroundColor(.cakeBrown)
                                    Text("Pending Orders")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.cakeGrey)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.cakeBrown.opacity(0.1))
                                .cornerRadius(12)
                                
                                // Active Listings
                                VStack(spacing: 8) {
                                    Text("7")
                                        .font(.urbanistBold(24))
                                        .foregroundColor(.cakeBrown)
                                    Text("Active Listings")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.cakeGrey)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.cakeBrown.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Actions
                        VStack(spacing: 12) {
                            Text("Quick Actions")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakeBrown)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button {
                                print("Add new cake")
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.cakeBrown)
                                    Text("Add New Cake")
                                        .font(.urbanistSemiBold(14))
                                        .foregroundColor(.cakeBrown)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.cakeBrown.opacity(0.05))
                                .cornerRadius(12)
                            }
                            
                            Button {
                                print("View orders")
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "cart.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.cakeBrown)
                                    Text("View Orders")
                                        .font(.urbanistSemiBold(14))
                                        .foregroundColor(.cakeBrown)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.cakeBrown.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                }
                
                Spacer()
                
                // Logout button
                Button {
                    showLogout = true
                } label: {
                    Text("Logout")
                        .font(.urbanistSemiBold(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.cakeBrown)
                        .cornerRadius(16)
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
