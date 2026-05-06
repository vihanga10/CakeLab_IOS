//
//  ContentView.swift
//  CakeLab_IOS
//
//  Created by Vihanga Madushamini on 2026-04-03.
//

import SwiftUI

private enum AuthEntryMode {
    case onboarding
    case biometric
}

private struct AuthEntryView: View {
    let mode: AuthEntryMode

    var body: some View {
        switch mode {
        case .onboarding:
            OnboardingView()
        case .biometric:
            NavigationStack {
                BiometricAuthView()
            }
        }
    }
}

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
        .id("\(user.id)-\(user.role.rawValue)")
        .task {
            WidgetDataSyncManager.shared.refreshFromCurrentSession()
        }
    }
}

struct ContentView: View {
    @State private var currentUser: AppUser?
    @State private var showSplash = true
    @State private var authEntryMode: AuthEntryMode = .onboarding
    
    var body: some View {
        Group {
            if showSplash {
                SplashView {
                    showSplash = false
                }
            } else if let user = currentUser {
                ContentViewWrapper(user: user)
            } else {
                AuthEntryView(mode: authEntryMode)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidAuthenticate)) { notification in
            guard let user = notification.object as? AppUser else { return }
            currentUser = user
            authEntryMode = .biometric
            showSplash = false
        }
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
