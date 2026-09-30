//
//  SectionOptionalPagesDecodingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4045: welcome and success pages are optional in the opt-in and the
//  integration onboarding sections, and a section with nothing to show is
//  skipped. These specs decode through the production mapping of
//  `NetworkApiGateway.send` (`Response.mapJSONAPIMappable`: Japx with the
//  entity's `includeList`, the keyPath-scoped JSONDecoder, and the opt-in
//  null-id fallback), and one spec drives the gateway itself through a stubbed
//  Moya provider, so that a relationship that is absent, null or not included,
//  or a null primary id (FUAM-4036), cannot regress into a parse failure.
//

import Quick
import Nimble
import Moya
import RxSwift
@testable import ForYouAndMe

class SectionOptionalPagesDecodingSpec: QuickSpec {

    /// The production mapping used by `NetworkApiGateway.send` (`Response.mapJSONAPIMappable`).
    private static func decode<T: JSONAPIMappable>(_ type: T.Type, from json: String) -> T? {
        return try? Response(statusCode: 200, data: Data(json.utf8)).mapJSONAPIMappable(T.self)
    }

    /// A real `NetworkApiGateway` whose Moya provider answers every request with `json` (HTTP 200).
    private static func gateway(answering json: String) -> NetworkApiGateway {
        let gateway = NetworkApiGateway(studyId: "1", reachability: ReachableStub(), storage: StorageStub())
        gateway.defaultProvider = MoyaProvider<DefaultService>(endpointClosure: { target in
            Endpoint(url: "https://example.invalid/\(target.path)",
                     sampleResponseClosure: { .networkResponse(200, Data(json.utf8)) },
                     method: target.method,
                     task: target.task,
                     httpHeaderFields: nil)
        }, stubClosure: MoyaProvider.immediatelyStub)
        return gateway
    }

    private struct ReachableStub: ReachabilityService {
        var isCurrentlyReachable: Bool { true }
        var currentReachabilityType: ReachabilityServiceType { .wifi }
        func getReachability() -> Observable<ReachabilityServiceType> { .just(.wifi) }
    }

    private final class StorageStub: NetworkStorage {
        var accessToken: String?
    }

    /// A `page` resource object, minimally populated, optionally linking `link_1` to `link1`.
    private static func pageResource(id: String, link1: String? = nil) -> String {
        let relationships = link1.map { ", \"relationships\": { \"link_1\": \(self.relationshipToPage($0)) }" } ?? ""
        return """
        {
            "id": "\(id)",
            "type": "page",
            "attributes": { "title": "Title \(id)", "body": "Body \(id)" }\(relationships)
        }
        """
    }

    private static func relationshipToPage(_ id: String?) -> String {
        guard let id = id else { return "{ \"data\": null }" }
        return "{ \"data\": { \"id\": \"\(id)\", \"type\": \"page\" } }"
    }

    /// Builds an `opt_in` JSON:API payload. A nil `welcomePageId` /
    /// `successPageId` renders the relationship with a null `data`, which is
    /// what the backend emits for an unlinked page.
    private static func optInPayload(welcomePageId: String?,
                                     successPageId: String?,
                                     permissionIds: [String] = []) -> String {
        let pageIds = [welcomePageId, successPageId].compactMap { $0 }
        let relationships = """
            "relationships": {
                "pages": { "data": [\(pageIds.map { "{ \"id\": \"\($0)\", \"type\": \"page\" }" }.joined(separator: ", "))] },
                "welcome_page": \(self.relationshipToPage(welcomePageId)),
                "success_page": \(self.relationshipToPage(successPageId)),
                "permissions": { "data": [\(permissionIds.map { "{ \"id\": \"\($0)\", \"type\": \"permission\" }" }
            .joined(separator: ", "))] }
            },
        """
        let included = (pageIds.map { self.pageResource(id: $0) } + permissionIds.map { self.permissionResource(id: $0) })
            .joined(separator: ", ")
        return """
        {
            "data": {
                "id": "1",
                "type": "opt_in",
                "attributes": {},
                \(relationships)
                "meta": {}
            },
            "included": [\(included)]
        }
        """
    }

    private static func permissionResource(id: String, platforms: String = "[]") -> String {
        return """
        {
            "id": "\(id)",
            "type": "permission",
            "attributes": {
                "title": "Permission \(id)",
                "body": "Body",
                "agree_text": "",
                "disagree_text": "",
                "system_permissions": [],
                "mandatory": false,
                "mandatory_description": "",
                "platforms": \(platforms)
            }
        }
        """
    }

    private static func integrationPayload(welcomePageId: String?,
                                           successPageId: String?,
                                           pageIds: [String] = [],
                                           links: [String: String] = [:]) -> String {
        let allPageIds = Array(Set(pageIds + [welcomePageId, successPageId].compactMap { $0 })).sorted()
        let relationships = """
            "relationships": {
                "pages": { "data": [\(pageIds.map { "{ \"id\": \"\($0)\", \"type\": \"page\" }" }.joined(separator: ", "))] },
                "welcome_page": \(self.relationshipToPage(welcomePageId)),
                "success_page": \(self.relationshipToPage(successPageId))
            },
        """
        return """
        {
            "data": {
                "id": "1",
                "type": "integration",
                "attributes": {},
                \(relationships)
                "meta": {}
            },
            "included": [\(allPageIds.map { self.pageResource(id: $0, link1: links[$0]) }.joined(separator: ", "))]
        }
        """
    }

    override class func spec() {

        describe("OptInSection decoding — FUAM-4045 optional pages") {

            it("still decodes a fully-linked section (regression)") {
                let section = decode(OptInSection.self,
                                     from: optInPayload(welcomePageId: "101", successPageId: "109", permissionIds: ["221"]))
                expect(section).toNot(beNil())
                expect(section?.welcomePage?.id).to(equal("101"))
                expect(section?.successPage?.id).to(equal("109"))
                expect(section?.optInPermissions.count).to(equal(1))
                expect(section?.isEmpty).to(beFalse())
            }

            it("decodes with an absent welcome page") {
                let section = decode(OptInSection.self,
                                     from: optInPayload(welcomePageId: nil, successPageId: "109", permissionIds: ["221"]))
                expect(section).toNot(beNil())
                expect(section?.welcomePage).to(beNil())
                expect(section?.successPage?.id).to(equal("109"))
                expect(section?.isEmpty).to(beFalse())
            }

            it("decodes with an absent success page") {
                let section = decode(OptInSection.self,
                                     from: optInPayload(welcomePageId: "101", successPageId: nil, permissionIds: ["221"]))
                expect(section).toNot(beNil())
                expect(section?.welcomePage?.id).to(equal("101"))
                expect(section?.successPage).to(beNil())
                expect(section?.isEmpty).to(beFalse())
            }

            it("decodes with both pages absent but permissions present — not empty") {
                let section = decode(OptInSection.self,
                                     from: optInPayload(welcomePageId: nil, successPageId: nil, permissionIds: ["221"]))
                expect(section).toNot(beNil())
                expect(section?.welcomePage).to(beNil())
                expect(section?.successPage).to(beNil())
                expect(section?.optInPermissions.count).to(equal(1))
                expect(section?.isEmpty).to(beFalse())
            }

            it("is empty when both pages and every permission are absent") {
                let section = decode(OptInSection.self, from: optInPayload(welcomePageId: nil, successPageId: nil))
                expect(section).toNot(beNil())
                expect(section?.isEmpty).to(beTrue())
            }

            it("is empty when the only permission is gated to another platform (FUAM-3364)") {
                let payload = """
                {
                    "data": {
                        "id": "1",
                        "type": "opt_in",
                        "attributes": {},
                        "relationships": {
                            "pages": { "data": [] },
                            "welcome_page": { "data": null },
                            "success_page": { "data": null },
                            "permissions": { "data": [{ "id": "221", "type": "permission" }] }
                        },
                        "meta": {}
                    },
                    "included": [\(permissionResource(id: "221", platforms: "[\"android\"]"))]
                }
                """
                let section = decode(OptInSection.self, from: payload)
                expect(section?.optInPermissions.count).to(equal(1))
                expect(section?.isEmpty).to(beTrue())
            }

            it("decodes a payload whose relationships are all empty") {
                let section = decode(OptInSection.self, from: optInPayload(welcomePageId: nil, successPageId: nil))
                expect(section).toNot(beNil())
                expect(section?.welcomePage).to(beNil())
                expect(section?.successPage).to(beNil())
                expect(section?.pages).to(beEmpty())
                expect(section?.optInPermissions).to(beEmpty())
                expect(section?.isEmpty).to(beTrue())
            }
        }

        describe("IntegrationSection decoding — FUAM-4045 / FUAM-4036 optional pages") {

            it("still decodes a fully-linked section and starts at the welcome page (regression)") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: "101", successPageId: "109", pageIds: ["101", "109"]))
                expect(section).toNot(beNil())
                expect(section?.welcomePage?.id).to(equal("101"))
                expect(section?.successPage?.id).to(equal("109"))
                expect(section?.pages.count).to(equal(2))
                expect(section?.startingPage?.id).to(equal("101"))
                expect(section?.isEmpty).to(beFalse())
            }

            // S4: the success page alone is a valid step; the loose `pages`
            // are reachable only via page links, never as a starting step.
            it("starts at the success page when it is the only linked page, ignoring loose pages") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: nil, successPageId: "109", pageIds: ["102", "109"]))
                expect(section).toNot(beNil())
                expect(section?.welcomePage).to(beNil())
                expect(section?.successPage?.id).to(equal("109"))
                expect(section?.startingPage?.id).to(equal("109"))
                expect(section?.isEmpty).to(beFalse())
            }

            // S3.
            it("starts at the welcome page when there is no success page") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: "101", successPageId: nil, pageIds: ["101"]))
                expect(section).toNot(beNil())
                expect(section?.successPage).to(beNil())
                expect(section?.startingPage?.id).to(equal("101"))
                expect(section?.isEmpty).to(beFalse())
            }

            // S2.
            it("is empty when only loose content pages are present — they are not a starting step") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: nil, successPageId: nil, pageIds: ["102"]))
                expect(section?.welcomePage).to(beNil())
                expect(section?.successPage).to(beNil())
                expect(section?.pages.count).to(equal(1))
                expect(section?.startingPage).to(beNil())
                expect(section?.isEmpty).to(beTrue())
            }

            it("is empty when neither welcome nor success page is linked") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: nil, successPageId: nil))
                expect(section).toNot(beNil())
                expect(section?.isEmpty).to(beTrue())
            }

            // S1b.
            it("decodes the null-id empty record the backend returns for a study with no integration") {
                // Mirrors `IntegrationsController#show` rendering `Integration.new`
                // through `IntegrationSerializer` (fast_jsonapi): null id, empty
                // attributes and every declared relationship emitted but empty.
                let payload = """
                {
                    "data": {
                        "id": null,
                        "type": "integration",
                        "attributes": { "created_at": null, "updated_at": null },
                        "relationships": {
                            "pages": { "data": [] },
                            "welcome_page": { "data": null },
                            "success_page": { "data": null },
                            "failure_page": { "data": null }
                        }
                    },
                    "included": []
                }
                """
                let section = decode(IntegrationSection.self, from: payload)
                expect(section).toNot(beNil())
                expect(section?.id).to(equal(""))
                expect(section?.welcomePage).to(beNil())
                expect(section?.successPage).to(beNil())
                expect(section?.pages).to(beEmpty())
                expect(section?.isEmpty).to(beTrue())
            }

            // Drives the real `NetworkApiGateway.send` chain, so dropping the
            // normalisation from the gateway's mapping fails here.
            it("decodes the null-id empty record through the real gateway send chain") {
                let payload = """
                {
                    "data": {
                        "id": null,
                        "type": "integration",
                        "attributes": { "created_at": null, "updated_at": null },
                        "relationships": {
                            "pages": { "data": [] },
                            "welcome_page": { "data": null },
                            "success_page": { "data": null },
                            "failure_page": { "data": null }
                        }
                    },
                    "included": []
                }
                """
                let api = gateway(answering: payload)
                var result: Result<IntegrationSection, Error>?
                let disposeBag = DisposeBag()
                waitUntil(timeout: .seconds(5)) { done in
                    let single: Single<IntegrationSection> = api.send(request: ApiRequest(serviceRequest: .getIntegrationSection),
                                                                      errorType: UnhandledError.self)
                    single.subscribe(onSuccess: { result = .success($0); done() },
                                     onFailure: { result = .failure($0); done() })
                        .disposed(by: disposeBag)
                }
                guard case .success(let section) = result else {
                    fail("Expected the empty integration to decode, got \(String(describing: result))")
                    return
                }
                expect(section.id).to(equal(""))
                expect(section.isEmpty).to(beTrue())
            }

            it("keeps rejecting a null id for a type that did not opt in") {
                // A real parse failure must stay an error, never a silent skip.
                let payload = optInPayload(welcomePageId: "101", successPageId: nil)
                    .replacingOccurrences(of: "\"id\": \"1\"", with: "\"id\": null")
                expect(payload).to(contain("\"id\": null"))
                expect(decode(OptInSection.self, from: payload)).to(beNil())
            }

            describe("link resolution") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: "101",
                                                              successPageId: "109",
                                                              pageIds: ["101", "102"],
                                                              links: ["101": "109", "102": "999"]))

                it("resolves a link to the success page id to the success page, even when it is not among pages") {
                    expect(section?.pages.map { $0.id }).toNot(contain("109"))
                    guard let welcomeLink = section?.welcomePage?.buttonFirstPage else {
                        fail("Missing welcome link_1")
                        return
                    }
                    expect(section?.linkedPage(forPageRef: welcomeLink)?.id).to(equal("109"))
                    expect(section?.linkedPage(forPageRef: welcomeLink)?.id).to(equal(section?.successPage?.id))
                }

                it("resolves a link to a content page") {
                    expect(section?.linkedPage(forPageRef: PageRef(id: "102", type: "page"))?.id).to(equal("102"))
                }

                it("decodes a link to a page that is not in the payload as no link (end of chain)") {
                    // Japx drops a relationship whose target is not `included`, so the page
                    // behaves as the last of the chain (`onUnhandledPrimaryButtonNavigation`).
                    let danglingPage = section?.pages.first { $0.id == "102" }
                    expect(danglingPage).toNot(beNil())
                    expect(danglingPage?.buttonFirstPage).to(beNil())
                }

                it("resolves a reference to an id missing from the section to nil (end of chain)") {
                    expect(section?.linkedPage(forPageRef: PageRef(id: "999", type: "page"))).to(beNil())
                }
            }
        }

        describe("ApiError.statusCode — FUAM-4045 section-absent tolerance") {
            let request = ApiRequest(serviceRequest: .getOptInSection)

            it("exposes the status code of an unexpected error") {
                let error = ApiError.unexpectedError(pathUrl: "/opt_in", request: request, statusCode: 404, responseBody: "")
                expect(error.statusCode).to(equal(404))
            }

            it("exposes the status code of an expected error") {
                let error = ApiError.expectedError(pathUrl: "/opt_in",
                                                   request: request,
                                                   statusCode: 404,
                                                   responseBody: "",
                                                   parsedError: "")
                expect(error.statusCode).to(equal(404))
            }

            it("has no status code for connectivity failures") {
                expect(ApiError.connectivity.statusCode).to(beNil())
            }
        }
    }
}
