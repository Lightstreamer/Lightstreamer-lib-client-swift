/*
 * Copyright (C) 2021 Lightstreamer Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import Foundation
#if LS_JSON_PATCH
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
#endif
