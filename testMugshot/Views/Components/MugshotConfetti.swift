//
//  MugshotConfetti.swift
//  testMugshot
//
//  Custom confetti animation component inspired by ConfettiSwiftUI
//  Designed for Mugshot brand with mint and colorful palette
//  Shoots confetti from a specific source point in an explosion pattern
//

import SwiftUI

// MARK: - Mugshot Confetti Cannon

struct MugshotConfettiCannon: View {
    @Binding var trigger: Int
    let sourcePoint: CGPoint
    let num: Int
    let colors: [Color]
    let confettiSize: CGFloat
    let openingAngle: Angle
    let closingAngle: Angle
    let radius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if trigger > 0 {
                    ForEach(0..<num, id: \.self) { index in
                        ConfettiPiece(
                            index: index,
                            total: num,
                            colors: colors,
                            size: confettiSize,
                            openingAngle: openingAngle,
                            closingAngle: closingAngle,
                            radius: radius,
                            sourcePoint: sourcePoint
                        )
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Confetti Piece

struct ConfettiPiece: View {
    let index: Int
    let total: Int
    let colors: [Color]
    let size: CGFloat
    let openingAngle: Angle
    let closingAngle: Angle
    let radius: CGFloat
    let sourcePoint: CGPoint
    
    @State private var opacity: Double = 1.0
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var hasAnimated: Bool = false
    
    // Calculate direction based on opening/closing angles
    private var directionAngle: Double {
        let angleRange = closingAngle.degrees - openingAngle.degrees
        let baseAngle = openingAngle.degrees
        let normalizedIndex = Double(index) / Double(total)
        let angleInRange = baseAngle + (angleRange * normalizedIndex)
        // Add some randomness for more natural spread
        return angleInRange + Double.random(in: -15...15)
    }
    
    private var color: Color {
        colors[index % colors.count]
    }
    
    private var confettiShape: some View {
        // Randomly choose between circle, rectangle, and triangle
        let shapeType = index % 3
        switch shapeType {
        case 0:
            return AnyView(Circle().fill(color))
        case 1:
            return AnyView(RoundedRectangle(cornerRadius: 2).fill(color))
        default:
            return AnyView(ConfettiTriangle().fill(color))
        }
    }
    
    var body: some View {
        confettiShape
            .frame(width: size, height: size)
            .opacity(opacity)
            .position(
                x: sourcePoint.x + offset.width,
                y: sourcePoint.y + offset.height
            )
            .rotationEffect(.degrees(rotation))
            .onAppear {
                if !hasAnimated {
                    hasAnimated = true
                    // Small delay to ensure view is rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        animate()
                    }
                }
            }
    }
    
    private func animate() {
        let duration = Double.random(in: 1.5...2.5)
        let radians = directionAngle * .pi / 180
        
        // Calculate distance with random variation
        let distance = CGFloat(radius) * CGFloat.random(in: 0.7...1.0)
        
        // Calculate final offset from source point
        let finalOffsetX = cos(radians) * distance
        let finalOffsetY = sin(radians) * distance
        
        // Rotation animation
        withAnimation(.linear(duration: duration)) {
            rotation = Double.random(in: 360...1080) * (Bool.random() ? 1 : -1)
        }
        
        // Movement animation with gravity-like deceleration
        withAnimation(.easeOut(duration: duration)) {
            offset = CGSize(width: finalOffsetX, height: finalOffsetY)
        }
        
        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.7) {
            withAnimation(.easeOut(duration: duration * 0.3)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Triangle Shape for Confetti

struct ConfettiTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - View Extension

extension View {
    func mugshotConfettiOverlay(
        trigger: Binding<Int>,
        sourcePoint: CGPoint,
        num: Int = 60,
        colors: [Color] = [
            Color(hex: "B7E2B5"),  // Mugshot mint
            Color(hex: "FAF8F6"),  // Cream white
            Color(hex: "2563EB"),  // Blue accent
            Color(hex: "FACC15"),  // Yellow accent
            Color(hex: "ECF8EC"),  // Mint soft fill
            Color(hex: "8AC28E"),  // Mint dark
        ],
        confettiSize: CGFloat = 10.0,
        openingAngle: Angle = .degrees(0),
        closingAngle: Angle = .degrees(360),
        radius: CGFloat = 350.0
    ) -> some View {
        self.overlay(
            MugshotConfettiCannon(
                trigger: trigger,
                sourcePoint: sourcePoint,
                num: num,
                colors: colors,
                confettiSize: confettiSize,
                openingAngle: openingAngle,
                closingAngle: closingAngle,
                radius: radius
            )
            .allowsHitTesting(false)
        )
    }
}

