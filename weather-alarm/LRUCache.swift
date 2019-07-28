//
// http://stackoverflow.com/questions/25970415/standard-implementation-of-an-lru-cache
// Usage:
//   let cache = LRUCache<NSString, NSString>()
//   cache.countLimit = 3
//   cache["key1"] = "val1"
//   ...
//   cache["key1"]   // may contain value or nil
//
import Foundation

struct LRUCache<K:AnyObject, V:AnyObject> {
	
    private let _cache = NSCache<AnyObject, AnyObject>()
	private let _keys = NSMutableSet()
	
	var countLimit:Int {
		get {
			return _cache.countLimit
		}
		nonmutating set(countLimit) {
			_cache.countLimit = countLimit
		}
	}
	subscript(key:K) -> V? {
		get {
            let obj:AnyObject? = _cache.object(forKey: key)
			return obj as! V?
		}
        nonmutating set(obj) {
			if(obj == nil) {
                _cache.removeObject(forKey: key)
                _keys.remove(key)
			}
			else {
                _cache.setObject(obj!, forKey: key)
                _keys.add(key)
			}
		}
	}
	var	keys:NSMutableSet {
		get {
			return _keys
		}
	}
}
