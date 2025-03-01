import SwiftUI

@main
struct IndexerApp: App {
   var body: some Scene {
       WindowGroup {
           ContentView()
               .frame(minWidth: 800, minHeight: 600)
       }
       .windowStyle(HiddenTitleBarWindowStyle())
   }
}
