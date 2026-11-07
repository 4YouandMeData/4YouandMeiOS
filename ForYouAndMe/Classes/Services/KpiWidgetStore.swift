//
//  KpiWidgetStore.swift
//  ForYouAndMe
//
//  FUAM-4315 (D2): in-process holder of the Feed KPI widgets. The value is a snapshot at the
//  participant's last local midnight, so it loads once per local day, independently of the feed:
//  explicit pull-to-refresh forces a reload, a calendar-day change refreshes it, every other feed
//  event is a no-op on the same day. In-memory only (D19): no cache, no placeholder.
//

import UIKit
import RxSwift
import RxRelay

final class KpiWidgetStore {

    typealias Fetch = () -> Single<[KpiWidget]>

    /// `.idle` until the API confirms the widgets; then `.loaded`, also with an empty list.
    /// Emitted on the main thread.
    let state = BehaviorRelay<KpiWidgetState>(value: .idle)

    private(set) var widgets: [KpiWidget]?
    private(set) var loadedLocalDay: String?
    private(set) var isLoading: Bool = false
    private(set) var lastFailed: Bool = false
    /// Last fill drawn per widget id, written when a gauge animation completes (D11).
    private(set) var renderedFill: [String: CGFloat] = [:]

    private let fetch: Fetch
    private let notificationCenter: NotificationCenter
    private var generation: Int = 0
    private var requestDisposable: Disposable?
    private var timeChangeObserver: NSObjectProtocol?

    init(fetch: @escaping Fetch, notificationCenter: NotificationCenter = .default) {
        self.fetch = fetch
        self.notificationCenter = notificationCenter
        // A Feed left open across midnight: the system posts this at the day change.
        self.timeChangeObserver = notificationCenter.addObserver(forName: UIApplication.significantTimeChangeNotification,
                                                                 object: nil,
                                                                 queue: .main) { [weak self] _ in
            self?.refreshIfNeeded()
        }
    }

    deinit {
        self.requestDisposable?.dispose()
        if let observer = self.timeChangeObserver {
            self.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Public

    /// Fetches when `force`, when nothing is loaded, after a failure, or on a new local day.
    /// No-op while a request is in flight.
    func refreshIfNeeded(force: Bool = false, today: String = Date().localDayKey) {
        guard !self.isLoading else { return }
        guard force || self.widgets == nil || self.lastFailed || self.loadedLocalDay != today else { return }

        self.isLoading = true
        let requestGeneration = self.generation
        self.requestDisposable = self.fetch()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] widgets in
                guard let self = self, self.generation == requestGeneration else { return }
                self.didLoad(widgets, today: today)
            }, onFailure: { [weak self] error in
                guard let self = self, self.generation == requestGeneration else { return }
                // A backend without the endpoint, with no card on screen (nothing loaded, or an empty
                // list from an earlier 404): no widget for the day, so apps make one request per day
                // instead of retrying on every Feed visit. With a card shown, a 404 is an ordinary
                // failure that keeps it.
                if case KpiWidgetError.endpointNotFound = error, self.widgets?.isEmpty ?? true {
                    self.didLoad([], today: today)
                    return
                }
                // Keep whatever was shown; never surface the error. The next trigger retries.
                print("KpiWidgetStore - fetch failed: \(error.localizedDescription)")
                self.isLoading = false
                self.lastFailed = true
            })
    }

    private func didLoad(_ widgets: [KpiWidget], today: String) {
        self.isLoading = false
        self.lastFailed = false
        self.widgets = widgets
        self.loadedLocalDay = today
        let newState = KpiWidgetState.loaded(widgets)
        if self.state.value != newState {
            self.state.accept(newState)
        }
    }

    /// Logout: forget everything, and drop any response still in flight.
    func reset() {
        self.generation += 1
        self.requestDisposable?.dispose()
        self.requestDisposable = nil
        self.widgets = nil
        self.loadedLocalDay = nil
        self.isLoading = false
        self.lastFailed = false
        self.renderedFill = [:]
        self.state.accept(.idle)
    }

    // MARK: - Gauge animation bookkeeping (D11)

    /// The fill the gauge should animate from, or nil when it already shows `widget.fill`.
    func animationStart(for widget: KpiWidget) -> CGFloat? {
        let from = self.renderedFill[widget.id] ?? 0
        return from == widget.fill ? nil : from
    }

    func markRendered(widgetId: String, fill: CGFloat) {
        self.renderedFill[widgetId] = fill
    }
}

extension Date {
    /// `yyyy-MM-dd` of this instant in the device calendar and time zone.
    var localDayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
