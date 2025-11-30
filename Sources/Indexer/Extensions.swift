import WebKit

public extension Array {
    subscript(mod index: Index) -> Element {
        return self[modIndex(index)]
    }
    subscript(at index: Index) -> Element? {
        guard 0 ..< self.count ~= index else { return nil }
        return self[index]
    }
    func upTo(_ index: Index) -> [Element] {
        return Array(self.prefix(upTo: Swift.min(index, self.count)))
    }
    func modIndex(_ index: Index) -> Index {
        return ((index % self.count) + self.count) % self.count
    }
    mutating func swapIndexes(i: Int, j: Int) {
        self.swapAt(modIndex(i), modIndex(j))
    }
    mutating func move(from sourceIndex: Int, to destinationIndex: Int, before: Bool = true) {
        let fromIdx = modIndex(sourceIndex)
        let toIdx = before ? modIndex(destinationIndex) : modIndex(destinationIndex + 1)
        guard fromIdx != toIdx else { return }
        guard Swift.abs(toIdx - fromIdx) != 1 else {
            self.swapAt(fromIdx, toIdx)
            return
        }
        self.insert(self.remove(at: fromIdx), at: fromIdx < toIdx ? toIdx - 1 : toIdx)
    }
    mutating func pick(at idx: Int) -> Element? {
        guard 0 ..< self.count ~= idx, self.count > 0 else { return nil }
        return self.remove(at: idx)
    }
    mutating func reverse(between index1: Int, and index2: Int) {
        if let ans = reversed(between: index1, and: index2) {
            self = ans
        }
    }
    func reversed(between index1: Int, and index2: Int) -> Array? {
        guard index1 != index2, 0..<self.count ~= index1, 0..<self.count ~= index2 else { return nil }
        if index1 > index2 {
            let reversed = Array((self[(index1 + 1) ..< self.count] + self[0 ..< index2]).reversed())
            let arr = Array(self[index2 ... index1] + reversed)
            let cut = self.count - index2
            return Array(arr[cut ..< self.count] + arr[0 ..< cut])
        } else {
            let arr0 = self[0 ... index1]
            let arr1 = Array(self[(index1 + 1) ..< index2].reversed())
            let arr2 = self[index2 ..< self.count]
            return arr0 + arr1 + arr2
        }
    }
    func chunk(max size: Int) -> [[Element]] {
        return Swift.stride(from: 0, to: self.count, by: size).compactMap {
            Array(self[$0 ..< Swift.min($0 + size, self.count)])
        }
    }
}

public final class Atomic<V> {
    private let q = DispatchQueue(label: "Atomic serial queue")
    private var v: V
    init(_ value: V) {
        self.v = value
    }
    var value: V {
        get { return q.sync { self.v } }
        set { self.mutate { $0 = newValue } }
    }
    func mutate(_ transform: (inout V) -> ()) {
        q.sync { transform(&self.v) }
    }
}
public extension Atomic where V == Int {
    func increase(n: Int = 1) {
        mutate { $0 += n }
    }
    var increased: V {
        increase()
        return value
    }
    func decrease(n: Int = 1) {
        mutate { $0 -= n }
    }
    var decreased: V {
        decrease()
        return value
    }
    var str: String {
        return "\(value)"
    }
}

public final class BenchTimer {
    var startTime = CFAbsoluteTimeGetCurrent()
    public init() { }
    public var elapsed: CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    public var milliseconds: CFAbsoluteTime {
        return 1000 * (CFAbsoluteTimeGetCurrent() - startTime)
    }
    public func restart() {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    public func str(reset: Bool = false, zeros: Int = 3, leading: String = "", trailing: String = "") -> String {
        let ans = "\(leading)\(elapsed.zeros(zeros))\(trailing)"
        if reset { restart() }
        return ans
    }
}

public extension Double {
    func zeros(_ decimals: Int) -> String {
        return String(format: "%.\(decimals)f", self)
    }
    func rounded(to unit: Double) -> Double {
        return (self / unit).rounded() * unit
    }
}

public extension Int {
    func rounded(to unit: Int) -> Int {
        return Int(Double(self).rounded(to: Double(unit)))
    }
}

public extension RangeReplaceableCollection {
    mutating func rotate(shift: Int) {
        let positions = ((shift % self.count) + self.count) % self.count
        let index = self.index(self.startIndex, offsetBy: positions, limitedBy: self.endIndex) ?? self.endIndex
        let slice = self[..<index]
        self.removeSubrange(..<index)
        self.insert(contentsOf: slice, at: self.endIndex)
    }
    func rotated(shift: Int) -> Self {
        var arr = self
        arr.rotate(shift: shift)
        return arr
    }
}

public extension String {
    subscript (index: Int) -> Character {
        let charIndex = self.index(self.startIndex, offsetBy: index)
        return self[charIndex]
    }
    subscript(_ range: CountableRange<Int>) -> String {
        let start = self.index(self.startIndex, offsetBy: Swift.max(0, range.lowerBound))
        let end = self.index(start, offsetBy: Swift.min(self.count - range.lowerBound, range.upperBound - range.lowerBound))
        return String(self[start..<end])
    }
    subscript(_ range: CountablePartialRangeFrom<Int>) -> String {
        let start = self.index(self.startIndex, offsetBy: Swift.max(0, range.lowerBound))
        return String(self[start...])
    }
    subscript (range: Range<Int>) -> Substring {
        let startIndex = self.index(self.startIndex, offsetBy: range.startIndex)
        let stopIndex = self.index(self.startIndex, offsetBy: range.startIndex + range.count)
        return self[startIndex..<stopIndex]
    }
    var smallSpaced: String {
        return self.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression, range: nil).replacingOccurrences(of: "  +", with: " ", options: .regularExpression, range: nil)
    }
    static var compatible: CharacterSet {
        let comp = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~£ª«¬­°·º»¿ÀÁÂÃÇÈÉÊÌÍÎÑÒÓÔÕÙÚÜàáâãçèéêìíîñòóôõùúûü–—‘’‚“”•…€ \n"
        return CharacterSet(charactersIn: comp)
    }
    func compatibilized(separator: String = " ") -> String {
        return self.titleCased(separator: separator).components(separatedBy: String.compatible.inverted).joined(separator: separator).smallSpaced
    }
    func titleCased(separator: String = " ") -> String {
        return self
            .replacingOccurrences(of: "([a-z])([A-Z](?=[A-Z])[a-z]*)", with: "$1\(separator)$2", options: .regularExpression)
            .replacingOccurrences(of: "([A-Z])([A-Z][a-z])", with: "$1\(separator)$2", options: .regularExpression)
            .replacingOccurrences(of: "([a-z])([A-Z][a-z])", with: "$1\(separator)$2", options: .regularExpression)
            .replacingOccurrences(of: "([a-z])([A-Z][a-z])", with: "$1\(separator)$2", options: .regularExpression)
    }
    func words(simplify: Bool, referenceSize: Int) -> [(token: String, location: Int, excerpt: String)] {
        var tokens: [(token: String, location: Int, excerpt: String)] = []
        let range = NSRange(location: 0, length: self.utf16.count)
        let options: NSLinguisticTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = self
        tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: options) { _, tokenRange, _ in
            let token = (self as NSString).substring(with: tokenRange)
            if referenceSize > 0 {
                let lBound = Swift.max(0, (tokenRange.location + tokenRange.length / 2) - referenceSize / 2)
                let aLenght = Swift.max(0, Swift.min(lBound + referenceSize, range.length) - lBound)
                let selfNsString = self as NSString
                let excerpt = selfNsString.substring(with: NSRange(location: lBound, length: aLenght))
                tokens.append((token: simplify ? token.simple : token, location: tokenRange.location, excerpt: excerpt))
            } else {
                tokens.append((token: simplify ? token.simple : token, location: tokenRange.location, excerpt: ""))
            }
        }
        return tokens
    }
    var searchable: String {
        return self.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: nil)
    }
    var prepareSearch: String {
        guard !self.isEmpty else { return self }
        let other = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-'_ ").inverted
        return self.searchable.trimmingCharacters(in: .whitespaces).components(separatedBy: other).joined()
    }
    var simple: String {
        let simple = self.trimmingCharacters(in: .illegalCharacters)
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .symbols)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return simple.searchable
    }
    func matches(regularExpression regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
    func matching(regex: String) -> String? {
        guard let range = self.range(of: regex, options: .regularExpression, range: nil, locale: nil) else { return nil }
        let matched = String(self[range])
        return matched
    }
    func matches(regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.compactMap {
                String(self[Range($0.range, in: self)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    func matching(pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let str = self as NSString
        let textCheckingResults = regex.matches(in: self, range: NSMakeRange(0, str.length))
        return textCheckingResults.compactMap { result in
            (0..<result.numberOfRanges).compactMap {
                result.range(at: $0).location != NSNotFound ? str.substring(with: result.range(at: $0)) : ""
            }
        }
    }
    func near(location: Int, size: Int) -> String {
        guard location >= 0, size > 0, location < self.count else { return self }
        let trailing = location - size / 2
        let left = Swift.max(0, trailing)
        let right = Swift.min(self.utf16.count, size + left)
        let range = left..<right
        let ret = String(self[range])
        return ret
    }
    func keyForSaving(_ val: Any, sync: Bool = true) {
        func perform(_ key: String) {
            guard !key.isEmpty else { return }
            let userDefaults = UserDefaults.standard
            userDefaults.set(val, forKey: key)
            userDefaults.synchronize()
        }
        let key = self
        sync ? perform(key) : DispatchQueue.global(qos: .background).async { perform(key) }
    }
    func keyForSavingObject(_ val: Any, sync: Bool = true) {
        func perform(_ key: String) {
            guard !key.isEmpty else { return }
            do {
                let userDefaults = UserDefaults.standard
                let data = try NSKeyedArchiver.archivedData(withRootObject: val, requiringSecureCoding: true)
                userDefaults.set(data, forKey: self)
                userDefaults.synchronize()
            } catch {
                print("Failed to convert UIColor to Data : \(error.localizedDescription)")
            }
        }
        let key = self
        sync ? perform(key) : DispatchQueue.global(qos: .background).async { perform(key) }
    }
    func keyForReadString() -> String? {
        guard !isEmpty else { return nil }
        return UserDefaults.standard.string(forKey: self)
    }
    func keyForReadStrings() -> [String] {
        guard !isEmpty else { return [String]() }
        return UserDefaults.standard.stringArray(forKey: self) ?? [String]()
    }
    func keyForReadObject(ofClasses: AnyClass...) -> Any? {
        guard !isEmpty else { return nil }
        do {
            guard let data = UserDefaults.standard.object(forKey: self) as? Data else { return nil }
            guard let obj = try NSKeyedUnarchiver.unarchivedObject(ofClasses: ofClasses, from: data) else { return nil }
            return obj
        } catch {
            print("Failed to convert UIColor to Data : \(error.localizedDescription)")
            return nil
        }
    }
    func keyToRemoveObject(sync: Bool) {
        func perform(_ key: String) {
            guard !key.isEmpty else { return }
            let userDefaults = UserDefaults.standard
            userDefaults.removeObject(forKey: key)
            userDefaults.synchronize()
        }
        let key = self
        sync ? perform(key) : DispatchQueue.global(qos: .background).async { perform(key) }
    }
    func writeFile(name: String, atomically: Bool = false) -> Error? {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(name)
            do { try self.write(to: fileURL, atomically: atomically, encoding: .utf8) } catch { return error }
        }
        return nil
    }
    func readFile() -> String? {
        if !self.isEmpty, let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(self)
            do { return try String(contentsOf: fileURL, encoding: .utf8) } catch { print(error) }
        }
        return nil
    }
}

public extension StringProtocol {
    func leftIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        self.range(of: string, options: options)?.lowerBound
    }
    func rightIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        self.range(of: string, options: options)?.upperBound
    }
    func substringRange<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Range<Index>? {
        return self.range(of: string, options: options)
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        var indices: [Index] = []
        var startIndex = self.startIndex
        while startIndex < self.endIndex, let range = self[startIndex...].range(of: string, options: options) {
            indices.append(range.lowerBound)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound : self.index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return indices
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < self.endIndex, let range = self[startIndex...].range(of: string, options: options) {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound : self.index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

public extension UserDefaults {
    func object<T: Codable>(_ type: T.Type, with key: String, usingDecoder decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = self.value(forKey: key) as? Data else { return nil }
        return try? decoder.decode(type.self, from: data)
    }
    func set<T: Codable>(object: T, forKey key: String, usingEncoder encoder: JSONEncoder = JSONEncoder()) {
        let data = try? encoder.encode(object)
        self.set(data, forKey: key)
        self.synchronize()
    }
}

public extension WKWebView {
    func load(_ urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            self.load(request)
        }
    }
}
