//
//  SectionOptionalPagesDecodingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4045: welcome and success pages are optional in the opt-in and the
//  integration onboarding sections, and a section with nothing to show is
//  skipped. These specs run the real network decoding path (Japx with the
//  entity's `includeList`, then the keyPath-scoped JSONDecoder — same as
//  `Response.mapCodableJSONAPI`) so that a relationship that is absent, null
//  or not included cannot regress into a parse failure.
//

import Quick
import Nimble
@testable import ForYouAndMe

class SectionOptionalPagesDecodingSpec: QuickSpec {

    /// Mirrors `Response.mapCodableJSONAPI(includeList:keyPath:)`.
    private static func decode<T: JSONAPIMappable>(_ type: T.Type, from json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JapxDecoder()
        guard let parsed = try? Japx.Decoder.jsonObject(with: data, includeList: T.includeList, options: decoder.options),
              let keyPath = T.keyPath,
              let jsonForKeyPath = (parsed as AnyObject).value(forKeyPath: keyPath),
              let jsonApiData = try? JSONSerialization.data(withJSONObject: jsonForKeyPath) else {
            return nil
        }
        return try? decoder.jsonDecoder.decode(T.self, from: jsonApiData)
    }

    /// A `page` resource object, minimally populated.
    private static func pageResource(id: String) -> String {
        return """
        {
            "id": "\(id)",
            "type": "page",
            "attributes": { "title": "Title \(id)", "body": "Body \(id)" }
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
                                           pageIds: [String] = []) -> String {
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
            "included": [\(allPageIds.map { self.pageResource(id: $0) }.joined(separator: ", "))]
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

        describe("IntegrationSection decoding — FUAM-4045 optional pages") {

            it("still decodes a fully-linked section (regression)") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: "101", successPageId: "109", pageIds: ["101", "109"]))
                expect(section).toNot(beNil())
                expect(section?.welcomePage?.id).to(equal("101"))
                expect(section?.successPage?.id).to(equal("109"))
                expect(section?.pages.count).to(equal(2))
                expect(section?.isEmpty).to(beFalse())
            }

            // The loose `pages` are reachable only via page links from the
            // welcome (or success) page, never as a starting step or a
            // fallback: without a welcome page nothing is reachable, so the
            // whole section is skipped regardless of pages / success page.
            it("is empty without a welcome page, even with content and success pages") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: nil, successPageId: "109", pageIds: ["102", "109"]))
                expect(section).toNot(beNil())
                expect(section?.welcomePage).to(beNil())
                expect(section?.pages.first?.id).to(equal("102"))
                expect(section?.successPage?.id).to(equal("109"))
                expect(section?.isEmpty).to(beTrue())
            }

            it("decodes with an absent success page") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: "101", successPageId: nil, pageIds: ["101"]))
                expect(section).toNot(beNil())
                expect(section?.successPage).to(beNil())
                expect(section?.welcomePage?.id).to(equal("101"))
                expect(section?.isEmpty).to(beFalse())
            }

            it("is empty when only content pages are present — they are not a starting step") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: nil, successPageId: nil, pageIds: ["102"]))
                expect(section?.welcomePage).to(beNil())
                expect(section?.successPage).to(beNil())
                expect(section?.pages.count).to(equal(1))
                expect(section?.isEmpty).to(beTrue())
            }

            it("is not empty with a welcome page alone") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: "101", successPageId: nil))
                expect(section?.welcomePage?.id).to(equal("101"))
                expect(section?.pages).to(beEmpty())
                expect(section?.isEmpty).to(beFalse())
            }

            it("is empty when the welcome page is absent") {
                let section = decode(IntegrationSection.self,
                                     from: integrationPayload(welcomePageId: nil, successPageId: nil))
                expect(section).toNot(beNil())
                expect(section?.isEmpty).to(beTrue())
            }

            it("decodes the empty record the backend returns for a study with no integration") {
                // Mirrors `IntegrationsController#show` rendering `Integration.new`
                // through `IntegrationSerializer`: blank id, empty attributes and
                // every declared relationship emitted but empty.
                let payload = """
                {
                    "data": {
                        "id": "",
                        "type": "integration",
                        "attributes": { "created_at": null, "updated_at": null },
                        "relationships": {
                            "pages": { "data": [] },
                            "welcome_page": { "data": null },
                            "success_page": { "data": null },
                            "failure_page": { "data": null }
                        }
                    }
                }
                """
                let section = decode(IntegrationSection.self, from: payload)
                expect(section).toNot(beNil())
                expect(section?.welcomePage).to(beNil())
                expect(section?.successPage).to(beNil())
                expect(section?.pages).to(beEmpty())
                expect(section?.isEmpty).to(beTrue())
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
