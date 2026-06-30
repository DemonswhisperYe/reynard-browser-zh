//
//  ContentPermissionPresentation.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import GeckoView
import Foundation

extension ContentPermission {
    var alertTitle: String? {
        let host = Self.permissionHost(from: uri)
        switch permission {
        case .geolocation:
            return String(format: L("Allow %@ to use your location?"), host)
        case .desktopNotification:
            return String(format: L("Allow %@ to send notifications?"), host)
        case .persistentStorage:
            return String(format: L("Allow %@ to store data in persistent storage?"), host)
        case .mediaKeySystemAccess:
            return String(format: L("Allow %@ to play DRM-controlled content?"), host)
        case .storageAccess:
            return String(format: L("Allow %@ to use its cookies on %@?"), Self.permissionHost(from: thirdPartyOrigin), host)
        case .localDeviceAccess:
            return String(format: L("Allow %@ to access other apps and services on this device?"), host)
        case .localNetworkAccess:
            return String(format: L("Allow %@ to access apps and services on devices connected to your local network?"), host)
        case .deviceSensors:
            return String(format: L("Allow %@ to use motion & orientation sensors?"), host)
        case .camera,
                .microphone,
                .webxr,
                .autoplay,
                .tracking,
            nil:
            return nil
        }
    }
    
    var alertMessage: String? {
        switch permission {
        case .storageAccess:
            return String(format: L("You may want to block access if it’s not clear why %@ needs this data."), Self.permissionHost(from: thirdPartyOrigin))
        case .camera,
                .microphone,
                .geolocation,
                .desktopNotification,
                .persistentStorage,
                .webxr,
                .autoplay,
                .mediaKeySystemAccess,
                .tracking,
                .localDeviceAccess,
                .localNetworkAccess,
                .deviceSensors,
            nil:
            return nil
        }
    }
    
    static func mediaAlertTitle(uri: String, videoRequested: Bool, audioRequested: Bool) -> String {
        let host = permissionHost(from: uri)
        switch (videoRequested, audioRequested) {
        case (true, true):
            return String(format: L("Allow %@ to use your camera and microphone?"), host)
        case (true, false):
            return String(format: L("Allow %@ to use your camera?"), host)
        case (false, true):
            return String(format: L("Allow %@ to use your microphone?"), host)
        case (false, false):
            return String(format: L("Allow %@ to use your camera and microphone?"), host)
        }
    }
}
