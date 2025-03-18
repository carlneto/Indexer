import SwiftUI

@main
struct IndexerApp: App {
   var body: some Scene {
       WindowGroup {
           ContentView()
               .frame(minWidth: 800, minHeight: 600)
       }
       .windowStyle(HiddenTitleBarWindowStyle())
       .commands {
           CommandGroup(replacing: .newItem) {
               Button("Escolher Pasta") {
                   NotificationCenter.default.post(name: NSNotification.Name("SelectFolder"), object: nil)
               }
               .keyboardShortcut("O", modifiers: [.command])
           }
       }
   }
}
