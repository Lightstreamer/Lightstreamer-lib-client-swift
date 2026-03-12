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
    #if LS_JSON_PATCH
    let LS_CID_MACOS = "scFuxkwp1ltvcC4FJ4Ji kOj2DK6S793hk"
    let LS_CID = LS_CID_MACOS
    #else
    let LS_CID_MACOS_COMPACT = "scFuxkwp1ltvcC4FJ4Ji kOj2DK6S793h4hz3twjzx"
    let LS_CID = LS_CID_MACOS_COMPACT
    #endif
#elseif os(tvOS)
    #if LS_JSON_PATCH
    let LS_CID_TVOS = "zxRyen2m uz.l59AK1x-onG37BMAMA74o"
    let LS_CID = LS_CID_TVOS
    #else
    let LS_CID_TVOS_COMPACT = "zxRyen2m uz.l59AK1x-onG37BMAMA74ditx6ey c"
    let LS_CID = LS_CID_TVOS_COMPACT
    #endif
#elseif os(watchOS)
    #if LS_JSON_PATCH
    let LS_CID_WATCHOS = ".cWimz9dysogQz2HJ8L73dXoqoH6M9C2i77p"
    let LS_CID = LS_CID_WATCHOS
    #else
    let LS_CID_WATCHOS_COMPACT = ".cWimz9dysogQz2HJ8L73dXoqoH6M9C2i779ws5wgeWd"
    let LS_CID = LS_CID_WATCHOS_COMPACT
    #endif
#elseif os(visionOS)
    #if LS_JSON_PATCH
    let LS_CID_VISIONOS = "-kVoty5wvjrkHty8Q3Q66.E nwx1O788f96Dt"
    let LS_CID = LS_CID_VISIONOS
    #else
    let LS_CID_VISIONOS_COMPACT = "-kVoty5wvjrkHty8Q3Q66.E nwx1O788f96DIg7tvcFzh"
    let LS_CID = LS_CID_VISIONOS_COMPACT
    #endif
#else // iOS
    #if LS_JSON_PATCH
    let LS_CID_IOS = "oqVfhw.i6 38eA4BHfDprfc85DQ4P88k"
    let LS_CID = LS_CID_IOS
    #else
    let LS_CID_IOS_COMPACT = "oqVfhw.i6 38eA4BHfDprfc85DQ4P880Fur ugCx"
    let LS_CID = LS_CID_IOS_COMPACT
    #endif
#endif
let LS_LIB_NAME = "swift_client"
let LS_LIB_VERSION = "6.4.0"

let TLCP_VERSION = "TLCP-2.5.0"
let FULL_TLCP_VERSION = TLCP_VERSION + ".lightstreamer.com"
