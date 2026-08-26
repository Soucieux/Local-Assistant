import AppKit
import Foundation

/// Draws the connector icon from system vector artwork during release preparation.
@main
enum GenerateConnectorIcon {
    /// Renders the complete source icon at the output path supplied by the build script.
    /// - Throws: A drawing or PNG-encoding error when the icon cannot be written.
    internal static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw IconGenerationError.missingOutputPath
        }

        let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let canvasSize = NSSize(width: 1024, height: 1024)
        guard let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.76, alpha: 1),
            NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.72, alpha: 1)
        ]) else {
            throw IconGenerationError.gradientUnavailable
        }

        let symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 390,
            weight: .semibold
        ).applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
        guard let symbol = NSImage(
            systemSymbolName: "point.3.connected.trianglepath.dotted",
            accessibilityDescription: "OpenClaw Connector"
        )?.withSymbolConfiguration(symbolConfiguration) else {
            throw IconGenerationError.symbolUnavailable
        }

        let image = NSImage(size: canvasSize)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()

        let iconRect = NSRect(x: 64, y: 64, width: 896, height: 896)
        let iconShape = NSBezierPath(roundedRect: iconRect, xRadius: 210, yRadius: 210)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
        shadow.shadowBlurRadius = 34
        shadow.shadowOffset = NSSize(width: 0, height: -18)
        shadow.set()
        gradient.draw(in: iconShape, angle: -45)

        let symbolRect = NSRect(x: 258, y: 260, width: 508, height: 508)
        symbol.draw(in: symbolRect)
        image.unlockFocus()

        guard let representation = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: representation),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw IconGenerationError.encodingFailed
        }
        try png.write(to: outputURL, options: .atomic)
    }
}

private enum IconGenerationError: LocalizedError {
    case missingOutputPath
    case gradientUnavailable
    case symbolUnavailable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .missingOutputPath: "An output PNG path is required."
        case .gradientUnavailable: "The connector icon gradient could not be created."
        case .symbolUnavailable: "The connector icon symbol is unavailable."
        case .encodingFailed: "The connector icon could not be encoded as PNG."
        }
    }
}
