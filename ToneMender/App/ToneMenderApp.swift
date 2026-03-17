//
//  ToneMenderApp.swift
//  ToneMender
//
//  Created by Evan McHugh on 3/12/26.
//

import SwiftUI

@main
struct ToneMenderApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(appViewModel)
        }
    }
}
