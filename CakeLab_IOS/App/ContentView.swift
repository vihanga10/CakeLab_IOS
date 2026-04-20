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
    @State private var widgetRoute: WidgetDeepLinkRoute?
    
    var body: some View {
        Group {
            if user.role == .customer {
                CustomerTabView(user: user, widgetRoute: $widgetRoute)
            } else if user.role == .baker {
                BakerTabView(user: user, widgetRoute: $widgetRoute)
            } else {
                Text("Unknown role")
            }
        }
        .onOpenURL { url in
            widgetRoute = WidgetDeepLinkRoute(url: url)
        }
        .task {
            WidgetDataSyncManager.shared.refreshFromCurrentSession()
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



#Preview {
    ContentView()
}
