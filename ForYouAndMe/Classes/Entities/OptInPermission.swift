//
//  OptInPermission.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/2020.
//

import Foundation

enum SystemPermission: String, Codable {
    case location
    case health
    case notification
    case sensorKit = "sensorkit"
}

/// FUAM-3364. Controls whether the opt-in permission screen renders the
/// agree/disagree radio pair or an info-only variant (title + body + image
/// + single forward CTA, no recorded user choice).
///
/// Backward-compat: when the field is absent from the BE payload, defaults
/// to `.agreeDisagree` (today's behaviour).
enum OptInAgreementDisplay: String, Codable {
    case agreeDisagree = "agree_disagree"
    case disabled
}

struct OptInPermission {
    let id: String
    let type: String

    let title: String
    let body: String
    let grantText: String
    let denyText: String
    @ExcludeInvalid
    var systemPermissions: [SystemPermission]
    let imageData: Data?
    let isMandatory: Bool
    @NilIfEmptyString
    var mandatoryText: String?

    // MARK: - FUAM-3364

    /// Platforms on which this permission should be rendered. Empty / missing
    /// means "all platforms" (backward compat). Non-empty means "only the
    /// listed platforms" — on iOS, the coordinator filters out any permission
    /// whose `platforms` is non-empty and does not contain `"ios"`.
    let platforms: [String]

    /// Controls the render mode for this permission. See `OptInAgreementDisplay`.
    let agreementDisplay: OptInAgreementDisplay
}

extension OptInPermission: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case grantText = "agree_text"
        case denyText = "disagree_text"
        case systemPermissions = "system_permissions"
        case imageData = "image"
        case isMandatory = "mandatory"
        case mandatoryText = "mandatory_description"
        case platforms
        case agreementDisplay = "agreement_display"
    }

    /// Custom decoder so that the two FUAM-3364 fields default to their
    /// backward-compatible values when absent or unrecognised on the wire.
    /// All other fields delegate to their property-wrapper-driven defaults
    /// or throw as they did before this ticket.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.title = try container.decode(String.self, forKey: .title)
        self.body = try container.decode(String.self, forKey: .body)
        self.grantText = try container.decode(String.self, forKey: .grantText)
        self.denyText = try container.decode(String.self, forKey: .denyText)
        self._systemPermissions = try container.decode(ExcludeInvalid<SystemPermission>.self,
                                                       forKey: .systemPermissions)
        self.imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        self.isMandatory = try container.decode(Bool.self, forKey: .isMandatory)
        // NilIfEmptyString conforms to OptionalCodingWrapper; the
        // KeyedDecodingContainer overload in PropertyWrappers.swift takes
        // care of falling back to `nil` when the key is absent.
        self._mandatoryText = try container.decode(NilIfEmptyString.self, forKey: .mandatoryText)

        // FUAM-3364: default to `[]` (= "all platforms") when absent or null.
        // Unknown entries (e.g. a future "web") are preserved as-is — the
        // iOS-side filter checks for the literal string "ios".
        self.platforms = (try? container.decodeIfPresent([String].self, forKey: .platforms)) ?? []

        // FUAM-3364: default to `.agreeDisagree` when absent, null, or any
        // value the SDK doesn't recognise. An unknown value is treated as
        // "render the standard screen" so older clients don't break against
        // a newer BE.
        if let raw = try? container.decodeIfPresent(String.self, forKey: .agreementDisplay),
           let parsed = OptInAgreementDisplay(rawValue: raw) {
            self.agreementDisplay = parsed
        } else {
            self.agreementDisplay = .agreeDisagree
        }
    }
}

extension OptInPermission {
    var image: UIImage? {
        if let data = self.imageData {
            return UIImage(data: data)
        } else {
            return nil
        }
    }

    // MARK: - FUAM-3364 helpers

    /// `true` when this permission should be presented on iOS. A permission
    /// whose `platforms` is non-empty and does not contain `"ios"` is
    /// excluded from the opt-in step list at the coordinator level.
    var isAvailableOnIOS: Bool {
        if self.platforms.isEmpty { return true }
        return self.platforms.contains("ios")
    }

    /// `true` when the permission should render the info-only variant
    /// (no agree/disagree controls; single forward CTA).
    var isInfoOnly: Bool {
        self.agreementDisplay == .disabled
    }
}
