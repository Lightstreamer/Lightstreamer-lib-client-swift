import Foundation

#if os(macOS)
let LS_CID_MACOS = "scFuxkwp1ltvcC4DJ4Ji kOj2DK6Q864om"
let LS_CID = LS_CID_MACOS
#elseif os(tvOS)
let LS_CID_TVOS = "zxRyen2m uz.l57AK1x-onG37BM8N78Bq"
let LS_CID = LS_CID_TVOS
#elseif os(watchOS)
let LS_CID_WATCHOS = ".cWimz9dysogQz2HJ6L73dXoqoH6M9A3f8Er"
let LS_CID = LS_CID_WATCHOS
#elseif os(visionOS)
let LS_CID_VISIONOS = "-kVoty5wvjrkHty8Q3O66.E nwx1O786g67Kv"
let LS_CID = LS_CID_VISIONOS
#else // iOS
let LS_CID_IOS = "oqVfhw.i6 38e84BHfDprfc85DO5M9Fm"
let LS_CID = LS_CID_IOS
#endif
let LS_LIB_NAME = "swift_client"
let LS_LIB_VERSION = "6.2.0"

let TLCP_VERSION = "TLCP-2.5.0"
let FULL_TLCP_VERSION = TLCP_VERSION + ".lightstreamer.com"
