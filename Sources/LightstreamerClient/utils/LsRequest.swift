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

class LsRequest {
    var body: String = ""
    
    var byteSize: Int {
        body.lengthOfBytes(using: .utf8)
    }
    
    func addSubRequest(_ req: String) {
        if body.isEmpty  {
            body = req
        } else {
            body += "\r\n" + req
        }
    }
    
    func addSubRequestOnlyIfBodyIsLessThan(_ req: String, requestLimit: Int) -> Bool {
        if body.isEmpty && req.lengthOfBytes(using: .utf8) <= requestLimit {
            body = req
            return true
        } else if body.lengthOfBytes(using: .utf8) + "\r\n".lengthOfBytes(using: .utf8) + req.lengthOfBytes(using:  .utf8) <= requestLimit {
            body += "\r\n" + req
            return true
        }
        return false
    }
}
