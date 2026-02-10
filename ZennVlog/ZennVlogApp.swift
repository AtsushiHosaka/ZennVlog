//
//  ZennVlogApp.swift
//  ZennVlog
//
//  Created by 保坂篤志 on 2026/01/25.
//

import SwiftUI
import FirebaseCore

@main
struct ZennVlogApp: App {
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
