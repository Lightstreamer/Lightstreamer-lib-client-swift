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
