import Foundation

extension String {
    func trimmingCharacters() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isBlank: Bool {
        return self.trimmingCharacters().isEmpty
    }
    
    func truncated(toLength length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        } else {
            return self
        }
    }
    
    func containsIgnoringCase(_ string: String) -> Bool {
        return self.range(of: string, options: .caseInsensitive) != nil
    }
    
    func highlightedMarkdown() -> AttributedString {
        do {
            return try AttributedString(markdown: self)
        } catch {
            return AttributedString(self)
        }
    }
}