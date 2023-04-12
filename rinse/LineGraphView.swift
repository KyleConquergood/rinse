//
//  LineGraphView.swift
//  rinse
//
//  Created by kyle on 2023-04-12.
//

import SwiftUI

struct LineGraphView: View {
    var data: [CGFloat]
    var frameHeight: CGFloat = 200
    var lineWidth: CGFloat = 2
    var lineColor: Color = .blue
    
    private var path: Path {
        var path = Path()
        guard data.count > 1 else { return path }
        
        let maxValue = data.max() ?? 1
        let points = data.map { $0 / maxValue }
        
        let deltaX = 1 / CGFloat(data.count - 1)
        var currentX: CGFloat = 0
        
        path.move(to: CGPoint(x: currentX, y: 1 - points[0]))
        
        for point in points.dropFirst() {
            currentX += deltaX
            path.addLine(to: CGPoint(x: currentX, y: 1 - point))
        }
        
        return path
    }
    
    var body: some View {
        GeometryReader { geometry in
            let frameWidth = geometry.size.width
            VStack {
                ZStack(alignment: .bottom) {
                    // Y-axis labels
                    ForEach(0..<6) { i in
                        Text("\(i * 20)%")
                            .font(.system(size: 12))
                            .position(x: 0, y: CGFloat(5 - i) * frameHeight / 5)
                    }
                    HStack {
                        Spacer()
                        VStack {
                            path
                                .scale(x: frameWidth - 40, y: frameHeight - 40, anchor: .topLeading)
                                .stroke(lineColor, lineWidth: lineWidth)
                                .frame(height: frameHeight)
                            // X-axis labels
                            HStack {
                                ForEach(Array(0..<data.count), id: \.self) { i in
                                    Spacer()
                                    Text("W\(i + 1)")
                                        .font(.system(size: 12))
                                    Spacer()
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
