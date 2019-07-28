// https://github.com/andrei512/magic
// http://www.weheartswift.com/swift-objc-magic/

import Foundation

extension NSObject {
    class func fromJson(jsonInfo: NSDictionary) -> Self {
        let object = self.init()
        
        (object as NSObject).load(jsonInfo: jsonInfo)

        return object
    }
    
    func load(jsonInfo: NSDictionary) {
        for (key, value) in jsonInfo {
            let keyName = key as! String
            
            if (responds(to:Selector(keyName))) {
                setValue(value, forKey: keyName)
            }
        }
    }
    
    func propertyNames() -> [String] {
        var names: [String] = []
        var count: UInt32 = 0
        let properties = class_copyPropertyList(classForCoder, &count)
        for i:Int in 1..<Int(count) {
            let property: objc_property_t = (properties?[i])!
            let name: String = String(cString: property_getName(property))
            names.append(name)
        }
        free(properties)
        return names
    }
    
    func asJson() -> Dictionary<String, Any> {
        var json:Dictionary<String, Any> = [:]
        
        for name in propertyNames() {
            if let value: Any = value(forKey: name) {
                json[name] = value
            }
        }
        
        
        return json
    }
    
}
