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
