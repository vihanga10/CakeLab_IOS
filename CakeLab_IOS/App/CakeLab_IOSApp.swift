
//  CakeLab_IOSApp.swift
//  CakeLab_IOS

//  Created by Vihanga Madushamini on 2026-04-03.

import SwiftUI
import FirebaseCore
import CoreData
import GoogleSignIn
import UserNotifications


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func application(_ app: UIApplication,
                   open url: URL,
                   options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
  }

  // Shows notifications even when the user is inside the app
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }
}

@main
struct CakeLab_IOSApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var notificationManager = NotificationManager()
  // Accessibility settings 
  @AppStorage("accessibilityHighContrastEnabled") private var highContrastEnabled = false
  @AppStorage("accessibilityDarkModeEnabled") private var darkModeEnabled = false
  @AppStorage("accessibilityFontScale") private var fontScaleRawValue = AccessibilityFontScale.standard.rawValue

  private var accessibilityFontScale: AccessibilityFontScale {
    AccessibilityFontScale(rawValue: fontScaleRawValue) ?? .standard
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .dynamicTypeSize(accessibilityFontScale.dynamicTypeSize)
        .contrast(highContrastEnabled ? 1.2 : 1.0)
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
        .environmentObject(notificationManager)
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            WidgetDataSyncManager.shared.refreshFromCurrentSession()
          }
        }
    }
  }
}
