import Foundation
import UIKit
import Combine

class OrientationManager: ObservableObject {

    static let shared = OrientationManager()

    @Published var orientation = "Desconhecida"

    init() {

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateOrientation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        updateOrientation()
    }

    @objc func updateOrientation() {

        switch UIDevice.current.orientation {

        case .portrait:
            orientation = "Portrait"

        case .portraitUpsideDown:
            orientation = "Portrait Invertido"

        case .landscapeLeft:
            orientation = "Landscape Esquerda"

        case .landscapeRight:
            orientation = "Landscape Direita"

        case .faceUp:
            orientation = "Tela para cima"

        case .faceDown:
            orientation = "Tela para baixo"

        default:
            orientation = "Desconhecida"
        }
    }

    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }
}//
//  OrientationManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

