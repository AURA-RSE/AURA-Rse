import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let space = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:4096,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red:11/255,green:13/255,blue:18/255,alpha:1))
context.fill(CGRect(x:0,y:0,width:1024,height:1024))
context.scaleBy(x:1024/108,y:1024/108)
let lime = CGColor(red:209/255,green:1,blue:114/255,alpha:1)
context.setStrokeColor(lime);context.setLineWidth(6);context.setLineCap(.round)
context.addArc(center:CGPoint(x:54,y:54),radius:26,startAngle:.pi/2,endAngle:2 * .pi,clockwise:false)
context.addLine(to:CGPoint(x:80,y:74));context.strokePath()
context.setFillColor(lime);context.fillEllipse(in:CGRect(x:76,y:74,width:10,height:10))
let image=context.makeImage()!
let destination=CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,image,nil)
guard CGImageDestinationFinalize(destination) else { fatalError("PNG export failed") }
print("Opaque 1024px Aura icon rendered")
