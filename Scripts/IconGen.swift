import AppKit

// Renders the 1024x1024 master app icon: a dark rounded-rect body with the
// mirrored-bars motif in the calm theme gradient. Run via Scripts/make-icon.sh.

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("could not create context")
}

let s = Double(size)
ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

let margin = 86.0
let rect = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
let corner = rect.width * 0.225
let body = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

ctx.saveGState()
ctx.addPath(body)
ctx.clip()

let background = CGGradient(
    colorsSpace: space,
    colors: [CGColor(red: 0.09, green: 0.07, blue: 0.16, alpha: 1),
             CGColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: s),
                       end: CGPoint(x: 0, y: 0), options: [])

let count = 15
let centerY = s / 2
let usableWidth = rect.width * 0.62
let startX = rect.midX - usableWidth / 2
let barWidth = usableWidth / (Double(count) * 1.46)
let gap = (usableWidth - barWidth * Double(count)) / Double(count - 1)
let maxHeight = rect.height * 0.50

let stops: [(Double, Double, Double)] = [
    (0.22, 0.20, 0.46), (0.16, 0.54, 0.57), (0.95, 0.65, 0.34),
]
func themeColor(_ t: Double) -> CGColor {
    let e = min(max(t, 0), 1)
    let scaled = e * 2
    let low = min(Int(scaled), 1)
    let high = min(low + 1, 2)
    let f = scaled - Double(low)
    let a = stops[low], b = stops[high]
    return CGColor(red: a.0 + (b.0 - a.0) * f,
                   green: a.1 + (b.1 - a.1) * f,
                   blue: a.2 + (b.2 - a.2) * f, alpha: 1)
}

for i in 0..<count {
    let x01 = Double(i) / Double(count - 1)
    let hump = 0.20 + 0.80 * pow(sin(x01 * Double.pi), 0.8)
    let height = hump * maxHeight
    let x = startX + Double(i) * (barWidth + gap)
    let bar = CGRect(x: x, y: centerY - height / 2, width: barWidth, height: height)
    let radius = barWidth * 0.45
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: radius, cornerHeight: radius,
                       transform: nil))
    ctx.setFillColor(themeColor(hump))
    ctx.fillPath()
}
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("could not render image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode png")
}
let output = URL(fileURLWithPath: "/Users/danb/code/local/echoform/Resources/icon-1024.png")
try! png.write(to: output)
print("wrote \(output.path)")
