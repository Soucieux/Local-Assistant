import Foundation

/// Resolves and protects the app's private writable directories.
enum AppDirectories {
    /// Returns the private application-support directory.
    /// - Returns: The application-support URL inside the sandbox container.
    /// - Throws: A local error when the location cannot be resolved.
    internal static func applicationSupport() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return baseURL.appendingPathComponent(
            AppConstants.Identity.applicationSupportDirectory,
            isDirectory: true
        )
    }

    /// Returns the private directory containing the SQLite index.
    /// - Returns: The index directory URL.
    /// - Throws: A local error when application support cannot be resolved.
    internal static func indexDirectory() throws -> URL {
        try applicationSupport().appendingPathComponent(
            AppConstants.Identity.indexDirectory,
            isDirectory: true
        )
    }

    /// Returns the private directory containing model assets.
    /// - Returns: The models directory URL.
    /// - Throws: A local error when application support cannot be resolved.
    internal static func modelsDirectory() throws -> URL {
        try applicationSupport().appendingPathComponent(
            AppConstants.Identity.modelsDirectory,
            isDirectory: true
        )
    }

    /// Returns the owner-only spool shared with the optional connector process.
    /// - Returns: The connector root inside this app's private container.
    /// - Throws: A local error when application support cannot be resolved.
    internal static func connectorDirectory() throws -> URL {
        try applicationSupport().appendingPathComponent(
            ReminderConstants.Identity.connectorDirectory,
            isDirectory: true
        )
    }

    /// Returns the queue where the app atomically publishes connector requests.
    /// - Returns: Request queue inside the private connector spool.
    /// - Throws: A local directory-resolution error when the container is unavailable.
    internal static func connectorRequestsDirectory() throws -> URL {
        try connectorDirectory().appendingPathComponent(
            ReminderConstants.Identity.requestDirectory,
            isDirectory: true
        )
    }

    /// Returns the connector-owned directory for claimed requests.
    /// - Returns: Processing queue inside the private connector spool.
    /// - Throws: A local directory-resolution error when the container is unavailable.
    internal static func connectorProcessingDirectory() throws -> URL {
        try connectorDirectory().appendingPathComponent(
            ReminderConstants.Identity.processingDirectory,
            isDirectory: true
        )
    }

    /// Returns the queue where the connector atomically publishes responses.
    /// - Returns: Response queue inside the private connector spool.
    /// - Throws: A local directory-resolution error when the container is unavailable.
    internal static func connectorResponsesDirectory() throws -> URL {
        try connectorDirectory().appendingPathComponent(
            ReminderConstants.Identity.responseDirectory,
            isDirectory: true
        )
    }

    /// Returns the expected SQLite database location.
    /// - Returns: A file URL in the private index directory.
    /// - Throws: A local error when application support cannot be resolved.
    internal static func databaseURL() throws -> URL {
        try indexDirectory().appendingPathComponent(AppConstants.Identity.databaseFilename)
    }

    /// Creates all private writable directories with owner-only permissions.
    /// - Throws: A local error when a directory cannot be created or protected.
    internal static func prepare() throws {
        let directories = try [
            applicationSupport(),
            indexDirectory(),
            modelsDirectory(),
            connectorDirectory(),
            connectorRequestsDirectory(),
            connectorProcessingDirectory(),
            connectorResponsesDirectory()
        ]
        let fileManager = FileManager.default

        do {
            for directory in directories {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: AppConstants.Storage.ownerOnlyDirectoryPermissions]
                )
                try fileManager.setAttributes(
                    [.posixPermissions: AppConstants.Storage.ownerOnlyDirectoryPermissions],
                    ofItemAtPath: directory.path
                )
            }
        } catch {
            throw LocalAssistantError.permission(error.localizedDescription)
        }
    }
}
