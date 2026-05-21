import CoreGraphics
import Foundation

/// Builds a spectrogram `CGImage` from recent band columns. Drawing the heat
/// field as one scaled image is far cheaper than thousands of Canvas cells.
enum HeatFieldRenderer {
    static func image(columns: [[Float]], palette: Palette, intensity: Double) -> CGImage? {
        guard let firstColumn = columns.first, !firstColumn.isEmpty else { return nil }
        let width = columns.count
        let height = firstColumn.count
        guard width > 0, height > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for x in 0..<width {
            let column = columns[x]
            for y in 0..<height {
                let band = y < column.count ? Double(column[y]) : 0
                let energy = min(1, pow(max(0, band), 0.6) * 1.7 * intensity)
                let rgb = palette.energyRGB(energy)
                // Flip vertically so low frequencies sit at the bottom.
                let pixelIndex = ((height - 1 - y) * width + x) * 4
                pixels[pixelIndex] = component(rgb.r)
                pixels[pixelIndex + 1] = component(rgb.g)
                pixels[pixelIndex + 2] = component(rgb.b)
                pixels[pixelIndex + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: colorSpace,
                       bitmapInfo: bitmapInfo, provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private static func component(_ value: Double) -> UInt8 {
        UInt8(min(255, max(0, value * 255)))
    }
}
