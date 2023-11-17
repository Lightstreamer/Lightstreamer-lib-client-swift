import Foundation

#if os(macOS)
let LS_CID = "scFuxkwp1ltvcC4CJ4Ji kOj2DK6P873mi"
#elseif os(tvOS)
let LS_CID = "zxRyen2m uz.l56AK1x-onG37BM7N879m"
#elseif os(watchOS)
let LS_CID = ".cWimz9dysogQz2HJ5L73dXoqoH6M993g7Cn"
#elseif os(visionOS)
let LS_CID = "-kVoty5wvjrkHty8Q3N66.E nwx1O785g76Ir"
#else // iOS
let LS_CID = "oqVfhw.i6 38e74BHfDprfc85DN5N8Di"
#endif
let LS_LIB_NAME = "swift_client"
let LS_LIB_VERSION = "6.1.0"

let TLCP_VERSION = "TLCP-2.5.0"
let FULL_TLCP_VERSION = TLCP_VERSION + ".lightstreamer.com"
