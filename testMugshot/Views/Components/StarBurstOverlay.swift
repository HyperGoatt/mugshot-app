//
//  StarBurstOverlay.swift
//  testMugshot
//
//  Star particle burst animation overlay for rating interactions
//  Pure SwiftUI implementation - no external dependencies
//

import SwiftUI

struct StarBurstOverlay: View {
    var rating: Double  // 0...maxRating
    var maxRating: Double = 5
    @Binding var triggerID: Int
    
    @State private var particles: [StarParticle] = []
    
    // Design system constants
    private let particleCount = 6
    private let particleSize: CGFloat = 8
    private let starSpacing: CGFloat = 4
    private let starSize: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Floating star particles
            ForEach(particles) { particle in
                Image(systemName: "star.fill")
                    .font(.system(size: particleSize))
                    .foregroundStyle(DS.Colors.primaryAccent)
                    .opacity(particle.opacity)
                    .offset(x: particle.x, y: particle.y)
                    .scaleEffect(particle.scale)
            }
        }
        .frame(width: 120, height: 50) // Match star row width with extra height for particles
        .allowsHitTesting(false)
        .onChange(of: triggerID) {
            triggerAnimation()
        }
    }
    
    private func triggerAnimation() {
        // Calculate x position of the tapped star
        // Stars are spaced with starSize + starSpacing
        // First star is at position 0, each subsequent star is offset by (starSize + starSpacing)
        let starIndex = Int(rating) - 1
        let xPosition = CGFloat(starIndex) * (starSize + starSpacing) + (starSize / 2) - 60 // Center around 0
        
        // Create particles
        createParticles(at: xPosition)
    }
    
    private func createParticles(at xPosition: CGFloat) {
        var newParticles: [StarParticle] = []
        
        for i in 0..<particleCount {
            let angle = Double(i) * (2 * .pi / Double(particleCount)) + Double.random(in: -0.3...0.3)
            let distance: CGFloat = 12 + CGFloat.random(in: -2...2)
            let x = xPosition + cos(angle) * distance
            let y = sin(angle) * distance
            
            newParticles.append(StarParticle(
                id: UUID(),
                x: x,
                y: y,
                opacity: 1.0,
                scale: 0.6
            ))
        }
        
        particles = newParticles
        
        // Animate particles floating outward and fading
        withAnimation(.easeOut(duration: 0.5)) {
            for i in particles.indices {
                let angle = Double(i) * (2 * .pi / Double(particleCount))
                let distance: CGFloat = 25 + CGFloat.random(in: -5...5)
                particles[i].x += cos(angle) * distance
                particles[i].y += sin(angle) * distance - 15 // Float up
                particles[i].opacity = 0
                particles[i].scale = 0.15
            }
        }
        
        // Clean up particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            particles = []
        }
    }
}

// Particle model for floating stars
private struct StarParticle: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
    var scale: CGFloat
}

