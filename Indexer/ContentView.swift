import UtilsPackage
import SwiftUI
import QuickLook
import QuickLookUI
import Foundation
import PDFKit
import UniformTypeIdentifiers

// MARK: - ViewModel
class IndexerViewModel: ObservableObject, IndexController {
   @Published var indexer = Indexer()
   @Published var searchQuery = ""
   @Published var searchResults: [Reference] = []
   @Published var isIndexing = false
   @Published var selectedFolder: URL?
   @Published var indexStats: (count: Int, bigWord: String) = (0, "")
   @Published var selectedReference: Reference?
   @Published var fileContent: String = ""
   @Published var selectedLine: Int = 0
   
   // MARK: - Indexação
   func selectFolder() {
      let panel = NSOpenPanel()
      panel.allowsMultipleSelection = false
      panel.canChooseDirectories = true
      panel.canChooseFiles = false
      if panel.runModal() == .OK {
         guard let url = panel.url else { return }
         self.selectedFolder = url
         self.startIndexing(folderURL: url)
      }
   }
   
   func startIndexing(folderURL: URL) {
      self.isIndexing = true
      Task {
         await MainActor.run {
            let startTime = DispatchTime.now()
            self.indexer.insertFolderParallel(folderURL: folderURL, master: self) { [weak self] insertedCount in
               guard let self else { return }
               self.updateStats()
               startTime.elapsed(comment: "End indexing async: \(self.indexStats.count.spaces())")
            }
         }
      }
   }
   
   func updateStats() {
      self.indexStats = self.indexer.indexed()
   }
   
   // MARK: - Pesquisa
   func performSearch() {
      if self.searchQuery.count >= 3 {
         self.indexer.find(text: self.searchQuery, master: self)
      } else {
         self.searchResults = []
      }
   }
   
   // MARK: - Visualização de conteúdo
   func openFile(reference: Reference) {
      self.selectedReference = reference
      let url = reference.url
      do {
         let content = try url.readTextContent()
         self.fileContent = content
         self.selectedLine = reference.location
         let lines = content.components(separatedBy: .newlines)
         var cumulativeCount = 0
         for line in lines {
            cumulativeCount += line.count + 1
            if cumulativeCount >= self.selectedLine {
               self.selectedLine = cumulativeCount
               break
            }
         }
      } catch {
         self.fileContent = "Erro ao abrir o ficheiro: \(error.localizedDescription)"
      }
   }
   
   // MARK: - IndexController Protocol
   func didInsert() {
      DispatchQueue.main.async { [weak self] in
         guard let self = self else { return }
         self.isIndexing = false
         self.updateStats()
      }
   }
   
   func didFind(references: References, increment: Bool, for text: String) {
      DispatchQueue.main.async { [weak self] in
         guard let self = self else { return }
         if self.searchQuery == text {
            if increment {
               self.searchResults.append(contentsOf: references)
            } else {
               self.searchResults = references
            }
         }
      }
   }
}

// MARK: - Vista principal
struct ContentView: View {
   @StateObject private var viewModel = IndexerViewModel()
   @State private var isPresentingFolderPicker = false
   
   var body: some View {
      NavigationSplitView {
         VStack {
            // Barra de pesquisa
            HStack {
               Image(systemName: "magnifyingglass")
                  .foregroundColor(.secondary)
               TextField("Pesquisar...", text: $viewModel.searchQuery)
                  .textFieldStyle(RoundedBorderTextFieldStyle())
                  .onChange(of: self.viewModel.searchQuery) { _, newValue in
                     if newValue.count >= 3 { viewModel.performSearch() }
                  }
               if !self.viewModel.searchQuery.isEmpty {
                  Button(action: {
                     self.viewModel.searchQuery = ""
                     self.viewModel.searchResults = []
                  }) {
                     Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                  }
                  .buttonStyle(PlainButtonStyle())
               }
            }
            .padding([.horizontal, .top])
            
            // Lista de resultados
            List(self.viewModel.searchResults, id: \.location) { reference in
               VStack(alignment: .leading) {
                  Text(reference.url.lastPathComponent)
                     .font(.headline)
                  Text(reference.excerpt)
                     .font(.subheadline)
                     .lineLimit(2)
               }
               .padding(.vertical, 4)
               .onTapGesture {
                  self.viewModel.openFile(reference: reference)
               }
            }
            .listStyle(SidebarListStyle())
            
            // Estatísticas e controles
            VStack {
               Divider()
               HStack {
                  Button(action: {
                     self.viewModel.selectFolder()
                  }) {
                     Label("Escolher Pasta", systemImage: "folder.badge.plus")
                  }
                  .disabled(self.viewModel.isIndexing)
                  Spacer()
                  if self.viewModel.isIndexing {
                     ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                     Text("A indexar...")
                        .font(.caption)
                  } else if self.viewModel.indexStats.count > 0 {
                     Text("\(self.viewModel.indexStats.count) referências")
                        .font(.caption)
                  }
               }
               .padding(.horizontal)
               .padding(.bottom, 8)
               if let folder = self.viewModel.selectedFolder {
                  HStack {
                     Text("Pasta: \(folder.lastPathComponent)")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                     Spacer()
                  }
                  .padding(.horizontal)
                  .padding(.bottom, 8)
               }
            }
         }
      } detail: {
         if let reference = self.viewModel.selectedReference {
            DocumentView(fileContent: self.viewModel.fileContent, selectedLine: self.viewModel.selectedLine, reference: reference)
         } else {
            VStack {
               Image(systemName: "doc.text.magnifyingglass")
                  .font(.system(size: 72))
                  .foregroundColor(.secondary)
                  .opacity(0.5)
               Text("Selecione um resultado para visualizar o seu conteúdo")
                  .font(.headline)
                  .foregroundColor(.secondary)
                  .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
         }
      }
      .frame(minWidth: 800, minHeight: 600)
      .navigationTitle("Indexer")
   }
}

// MARK: - Visualização de documentos
struct DocumentView: View {
   let fileContent: String
   let selectedLine: Int
   let reference: Reference
   @State private var scrollTarget: Int?
   
   var body: some View {
      VStack {
         HStack {
            Text(self.reference.url.lastPathComponent)
               .font(.headline)
            Spacer()
            Button(action: {
               NSWorkspace.shared.open(self.reference.url)
            }) {
               Label("Abrir no Finder", systemImage: "arrow.up.forward.app")
                  .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
         }
         .padding([.horizontal, .top])
         Divider()
         
         QuickLookPreview(url: self.reference.url)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(NSColor.textBackgroundColor))
   }
   
   // Determina se uma linha deve ser destacada
   private func isTargetLine(_ index: Int) -> Bool {
      return index == self.scrollTarget
   }
   
   // Encontra o índice da linha baseado na localização do caractere
   private func findLineIndexForLocation(_ location: Int) -> Int {
      let lines = self.fileContent.components(separatedBy: .newlines)
      var currentPos = 0
      for (index, line) in lines.enumerated() {
         let lineLength = line.count + 1  // +1 para o caractere de nova linha
         if currentPos <= location && location < currentPos + lineLength {
            return index
         }
         currentPos += lineLength
      }
      // Fallback se não encontrarmos a posição exata
      return Swift.min(location / 50, lines.count - 1)
   }
}

// Componente QuickLookPreview
struct QuickLookPreview: NSViewRepresentable {
   let url: URL
   func makeNSView(context: Context) -> QLPreviewView {
      // Desembrulha de forma segura o QLPreviewView
      guard let previewView = QLPreviewView(frame: .zero, style: .normal) else {
         fatalError("Unable to create QLPreviewView")
      }
      previewView.autostarts = true
      return previewView
   }
   func updateNSView(_ nsView: QLPreviewView, context: Context) {
      nsView.previewItem = PreviewItem(url: url)
   }
}

// Classe que encapsula o URL para conformar com QLPreviewItem
class PreviewItem: NSObject, QLPreviewItem {
   let url: URL
   init(url: URL) { self.url = url }
   var previewItemURL: URL? { self.url }
   var previewItemTitle: String? { self.url.lastPathComponent }
}
