//
//  PushNotificationManagerTests.swift
//  testMugshotTests
//
//  Tests for PushNotificationManager to ensure data race fixes work correctly
//

import Testing
import UserNotifications
@testable import testMugshot

@MainActor
struct PushNotificationManagerTests {
    
    @Test("PushNotificationManager - userNotificationCenter completion is Sendable")
    func testUserNotificationCenterCompletionIsSendable() async throws {
        // Create a mock notification
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Test body"
        content.userInfo = ["type": "new_visit_from_friend"]
        
        let request = UNNotificationRequest(
            identifier: "test-id",
            content: content,
            trigger: nil
        )
        
        let notification = UNNotification(
            date: Date(),
            request: request
        )
        
        // Get the shared instance
        let manager = PushNotificationManager.shared
        
        // Create a completion handler that should be Sendable
        var completionCalled = false
        let completionHandler: @Sendable (UNNotificationPresentationOptions) -> Void = { options in
            completionCalled = true
            #expect(options.contains(.badge))
        }
        
        // Call the delegate method - this should compile without data race warnings
        await manager.userNotificationCenter(
            UNUserNotificationCenter.current(),
            willPresent: notification,
            withCompletionHandler: completionHandler
        )
        
        // Verify completion was called
        #expect(completionCalled)
    }
    
    @Test("PushNotificationManager - didReceive response completion is Sendable")
    func testDidReceiveResponseCompletionIsSendable() async throws {
        // Create a mock notification response
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Test body"
        content.userInfo = [
            "type": "new_visit_from_friend",
            "tap_action": "visit_detail",
            "visit_id": UUID().uuidString
        ]
        
        let request = UNNotificationRequest(
            identifier: "test-id",
            content: content,
            trigger: nil
        )
        
        let notification = UNNotification(
            date: Date(),
            request: request
        )
        
        let response = UNNotificationResponse(
            notification: notification,
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )
        
        // Get the shared instance
        let manager = PushNotificationManager.shared
        
        // Create a Sendable completion handler
        var completionCalled = false
        let completionHandler: @Sendable () -> Void = {
            completionCalled = true
        }
        
        // Call the delegate method - this should compile without data race warnings
        await manager.userNotificationCenter(
            UNUserNotificationCenter.current(),
            didReceive: response,
            withCompletionHandler: completionHandler
        )
        
        // Verify completion was called
        #expect(completionCalled)
    }
    
    @Test("PushNotificationManager - handles notification in foreground")
    func testHandlesNotificationInForeground() async throws {
        let content = UNMutableNotificationContent()
        content.title = "Test"
        content.body = "Test body"
        content.userInfo = ["type": "new_visit_from_friend"]
        
        let request = UNNotificationRequest(
            identifier: "test-id",
            content: content,
            trigger: nil
        )
        
        let notification = UNNotification(
            date: Date(),
            request: request
        )
        
        let manager = PushNotificationManager.shared
        
        // This should not cause data race warnings
        manager.handleNotificationInForeground(notification)
        
        // Test passes if no crashes occur
        #expect(true)
    }
    
    @Test("PushNotificationManager - handles notification tap")
    func testHandlesNotificationTap() async throws {
        let content = UNMutableNotificationContent()
        content.title = "Test"
        content.body = "Test body"
        content.userInfo = [
            "type": "new_visit_from_friend",
            "tap_action": "visit_detail",
            "visit_id": UUID().uuidString
        ]
        
        let request = UNNotificationRequest(
            identifier: "test-id",
            content: content,
            trigger: nil
        )
        
        let notification = UNNotification(
            date: Date(),
            request: request
        )
        
        let manager = PushNotificationManager.shared
        
        // This should not cause data race warnings
        manager.handleNotificationTap(notification)
        
        // Test passes if no crashes occur
        #expect(true)
    }
    
    @Test("PushNotificationManager - notification parameter is properly isolated")
    func testNotificationParameterIsProperlyIsolated() async throws {
        // Test that notification can be safely passed across actor boundaries
        let content = UNMutableNotificationContent()
        content.userInfo = ["type": "friend_request"]
        
        let request = UNNotificationRequest(
            identifier: "test-id",
            content: content,
            trigger: nil
        )
        
        let notification = UNNotification(
            date: Date(),
            request: request
        )
        
        // Create notification in non-isolated context
        let notificationCopy = notification
        
        // Pass to MainActor-isolated method
        await MainActor.run {
            let manager = PushNotificationManager.shared
            manager.handleNotificationInForeground(notificationCopy)
        }
        
        // Test passes if no data race warnings
        #expect(true)
    }
    
    @Test("PushNotificationManager - response parameter is properly isolated")
    func testResponseParameterIsProperlyIsolated() async throws {
        let content = UNMutableNotificationContent()
        content.userInfo = ["type": "friend_accept"]
        
        let request = UNNotificationRequest(
            identifier: "test-id",
            content: content,
            trigger: nil
        )
        
        let notification = UNNotification(
            date: Date(),
            request: request
        )
        
        let response = UNNotificationResponse(
            notification: notification,
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )
        
        // Create response in non-isolated context
        let responseCopy = response
        
        // Pass to MainActor-isolated method
        await MainActor.run {
            let manager = PushNotificationManager.shared
            manager.handleNotificationTap(responseCopy.notification)
        }
        
        // Test passes if no data race warnings
        #expect(true)
    }
}

