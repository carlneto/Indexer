import Foundation

public class CharIndex {
    
    public enum ResourceType: Int { case file = 1, dict }
    public typealias Resource = (type: CharIndex.ResourceType, name: String)
    typealias Resources = [CharIndex.Resource]
    public typealias Reference = (excerpt: String, location: Int, resource: CharIndex.Resource)
    public typealias References = [CharIndex.Reference]
    typealias Entry = (word: String, references: CharIndex.References)
    typealias Entries = [CharIndex.Entry]
    
    static let nullChar = Character("\0")
    static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-'")
    static let notAllowed = CharIndex.allowed.inverted
    static let referenceSize = 30
    
    let insertions = Atomic(0)
    
    private lazy var operationQueue: OperationQueue = {
        let operation = OperationQueue()
        operation.name = "CharIndex.operationQueue"
        operation.maxConcurrentOperationCount = 1
        return operation
    }()
    
    private(set) var char = CharIndex.nullChar
    var usage = 0
    var references = CharIndex.References()
    var sibling: CharIndex?
    var child: CharIndex?
    
    init() {}
    
    init(char: Character) {
        self.char = char
    }
    
    init(aCharIndex: CharIndex) {
        self.char = aCharIndex.char
        self.usage = aCharIndex.usage
        self.references = aCharIndex.references
        self.sibling = aCharIndex.sibling
        self.child = aCharIndex.child
    }
    
    func insert(text: String, nIndex: Set<String>, resource: CharIndex.Resource, master: IndexController?) -> Int {
        let group = text.words(simplify: true, referenceSize: CharIndex.referenceSize)
        var sum = 0
        for item in group {
            guard item.token.count > 1 else { continue }
            var location = 0
            for word in item.token.components(separatedBy: CharIndex.notAllowed) {
                let loc = location + item.location
                location += word.count + 1
                guard word.count > 1, !nIndex.contains(word) else {
                    continue
                }
                self.insert(word: word, reference: (excerpt: item.excerpt, location: loc, resource: resource), master: master)
                sum += 1
            }
        }
        return sum
    }
    
    private func insert(word: String, reference: CharIndex.Reference, master: IndexController?) {
        self.insertions.increase()
        self.operationQueue.addOperation {
            self.insert(word: word, reference: reference, parent: nil)
            if self.insertions.decreased == 0 {
                master?.didInsert()
            }
        }
    }
    
    private func insert(word: String, reference: CharIndex.Reference, parent: CharIndex?) {
        var letters = word
        let chr = letters.removeFirst()
        var actual = self
        if actual.char == chr {
            actual.usage += 1
        } else if actual.char == CharIndex.nullChar {
            actual.char = chr
            actual.usage += 1
        }  else {
            var siblingCharIndex = actual.sibling
            var previous = [CharIndex]()
            while let aCharIndex = siblingCharIndex {
                previous.append(actual)
                actual = aCharIndex
                if actual.char == chr {
                    break
                }
                siblingCharIndex = siblingCharIndex?.sibling
            }
            if siblingCharIndex == nil {
                actual.sibling = CharIndex(char: chr)
                previous.append(actual)
                actual = actual.sibling!
            }
            actual.usage += 1
            if let last = previous.last, last.usage < actual.usage {
                var penultCharIndex: CharIndex?
                for priorCharIndex in previous {
                    if priorCharIndex.usage < actual.usage {
                        last.sibling = actual.sibling
                        actual.sibling = priorCharIndex
                        if penultCharIndex == nil {
                            if parent != nil {
                                parent?.child = actual
                            } else {
                                actual = self.head(actual)
                            }
                        } else {
                            penultCharIndex?.sibling = actual
                        }
                        break
                    }
                    penultCharIndex = priorCharIndex
                }
            }
        }
        guard let aChar = letters.first else {
            actual.references.append(reference)
            return
        }
        if actual.child == nil {
            actual.child = CharIndex(char: aChar)
        }
        actual.child?.insert(word: letters, reference: reference, parent: actual)
    }
    
    private func head(_ head: CharIndex) -> CharIndex {
        let selfCopy = CharIndex(aCharIndex: self)
        self.char = head.char
        self.usage = head.usage
        self.references = head.references
        self.sibling = selfCopy
        self.child = head.child
        return self
    }
    
    func remove(resource: CharIndex.Resource, master: IndexController?) {
        guard !resource.name.isEmpty else { return }
        self.operationQueue.addOperation {
            let removed = self.remove(resource: resource)
            print("removed: \(removed) resource: \(resource.name)")
            self.balance()
            master?.didInsert()
        }
    }
    
    private func remove(resource: CharIndex.Resource) -> Int {
        var usages = self.child?.remove(resource: resource) ?? 0
        var toRemove = [Int]()
        for (i, selfReference) in self.references.enumerated() {
            if selfReference.resource.name == resource.name {
                toRemove.append(i)
            }
        }
        usages += toRemove.count
        for i in toRemove.reversed() {
            self.references.remove(at: i)
        }
        self.usage -= usages
        return usages + (self.sibling?.remove(resource: resource) ?? 0)
    }
    
    func balance(master: IndexController?) {
        self.operationQueue.addOperation {
            self.balance()
            master?.didInsert()
        }
    }
    
    private func balance() {
        let selfCopy = CharIndex(aCharIndex: self)
        let head = selfCopy.balanced()
        if self.char != head.char {
            self.char = head.char
            self.usage = head.usage
            self.references = head.references
            self.sibling = head.sibling
            self.child = head.child
        }
    }
    
    private func balanced() -> CharIndex {
        var root = self
        guard root.sibling != nil else {
            root.child = root.child?.balanced()
            return root
        }
        var siblings = [root]
        var actual = root.sibling
        var siblingUsage = root.usage
        var needSort = false
        while let sibling = actual {
            if !needSort, siblingUsage < sibling.usage {
                needSort = true
            }
            siblingUsage = sibling.usage
            siblings.append(sibling)
            actual = actual?.sibling
        }
        if needSort {
            siblings.sort(by: { $0.usage > $1.usage } )
            for (i, aSibling) in siblings.enumerated() {
                aSibling.sibling = siblings[at: i + 1]
            }
            root = siblings.first ?? root
        }
        actual = root
        while let charIndex = actual {
            charIndex.child = charIndex.child?.balanced()
            actual = actual?.sibling
        }
        return root
    }
    
    func find(word: String, suffixes: Bool) -> CharIndex.Entry {
        let letters = word.simple
        guard !letters.isEmpty else {
            return (word: "", references: [])
        }
        return (word: letters, references: self.find(chars: letters, enlarged: suffixes))
    }
    
    private func find(chars: String, enlarged: Bool) -> CharIndex.References {
        var letters = chars
        let chr = letters.removeFirst()
        var actual: CharIndex? = self
        while actual != nil {
            if actual?.char == chr {
                if letters.isEmpty {
                    var refs = actual?.references ?? []
                    if enlarged {
                        for entry in actual?.child?.inserted().entries ?? [] {
                            refs += entry.references
                        }
                    }
                    return refs
                } else {
                    return actual?.child?.find(chars: letters, enlarged: enlarged) ?? []
                }
            }
            actual = actual?.sibling
        }
        return []
    }
    
    func letters(until level: Int) -> Set<String> {
        var lettersArr = Set<String>()
        self.letters(chars: "", level: level, lettersArr: &lettersArr)
        return lettersArr
    }
    
    private func letters(chars: String, level: Int, lettersArr: inout Set<String>) {
        let str = "\(chars)\(self.char)"
        lettersArr.insert(str)
        self.sibling?.letters(chars: chars, level: level, lettersArr: &lettersArr)
        guard level > 1 else { return }
        self.child?.letters(chars: str, level: level - 1, lettersArr: &lettersArr)
    }
    
    func inserted() -> (entries: CharIndex.Entries, total: Int, biggestWord: String) {
        var wordsCount = 0
        var wordsIndexed = CharIndex.Entries()
        var biggestWord = ""
        self.inserted(chars: "", wordsCount: &wordsCount, wordsIndexed: &wordsIndexed, biggestWord: &biggestWord)
        return (wordsIndexed, wordsCount, biggestWord)
    }
    
    private func inserted(chars: String, wordsCount: inout Int, wordsIndexed: inout CharIndex.Entries, biggestWord: inout String) {
        let str = "\(chars)\(self.char)"
        let wordCount = self.references.count
        if wordCount > 0 {
            wordsCount += wordCount
            wordsIndexed.append(CharIndex.Entry(word: str, references: self.references))
            if str.count > biggestWord.count {
                biggestWord = str
            }
        }
        self.sibling?.inserted(chars: chars, wordsCount: &wordsCount, wordsIndexed: &wordsIndexed, biggestWord: &biggestWord)
        self.child?.inserted(chars: str, wordsCount: &wordsCount, wordsIndexed: &wordsIndexed, biggestWord: &biggestWord)
    }
}
