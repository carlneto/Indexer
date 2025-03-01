import SwiftUI
import PDFKit
import WebKit
import UtilsPackage

// MARK: - Modelo de Aplicação
class IndexerAppModel: ObservableObject, IndexController {
   @Published var indexer: Indexer
   @Published var indexerResults: [IndexerResult] = []
   @Published var isIndexing: Bool = false
   @Published var indexStats: (count: Int, bigWord: String) = (0, "")
   @Published var indexerQuery: String = ""
   @Published var lastIndexerQuery: String = ""
   @Published var statusMessage: String = "Pronto"
   @Published var isIndexering: Bool = false
   @Published var selectedResult: IndexerResult?
   private var indexerTask: DispatchWorkItem?
   
   init() {
      indexer = Indexer(loadPersisted: true)
      updateStats()
   }
   
   // MARK: - Métodos de Indexação
   func insertFile(url: URL) {
      let toIndex = CharIndex.Resource.resourceToIndex(url: url)
      guard let resource = toIndex.resource else { return }
      if toIndex.reInsert {
         statusMessage = "O arquivo \(url.lastPathComponent) já está indexado."
         self.indexer.removeSync(resource: resource)
      }
      isIndexing = true
      statusMessage = "A indexar \(url.lastPathComponent)..."
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
         guard let self = self else { return }
         do {
            if url.fileExt.lowercased() == "pdf" {
               if let doc = PDFDocument(url: url),
                  let text = doc.string {
                  let inserted = self.indexer.insert(text: text, resource: resource, master: self)
                  DispatchQueue.main.async {
                     self.statusMessage = "Indexados \(inserted) elementos de \(url.fileName)"
                  }
               }
            } else {
               let text = try String(contentsOf: url, encoding: .utf8)
               let inserted = self.indexer.insert(text: text, resource: resource, master: self)
               DispatchQueue.main.async {
                  self.statusMessage = "Indexados \(inserted) elementos de \(url.fileName)"
               }
            }
         } catch {
            DispatchQueue.main.async {
               self.statusMessage = "Erro ao indexar \(url.fileName): \(error.localizedDescription)"
            }
         }
         DispatchQueue.main.async {
            self.isIndexing = false
            self.updateStats()
            self.saveIndex()
         }
      }
   }
   func insertFolder(url: URL) {
      isIndexing = true
      statusMessage = "A indexar pasta \(url.lastPathComponent)..."
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
         guard let self = self else { return }
         let inserted = self.indexer.insertFolder(folderURL: url, extensions: ["txt", "pdf", "md"], master: self)
         DispatchQueue.main.async {
            self.statusMessage = "Indexados \(inserted) elementos da pasta \(url.lastPathComponent)"
            self.isIndexing = false
            self.updateStats()
            self.saveIndex()
         }
      }
   }
   func removeIndex() {
      indexer.charIndex = CharIndex()
      indexerResults = []
      updateStats()
      _ = indexer.removePersistedIndex()
      statusMessage = "Índice removido"
   }
   func saveIndex() {
      let success = indexer.saveIndex()
      statusMessage = if success { "Índice guardado com sucesso" } else { "Erro ao guardar o índice" }
   }
   func updateStats() {
      indexStats = indexer.indexed()
   }
   
   // MARK: - Métodos de Pesquisa
   func performIndexer() {
      guard indexerQuery.count >= 3 else {
         indexerResults = []
         return
      }
      // Cancela a pesquisa anterior
      indexerTask?.cancel()
      isIndexering = true
      lastIndexerQuery = indexerQuery
      let task = DispatchWorkItem { [weak self] in
         guard let self = self else { return }
         self.indexer.find(text: self.indexerQuery, master: self)
      }
      indexerTask = task
      DispatchQueue.global(qos: .userInitiated).async(execute: task)
   }
   
   // MARK: - Protocolo IndexController
   func didInsert() {
      DispatchQueue.main.async { [weak self] in
         self?.updateStats()
      }
   }
   func didFind(references: CharIndex.References, increment: Bool, for text: String) {
      DispatchQueue.main.async { [weak self] in
         guard let self = self, text == self.lastIndexerQuery else { self?.indexerResults = []; return }
         if !increment {
            self.indexerResults = []
         }
         let newResults = references.map { reference in
            IndexerResult(
               fileURL: reference.resource.url,
               excerpt: reference.excerpt,
               location: reference.location
            )
         }
         // Adiciona novos resultados, evitando duplicados
         let existingKeys = Set(self.indexerResults.map { "\($0.fileURL.fileNameExt)-\($0.location)" })
         for result in newResults {
            let key = "\(result.fileURL.fileNameExt)-\(result.location)"
            if !existingKeys.contains(key) {
               self.indexerResults.append(result)
            }
         }
         self.statusMessage = "Encontrados \(self.indexerResults.count) resultados para '\(text)'"
         self.isIndexering = false
      }
   }
}

// MARK: - Modelo de Resultado de Pesquisa
struct IndexerResult: Identifiable, Hashable {
   let id = UUID()
   let fileURL: URL
   let excerpt: String
   let location: Int
   
   func hash(into hasher: inout Hasher) {
      hasher.combine(id)
   }
   static func == (lhs: IndexerResult, rhs: IndexerResult) -> Bool {
      return lhs.id == rhs.id
   }
}

// MARK: - Vista Principal da Aplicação

struct ContentView: View {
   @StateObject private var model = IndexerAppModel()
   @State private var isShowingFileImporter = false
   @State private var isShowingFolderImporter = false
   @State private var showConfirmationDialog = false
   
   var body: some View {
      NavigationSplitView {
         VStack {
            // Barra de pesquisa
            HStack {
               TextField("Pesquisar...", text: $model.indexerQuery)
                  .textFieldStyle(RoundedBorderTextFieldStyle())
                  .onChange(of: model.indexerQuery) { newValue, _ in
                     if newValue.count >= 3 {
                        model.performIndexer()
                     } else {
                        model.indexerResults = []
                     }
                  }
               Button(action: model.performIndexer) {
                  Image(systemName: "magnifyingglass")
               }
               .disabled(model.indexerQuery.count < 3)
            }
            .padding([.horizontal, .top])
            // Estatísticas
            Text("Elementos indexados: \(model.indexStats.count)")
               .font(.caption)
               .frame(maxWidth: .infinity, alignment: .leading)
               .padding(.horizontal)
            // Lista de resultados com seleção
            List(selection: $model.selectedResult) {
               ForEach(model.indexerResults) { result in
                  VStack(alignment: .leading) {
                     Text(result.fileURL.fileNameExt)
                        .font(.headline)
                     Text(result.excerpt)
                        .font(.body)
                        .lineLimit(2)
                  }
                  .tag(result)
               }
            }
            .listStyle(SidebarListStyle())
            // Barra de estado
            HStack {
               Text(model.statusMessage)
                  .font(.caption)
               Spacer()
               if model.isIndexing || model.isIndexering {
                  ProgressView()
                     .progressViewStyle(CircularProgressViewStyle())
                     .scaleEffect(0.7)
               }
            }
            .padding(.horizontal)
            .frame(height: 30)
         }
      } detail: {
         if let result = model.selectedResult {
            ResultDetailView(result: result)
               .id(result.id)
         } else {
            Text("Selecione um resultado para ver detalhes.")
               .font(.title)
               .foregroundColor(.gray)
         }
      }
      .toolbar {
         ToolbarItem(placement: .automatic) {
            Button(action: { isShowingFileImporter = true }) {
               Label("Adicionar Ficheiro", systemImage: "doc.badge.plus")
            }
         }
         ToolbarItem(placement: .automatic) {
            Button(action: { isShowingFolderImporter = true }) {
               Label("Adicionar Pasta", systemImage: "folder.badge.plus")
            }
         }
         ToolbarItem(placement: .automatic) {
            Button(action: { showConfirmationDialog = true }) {
               Label("Limpar Índice", systemImage: "trash")
            }
         }
         ToolbarItem(placement: .automatic) {
            Button(action: model.saveIndex) {
               Label("Guardar Índice", systemImage: "square.and.arrow.down")
            }
         }
      }
      .fileImporter(
         isPresented: $isShowingFileImporter,
         allowedContentTypes: [.plainText, .pdf],
         allowsMultipleSelection: true
      ) { result in
         switch result {
         case .success(let urls):
            for url in urls {
               model.insertFile(url: url)
            }
         case .failure(let error):
            model.statusMessage = "Erro ao importar ficheiro: \(error.localizedDescription)"
         }
      }
      .fileImporter(
         isPresented: $isShowingFolderImporter,
         allowedContentTypes: [.folder],
         allowsMultipleSelection: false
      ) { result in
         switch result {
         case .success(let urls):
            if let url = urls.first {
               model.insertFolder(url: url)
            }
         case .failure(let error):
            model.statusMessage = "Erro ao importar pasta: \(error.localizedDescription)"
         }
      }
      .confirmationDialog(
         "Tem a certeza que pretende limpar o índice?",
         isPresented: $showConfirmationDialog,
         titleVisibility: .visible
      ) {
         Button("Limpar", role: .destructive) {
            model.removeIndex()
         }
         Button("Cancelar", role: .cancel) { }
      }
   }
}

struct FileViewer: View {
   let fileURL: URL
   @Binding var searchText: String
   @State private var fileLines: [String] = []
   @State private var highlightedLine: Int? = nil
   @State private var isFileLoaded: Bool = false
   
   var body: some View {
      VStack {
         ScrollViewReader { proxy in
            ScrollView {
               LazyVStack(alignment: .leading, spacing: 2) {
                  ForEach(Array(fileLines.enumerated()), id: \.offset) { index, line in
                     Text(attributedString(for: line, searchText: searchText))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(highlightedLine == index ? Color.yellow.opacity(0.5) : Color.clear)
                        .id(index)
                  }
               }
            }
            .onChange(of: highlightedLine) { newValue, _ in
               if let line = newValue {
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                     withAnimation {
                        proxy.scrollTo(line, anchor: .center)
                     }
                  }
               }
            }
         }
      }
      .navigationTitle(fileURL.lastPathComponent)
      .onAppear {
         loadFile()
      }
      .onChange(of: searchText) { _, _ in
         performSearch()
      }
      .onChange(of: isFileLoaded) { _, _ in
         if isFileLoaded && !searchText.isEmpty {
            performSearch()
         }
      }
   }
   
   private func attributedString(for line: String, searchText: String) -> AttributedString {
      if searchText.isEmpty {
         return AttributedString(line)
      }
      
      var attributedString = AttributedString(line)
      
      // Ignora maiúsculas/minúsculas na pesquisa
      let ranges = line.ranges(of: searchText, options: [.caseInsensitive, .diacriticInsensitive])
      
      for range in ranges {
         // Corrigido: substituição de offsetByUtf8 por offsetByCharacters
         let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: line.distance(from: line.startIndex, to: range.lowerBound))
         let endIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: line.distance(from: line.startIndex, to: range.upperBound))
         
         if startIndex < attributedString.endIndex, endIndex <= attributedString.endIndex {
            attributedString[startIndex..<endIndex].backgroundColor = .yellow
            attributedString[startIndex..<endIndex].foregroundColor = .black
            attributedString[startIndex..<endIndex].font = .body.bold()
         }
      }
      
      return attributedString
   }
   
   private func loadFile() {
      do {
         let content = try fileURL.readTextContent()
         fileLines = content.components(separatedBy: .newlines)
         isFileLoaded = true
      } catch {
         fileLines = ["Erro ao carregar ficheiro: \(error.localizedDescription)"]
         isFileLoaded = true
      }
   }
   
   private func performSearch() {
      if searchText.isEmpty {
         highlightedLine = nil
         return
      }
      
      // Encontrar a primeira linha que contém o texto de pesquisa
      if let index = fileLines.firstIndex(where: {
         $0.localizedCaseInsensitiveContains(searchText)
      }) {
         // Usar DispatchQueue para garantir que a UI esteja atualizada
         DispatchQueue.main.async {
            highlightedLine = index
         }
      } else {
         highlightedLine = nil
      }
   }
}

extension String {
   func ranges(of searchString: String, options: NSString.CompareOptions = []) -> [Range<String.Index>] {
      var ranges: [Range<String.Index>] = []
      var searchRange = self.startIndex..<self.endIndex
      
      while let range = self.range(of: searchString, options: options, range: searchRange) {
         ranges.append(range)
         searchRange = range.upperBound..<self.endIndex
      }
      
      return ranges
   }
}

struct FileContentView: View {
   let fileURL: URL
   @State var searchText: String
   
   var body: some View {
      FileViewer(fileURL: fileURL, searchText: $searchText)
   }
}

struct WebViewer: NSViewRepresentable {
   let fileURL: URL
   @Binding var searchText: String
   
   func makeNSView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.load(URLRequest(url: fileURL))
      return webView
   }
   
   func updateNSView(_ webView: WKWebView, context: Context) {
      if !searchText.isEmpty {
         webView.evaluateJavaScript("document.documentElement.innerHTML.includes('\(searchText)')") { (result, error) in
            if let found = result as? Bool, found {
               let script = """
                    function findAndHighlight(text) {
                        window.find('\(searchText)', false, false, true, false, true, false);
                        return true;
                    }
                    findAndHighlight('\(searchText)');
                    """
               webView.evaluateJavaScript(script, completionHandler: nil)
            }
         }
      }
   }
}

struct WebContentView: View {
   let fileURL: URL
   @State var searchText: String
   var body: some View {
      WebViewer(fileURL: fileURL, searchText: $searchText)
         .navigationTitle(fileURL.lastPathComponent)
   }
}

struct PDFViewer: NSViewRepresentable {
   let fileURL: URL
   @Binding var searchText: String
   
   let pdfView = PDFView()
   
   func makeNSView(context: Context) -> PDFView {
      pdfView.autoScales = true
      pdfView.displayMode = .singlePageContinuous
      pdfView.displayDirection = .vertical
      
      if let document = PDFDocument(url: fileURL) {
         pdfView.document = document
      }
      
      return pdfView
   }
   
   func updateNSView(_ nsView: PDFView, context: Context) {
      // Se houver texto para pesquisar, encontra-o e centraliza
      if !searchText.isEmpty,
         let document = nsView.document {
         // Pesquisa a string com opções, por exemplo, insensível a maiúsculas/minúsculas
         let selections = document.findString(searchText, withOptions: .caseInsensitive)
         if let firstSelection = selections.first {
            nsView.setCurrentSelection(firstSelection, animate: true)
            centerSelection(nsView: nsView, selection: firstSelection)
         }
      }
   }
   
   private func centerSelection(nsView: PDFView, selection: PDFSelection) {
      guard let page = selection.pages.first else { return }
      // Obtém o retângulo da seleção na página
      let selectionRect = selection.bounds(for: page)
      // Calcula o centro da seleção
      let selectionCenter = CGPoint(x: selectionRect.midX, y: selectionRect.midY)
      // Cria uma destination para esse ponto
      let destination = PDFDestination(page: page, at: selectionCenter)
      nsView.go(to: destination)
   }
}

struct PDFContentView: View {
   let fileURL: URL
   @State var searchText: String
   var body: some View {
      PDFViewer(fileURL: fileURL, searchText: $searchText)
         .navigationTitle(fileURL.lastPathComponent)
   }
}

// MARK: - Vista de Detalhes do Resultado

struct ResultDetailView: View {
   let result: IndexerResult
   
   var body: some View {
      VStack(alignment: .leading, spacing: 20) {
         // Cabeçalho
         HStack {
            Image(systemName: "doc.text")
               .font(.largeTitle)
            
            VStack(alignment: .leading) {
               Text(result.fileURL.fileNameExt)
                  .font(.title)
               Text("Localização: \(result.fileURL.path)")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
            }
         }
         .padding()
         
         Divider()
         
         // Conteúdo
         if result.fileURL.fileExt.lowercased() == "pdf" {
            PDFContentView(fileURL: result.fileURL, searchText: result.excerpt)
         } else {
            FileContentView(fileURL: result.fileURL, searchText: result.excerpt)
         }
      }
      .padding()
      .frame(minWidth: 400, minHeight: 300)
   }
}
