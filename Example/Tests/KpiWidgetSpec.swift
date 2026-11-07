//
//  KpiWidgetSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4315: the Feed KPI widget. Covers decoding and the unsupported-type filter, the
//  display/fill clamping (D6), the HTML tag scanner (D14), the store refresh rule (D2), the
//  gauge animation bookkeeping and integer count (D11) and the palette defaults (D5).
//  Section ordering lives in FeedContentPinnedSpec.
//

import Quick
import Nimble
import Moya
import RxSwift
import UIKit
@testable import ForYouAndMe

class KpiWidgetSpec: QuickSpec {
    override class func spec() {

        // MARK: 1. Decoding

        describe("KpiWidget decoding") {
            it("decodes the fixture and keeps only supported types") {
                let data = Bundle.getTestData(from: "TestGetKpiWidgets")
                expect(data.isEmpty).to(beFalse(), description: "fixture must ship in the pod resource bundle")
                let decoded: ExcludeInvalid<KpiWidget>? = try? Response(statusCode: 200, data: data)
                    .mapCodableJSONAPI(includeList: KpiWidget.includeList, keyPath: KpiWidget.keyPath)
                let all = decoded?.wrappedValue ?? []
                expect(all.map { $0.id }).to(equal(["1", "2", "3"]))

                let supported = all.filter(\.isSupported)
                expect(supported.map { $0.id }).to(equal(["1", "2"]))

                let first = supported[0]
                expect(first.completed).to(equal(5))
                expect(first.total).to(equal(6))
                expect(first.meetsThreshold).to(beTrue())
                expect(first.title).to(equal("Quick Activities Completion"))
                expect(first.displayPercent).to(equal(83))

                let second = supported[1]
                expect(second.title).to(beNil())
                expect(second.body).to(beNil())
                expect(second.position).to(beNil())
                expect(second.percentage).to(beNil())
                expect(second.displayPercent).to(equal(0))
                expect(second.fill).to(equal(0))
            }
        }

        // MARK: 2. Display / fill

        describe("KpiWidget display and fill") {
            let table: [(Double?, Int, CGFloat)] = [
                (83.33, 83, 0.8333), (69.5, 69, 0.695), (69.86, 69, 0.6986), (70.0, 70, 0.70),
                (100, 100, 1.0), (120, 100, 1.0), (-5, 0, 0), (nil, 0, 0)
            ]
            for (percentage, display, fill) in table {
                it("maps \(String(describing: percentage)) to \(display) / \(fill)") {
                    let widget = makeWidget(percentage: percentage)
                    expect(widget.displayPercent).to(equal(display))
                    expect(Double(widget.fill)).to(beCloseTo(Double(fill), within: 0.000_1))
                }
            }
        }

        // MARK: 3. HTML scanner

        describe("KPI HTML scanner") {
            it("renders the Mindset body with one bold run") {
                let runs = KpiHtmlScanner.scan("<p>Tasks completed:<br>\n<strong>5</strong> of 6 assigned</p>\n")
                expect(runs.map(\.text).joined()).to(equal("Tasks completed:\n5 of 6 assigned"))
                expect(runs.filter(\.bold).map(\.text)).to(equal(["5"]))
                expect(runs.contains(where: \.italic)).to(beFalse())
            }
            it("turns a paragraph boundary into one newline") {
                expect(text("<p>A</p>\n<p>B</p>")).to(equal("A\nB"))
            }
            it("collapses raw newlines inside a paragraph") {
                expect(text("<p>a\nb</p>")).to(equal("a b"))
            }
            it("decodes entities") {
                expect(text("<p>&amp; &lt; &#39;</p>")).to(equal("& < '"))
                expect(text("<p>&gt; &quot; &amp;lt;</p>")).to(equal("> \" &lt;"))
            }
            it("renders italic runs and curly quotes") {
                let runs = KpiHtmlScanner.scan("<p><em>x</em> <q>y</q></p>")
                expect(runs.map(\.text).joined()).to(equal("x \u{201C}y\u{201D}"))
                expect(runs.filter(\.italic).map(\.text)).to(equal(["x"]))
            }
            it("drops unknown tags") {
                expect(text("<ul><li>z</li></ul>")).to(equal("z"))
            }
            it("handles Redcarpet's real paragraph boundary and whitespace before <br>") {
                expect(text("<p>A</p>\n\n<p>B</p>\n")).to(equal("A\nB"))
                expect(text("<p>a   <br>\n b</p>")).to(equal("a\nb"))
            }
            it("handles nested, unclosed and stray strong tags") {
                let nested = KpiHtmlScanner.scan("<p><strong>a <strong>b</strong> c</strong> d</p>")
                expect(nested).to(equal([KpiHtmlRun(text: "a b c", bold: true, italic: false),
                                         KpiHtmlRun(text: " d", bold: false, italic: false)]))
                let unclosed = KpiHtmlScanner.scan("<p>x <strong>y</p>")
                expect(unclosed.filter(\.bold).map(\.text)).to(equal(["y"]))
                let stray = KpiHtmlScanner.scan("<p></strong>y <b>z</b></p>")
                expect(stray).to(equal([KpiHtmlRun(text: "y ", bold: false, italic: false),
                                        KpiHtmlRun(text: "z", bold: true, italic: false)]))
            }
            it("applies the bold font to the bold run only") {
                let regular = UIFont.systemFont(ofSize: 15)
                let bold = UIFont.boldSystemFont(ofSize: 15)
                let attributed = "<p>a <b>b</b></p>".kpiAttributedString(regular: regular, bold: bold,
                                                                        italic: UIFont.italicSystemFont(ofSize: 15),
                                                                        color: .black, lineHeightMultiple: 1.5)
                expect(attributed.string).to(equal("a b"))
                expect(attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont).to(equal(regular))
                expect(attributed.attribute(.font, at: 2, effectiveRange: nil) as? UIFont).to(equal(bold))
                let style = attributed.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
                expect(style?.lineHeightMultiple).to(equal(1.5))
            }
        }

        // MARK: 4. Store refresh rule

        describe("KpiWidgetStore refresh rule") {
            var fake: FakeKpiFetch!
            var store: KpiWidgetStore!
            let widgetA = makeWidget(id: "1", percentage: 50)
            let widgetB = makeWidget(id: "1", percentage: 60)

            beforeEach {
                fake = FakeKpiFetch()
                store = KpiWidgetStore(fetch: { fake.fetch() }, notificationCenter: NotificationCenter())
            }

            it("fetches when fresh and guards a second call while in flight") {
                store.refreshIfNeeded(today: "2026-11-07")
                expect(fake.calls).to(equal(1))
                expect(store.isLoading).to(beTrue())
                store.refreshIfNeeded(today: "2026-11-07")
                store.refreshIfNeeded(force: true, today: "2026-11-07")
                expect(fake.calls).to(equal(1))
            }

            it("loads once per day, reloads on force and on a new day") {
                store.refreshIfNeeded(today: "2026-11-07")
                fake.succeed([widgetA])
                expect(store.state.value).toEventually(equal(.loaded([widgetA])))
                expect(store.loadedLocalDay).to(equal("2026-11-07"))
                expect(store.isLoading).to(beFalse())

                store.refreshIfNeeded(today: "2026-11-07")
                expect(fake.calls).to(equal(1))

                store.refreshIfNeeded(force: true, today: "2026-11-07")
                expect(fake.calls).to(equal(2))
                fake.succeed([widgetA])
                expect(store.isLoading).toEventually(beFalse())

                store.refreshIfNeeded(today: "2026-11-08")
                expect(fake.calls).to(equal(3))
                fake.succeed([widgetB])
                expect(store.state.value).toEventually(equal(.loaded([widgetB])))
                expect(store.loadedLocalDay).to(equal("2026-11-08"))
            }

            it("keeps the previous widgets on failure and retries on the next call") {
                store.refreshIfNeeded(today: "2026-11-07")
                fake.succeed([widgetA])
                expect(store.state.value).toEventually(equal(.loaded([widgetA])))

                store.refreshIfNeeded(force: true, today: "2026-11-07")
                fake.fail()
                expect(store.lastFailed).toEventually(beTrue())
                expect(store.state.value).to(equal(.loaded([widgetA])))
                expect(store.widgets).to(equal([widgetA]))

                store.refreshIfNeeded(today: "2026-11-07")
                expect(fake.calls).to(equal(3))
            }

            it("stays idle after a cold-start failure") {
                store.refreshIfNeeded(today: "2026-11-07")
                fake.fail()
                expect(store.lastFailed).toEventually(beTrue())
                expect(store.state.value).to(equal(.idle))
                expect(store.loadedLocalDay).to(beNil())
            }

            it("reset clears memory and rendered fills, and drops a response from before the reset") {
                store.refreshIfNeeded(today: "2026-11-07")
                fake.succeed([widgetA])
                expect(store.state.value).toEventually(equal(.loaded([widgetA])))
                store.markRendered(widgetId: "1", fill: 0.5)

                store.refreshIfNeeded(force: true, today: "2026-11-07")
                store.reset()
                expect(store.state.value).to(equal(.idle))
                expect(store.widgets).to(beNil())
                expect(store.loadedLocalDay).to(beNil())
                expect(store.isLoading).to(beFalse())
                expect(store.renderedFill).to(beEmpty())

                fake.succeed([widgetB]) // answers the request issued before reset()
                expect(store.state.value).toNever(equal(.loaded([widgetB])), until: .milliseconds(200))
                expect(store.loadedLocalDay).to(beNil())
            }

            it("treats an empty list as loaded with nothing to render") {
                store.refreshIfNeeded(today: "2026-11-07")
                fake.succeed([])
                expect(store.state.value).toEventually(equal(.loaded([])))
                expect(store.state.value.widgets).to(beEmpty())
                var content = FeedContent(withFeeds: [], kpiState: store.state.value)
                expect(content.sections).to(beEmpty())
            }

            it("refreshes on a significant time change") {
                let center = NotificationCenter()
                let observed = KpiWidgetStore(fetch: { fake.fetch() }, notificationCenter: center)
                // Raw name: the test target builds in Swift 4 mode, where the UIKit constant is spelled differently.
                center.post(name: Notification.Name("UIApplicationSignificantTimeChangeNotification"), object: nil)
                expect(fake.calls).toEventually(equal(1))
                _ = observed
            }
        }

        // MARK: 5. Animation rule

        describe("KPI gauge animation") {
            var store: KpiWidgetStore!
            beforeEach {
                store = KpiWidgetStore(fetch: { .never() }, notificationCenter: NotificationCenter())
            }

            it("animates from 0 on first render, from the stored fill on change, not at all when equal") {
                let widget = makeWidget(id: "1", percentage: 83.33)
                expect(store.animationStart(for: widget)).to(equal(0))
                store.markRendered(widgetId: "1", fill: widget.fill)
                expect(store.animationStart(for: widget)).to(beNil())
                expect(store.animationStart(for: makeWidget(id: "1", percentage: 90))).to(equal(widget.fill))
                // Nothing to animate at 0 %.
                expect(store.animationStart(for: makeWidget(id: "2", percentage: nil))).to(beNil())
            }

            it("writes the rendered fill only when the animation completes") {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
                let gauge = KpiGaugeView()
                window.addSubview(gauge)
                window.isHidden = false
                let widget = makeWidget(id: "1", percentage: 57)
                var completed = false
                gauge.set(id: widget.id, fill: widget.fill, display: widget.displayPercent,
                          progressColor: .green, trackColor: .gray,
                          animatedFrom: store.animationStart(for: widget),
                          completion: {
                    completed = true
                    store.markRendered(widgetId: widget.id, fill: widget.fill)
                })
                expect(completed).to(beFalse())
                expect(store.renderedFill["1"]).to(beNil())
                expect(completed).toEventually(beTrue(), timeout: .seconds(3))
                expect(store.renderedFill["1"]).to(equal(widget.fill))
                window.isHidden = true
            }

            it("counts by integer interpolation and lands exactly on the display value") {
                for display in [29, 53, 57, 58, 59, 100] {
                    let widget = makeWidget(percentage: Double(display))
                    expect(widget.displayPercent).to(equal(display))
                    let steps = (1...12).map { step -> Int in
                        let time = Double(step) / 12
                        return KpiGaugeView.countedValue(from: 0, to: display, progress: 1 - (1 - time) * (1 - time))
                    }
                    expect(steps.last).to(equal(display))
                    expect(steps).to(equal(steps.sorted()))
                    expect(KpiGaugeView.countedValue(from: 40, to: display, progress: 1)).to(equal(display))
                    expect(KpiGaugeView.countedValue(from: 40, to: display, progress: 0)).to(equal(40))
                }
            }
        }

        // MARK: Review round (FUAM-4315 fix round, F1-F8 + blank admin fields)

        describe("KpiWidget blank texts") {
            it("treats a blank title and an empty-paragraph body as absent") {
                let json = """
                {"data":[{"id":"9","type":"kpi_widget","attributes":{"kpi_type":"quick_activities_adherence",
                "display_mode":"gauge","position":null,"featured":false,"completed":1,"total":2,"percentage":50.0,
                "meets_threshold":false,"title":"","body":"<p></p>\\n"}},
                {"id":"10","type":"kpi_widget","attributes":{"kpi_type":"quick_activities_adherence",
                "display_mode":"gauge","position":null,"featured":false,"completed":1,"total":2,"percentage":50.0,
                "meets_threshold":false,"title":"  \\n ","body":"   "}}]}
                """
                let decoded: ExcludeInvalid<KpiWidget>? = try? Response(statusCode: 200, data: Data(json.utf8))
                    .mapCodableJSONAPI(includeList: KpiWidget.includeList, keyPath: KpiWidget.keyPath)
                let widgets = decoded?.wrappedValue ?? []
                expect(widgets.count).to(equal(2))
                expect(widgets.map { $0.title }).to(equal([nil, nil]))
                expect(widgets.map { $0.body }).to(equal([nil, nil]))

                let cell = KpiWidgetTableViewCell(style: .default, reuseIdentifier: nil)
                guard let widget = widgets.first else { return }
                cell.display(widget: widget, store: nil, showInfo: true, infoCallback: {})
                expect(cell.titleLabel.attributedText).to(beNil())
                expect(cell.titleLabel.isHidden).to(beFalse())
                expect(cell.bodyLabel.attributedText).to(beNil())
            }
        }

        describe("RepositoryImpl.getKpiWidgets") {
            var api: FakeApiGateway!
            var repository: RepositoryImpl!
            beforeEach {
                api = FakeApiGateway()
                repository = RepositoryImpl(api: api, storage: KpiFakeStorage(), notificationService: KpiFakeNotificationService(),
                                            analyticsService: KpiFakeAnalytics(), showDefaultUserInfo: false,
                                            appleWatchAlternativeIntegrations: [])
            }

            it("keeps only supported widgets") {
                var result: [KpiWidget]?
                _ = repository.getKpiWidgets().subscribe(onSuccess: { result = $0 })
                expect(result?.map { $0.id }).toEventually(equal(["1", "2"]))
            }

            it("surfaces a 404 as endpointNotFound") {
                api.kpiWidgetsError = apiError(statusCode: 404)
                var received: Error?
                _ = repository.getKpiWidgets().subscribe(onSuccess: { _ in }, onFailure: { received = $0 })
                expect(received).toEventuallyNot(beNil())
                guard case KpiWidgetError.endpointNotFound? = received else {
                    fail("expected endpointNotFound, got \(String(describing: received))")
                    return
                }
            }

            it("after a cold-start 404, only a forced refresh asks again until a 200 clears it") {
                api.kpiWidgetsError = apiError(statusCode: 404)
                var calls = 0
                let center = NotificationCenter()
                let store = KpiWidgetStore(fetch: { calls += 1; return repository.getKpiWidgets() },
                                           notificationCenter: center)
                store.refreshIfNeeded(today: "2026-11-07")
                expect(store.state.value).toEventually(equal(.loaded([])))
                expect(store.lastFailed).to(beFalse())
                expect(store.endpointUnavailable).to(beTrue())
                expect(calls).to(equal(1))

                // Feed appear, foreground, QA submission, section change: plain triggers.
                store.refreshIfNeeded(today: "2026-11-07")
                // Day change.
                store.refreshIfNeeded(today: "2026-11-08")
                // Significant time change (midnight with the Feed open).
                center.post(name: Notification.Name("UIApplicationSignificantTimeChangeNotification"), object: nil)
                expect(calls).toNever(beGreaterThan(1), until: .milliseconds(200))

                // Pull-to-refresh asks again; still 404: still unavailable, still no card.
                store.refreshIfNeeded(force: true, today: "2026-11-08")
                expect(calls).to(equal(2))
                expect(store.isLoading).toEventually(beFalse())
                expect(store.state.value).to(equal(.loaded([])))
                expect(store.lastFailed).to(beFalse())
                expect(store.endpointUnavailable).to(beTrue())
                store.refreshIfNeeded(today: "2026-11-09")
                expect(calls).to(equal(2))

                // The backend deploys: the next pull-to-refresh gets a 200 and clears the flag.
                api.kpiWidgetsError = nil
                store.refreshIfNeeded(force: true, today: "2026-11-09")
                expect(calls).to(equal(3))
                expect(store.state.value.widgets.map { $0.id }).toEventually(equal(["1", "2"]))
                expect(store.endpointUnavailable).to(beFalse())
                // The once-a-day rule applies again.
                store.refreshIfNeeded(today: "2026-11-09")
                expect(calls).to(equal(3))
                store.refreshIfNeeded(today: "2026-11-10")
                expect(calls).to(equal(4))
            }

            it("reset() clears the unavailable flag") {
                api.kpiWidgetsError = apiError(statusCode: 404)
                var calls = 0
                let store = KpiWidgetStore(fetch: { calls += 1; return repository.getKpiWidgets() },
                                           notificationCenter: NotificationCenter())
                store.refreshIfNeeded(today: "2026-11-07")
                expect(store.endpointUnavailable).toEventually(beTrue())
                store.reset()
                expect(store.endpointUnavailable).to(beFalse())
                store.refreshIfNeeded(today: "2026-11-07")
                expect(calls).to(equal(2))
            }

            it("once a card is loaded, a 404 is an ordinary failure that keeps the card") {
                var calls = 0
                let store = KpiWidgetStore(fetch: { calls += 1; return repository.getKpiWidgets() },
                                           notificationCenter: NotificationCenter())
                store.refreshIfNeeded(today: "2026-11-07")
                expect(store.state.value.widgets.map { $0.id }).toEventually(equal(["1", "2"]))
                let loaded = store.state.value

                api.kpiWidgetsError = apiError(statusCode: 404)
                store.refreshIfNeeded(force: true, today: "2026-11-07")
                expect(store.lastFailed).toEventually(beTrue())
                expect(store.state.value).to(equal(loaded))
                expect(store.endpointUnavailable).to(beFalse())
                store.refreshIfNeeded(today: "2026-11-07")
                expect(calls).to(equal(3)) // a failure retries on the next trigger
            }

            it("still fails on any other error") {
                api.kpiWidgetsError = apiError(statusCode: 500)
                var failed = false
                _ = repository.getKpiWidgets().subscribe(onSuccess: { _ in }, onFailure: { _ in failed = true })
                expect(failed).toEventually(beTrue())
            }
        }

        describe("KpiWidgetStore generation check") {
            it("drops a response that belongs to a request issued before reset()") {
                var store: KpiWidgetStore!
                let widget = makeWidget(id: "1", percentage: 50)
                // Logout lands while the request is being issued: dispose() has nothing to cancel yet,
                // so only the generation check can drop the synchronous answer.
                store = KpiWidgetStore(fetch: { store.reset(); return .just([widget]) },
                                       notificationCenter: NotificationCenter())
                store.refreshIfNeeded(today: "2026-11-07")
                expect(store.state.value).toNever(equal(.loaded([widget])), until: .milliseconds(200))
                expect(store.loadedLocalDay).to(beNil())
                expect(store.widgets).to(beNil())
            }
        }

        describe("Feed content mapping") {
            it("reads the KPI state when the feed response arrives, not when it was requested") {
                let store = KpiWidgetStore(fetch: { .never() }, notificationCenter: NotificationCenter())
                let feeds = PublishSubject<[Feed]>()
                var content: FeedContent?
                _ = FeedViewController.feedContentSingle(feeds: feeds.asSingle(), settings: .just(nil), kpiWidgetStore: store)
                    .subscribe(onSuccess: { content = $0 })
                let widget = makeWidget(id: "1", percentage: 50)
                store.state.accept(.loaded([widget])) // arrives while the feed request is in flight
                feeds.onNext([])
                feeds.onCompleted()
                expect(content?.kpiState).toEventually(equal(.loaded([widget])))
            }
        }

        describe("FeedListManager KPI wiring") {
            var host: UIViewController!
            var tableView: UITableView!
            var delegate: KpiFakeFeedDelegate!
            var manager: FeedListManager!
            beforeEach {
                host = UIViewController()
                tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 375, height: 800), style: .grouped)
                host.view.addSubview(tableView)
                delegate = KpiFakeFeedDelegate(presenter: host)
                let navigator = AppNavigator(withRepository: MockRepository(), analytics: KpiFakeAnalytics(),
                                             deeplinkService: DeeplinkManager(), window: UIWindow())
                manager = FeedListManager(repository: MockRepository(), navigator: navigator, tableView: tableView,
                                          delegate: delegate, pageSize: 20, analytics: KpiFakeAnalytics())
            }
            afterEach {
                manager = nil
            }

            it("reports a pull-to-refresh to the delegate") {
                tableView.refreshControl?.sendActions(for: .valueChanged)
                expect(delegate.pullToRefreshCount).to(equal(1))
            }

            it("keeps the background empty view and the empty-feed row exclusive") {
                let widget = makeWidget(id: "1", percentage: 50)
                manager.updateKpiState(.loaded([widget])) // before any feed: nothing to merge into
                expect(delegate.emptyListCalls).to(beEmpty())

                manager.refreshItems()
                expect(delegate.emptyListCalls.last).toEventually(equal(true))
                manager.updateKpiState(.loaded([widget]))
                expect(delegate.emptyListCalls.last).to(equal(false))
                expect(tableView.numberOfSections).to(equal(2)) // KPI + EmptyFeedSection
                manager.updateKpiState(.loaded([]))
                expect(delegate.emptyListCalls.last).to(equal(true))
                expect(tableView.numberOfSections).to(equal(0))
            }
        }

        describe("KPI gauge edge cases") {
            var window: UIWindow!
            var gauge: KpiGaugeView!
            beforeEach {
                window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
                gauge = KpiGaugeView()
                gauge.isReduceMotionEnabled = { false }
                window.addSubview(gauge)
                window.isHidden = false
            }
            afterEach {
                window.isHidden = true
            }

            it("does not restart for the same widget and value") {
                var completions = 0
                gauge.set(id: "1", fill: 0.5, display: 50, progressColor: .green, trackColor: .gray,
                          animatedFrom: 0, completion: { completions += 1 })
                let first = gauge.fillAnimation
                expect(first).toNot(beNil())
                gauge.set(id: "1", fill: 0.5, display: 50, progressColor: .green, trackColor: .gray,
                          animatedFrom: 0, completion: { completions += 1 })
                expect(gauge.fillAnimation === first).to(beTrue())
                expect(completions).toEventually(equal(1), timeout: .seconds(3))
                expect(completions).toNever(beGreaterThan(1), until: .milliseconds(300))
            }

            it("never records a superseded animation") {
                var firstCompleted = false
                var secondCompleted = false
                gauge.set(id: "1", fill: 0.5, display: 50, progressColor: .green, trackColor: .gray,
                          animatedFrom: 0, completion: { firstCompleted = true })
                gauge.set(id: "2", fill: 0.8, display: 80, progressColor: .green, trackColor: .gray,
                          animatedFrom: 0, completion: { secondCompleted = true })
                expect(secondCompleted).toEventually(beTrue(), timeout: .seconds(3))
                expect(firstCompleted).to(beFalse())
            }

            it("skips the animation with Reduce Motion and records immediately") {
                gauge.isReduceMotionEnabled = { true }
                var completed = false
                gauge.set(id: "1", fill: 0.5, display: 50, progressColor: .green, trackColor: .gray,
                          animatedFrom: 0, completion: { completed = true })
                expect(completed).to(beTrue())
                expect(gauge.fillAnimation).to(beNil())
                expect(gauge.valueLabel.text).to(equal("50"))
            }

            it("continues from the drawn arc and the shown number when the value changes mid-sweep") {
                gauge.set(id: "1", fill: 0.9, display: 90, progressColor: .green, trackColor: .gray,
                          animatedFrom: 0, completion: {})
                var midway = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { midway = true }
                expect(midway).toEventually(beTrue())
                let shown = gauge.valueLabel.text
                expect(Int(shown ?? "") ?? 0).to(beGreaterThan(0))
                // The store has not recorded the first sweep yet, so it still says "from 0".
                gauge.set(id: "1", fill: 0.5, display: 50, progressColor: .green, trackColor: .gray,
                          animatedFrom: 0, completion: {})
                let from = (gauge.fillAnimation?.fromValue as? NSNumber)?.doubleValue ?? 0
                expect(from).to(beGreaterThan(0.05))
                expect(gauge.valueLabel.text).to(equal(shown))
            }
        }

        describe("KPI card layout") {
            it("renders the Figma line height: 1.5 x the point size") {
                for size: CGFloat in [15, 16] {
                    let font = UIFont.systemFont(ofSize: size)
                    let multiple = KpiWidgetTableViewCell.lineHeightMultiple(for: font)
                    expect(Double(multiple * font.lineHeight)).to(beCloseTo(Double(size) * 1.5, within: 0.001))
                }
                let cell = KpiWidgetTableViewCell(style: .default, reuseIdentifier: nil)
                let widget = KpiWidget(id: "1", type: "kpi_widget", kpiType: KpiWidget.supportedKpiType, displayMode: "gauge",
                                       position: nil, featured: false, completed: 1, total: 2, percentage: 50,
                                       meetsThreshold: false, title: "T", body: "<p>B</p>")
                cell.display(widget: widget, store: nil, showInfo: false, infoCallback: {})
                for label in [cell.titleLabel, cell.bodyLabel] {
                    guard let text = label.attributedText,
                          let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
                          let style = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle else {
                        fail("missing attributes")
                        continue
                    }
                    expect(Double(style.lineHeightMultiple * font.lineHeight))
                        .to(beCloseTo(Double(font.pointSize) * 1.5, within: 0.001))
                }
            }

            it("exposes the title row as one button only when the info message exists") {
                let cell = KpiWidgetTableViewCell(style: .default, reuseIdentifier: nil)
                let titled = KpiWidget(id: "1", type: "kpi_widget", kpiType: KpiWidget.supportedKpiType, displayMode: "gauge",
                                       position: nil, featured: false, completed: 1, total: 2, percentage: 50,
                                       meetsThreshold: false, title: "Quick Activities", body: nil)
                cell.display(widget: titled, store: nil, showInfo: true, infoCallback: {})
                expect(cell.titleRow.isAccessibilityElement).to(beTrue())
                expect(cell.titleRow.accessibilityTraits & UIAccessibilityTraitButton).toNot(equal(0)) // Swift 4 test target
                expect(cell.titleRow.accessibilityLabel).to(equal("Quick Activities"))

                cell.display(widget: makeWidget(id: "2", percentage: 50), store: nil, showInfo: true,
                             infoMessageTitle: "Understanding Your Progress Tracker", infoCallback: {})
                expect(cell.titleRow.accessibilityLabel).to(equal("Understanding Your Progress Tracker"))
                cell.display(widget: makeWidget(id: "2", percentage: 50), store: nil, showInfo: true, infoCallback: {})
                expect(cell.titleRow.accessibilityLabel).to(equal("Info"))
                expect(cell.titleLabel.isHidden).to(beFalse()) // icon keeps its trailing slot

                cell.display(widget: titled, store: nil, showInfo: false, infoCallback: {})
                expect(cell.titleRow.isAccessibilityElement).to(beFalse())
                expect(cell.titleRow.accessibilityTraits & UIAccessibilityTraitButton).to(equal(0))
            }
        }

        // MARK: 7. Palette defaults

        describe("KPI palette keys") {
            afterEach {
                ColorPalette.initialize(light: [:], dark: [:])
            }

            it("falls back to the defaults when the keys are missing") {
                let json: NSDictionary = ["color_palette": ["primary_color_start": "#140F26"]]
                let light: ColorMap? = try? Mapper(JSON: json).from("color_palette")
                expect(light?[.kpiWidgetThreshold1]).to(beNil())
                ColorPalette.initialize(light: light ?? [:], dark: nil)

                expect(hex(.kpiWidgetThreshold1, .light)).to(equal(0x6B9211))
                expect(hex(.kpiWidgetThreshold0, .light)).to(equal(0x37424A))
                expect(hex(.kpiWidgetThreshold1, .dark)).to(equal(0x6B9211))
                expect(hex(.kpiWidgetThreshold0, .dark)).to(equal(0xD9D9D9))
            }

            it("reads the keys when present") {
                let json: NSDictionary = ["color_palette": ["kpi_widget_threshold_1_color": "#112233",
                                                            "kpi_widget_threshold_0_color": "#445566"]]
                let light: ColorMap? = try? Mapper(JSON: json).from("color_palette")
                ColorPalette.initialize(light: light ?? [:], dark: light ?? [:])
                expect(hex(.kpiWidgetThreshold1, .light)).to(equal(0x112233))
                expect(hex(.kpiWidgetThreshold0, .dark)).to(equal(0x445566))
            }
        }
    }
}

// MARK: - Helpers

private func makeWidget(id: String = "1", percentage: Double?) -> KpiWidget {
    return KpiWidget(id: id, type: "kpi_widget", kpiType: KpiWidget.supportedKpiType, displayMode: "gauge",
                     position: nil, featured: false, completed: 0, total: 0, percentage: percentage,
                     meetsThreshold: false, title: nil, body: nil)
}

private func text(_ html: String) -> String {
    return KpiHtmlScanner.scan(html).map(\.text).joined()
}

private func hex(_ type: ColorType, _ style: UIUserInterfaceStyle) -> Int {
    let color = ColorPalette.color(withType: type).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (Int((red * 255).rounded()) << 16) | (Int((green * 255).rounded()) << 8) | Int((blue * 255).rounded())
}

/// A fetch the spec answers by hand, so in-flight, failure and late responses are deterministic.
private final class FakeKpiFetch {
    private(set) var calls = 0
    private var observers: [(SingleEvent<[KpiWidget]>) -> Void] = []

    func fetch() -> Single<[KpiWidget]> {
        self.calls += 1
        return Single.create { observer in
            self.observers.append(observer)
            return Disposables.create()
        }
    }

    func succeed(_ widgets: [KpiWidget]) {
        self.observers.removeFirst()(.success(widgets))
    }

    func fail() {
        self.observers.removeFirst()(.failure(NSError(domain: "test", code: 1)))
    }
}

private func apiError(statusCode: Int) -> ApiError {
    return .unexpectedError(pathUrl: "v1/kpi_widgets", request: ApiRequest(serviceRequest: .getKpiWidgets),
                            statusCode: statusCode, responseBody: "")
}

private final class KpiFakeStorage: RepositoryStorage {
    var globalConfig: GlobalConfig?
    var user: User?
    var infoMessages: [MessageInfo]?
    var feedbackList: [String: [EmojiItem]] = [:]
}

private final class KpiFakeNotificationService: NotificationService {
    func getRegistrationToken() -> Single<String?> { .just(nil) }
}

private final class KpiFakeAnalytics: AnalyticsService {
    func track(event: AnalyticsEvent) {}
}

private final class KpiFakeFeedDelegate: FeedListManagerDelegate {
    let presenter: UIViewController
    private(set) var emptyListCalls: [Bool] = []
    private(set) var pullToRefreshCount = 0

    init(presenter: UIViewController) {
        self.presenter = presenter
    }

    func handleEmptyList(show: Bool) { self.emptyListCalls.append(show) }
    func getDataProviderSingle(repository: Repository, fetchMode: FetchMode) -> Single<FeedContent> {
        return .just(FeedContent(withFeeds: [], kpiState: .idle))
    }
    func onPullToRefresh() { self.pullToRefreshCount += 1 }
    func showError(error: Error) {}
}
