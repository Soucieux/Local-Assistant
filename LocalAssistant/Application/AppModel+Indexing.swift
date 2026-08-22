import Foundation

/// Folder indexing lifecycle: queuing, monitoring, activity history, and teardown.
extension AppModel {
    /// Requests read-only access to a new folder and indexes it.
    internal func addIndexedRoot() async {
        do {
            guard let root = try await services.authorization.authorizeNewRoot() else { return }
            try await services.database.upsertRoot(root)
            try await services.database.setMonitoringEnabled(true, rootID: root.id)
            indexedRoots = try await services.database.fetchRoots()
            pausedMonitoringRootIDs.remove(root.id)
            do {
                try startMonitoring(root)
            } catch {
                try? await recordActivityEvent(root: root, kind: .monitoringUnavailable)
                handle(error)
            }
            requestIndex(root: root, trigger: .manual)
        } catch {
            handle(error)
        }
    }

    /// Refreshes every currently authorized root sequentially.
    internal func indexAll() {
        let batchID = UUID()
        for root in indexedRoots {
            requestIndex(root: root, trigger: .manual, batchID: batchID)
        }
    }

    /// Queues one authorized root for a manual incremental update.
    /// - Parameter root: Folder authorization to scan and index.
    internal func index(root: AuthorizedRoot) {
        requestIndex(root: root, trigger: .manual)
    }

    /// Revokes a folder bookmark and deletes its dependent private index records.
    /// - Parameter root: Folder authorization to forget.
    internal func remove(root: AuthorizedRoot) async {
        do {
            stopMonitoring(rootID: root.id)
            monitoringDebounceTasks.removeValue(forKey: root.id)?.cancel()
            indexingQueue.removeAll { $0.rootID == root.id }
            dirtyIndexRequests.removeValue(forKey: root.id)
            indexingProgressByRoot.removeValue(forKey: root.id)
            try await services.database.deleteRoot(id: root.id)
            indexedRoots = try await services.database.fetchRoots()
            pausedMonitoringRootIDs.remove(root.id)
            try await refreshFileMatchAvailability()
        } catch {
            handle(error)
        }
    }

    /// Returns whether one folder owns the active indexing run.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: `true` only while that folder is actively indexing.
    internal func indexingIsActive(rootID: UUID) -> Bool {
        activeIndexingRootID == rootID
    }

    /// Returns whether automatic updates are paused for one folder.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: `true` when monitoring is persistently paused.
    internal func monitoringIsPaused(rootID: UUID) -> Bool {
        pausedMonitoringRootIDs.contains(rootID)
    }

    /// Returns whether the native watcher is currently active for one folder.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: `true` when a process-lifetime FSEvents stream is running.
    internal func monitoringIsActive(rootID: UUID) -> Bool {
        monitoredRootIDs.contains(rootID)
    }

    /// Cancels the active run and pauses automatic updates for its folder.
    /// - Parameter rootID: Identifier of the actively indexed folder.
    internal func pauseIndexing(rootID: UUID) {
        guard activeIndexingRootID == rootID else { return }
        indexingProgress.state = .stopping
        indexingProgressByRoot[rootID]?.state = .stopping
        if let activeIndexingBatchID {
            indexingQueue.removeAll { $0.batchID == activeIndexingBatchID }
        }
        activeIndexingTask?.cancel()
        Task { await pauseMonitoring(rootID: rootID) }
    }

    /// Pauses automatic updates for one authorized folder.
    /// - Parameter rootID: Authorized folder identifier.
    internal func pauseMonitoring(rootID: UUID) async {
        guard let root = indexedRoots.first(where: { $0.id == rootID }) else { return }
        do {
            try await services.database.setMonitoringEnabled(false, rootID: rootID)
            pausedMonitoringRootIDs.insert(rootID)
            stopMonitoring(rootID: rootID)
            monitoringDebounceTasks.removeValue(forKey: rootID)?.cancel()
            indexingQueue.removeAll { $0.rootID == rootID && $0.trigger != .manual }
            try await recordActivityEvent(root: root, kind: .monitoringPaused)
        } catch {
            handle(error)
        }
    }

    /// Resumes automatic updates and immediately schedules a catch-up scan.
    /// - Parameter rootID: Authorized folder identifier.
    internal func resumeMonitoring(rootID: UUID) async {
        guard let root = indexedRoots.first(where: { $0.id == rootID }) else { return }
        do {
            try startMonitoring(root)
            do {
                try await services.database.setMonitoringEnabled(true, rootID: rootID)
            } catch {
                stopMonitoring(rootID: rootID)
                throw error
            }
            pausedMonitoringRootIDs.remove(rootID)
            try await recordActivityEvent(root: root, kind: .monitoringResumed)
            requestIndex(root: root, trigger: .automatic)
        } catch {
            handle(error)
        }
    }

    /// Requests confirmation before retained indexing activity is cleared.
    internal func requestActivityClearConfirmation() {
        activityClearConfirmationIsPresented = true
    }

    /// Dismisses the activity-clear confirmation without changing history.
    internal func dismissActivityClearConfirmation() {
        activityClearConfirmationIsPresented = false
    }

    /// Clears retained activity without changing indexed content or authorizations.
    internal func confirmActivityClear() async {
        activityClearConfirmationIsPresented = false
        do {
            try await services.database.clearIndexActivity()
            indexingRuns = []
            indexingItemsByRun = [:]
            indexActivityEvents = []
        } catch {
            handle(error)
        }
    }

    /// Requests confirmation before every indexed file, passage, and vector is deleted.
    internal func requestSearchIndexClearConfirmation() {
        guard isIndexing == false else { return }
        searchIndexClearConfirmationIsPresented = true
    }

    /// Dismisses the search-index-clear confirmation without deleting anything.
    internal func dismissSearchIndexClearConfirmation() {
        searchIndexClearConfirmationIsPresented = false
    }

    /// Clears the search index, then immediately re-indexes every authorized folder.
    internal func confirmSearchIndexClear() async {
        searchIndexClearConfirmationIsPresented = false
        do {
            try await services.database.clearSearchIndex()
            indexedFileCount = try await services.database.indexedFileCount()
            indexStorageByteCount = try await services.database.databaseByteCount()
            try await refreshFileMatchAvailability()
            indexAll()
        } catch {
            handle(error)
        }
    }

    /// Loads file-level details for one expanded activity run.
    internal func loadIndexingItems(runID: UUID) async {
        guard indexingItemsByRun[runID] == nil else { return }
        do {
            indexingItemsByRun[runID] = try await services.database.fetchIndexingItems(
                runID: runID
            )
        } catch {
            handle(error)
        }
    }

    /// Coalesces one folder request into the sequential indexing queue.
    /// - Parameters:
    ///   - root: Authorized folder to update.
    ///   - trigger: Source that requested the update.
    ///   - batchID: Optional identifier shared by an Update All request.
    internal func requestIndex(
        root: AuthorizedRoot,
        trigger: IndexingTrigger,
        batchID: UUID? = nil
    ) {
        if activeIndexingRootID == root.id {
            if dirtyIndexRequests[root.id] == nil || trigger == .manual {
                dirtyIndexRequests[root.id] = (trigger: trigger, batchID: batchID)
            }
            return
        }
        if let offset = indexingQueue.firstIndex(where: { $0.rootID == root.id }) {
            if trigger == .manual {
                indexingQueue[offset].trigger = .manual
                indexingQueue[offset].batchID = batchID
            }
        } else {
            indexingQueue.append((rootID: root.id, trigger: trigger, batchID: batchID))
        }
        guard indexingWorker == nil else { return }
        indexingWorker = Task { [weak self] in
            await self?.drainIndexingQueue()
        }
    }

    /// Runs coalesced folder updates one at a time.
    private func drainIndexingQueue() async {
        while Task.isCancelled == false, indexingQueue.isEmpty == false {
            let request = indexingQueue.removeFirst()
            guard let root = indexedRoots.first(where: { $0.id == request.rootID }) else {
                continue
            }
            if request.trigger != .manual,
               pausedMonitoringRootIDs.contains(root.id) {
                continue
            }
            activeIndexingBatchID = request.batchID
            await performIndex(root: root, trigger: request.trigger)
            activeIndexingBatchID = nil
            if let followUp = dirtyIndexRequests.removeValue(forKey: root.id),
               followUp.trigger == .manual
                    || pausedMonitoringRootIDs.contains(root.id) == false {
                indexingQueue.append(
                    (rootID: root.id, trigger: followUp.trigger, batchID: followUp.batchID)
                )
            }
        }
        indexingWorker = nil
        if Task.isCancelled == false, indexingQueue.isEmpty == false {
            indexingWorker = Task { [weak self] in
                await self?.drainIndexingQueue()
            }
        }
    }

    /// Executes one cancellable indexing run under a bounded read-only access scope.
    /// - Parameters:
    ///   - root: Authorized folder to scan read-only.
    ///   - trigger: Source that requested this run.
    private func performIndex(root: AuthorizedRoot, trigger: IndexingTrigger) async {
        activeIndexingRootID = root.id
        let startingProgress = IndexingProgress(
            runID: nil,
            rootID: root.id,
            folderName: root.displayName,
            trigger: trigger,
            state: .scanning,
            currentPath: nil,
            currentItemState: nil,
            processedItems: 0,
            totalItems: 0,
            skippedItems: 0,
            newItems: 0,
            updatedItems: 0,
            unchangedItems: 0,
            removedItems: 0,
            fractionCompleted: 0
        )
        indexingProgress = startingProgress
        indexingProgressByRoot[root.id] = startingProgress
        let access: SecurityScopedAccess
        do {
            access = try services.authorization.beginAccess(to: root)
        } catch {
            indexingProgress.state = .failed
            indexingProgressByRoot[root.id]?.state = .failed
            activeIndexingRootID = nil
            handle(error)
            return
        }
        let service = services.indexing
        let task = Task {
            try await service.index(
                root: root,
                access: access,
                trigger: trigger
            ) { [weak self] value in
                await MainActor.run {
                    self?.indexingProgress = value
                    if let rootID = value.rootID {
                        self?.indexingProgressByRoot[rootID] = value
                    }
                }
            }
        }
        activeIndexingTask = task
        do {
            let outcome = try await task.value
            indexedRoots = try await services.database.fetchRoots()
            if outcome.newItems > 0 || outcome.removedItems > 0 {
                try await refreshFileMatchAvailability()
            }
        } catch is CancellationError {
            indexingProgress.state = .stopped
            indexingProgressByRoot[root.id]?.state = .stopped
        } catch {
            indexingProgress.state = .failed
            indexingProgressByRoot[root.id]?.state = .failed
            handle(error)
        }
        activeIndexingTask = nil
        activeIndexingRootID = nil
        try? await services.database.purgeIndexActivity(before: activityRetentionCutoff)
        try? await refreshIndexActivity()
    }

    /// Starts a process-lifetime FSEvents stream for one enabled folder.
    /// - Parameter root: Authorized folder whose read-only bookmark is resolved.
    /// - Throws: A local permission or indexing error when monitoring cannot start.
    internal func startMonitoring(_ root: AuthorizedRoot) throws {
        let access = try services.authorization.beginAccess(to: root)
        monitoredRootIDs.remove(root.id)
        do {
            try services.monitoring.start(root: root, access: access) { [weak self] rootID in
                Task { @MainActor in
                    self?.folderDidChange(rootID: rootID)
                }
            }
        } catch {
            monitoredRootIDs.remove(root.id)
            throw error
        }
        monitoredRootIDs.insert(root.id)
    }

    /// Stops one native watcher and updates observable monitoring state.
    /// - Parameter rootID: Authorized folder identifier.
    private func stopMonitoring(rootID: UUID) {
        services.monitoring.stop(rootID: rootID)
        monitoredRootIDs.remove(rootID)
    }

    /// Debounces rapid filesystem events before scheduling one incremental update.
    /// - Parameter rootID: Identifier reported by the native watcher.
    private func folderDidChange(rootID: UUID) {
        guard pausedMonitoringRootIDs.contains(rootID) == false,
              offlineStatus == .ready,
              indexedRoots.contains(where: { $0.id == rootID }) else { return }
        monitoringDebounceTasks[rootID]?.cancel()
        monitoringDebounceTasks[rootID] = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: AppConstants.Indexing.changeDebounceNanoseconds
                )
            } catch {
                return
            }
            guard let self,
                  let root = self.indexedRoots.first(where: { $0.id == rootID }),
                  self.pausedMonitoringRootIDs.contains(rootID) == false else { return }
            self.monitoringDebounceTasks[rootID] = nil
            try? await self.recordActivityEvents(
                root: root,
                kinds: [.changesDetected, .updateScheduled]
            )
            self.requestIndex(root: root, trigger: .automatic)
        }
    }

    /// Appends and refreshes one monitoring event.
    /// - Parameters:
    ///   - root: Authorized folder snapshot stored with the event.
    ///   - kind: Monitoring or indexing event to retain.
    /// - Throws: A local database error when the event cannot be retained.
    private func recordActivityEvent(
        root: AuthorizedRoot,
        kind: IndexActivityEventKind
    ) async throws {
        try await recordActivityEvents(root: root, kinds: [kind])
    }

    /// Appends related monitoring events and refreshes history once.
    /// - Parameters:
    ///   - root: Authorized folder snapshot stored with each event.
    ///   - kinds: Ordered events to retain.
    /// - Throws: A local database error when an event or refresh fails.
    private func recordActivityEvents(
        root: AuthorizedRoot,
        kinds: [IndexActivityEventKind]
    ) async throws {
        let occurredAt = Date()
        for (offset, kind) in kinds.enumerated() {
            try await services.database.insertIndexActivityEvent(
                IndexActivityEventRecord(
                    id: UUID(),
                    rootID: root.id,
                    folderName: root.displayName,
                    kind: kind,
                    occurredAt: occurredAt.addingTimeInterval(Double(offset) / 1_000_000)
                )
            )
        }
        try await services.database.purgeIndexActivity(before: activityRetentionCutoff)
        indexActivityEvents = try await services.database.fetchIndexActivityEvents()
    }

    /// Refreshes retained run summaries and monitoring events.
    /// - Throws: A local database error when retained history cannot be read.
    internal func refreshIndexActivity() async throws {
        indexingRuns = try await services.database.fetchIndexingRuns()
        indexActivityEvents = try await services.database.fetchIndexActivityEvents()
        let retainedRunIDs = Set(indexingRuns.map(\.id))
        indexingItemsByRun = indexingItemsByRun.filter { retainedRunIDs.contains($0.key) }
    }

    /// Cancels queued and in-flight indexing work and stops every folder watcher.
    ///
    /// Extracted from shutdown() so quit and the indexing subsystem share one teardown path
    /// instead of duplicating the queue, worker, and monitoring cleanup in two places.
    internal func stopIndexing() async {
        let worker = indexingWorker
        let activeTask = activeIndexingTask
        indexingQueue = []
        dirtyIndexRequests = [:]
        worker?.cancel()
        activeTask?.cancel()
        for task in monitoringDebounceTasks.values { task.cancel() }
        monitoringDebounceTasks = [:]
        services.monitoring.stopAll()
        monitoredRootIDs = []
        if let activeTask { _ = await activeTask.result }
        if let worker { await worker.value }
        indexingWorker = nil
        activeIndexingTask = nil
    }
}
