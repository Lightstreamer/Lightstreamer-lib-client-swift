// adapted from https://github.com/apple/swift-collections/blob/main/Sources/OrderedCollections/OrderedDictionary/OrderedDictionary%2BCustomStringConvertible.swift
extension OrderedDictionary: CustomStringConvertible {
  /// A textual representation of this instance.
  public var description: String {
    if isEmpty { return "[:]" }
    var result = "["
    var first = true
    for (key, value) in self {
      if first {
        first = false
      } else {
        result += ", "
      }
      result += "\(key): \(value)"
    }
    result += "]"
    return result
  }
}
