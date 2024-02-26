//
//  AutomationTypes.swift
//  Rownd
//
//  Created by Michael Murray on 5/23/23.
//

import Foundation
import AnyCodable

public struct RowndAutomation: Hashable {
    public var id: String
    public var name: String
    public var template: String
    public var state: RowndAutomationState
    public var actions: [RowndAutomationAction]
    public var rules: [RowndAutomationRule]
    public var triggers: [RowndAutomationTrigger]
}

extension RowndAutomation: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, template, state, actions, rules, triggers
    }
}

public enum RowndAutomationState: String, Codable {
    case enabled, disabled
}

public struct RowndAutomationAction: Hashable {
    public var type: RowndAutomationActionType
    public var args: Dictionary<String, AnyCodable>?
}

extension RowndAutomationAction: Codable {
    enum CodingKeys: String, CodingKey {
        case type, args
    }
}

public enum RowndAutomationActionType: String {
    case requireAuthentication = "REQUIRE_AUTHENTICATION"
    case promptForPasskey = "PROMPT_FOR_PASSKEY"
    case signOut = "SIGN_OUT"
    case requireVerification = "REQUIRE_VERIFICATION"
    case redirect = "REDIRECT"
    case promptForInput = "PROMPT_FOR_INPUT"
    case none = "NONE"
    case unknown
}

extension RowndAutomationActionType: Codable {
    public init(from decoder: Decoder) throws {
        self = try RowndAutomationActionType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
    }
}

public struct RowndAutomationRule: Hashable {
    public var attribute: String
    public var entityType: RowndAutomationRuleEntityRule
    public var condition: RowndAutomationRuleCondition
    public var value: AnyCodable?
}

extension RowndAutomationRule: Codable {
    enum CodingKeys: String, CodingKey {
        case attribute, condition, value
        case entityType = "entity_type"
    }
}

public enum RowndAutomationRuleEntityRule: String, Codable {
    case metadata
    case userData = "user_data"
}

public enum RowndAutomationRuleCondition: String {
    case equals = "EQUALS"
    case notEquals = "NOT_EQUALS"
    case contains = "CONTAINS"
    case notContains = "NOT_CONTAINS"
    case isIn = "IN"
    case isNotIn = "NOT_IN"
    case exists = "EXISTS"
    case notExists = "NOT_EXISTS"
    case greaterThan = "GREATER_THAN"
    case greaterThanEqual = "GREATER_THAN_EQUAL"
    case lessThan = "LESS_THAN"
    case lessThanEqual = "LESS_THAN_EQUAL"
    case unknown
}

extension RowndAutomationRuleCondition: Codable {
    public init(from decoder: Decoder) throws {
        self = try RowndAutomationRuleCondition(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
    }
}


public struct RowndAutomationTrigger: Hashable {
    public var type: RowndAutomationTriggerType
    public var value: String
    public var target: String?
}

extension RowndAutomationTrigger: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value, target
    }
}

public enum RowndAutomationTriggerType: String {
    case time = "TIME"
    case url = "URL"
    case event = "EVENT"
    case htmlSelector = "HTML_SELECTOR"
    case htmlSelectorVisible = "HTML_SELECTOR_VISIBLE"
    case unknown
}

extension RowndAutomationTriggerType: Codable {
    public init(from decoder: Decoder) throws {
        self = try RowndAutomationTriggerType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
    }
}
