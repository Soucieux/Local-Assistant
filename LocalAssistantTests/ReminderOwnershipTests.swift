import Foundation
import Testing

@testable import LocalAssistant

/// Ownership classification is retained as read-only reminder-card metadata.
internal struct ReminderOwnershipTests {
    @Test("Both historical Local Assistant markers classify a CloudBase-only row")
    internal func classifiesLocalAssistantOwnership() {
        let reminder = cached(
            managedBy: ReminderConstants.Identity.localAssistantOwner,
            clientRequestId: UUID().uuidString,
            syncPairId: nil,
            sourceMessageId: nil
        )
        #expect(reminder.ownership == .localAssistant)
    }

    @Test("A partial Local Assistant marker remains unclassified")
    internal func refusesPartialLocalAssistantOwnership() {
        let reminder = cached(
            managedBy: ReminderConstants.Identity.localAssistantOwner,
            clientRequestId: nil,
            syncPairId: nil,
            sourceMessageId: nil
        )
        #expect(reminder.ownership == .unknown)
    }

    @Test("A malformed client request identifier remains unclassified")
    internal func refusesMalformedLocalAssistantOwnership() {
        let reminder = cached(
            managedBy: ReminderConstants.Identity.localAssistantOwner,
            clientRequestId: "not-a-uuid",
            syncPairId: nil,
            sourceMessageId: nil
        )
        #expect(reminder.ownership == .unknown)
    }

    @Test("An OpenClaw pair marker takes display-metadata precedence")
    internal func pairMarkerTakesOwnershipPrecedence() {
        let reminder = cached(
            managedBy: ReminderConstants.Identity.localAssistantOwner,
            clientRequestId: UUID().uuidString,
            syncPairId: "pair-1",
            sourceMessageId: "message-1"
        )
        #expect(reminder.ownership == .openClaw)
    }

    @Test("Either OpenClaw pair marker keeps a row read-only to this app")
    internal func classifiesOpenClawOwnership() {
        let reminder = cached(
            managedBy: nil,
            clientRequestId: nil,
            syncPairId: "pair-1",
            sourceMessageId: nil
        )
        #expect(reminder.ownership == .openClaw)
    }

    @Test("A single exact-read object cannot masquerade as a complete list")
    internal func preservesRemoteDataShape() throws {
        let objectResponse = #"{"schemaVersion":1,"taskId":"446f8d12-e2db-4e18-9cbf-801751068890","status":"completed","calendarChanged":false,"payload":{"success":true,"data":{"_id":"r1","text":"Renew permit"}}}"#
        let listResponse = #"{"schemaVersion":1,"taskId":"446f8d12-e2db-4e18-9cbf-801751068890","status":"completed","calendarChanged":false,"payload":{"success":true,"data":[]}}"#

        let exact = try JSONDecoder().decode(
            ReminderConnectorResponse.self,
            from: Data(objectResponse.utf8)
        )
        let list = try JSONDecoder().decode(
            ReminderConnectorResponse.self,
            from: Data(listResponse.utf8)
        )

        #expect(exact.payload?.dataIsArray == false)
        #expect(exact.payload?.data?.count == 1)
        #expect(list.payload?.dataIsArray == true)
        #expect(list.payload?.data?.isEmpty == true)
    }

    /// Builds one normalized cached record around the ownership fields under test.
    /// - Parameters:
    ///   - managedBy: Stored owner marker.
    ///   - clientRequestId: Stored create idempotency marker.
    ///   - syncPairId: Stored calendar pairing marker.
    ///   - sourceMessageId: Stored originating message marker.
    /// - Returns: A cached reminder fixed apart from those ownership fields.
    private func cached(
        managedBy: String?,
        clientRequestId: String?,
        syncPairId: String?,
        sourceMessageId: String?
    ) -> ReminderItem {
        ReminderItem(
            remote: RemoteReminderItem(
                id: "reminder-1",
                text: "Renew permit",
                date: "2026-08-24",
                startTime: nil,
                endTime: nil,
                tag: nil,
                link: nil,
                managedBy: managedBy,
                clientRequestId: clientRequestId,
                syncPairId: syncPairId,
                sourceMessageId: sourceMessageId
            ),
            contentHash: "hash",
            syncedAt: Date(timeIntervalSince1970: 1)
        )
    }
}
