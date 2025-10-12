import Foundation
import ObjectiveC

public protocol ValidatableInterfaceElement {
    
    associatedtype InputType: Validatable
    var inputValue: InputType? { get }
    
    func validate<R: ValidationRule>(rule r: R) -> ValidationResult
    func validate(rules: ValidationRuleSet<InputType>) -> ValidationResult
    
    var validationHandler: ((ValidationResult) -> Void)? { get set }

    func validateOnInputChange(enabled: Bool)
}

private var validatableInterfaceElementRulesKey: UInt8 = 0
private var validatableInterfaceElementHandlerKey: UInt8 = 0

extension ValidatableInterfaceElement {

    public func validate<Rule: ValidationRule>(rule: Rule) -> ValidationResult {
        
        guard let value = inputValue as? Rule.InputType else {
            
            return .invalid([rule.error])
        }
        
        let result = Validator.validate(input: value, rule: rule)
        validationHandler?(result)
        return result
    }
    
    public func validate(rules: ValidationRuleSet<InputType>) -> ValidationResult {
        
        let result = Validator.validate(input: inputValue, rules: rules)
        validationHandler?(result)
        return result
    }
    
    @discardableResult
    public func validate() -> ValidationResult {
        
        guard let attachedRules = validationRules else {
            
            #if DEBUG
            print("Validator Error: attempted to validate without attaching rules")
            #endif
            return .valid
        }
        
        return validate(rules: attachedRules)
    }
    
    public var validationRules: ValidationRuleSet<InputType>? {
        
        get {
        
            return objc_getAssociatedObject(self, &validatableInterfaceElementRulesKey) as? ValidationRuleSet<InputType>
        }
        
        set(newValue) {
            
            if let n = newValue {
            
                objc_setAssociatedObject(self, &validatableInterfaceElementRulesKey, n as AnyObject, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public var validationHandler: ((ValidationResult) -> Void)? {
        
        get {
        
            return objc_getAssociatedObject(self, &validatableInterfaceElementHandlerKey) as? (ValidationResult) -> Void
        }
        
        set(newValue) {
        
            if let n = newValue {
            
                objc_setAssociatedObject(self, &validatableInterfaceElementHandlerKey, n as AnyObject, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}
