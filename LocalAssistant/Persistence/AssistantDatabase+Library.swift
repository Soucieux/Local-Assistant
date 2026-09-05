import Foundation

extension AssistantDatabase {
    /// Appends one message to private local conversation history.
    /// - Parameter message: Message and bounded evidence list to persist.
    /// - Throws: A local database error when encoding or insertion fails.
    internal func insertChatMessage(_ message: ChatMessage) throws {
        let payload = try encoder.encode(message)
        let statement = try preparedStatement(SQLStatements.insertChatMessage)
        defer { recycle(statement) }
        try bind(message.id.uuidString, at: 1, in: statement)
        try bind(message.role.rawValue, at: 2, in: statement)
        try bind(payload, at: 3, in: statement)
        try bind(message.createdAt, at: 4, in: statement)
        try stepDone(statement)
    }

    /// Returns recent private conversation history in chronological order.
    /// - Parameter limit: Maximum number of messages.
    /// - Returns: Decoded local messages.
    /// - Throws: A local database error when rows cannot be decoded.
    internal func fetchChatMessages(limit: Int) throws -> [ChatMessage] {
        let statement = try preparedStatement(SQLStatements.fetchChatMessages)
        defer { recycle(statement) }
        try bind(limit, at: 1, in: statement)
        var messages: [ChatMessage] = []
        while try step(statement) {
            let payload = requiredData(statement, column: 0)
            messages.append(try decoder.decode(ChatMessage.self, from: payload))
        }
        return messages.reversed()
    }

    /// Deletes private local conversation history.
    /// - Throws: A local database error when deletion fails.
    internal func clearChatMessages() throws {
        try execute(SQLStatements.clearChatMessages)
    }
}
