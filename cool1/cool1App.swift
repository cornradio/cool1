//
//  cool1App.swift
//  cool1
//
//  Created by shrimp on 2025/3/20.
//

import SwiftUI

@main
struct cool1App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
