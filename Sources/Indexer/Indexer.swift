import PDFKit

public protocol IndexController {
    func didInsert()
    func didFind(references: CharIndex.References, increment: Bool, for text: String)
}

public class Indexer {
    
    private var notIndex = Set<String>()
    private var prefixes = Set<String>()
    private var charIndex: CharIndex
    lazy var operationQueue: OperationQueue = {
        let operation = OperationQueue()
        operation.name = "Indexer.operationQueue"
        operation.qualityOfService = .userInitiated
        operation.maxConcurrentOperationCount = 1
        return operation
    }()
    
    public init() {
        self.charIndex = CharIndex()
        guard let path = Bundle.main.path(forResource: "ndexar", ofType: "txt") else { return }
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let text = data.components(separatedBy: .whitespacesAndNewlines)
            for ndex in text {
                self.notIndex.insert(ndex)
            }
        } catch {
            print(error)
        }
        DispatchQueue.global(qos: .utility).async {
            guard let path = Bundle.main.path(forResource: "prefixes", ofType: "txt") else { return }
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let text = data.components(separatedBy: .whitespacesAndNewlines)
                for prefix in text {
                    self.prefixes.insert(prefix)
                }
            } catch {
                print(error)
            }
        }
    }
    
    public func insert(fileName: String, fileExtension ext: String = "txt", master: IndexController?) -> Int {
        self.insert(name: fileName, fileExtension: ext, controller: master)
    }
    
    private func insert(name fileName: String, fileExtension ext: String = "txt", controller master: IndexController?) -> Int {
        if ext.lowercased() == "pdf" {
            if let path = Bundle.main.url(forResource: fileName, withExtension: "pdf"),
                let doc = PDFDocument(url: path), let text = doc.string {
                let name = "\(fileName).txt"
                if let error = text.compatibilized().writeFile(name: name, atomically: true) {
                    print("not writeFile: \(error)")
                } else if let txtFile = name.readFile() {
                    return self.insert(text: txtFile, resource: CharIndex.Resource(type: .file, name: name), master: master)
                } else { print("not inserted: \(fileName)") }
            }
        } else if let path = Bundle.main.path(forResource: fileName, ofType: ext) {
            do {
                let txtFile = try String(contentsOfFile: path, encoding: .utf8)
                let name = path.components(separatedBy: "/").last ?? ""
                return self.insert(text: txtFile, resource: CharIndex.Resource(type: .file, name: name), master: master)
            } catch { print("not inserted: \(error)") }
        }
        return 0
    }
    
    public func insert(text: String, resource: CharIndex.Resource, master: IndexController?) -> Int {
        return self.charIndex.insert(text: text, nIndex: self.notIndex, resource: resource, master: master)
    }
    
    public func remove(resource: CharIndex.Resource, master: IndexController?) {
        self.charIndex.remove(resource: resource, master: master)
    }
    
    public func balance(master: IndexController?) {
        self.charIndex.balance(master: master)
    }
    
    public func find(text: String, master: IndexController) {
        self.find(string: text, master: master)
    }
    
    private func find(string text: String, master: IndexController) {
        self.operationQueue.cancelAllOperations()
        master.didFind(references: [], increment: false, for: text)
        self.operationQueue.addOperation {
            guard self.operationQueue.operationCount == 1, text.count > 1 else {
                return
            }
            let tokens = text.components(separatedBy: CharacterSet(charactersIn: "- ")).filter { !$0.isEmpty }
            if tokens.count > 1 {
                self.find(tokens: tokens, from: text, master: master)
                return
            }
            let tot = text.count
            master.didFind(references: self.find(letters: text, suffixes: false).references, increment: false, for: text)
            let finded = self.find(letters: text, suffixes: true)
            master.didFind(references: finded.references, increment: false, for: text)
            var insetted = Set<String>()
            for reference in finded.references {
                insetted.insert("\(reference.excerpt)\(reference.resource.name)")
            }
            let prxRefs = self.find(letters: text, prefixes: tot, insetted: &insetted)
            master.didFind(references: prxRefs, increment: true, for: text)
            let refs = self.find(regex: text, insetted: &insetted)
            master.didFind(references: refs, increment: true, for: text)
        }
    }
    
    private func find(tokens: [String], from text: String, master: IndexController) {
        var entries = CharIndex.Entries()
        for token in tokens.reversed() {
            if self.notIndex.contains(token) || token.count < 3 { continue }
            entries.append(self.find(letters: token, suffixes: true))
        }
        var insetted = Set<String>()
        let maxSize = 512, j = 1 , maxDist = tokens.count * 10, unit = maxDist * 25
        for i in j ... (j + 2) {
            guard self.operationQueue.operationCount == 1 else { return }
            let dist = maxDist * i * 3
            func compare(item: CharIndex.Entry, items: CharIndex.Entries) -> CharIndex.References {
                if items.count > 0 {
                    let refs = compare(item: items[0], items: Array(items[1..<items.endIndex]))
                    var refers = CharIndex.References()
                    for ref1 in refs {
                        for ref0 in item.references {
                            guard self.operationQueue.operationCount == 1 else { return [] }
                            guard refers.count < maxSize else { break }
                            if ref0.resource.name == ref1.resource.name, Swift.abs(ref0.location - ref1.location) < dist {
                                refers.append(ref1)
                            }
                        }
                    }
                    return refers
                }
                return item.references
            }
            let refers = compare(item: entries[0], items: Array(entries[1..<entries.endIndex]))
            var singleReferences = CharIndex.References()
            for refer in refers {
                if insetted.insert("\(refer.location.rounded(to: unit))\(refer.resource.name)").inserted {
                    singleReferences.append(refer)
                }
            }
            master.didFind(references: singleReferences, increment: i != j, for: text)
        }
    }
    
    private func find(letters: String, suffixes: Bool) -> CharIndex.Entry {
        let charIndexCopy = self.charIndex
        return charIndexCopy.find(word: letters, suffixes: suffixes)
    }
    
    private func find(letters: String, prefixes level: Int, insetted: inout Set<String>) -> CharIndex.References {
        guard level > 0 else { return [] }
        let charIndexCopy = self.charIndex
        var prefixeSet = self.prefixes
        if level > 3 { for p in charIndexCopy.letters(until: level) { prefixeSet.insert(p) } }
        prefixeSet.remove("\0")
        prefixeSet.remove("")
        var references = CharIndex.References()
        for prefix in prefixeSet {
            let finded2 = charIndexCopy.find(word: "\(prefix)\(letters)", suffixes: true)
            for reference in finded2.references {
                if insetted.insert("\(reference.excerpt)\(reference.resource.name)").inserted {
                    references.append(reference)
                }
            }
        }
        return references
    }
    
    private func find(regex fromLetters: String, insetted: inout Set<String>) -> CharIndex.References {
        var references = CharIndex.References()
        let charIndexCopy = self.charIndex
        let entries = charIndexCopy.inserted().entries
        var regex = ".*"
        if fromLetters.starts(with: "^") {
            regex = fromLetters
        } else {
            for letter in Array(fromLetters) { regex += "\(letter).*" }
        }
        for entry in entries {
            guard entry.word.matches(regularExpression: regex) else { continue }
            for reference in entry.references {
                guard insetted.insert("\(reference.excerpt)\(reference.resource.name)").inserted else { continue }
                references.append(reference)
            }
        }
        return references
    }
    
    func inserted() -> (entries: CharIndex.Entries, total: Int, biggestWord: String) {
        let charIndexCopy = self.charIndex
        let charIndexInserted = charIndexCopy.inserted()
        return charIndexInserted
    }
    
    public func indexed() -> (count: Int, bigWord: String) {
        let idxed = self.inserted()
        return (idxed.total, idxed.biggestWord)
    }
    
    func prt(details: Bool = false) {
        let t = BenchTimer()
        let all = self.inserted()
        if details {
            var lines = [[String]]()
            var sizes = [0, 0]
            for wordIndexed in (all.entries.sorted { $0.0 < $1.0 }) {
                let lin0 = "\(wordIndexed.references.count)", lin1 = "\(wordIndexed.word)", lin2 = "\(wordIndexed.references.description)"
                sizes[0] = Swift.max(sizes[0], lin0.count)
                sizes[1] = Swift.max(sizes[1], lin1.count)
                lines.append([lin0, lin1, lin2])
            }
            for line in lines {
                let s0 = String(repeating: " ", count: sizes[0] - line[0].count + 1)
                let s1 = String(repeating: " ", count: sizes[1] - line[1].count + 1)
                print("\(line[0])\(s0)\(line[1])\(s1)\(line[2])")
            }
        }
        print(t.str(reset: true, zeros: 3, leading: "indexed: \(all.total) \tt"))
    }
}
