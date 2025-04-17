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

#if os(macOS)
let LS_CID_MACOS = "scFuxkwp1ltvcC4DJ5Ji kOj2DK6R784kl"
let LS_CID = LS_CID_MACOS
#elseif os(tvOS)
let LS_CID_TVOS = "zxRyen2m uz.l57AL1x-onG37BM9M987p"
let LS_CID = LS_CID_TVOS
#elseif os(watchOS)
let LS_CID_WATCHOS = ".cWimz9dysogQz2HJ6L83dXoqoH6M9B2h8Aq"
let LS_CID = LS_CID_WATCHOS
#elseif os(visionOS)
let LS_CID_VISIONOS = "-kVoty5wvjrkHty8Q3O67.E nwx1O787f87Gu"
let LS_CID = LS_CID_VISIONOS
#else // iOS
let LS_CID_IOS = "oqVfhw.i6 38e84CHfDprfc85DP4O9Bl"
let LS_CID = LS_CID_IOS
#endif
let LS_LIB_NAME = "swift_client"
let LS_LIB_VERSION = "6.2.1"

let TLCP_VERSION = "TLCP-2.5.0"
let FULL_TLCP_VERSION = TLCP_VERSION + ".lightstreamer.com"
