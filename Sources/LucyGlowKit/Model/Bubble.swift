// Un aviso en pantalla.

import Foundation

struct Bubble {
    var mood: Mood
    var text: String
    var workspaceId: String?
    var sticky: Bool
    var createdAt: Date = Date()
}

/// La voz del droide. Un pitido segun el animo, la frase, y a veces un cierre.
/// Todo en un parrafo: el asistente habla como una unidad astromecanica, no
