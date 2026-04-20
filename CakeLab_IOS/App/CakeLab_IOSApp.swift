//
//  CakeLab_IOSApp.swift
//  CakeLab_IOS
//
//  Created by Vihanga Madushamini on 2026-04-03.
//
import SwiftUI
import FirebaseCore


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


  var body: some Scene {
    WindowGroup {
      SplashView()
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            WidgetDataSyncManager.shared.refreshFromCurrentSession()
          }
        }
    }
  }
}
