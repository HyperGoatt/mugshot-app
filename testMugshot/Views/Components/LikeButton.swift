//
//  LikeButton.swift
//  testMugshot
//
//  Animated like button with subtle heart animation, fully aligned with design system
//

import SwiftUI

struct LikeButton: View {
    /// Whether the current user has liked this item (driven by the data model)
    let isLiked: Bool
    /// Total like count for the item
    let likeCount: Int
    /// Callback invoked when the like state should be toggled in the data model
    var onToggle: (() -> Void)? = nil
    
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var ringScale: CGFloat = 0
    @State private var ringOpacity: Double = 0
    @State private var heartScale: CGFloat = 1.0
    @State private var particles: [Particle] = []
    @State private var showRing: Bool = false
    
    // Design system constants
    private let iconSize: CGFloat = 15
    private let ringSize: CGFloat = 36
    private let tapTargetSize: CGFloat = 44
    
    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 4) {
                ZStack {
                    // Subtle ring animation (only during transition)
                    if showRing {
                        Circle()
                            .stroke(DS.Colors.primaryAccent.opacity(0.4), lineWidth: 2)
                            .frame(width: ringSize, height: ringSize)
                            .opacity(ringOpacity)
                            .scaleEffect(ringScale)
                    }
                    
                    // Heart icon
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: iconSize))
                        .foregroundStyle(isLiked ? DS.Colors.primaryAccent : DS.Colors.textSecondary)
                        .scaleEffect(heartScale)
                    
                    // Floating heart particles (only on like transition)
                    ForEach(particles) { particle in
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(DS.Colors.primaryAccent)
                            .opacity(particle.opacity)
                            .offset(x: particle.x, y: particle.y)
                            .scaleEffect(particle.scale)
                    }
                }
                .frame(width: tapTargetSize, height: tapTargetSize)
                
                // Like count label
                Text("\(likeCount)")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "Unlike, \(likeCount) likes" : "Like, \(likeCount) likes")
        .accessibilityHint("Double tap to \(isLiked ? "unlike" : "like") this post")
    }
    
    private func handleTap() {
        let wasLiked = isLiked
        
        // Trigger animation immediately based on current state
        // The binding will update reactively when data model changes
        if !wasLiked {
            // Haptic: confirm like toggle
            hapticsManager.lightTap()
            
            // Show ring and start animation
            showRing = true
            ringOpacity = 1.0
            ringScale = 0.5
            
            withAnimation(.easeOut(duration: 0.3)) {
                ringScale = 1.2
                heartScale = 1.3
            }
            
            // Create floating particles
            createParticles()
            
            // Reset animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    ringOpacity = 0
                    heartScale = 1.0
                }
                // Hide ring after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showRing = false
                }
            }
        } else {
            // Haptic: confirm unlike toggle
            hapticsManager.lightTap()
            // Smooth transition to unliked (no animation)
            withAnimation(.easeOut(duration: 0.2)) {
                heartScale = 1.0
            }
        }
        
        // Update data model (this will trigger binding update)
        onToggle?()
    }
    
    private func createParticles() {
        // Create 4-6 small floating hearts
        let particleCount = Int.random(in: 4...6)
        var newParticles: [Particle] = []
        
        for i in 0..<particleCount {
            let angle = Double(i) * (2 * .pi / Double(particleCount)) + Double.random(in: -0.3...0.3)
            let distance: CGFloat = 20 + CGFloat.random(in: -5...5)
            let x = cos(angle) * distance
            let y = sin(angle) * distance
            
            newParticles.append(Particle(
                id: UUID(),
                x: x,
                y: y,
                opacity: 1.0,
                scale: 0.5
            ))
        }
        
        particles = newParticles
        
        // Animate particles floating up and fading out
        withAnimation(.easeOut(duration: 0.6)) {
            for i in particles.indices {
                particles[i].y -= 30
                particles[i].opacity = 0
                particles[i].scale = 0.2
            }
        }
        
        // Clean up particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            particles = []
        }
    }
}

// Particle model for floating hearts
private struct Particle: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
    var scale: CGFloat
}

// Preview
struct LikeButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LikeButton(isLiked: false, likeCount: 12, onToggle: {})
            LikeButton(isLiked: true, likeCount: 42, onToggle: {})
        }
        .padding()
        .background(DS.Colors.screenBackground)
    }
}

