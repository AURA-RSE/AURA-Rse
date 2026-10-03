import SwiftUI

/// The same open ring and satellite mark used by the Android launcher icon.
struct AuraMark: View {
    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width,geometry.size.height) / 108
            Path { path in
                path.addArc(center:CGPoint(x:54*unit,y:54*unit),radius:26*unit,startAngle:.degrees(-90),endAngle:.degrees(0),clockwise:true)
                path.addLine(to:CGPoint(x:80*unit,y:34*unit))
            }.stroke(AuraTheme.lime,style:StrokeStyle(lineWidth:6*unit,lineCap:.round))
            Circle().fill(AuraTheme.lime).frame(width:10*unit,height:10*unit).position(x:81*unit,y:29*unit)
        }.accessibilityHidden(true)
    }
}
struct AuraBrand: View {
    var size: CGFloat = 34
    var body: some View {
        HStack(spacing:0) {
            Text("aura").font(.system(size:size,weight:.bold,design:.rounded)).tracking(-1)
            AuraMark().frame(width:size*1.2,height:size*1.2)
        }.accessibilityElement(children:.ignore).accessibilityLabel("Aura")
    }
}
