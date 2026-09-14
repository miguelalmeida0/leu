import SwiftUI

struct OpeningDustView: View {
    let visible: Bool
    private let points:[(CGFloat,CGFloat,CGFloat)] = [(0.16,0.23,2),(0.24,0.34,1.4),(0.31,0.27,2.6),(0.38,0.42,1.8),(0.44,0.31,1.3),(0.51,0.47,2.2),(0.58,0.35,1.6),(0.65,0.28,1.9),(0.71,0.43,1.4),(0.79,0.32,2.3),(0.84,0.49,1.7),(0.55,0.21,1.1)]
    var body: some View { GeometryReader { proxy in TimelineView(.animation(minimumInterval: 1/30)) { timeline in let t=timeline.date.timeIntervalSinceReferenceDate; ZStack { ForEach(Array(points.enumerated()), id: \.offset) { i,p in let drift=CGFloat(sin(t*(0.55+Double(i%4)*0.08)+Double(i))); Circle().fill(Color.white.opacity(0.58)).frame(width:p.2,height:p.2).blur(radius:0.45).position(x:proxy.size.width*p.0+drift*8,y:proxy.size.height*p.1-drift*13) } } } }.opacity(visible ? 0.72 : 0).animation(.easeOut(duration:0.55), value:visible).allowsHitTesting(false) }
}
