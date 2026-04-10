import CoreLocation
import EventKit
import Foundation
import Observation

/// Central service layer wrapping EKEventStore for full Reminders API access.
///
/// This class exposes the complete EventKit surface area for reminders to
/// evaluate what can be built on top of Reminders as a durable task storage system.
///
/// ## EventKit API Surface Exposed
///
/// **Authorization**: `requestFullAccessToReminders()` (iOS 17+)
/// **Calendars (Lists)**: Full CRUD via `EKCalendar` — title, color, source
/// **Reminders**: Full CRUD via `EKReminder` — title, notes, URL, dates, priority, flags
/// **Predicates**: Incomplete, completed, date-range, calendar-scoped fetching
/// **Recurrence**: Daily/weekly/monthly/yearly via `EKRecurrenceRule`
/// **Alarms**: Time-based and location-based via `EKAlarm` + `EKStructuredLocation`
/// **Sources**: Local, iCloud (CalDAV), Exchange — each with different sync behavior
/// **Change Notifications**: `.EKEventStoreChanged` for external mutation detection
///
/// ## Limitations Discovered
///
/// - **Subtasks**: Not exposed via public EventKit API. Apple Reminders uses
///   private APIs for parent/child relationships. No `parentReminder` property exists.
/// - **Tags**: iOS 17+ Reminders tags are not accessible through EventKit.
/// - **Sections/Groups**: No API for Reminders' column/section board view.
/// - **Images/Attachments**: Reminders' attachment support is not in EventKit.
/// - **Smart Lists**: Must be manually reconstructed via predicates.
/// - **Ordering**: Custom sort order within lists is not preserved by EventKit.
/// - **Templates**: Reminder templates are not exposed.
@Observable
@MainActor
final class ReminderStore {

    // MARK: - State

    private(set) var authStatus: EKAuthorizationStatus = .notDetermined
    private(set) var lists: [ReminderList] = []
    private(set) var smartListCounts: [SmartList: Int] = [:]
    var errorMessage: String?

    // MARK: - Private

    private let ekStore = EKEventStore()
    private var ekReminderCache: [String: EKReminder] = [:]
    private var notificationObserver: Any?

    // MARK: - Lifecycle

    init() {
        authStatus = EKEventStore.authorizationStatus(for: .reminder)
        setupChangeNotifications()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Authorization

    /// Requests full access to reminders (iOS 17+ API).
    /// Returns whether access was granted.
    func requestAccess() async -> Bool {
        do {
            let granted = try await ekStore.requestFullAccessToReminders()
            authStatus = EKEventStore.authorizationStatus(for: .reminder)
            if granted {
                refreshLists()
                await refreshSmartListCounts()
            }
            return granted
        } catch {
            errorMessage = "Access request failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Change Notifications

    private func setupChangeNotifications() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: ekStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleStoreChanged()
            }
        }
    }

    private func handleStoreChanged() {
        ekReminderCache.removeAll()
        refreshLists()
        Task {
            await refreshSmartListCounts()
        }
    }

    // MARK: - Lists (EKCalendar)

    /// Fetches all reminder calendars from EventKit.
    func refreshLists() {
        let calendars = ekStore.calendars(for: .reminder)
        lists = calendars.map { ReminderList(from: $0) }
    }

    /// Returns the default calendar for new reminders, if one exists.
    func defaultList() -> ReminderList? {
        guard let cal = ekStore.defaultCalendarForNewReminders() else { return nil }
        return ReminderList(from: cal)
    }

    /// Creates a new reminder list (EKCalendar).
    @discardableResult
    func createList(title: String, color: CGColor? = nil, sourceType: ReminderList.SourceType? = nil) throws -> ReminderList {
        let calendar = EKCalendar(for: .reminder, eventStore: ekStore)
        calendar.title = title
        if let color { calendar.cgColor = color }

        // Pick a source — prefer the requested type, fall back to default
        if let sourceType, let source = ekStore.sources.first(where: { ReminderList.SourceType(from: $0.sourceType) == sourceType }) {
            calendar.source = source
        } else if let defaultCal = ekStore.defaultCalendarForNewReminders() {
            calendar.source = defaultCal.source
        } else if let localSource = ekStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        }

        try ekStore.saveCalendar(calendar, commit: true)
        refreshLists()
        return ReminderList(from: calendar)
    }

    /// Updates an existing list's properties.
    func updateList(_ list: ReminderList, title: String? = nil, color: CGColor? = nil) throws {
        guard let calendar = ekStore.calendar(withIdentifier: list.id) else {
            throw ReminderStoreError.listNotFound
        }
        if let title { calendar.title = title }
        if let color { calendar.cgColor = color }
        try ekStore.saveCalendar(calendar, commit: true)
        refreshLists()
    }

    /// Deletes a reminder list and all its reminders.
    func deleteList(_ list: ReminderList) throws {
        guard let calendar = ekStore.calendar(withIdentifier: list.id) else {
            throw ReminderStoreError.listNotFound
        }
        try ekStore.removeCalendar(calendar, commit: true)
        refreshLists()
    }

    // MARK: - Sources

    /// Returns all available reminder sources (iCloud, local, Exchange, etc.)
    func availableSources() -> [(name: String, type: ReminderList.SourceType)] {
        ekStore.sources
            .filter { source in
                source.calendars(for: .reminder).count > 0 ||
                source.sourceType == .local ||
                source.sourceType == .calDAV
            }
            .map { ($0.title, ReminderList.SourceType(from: $0.sourceType)) }
    }

    // MARK: - Fetching Reminders

    /// Fetches all reminders in a specific list.
    func fetchReminders(in list: ReminderList) async -> [ReminderItem] {
        guard let calendar = ekStore.calendar(withIdentifier: list.id) else { return [] }
        let predicate = ekStore.predicateForReminders(in: [calendar])
        return await fetchWithPredicate(predicate)
    }

    /// Fetches incomplete reminders, optionally scoped to specific calendars.
    func fetchIncompleteReminders(in calendars: [EKCalendar]? = nil) async -> [ReminderItem] {
        let predicate = ekStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )
        return await fetchWithPredicate(predicate)
    }

    /// Fetches completed reminders within a date range.
    func fetchCompletedReminders(from: Date? = nil, to: Date? = nil) async -> [ReminderItem] {
        let predicate = ekStore.predicateForCompletedReminders(
            withCompletionDateStarting: from,
            ending: to,
            calendars: nil
        )
        return await fetchWithPredicate(predicate)
    }

    /// Fetches reminders due today (smart list).
    func fetchTodayReminders() async -> [ReminderItem] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = ekStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: end,
            calendars: nil
        )
        let items = await fetchWithPredicate(predicate)
        // Include overdue + today
        return items.filter { item in
            guard let due = item.dueDate else { return false }
            return due < end
        }
    }

    /// Fetches all reminders with a due date (smart list).
    func fetchScheduledReminders() async -> [ReminderItem] {
        let predicate = ekStore.predicateForIncompleteReminders(
            withDueDateStarting: Date.distantPast,
            ending: Date.distantFuture,
            calendars: nil
        )
        return await fetchWithPredicate(predicate)
    }

    /// Fetches all flagged incomplete reminders (smart list).
    func fetchFlaggedReminders() async -> [ReminderItem] {
        let all = await fetchIncompleteReminders()
        return all.filter { $0.isFlagged }
    }

    /// Fetches all incomplete reminders across all lists (smart list).
    func fetchAllReminders() async -> [ReminderItem] {
        return await fetchIncompleteReminders()
    }

    /// Searches reminders by title text across all lists.
    func searchReminders(query: String) async -> [ReminderItem] {
        let all = await fetchIncompleteReminders()
        let completed = await fetchCompletedReminders()
        let combined = all + completed
        let lowered = query.lowercased()
        return combined.filter { item in
            item.title.lowercased().contains(lowered) ||
            (item.notes?.lowercased().contains(lowered) ?? false)
        }
    }

    // MARK: - Smart List Counts

    func refreshSmartListCounts() async {
        async let today = fetchTodayReminders()
        async let scheduled = fetchScheduledReminders()
        async let all = fetchAllReminders()
        async let flagged = fetchFlaggedReminders()
        async let completed = fetchCompletedReminders()

        let counts = await [
            SmartList.today: today.count,
            SmartList.scheduled: scheduled.count,
            SmartList.all: all.count,
            SmartList.flagged: flagged.count,
            SmartList.completed: completed.count,
        ]
        smartListCounts = counts
    }

    // MARK: - CRUD Operations

    /// Creates a new reminder in the specified list.
    @discardableResult
    func createReminder(
        title: String,
        in list: ReminderList,
        notes: String? = nil,
        url: URL? = nil,
        dueDate: DateComponents? = nil,
        startDate: DateComponents? = nil,
        priority: Int = 0,
        isFlagged: Bool = false
    ) throws -> ReminderItem {
        let reminder = EKReminder(eventStore: ekStore)
        reminder.title = title
        reminder.notes = notes
        reminder.url = url
        reminder.dueDateComponents = dueDate
        reminder.startDateComponents = startDate
        reminder.priority = priority
        reminder.isFlagged = isFlagged
        if let calendar = ekStore.calendar(withIdentifier: list.id) {
            reminder.calendar = calendar
        }
        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    /// Updates an existing reminder's properties.
    func updateReminder(
        _ item: ReminderItem,
        title: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        dueDate: DateComponents?? = nil,
        startDate: DateComponents?? = nil,
        priority: Int? = nil,
        isFlagged: Bool? = nil,
        isCompleted: Bool? = nil,
        listId: String? = nil
    ) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }

        if let title { reminder.title = title }
        if let notes { reminder.notes = notes }
        if let url { reminder.url = url }
        if let dueDate { reminder.dueDateComponents = dueDate }
        if let startDate { reminder.startDateComponents = startDate }
        if let priority { reminder.priority = priority }
        if let isFlagged { reminder.isFlagged = isFlagged }
        if let isCompleted { reminder.isCompleted = isCompleted }
        if let listId, let calendar = ekStore.calendar(withIdentifier: listId) {
            reminder.calendar = calendar
        }

        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    /// Toggles a reminder's completion state.
    func toggleCompletion(_ item: ReminderItem) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }
        reminder.isCompleted.toggle()
        if reminder.isCompleted {
            reminder.completionDate = Date()
        }
        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    /// Deletes a reminder permanently.
    func deleteReminder(_ item: ReminderItem) throws {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }
        try ekStore.remove(reminder, commit: true)
        ekReminderCache.removeValue(forKey: item.id)
    }

    // MARK: - Recurrence Rules

    /// Adds a recurrence rule to a reminder.
    func addRecurrenceRule(
        to item: ReminderItem,
        frequency: RecurrenceInfo.Frequency,
        interval: Int = 1,
        daysOfWeek: [EKRecurrenceDayOfWeek]? = nil,
        daysOfMonth: [NSNumber]? = nil,
        monthsOfYear: [NSNumber]? = nil,
        end: EKRecurrenceEnd? = nil
    ) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }

        let ekFrequency: EKRecurrenceFrequency
        switch frequency {
        case .daily: ekFrequency = .daily
        case .weekly: ekFrequency = .weekly
        case .monthly: ekFrequency = .monthly
        case .yearly: ekFrequency = .yearly
        }

        let rule = EKRecurrenceRule(
            recurrenceWith: ekFrequency,
            interval: interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: daysOfMonth,
            monthsOfTheYear: monthsOfYear,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
        reminder.addRecurrenceRule(rule)
        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    /// Removes all recurrence rules from a reminder.
    func removeRecurrenceRules(from item: ReminderItem) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }
        for rule in reminder.recurrenceRules ?? [] {
            reminder.removeRecurrenceRule(rule)
        }
        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    // MARK: - Alarms

    /// Adds an alarm to a reminder at a specific date.
    func addAlarm(to item: ReminderItem, date: Date) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }
        let alarm = EKAlarm(absoluteDate: date)
        reminder.addAlarm(alarm)
        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    /// Adds a relative alarm (offset from due date in seconds, negative = before).
    func addRelativeAlarm(to item: ReminderItem, offset: TimeInterval) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }
        let alarm = EKAlarm(relativeOffset: offset)
        reminder.addAlarm(alarm)
        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    /// Adds a location-based alarm (geofence) to a reminder.
    func addLocationAlarm(
        to item: ReminderItem,
        title: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 100,
        proximity: EKAlarmProximity = .enter
    ) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }
        let location = EKStructuredLocation(title: title)
        location.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
        location.radius = radius

        let alarm = EKAlarm(relativeOffset: 0)
        alarm.structuredLocation = location
        alarm.proximity = proximity
        reminder.addAlarm(alarm)

        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    /// Removes all alarms from a reminder.
    func removeAlarms(from item: ReminderItem) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }
        for alarm in reminder.alarms ?? [] {
            reminder.removeAlarm(alarm)
        }
        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    // MARK: - Move Reminder Between Lists

    /// Moves a reminder to a different list.
    func moveReminder(_ item: ReminderItem, to list: ReminderList) throws -> ReminderItem {
        guard let reminder = cachedReminder(for: item.id) else {
            throw ReminderStoreError.reminderNotFound
        }
        guard let calendar = ekStore.calendar(withIdentifier: list.id) else {
            throw ReminderStoreError.listNotFound
        }
        reminder.calendar = calendar
        try ekStore.save(reminder, commit: true)
        cacheReminder(reminder)
        return ReminderItem(from: reminder)
    }

    // MARK: - Cache Management

    private func cacheReminder(_ reminder: EKReminder) {
        ekReminderCache[reminder.calendarItemIdentifier] = reminder
    }

    private func cachedReminder(for id: String) -> EKReminder? {
        if let cached = ekReminderCache[id] { return cached }
        // Try to fetch from store
        let predicate = ekStore.predicateForReminders(in: nil)
        // Note: this is synchronous fetch via calendar item — EventKit doesn't have
        // a direct "fetch by ID" API, so we use calendarItem(withIdentifier:)
        if let item = ekStore.calendarItem(withIdentifier: id) as? EKReminder {
            cacheReminder(item)
            return item
        }
        return nil
    }

    private func fetchWithPredicate(_ predicate: NSPredicate) async -> [ReminderItem] {
        let ekReminders = await withCheckedContinuation { continuation in
            ekStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        for reminder in ekReminders {
            cacheReminder(reminder)
        }
        return ekReminders.map { ReminderItem(from: $0) }
    }

    // MARK: - API Surface Diagnostics

    /// Returns a diagnostic summary of the EventKit capabilities available on this device.
    func diagnosticSummary() -> [String: String] {
        var info: [String: String] = [:]

        info["Authorization Status"] = switch authStatus {
        case .notDetermined: "Not Determined"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .fullAccess: "Full Access"
        case .writeOnly: "Write Only"
        @unknown default: "Unknown"
        }

        info["Sources"] = ekStore.sources
            .map { "\($0.title) (\(ReminderList.SourceType(from: $0.sourceType).displayName))" }
            .joined(separator: ", ")

        let calendars = ekStore.calendars(for: .reminder)
        info["Total Lists"] = "\(calendars.count)"
        info["Immutable Lists"] = "\(calendars.filter { $0.isImmutable }.count)"

        if let defaultCal = ekStore.defaultCalendarForNewReminders() {
            info["Default List"] = defaultCal.title
        }

        return info
    }
}

// MARK: - Errors

enum ReminderStoreError: LocalizedError {
    case reminderNotFound
    case listNotFound
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .reminderNotFound: return "Reminder not found in EventKit store."
        case .listNotFound: return "Reminder list not found in EventKit store."
        case .unauthorized: return "Not authorized to access reminders."
        }
    }
}

