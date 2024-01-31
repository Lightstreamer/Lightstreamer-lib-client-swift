import Foundation

#if os(macOS)
let LS_CID = "scFuxkwp1ltvcC4CJ5Ji kOj2DK6Q775gf"
#elseif os(tvOS)
let LS_CID = "zxRyen2m uz.l56AL1x-onG37BM8M893j"
#elseif os(watchOS)
let LS_CID = ".cWimz9dysogQz2HJ5L83dXoqoH6M9A2g96k"
#elseif os(visionOS)
let LS_CID = "-kVoty5wvjrkHty8Q3N67.E nwx1O786f78Co"
#else // iOS
let LS_CID = "oqVfhw.i6 38e74CHfDprfc85DO4NA7f"
#endif
let LS_LIB_NAME = "swift_client"
let LS_LIB_VERSION = "6.1.1"

let TLCP_VERSION = "TLCP-2.5.0"
let FULL_TLCP_VERSION = TLCP_VERSION + ".lightstreamer.com"
