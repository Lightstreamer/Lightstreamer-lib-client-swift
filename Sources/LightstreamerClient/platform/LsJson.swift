import Foundation
import JSONPatch

typealias LsJson = Any

typealias LsJsonPatch = JSONPatch

func newJson(_ str: String) throws -> LsJson {
    return try JSONSerialization.jsonObject(with: str.data(using: .utf8)!)
}

func applyPatch(_ json: LsJson, _ patch: LsJsonPatch) throws -> LsJson {
    return try patch.apply(to: json, options: [.applyOnCopy])
}

func jsonToString(_ json: LsJson) -> String {
    return String(decoding: try! JSONSerialization.data(withJSONObject: json), as: UTF8.self)
}

func newJsonPatch(_ str: String) throws -> LsJsonPatch {
    return try JSONPatch(data: str.data(using: .utf8)!)
}

func jsonPatchToString(_ patch: LsJsonPatch) -> String {
    return String(decoding: try! patch.data(), as: UTF8.self)
}
