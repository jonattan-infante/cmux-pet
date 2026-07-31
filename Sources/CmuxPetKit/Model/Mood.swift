// Estados de animo del droide y su paleta.

import AppKit

enum Mood: String {
    case idle, working, done, error, attention, info

    /// Color del acento (antena, anillo) por estado.
    var accent: NSColor {
        switch self {
        case .idle:      return NSColor(srgbRed: 0.42, green: 0.62, blue: 0.98, alpha: 1)
        case .working:   return NSColor(srgbRed: 0.98, green: 0.72, blue: 0.24, alpha: 1)
        case .done:      return NSColor(srgbRed: 0.30, green: 0.80, blue: 0.50, alpha: 1)
        case .error:     return NSColor(srgbRed: 0.94, green: 0.36, blue: 0.36, alpha: 1)
        case .attention: return NSColor(srgbRed: 0.98, green: 0.55, blue: 0.20, alpha: 1)
        case .info:      return NSColor(srgbRed: 0.55, green: 0.60, blue: 0.98, alpha: 1)
        }
    }

    /// Cuerpo del personaje, dos tonos para el degradado.
    var body: (NSColor, NSColor) {
        switch self {
        case .error:
            return (NSColor(srgbRed: 0.36, green: 0.19, blue: 0.22, alpha: 1),
                    NSColor(srgbRed: 0.24, green: 0.13, blue: 0.16, alpha: 1))
        case .done:
            return (NSColor(srgbRed: 0.18, green: 0.34, blue: 0.28, alpha: 1),
                    NSColor(srgbRed: 0.11, green: 0.22, blue: 0.19, alpha: 1))
        case .attention:
            return (NSColor(srgbRed: 0.36, green: 0.28, blue: 0.16, alpha: 1),
                    NSColor(srgbRed: 0.24, green: 0.18, blue: 0.10, alpha: 1))
        default:
            return (NSColor(srgbRed: 0.20, green: 0.24, blue: 0.34, alpha: 1),
                    NSColor(srgbRed: 0.12, green: 0.15, blue: 0.23, alpha: 1))
        }
    }
}

