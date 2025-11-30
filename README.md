# 🔎 Indexer: Fast File Content Search

## 📄 Description

**Indexer** is a macOS application designed to quickly index the textual content of files within a selected directory and its subdirectories, allowing for **rapid, real-time searching** across the entire indexed content. It's built using **SwiftUI** and leverages parallel processing to ensure fast indexing performance. The application features a split view for search results and document content viewing, utilizing **QuickLook** for rich file previews.

-----

## 🛠️ Requirements

The project is developed using modern Apple technologies and has the following minimum requirements:

  * **Operating System:** macOS (Minimum version compatible with SwiftUI and required APIs, typically the latest major release, e.g., macOS 14.0+)
  * **Xcode:** 15.0+
  * **Swift:** 5.9+

-----

## ⚙️ Installation

As this is a macOS application project, you typically install it by building from the source code in Xcode.

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/carlneto/Indexer.git
    cd Indexer
    ```
2.  **Open in Xcode:**
    ```bash
    open Indexer.xcodeproj
    ```
3.  **Build and Run:**
      * Select your Mac as the target device.
      * Click the **Run** button (▶︎) or press `Cmd + R`.

The application will launch automatically.

-----

## 🚀 Usage

1.  **Select a Folder:**
      * Click the **"Escolher Pasta"** (Select Folder) button at the bottom of the sidebar, or use the keyboard shortcut **`Cmd + O`**.
      * Choose the root directory you wish to index.
2.  **Indexing:**
      * The application will start indexing the folder's content in parallel. A progress indicator will show **"A indexar..."** (Indexing...) during this process.
      * Upon completion, the status will update to show the total number of indexed references.
3.  **Search:**
      * Start typing your query into the **"Pesquisar..."** (Search...) bar in the sidebar.
      * Search results (references) will appear in the list once you type **3 or more characters**.
4.  **View File Content:**
      * Click on any search result in the list.
      * The main **Detail** view will display a preview of the file using **QuickLook**. The search location within the file is automatically calculated and highlighted (though line-based scrolling is currently being developed/refined in the `DocumentView`).

-----

## 📂 Project Structure

The key files and components in this SwiftUI project are:

| File/Folder | Description |
| :--- | :--- |
| `IndexerApp.swift` | The main application entry point (`@main`) for the SwiftUI app. Defines the main `WindowGroup` and custom application commands (`Cmd + O`). |
| `IndexerViewModel.swift` | The central **`ObservableObject`** responsible for all application logic: managing the indexer state, handling folder selection (`selectFolder`), starting parallel indexing (`startIndexing`), performing searches (`performSearch`), and opening files (`openFile`). Conforms to the `IndexController` protocol (assumed to be in another file). |
| `ContentView.swift` | The primary SwiftUI View, implementing the `NavigationSplitView` structure. It contains the search bar, the results list, and the main detail view logic. |
| `DocumentView.swift` | A SwiftUI View component responsible for displaying the content of the selected file. It uses `QuickLookPreview` for rich previews and includes logic to attempt to find and scroll to the match location. |
| `QuickLookPreview.swift` | A custom `NSViewRepresentable` wrapper to integrate the native **`QLPreviewView`** (QuickLook Preview) into the SwiftUI interface, enabling previews for various file types. |
| `[Other Indexer Logic]` | Assumed external files (e.g., `Indexer.swift`, `Reference.swift`, utility extensions) containing the core file traversal, indexing, and search algorithms. |

-----

## ✨ Main Features

  * **Fast Indexing:** Utilizes parallel processing (`Task` and presumably concurrent queues within `Indexer`'s logic) for quick folder content insertion.
  * **Real-time Search:** Results update immediately as the user types (with a minimum of 3 characters).
  * **macOS Native UI:** Built with **SwiftUI** using a standard `NavigationSplitView` layout for a familiar user experience.
  * **Rich File Previews:** Integration with **QuickLook** to display a wide range of file types (text, images, documents, etc.) in the detail view.
  * **Keyboard Shortcut:** Quick access to the "Select Folder" function via **`Cmd + O`**.

-----

## 📜 License

This software is distributed under a **RESTRICTED USE LICENSE**.

**Key Limitations:**

1.  **Prohibitions:** You may **NOT** modify, adapt, reverse engineer, translate, create derivative works, distribute, sublicense, share, transfer, or engage in any commercial use (sale, rental, monetization) of this software without explicit prior written authorization from the Author.
2.  **Intellectual Property:** The software is the **exclusive property of the Author**. No implied license is granted.
3.  **Permitted Use:** Strictly **personal, private, and non-commercial use is permitted** solely for the purpose of evaluation and testing. Any other use requires express written authorization.
4.  **Disclaimer of Warranties:** The software is provided **"AS IS"** without any warranty (express or implied), including but not limited to merchantability, fitness for a particular purpose, or error-free operation.
5.  **Limitation of Liability:** The Author is **not liable** for any damages (direct, indirect, consequential, etc.) resulting from the use or inability to use the software.

© 2025 Author. All rights reserved.

-----

## 👤 Credits / Authors

  * **Author:** carlneto
  * **Year:** 2025
