import AVFoundation

enum MicrophonePermissionState: Equatable {
    case granted
    case denied
    case undetermined
    case restricted
    case unknown

    var isGranted: Bool {
        self == .granted
    }

    var label: String {
        switch self {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .undetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .unknown:
            return "Unknown"
        }
    }

    static func current() -> MicrophonePermissionState {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                return .undetermined
            @unknown default:
                return .unknown
            }
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .undetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }
}
