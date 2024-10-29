import Foundation

#if os(macOS)
let LS_CID = "scFuxkwp1ltvcC4DJ4Ji kOj2DK6Q864om"
#elseif os(tvOS)
let LS_CID = "zxRyen2m uz.l57AK1x-onG37BM8N78Bq"
#elseif os(watchOS)
let LS_CID = ".cWimz9dysogQz2HJ6L73dXoqoH6M9A3f8Er"
#elseif os(visionOS)
let LS_CID = "-kVoty5wvjrkHty8Q3O66.E nwx1O786g67Kv"
#else // iOS
let LS_CID = "oqVfhw.i6 38e84BHfDprfc85DO5M9Fm"
#endif
let LS_LIB_NAME = "swift_client"
let LS_LIB_VERSION = "6.2.0"

let TLCP_VERSION = "TLCP-2.5.0"
let FULL_TLCP_VERSION = TLCP_VERSION + ".lightstreamer.com"
