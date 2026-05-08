//
//  ContentView.swift
//  CakeLab_IOS
//
//  Created by Vihanga Madushamini on 2026-04-03.
//

import SwiftUI

// Controls which auth screen to show: onboarding for new users, biometric for returning users
private enum AuthEntryMode {
    case onboarding
    case biometric
}

// Renders the correct auth screen based on AuthEntryMode
private struct AuthEntryView: View {
    let mode: AuthEntryMode

    var body: some View {
        switch mode {
        case .onboarding:
            OnboardingView()   // Shown on first launch
        case .biometric:
            NavigationStack {
                BiometricAuthView()   // Shown for returning users after sign-out
            }
        }
    }
}

// MARK: - Wrapper for navigation
// Routes authenticated users to the correct tab view based on their role (customer or baker)
struct ContentViewWrapper: View {
    let user: AppUser
    @State private var widgetRoute: WidgetDeepLinkRoute?   // Holds the deep link route from a widget tap

    var body: some View {
        Group {
            if user.role == .customer {
                CustomerTabView(user: user, widgetRoute: $widgetRoute)   // Customer main tab UI
            } else if user.role == .baker {
                BakerTabView(user: user, widgetRoute: $widgetRoute)   // Baker main tab UI
            } else {
                Text("Unknown role")
            }
        }
        .onOpenURL { url in
            widgetRoute = WidgetDeepLinkRoute(url: url)   // Parse and store widget deep link on open
        }
        .id("\(user.id)-\(user.role.rawValue)")   // Re-creates view if user or role changes
        .task {
            WidgetDataSyncManager.shared.refreshFromCurrentSession()   // Syncs widget data when app opens
        }
    }
}

// Root view that manages the full app navigation lifecycle
struct ContentView: View {
    @State private var currentUser: AppUser?   // Holds the logged-in user;  when unauthenticated
    @State private var showSplash = true   // Displays splash screen on first launch
    @State private var authEntryMode: AuthEntryMode = .onboarding   // Default to onboarding for fresh installs

    var body: some View {
        Group {
            if showSplash {
                SplashView {
                    showSplash = false   // Dismiss splash when animation completes
                }
            } else if let user = currentUser {
                ContentViewWrapper(user: user)   // Navigate to main app for authenticated user
            } else {
                AuthEntryView(mode: authEntryMode)   // Show auth screen when no user is logged in
            }
        }
        // Called when user successfully logs in; stores user and switches to biometric auth for next session
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidAuthenticate)) { notification in
            guard let user = notification.object as? AppUser else { return }
            currentUser = user
            authEntryMode = .biometric
            showSplash = false
        }
        // Called on sign-out; clears user and shows biometric login screen
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidSignOut)) { _ in
            currentUser = nil
            authEntryMode = .biometric
            showSplash = false
        }
    }
}



#Preview {
    ContentView()
}
