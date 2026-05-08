//
//  CakeLab_IOSApp.swift
//  CakeLab_IOS
//
//  Created by Vihanga Madushamini on 2026-04-03.
//
import SwiftUI
import FirebaseCore
import CoreData


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct CakeLab_IOSApp: App {
  // register app delegate for Firebase setup
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var notificationManager = NotificationManager()
  @AppStorage("accessibilityHighContrastEnabled") private var highContrastEnabled = false
  @AppStorage("accessibilityFontScale") private var fontScaleRawValue = AccessibilityFontScale.standard.rawValue

  private var accessibilityFontScale: AccessibilityFontScale {
    AccessibilityFontScale(rawValue: fontScaleRawValue) ?? .standard
  }


  var body: some Scene {
    WindowGroup {
      ContentView()
        .preferredColorScheme(.light)
        .dynamicTypeSize(accessibilityFontScale.dynamicTypeSize)
        .contrast(highContrastEnabled ? 1.2 : 1.0)
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
        .environmentObject(notificationManager)
        .notificationOverlay(notificationManager)
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            WidgetDataSyncManager.shared.refreshFromCurrentSession()
          }
        }
    }
  }
}
