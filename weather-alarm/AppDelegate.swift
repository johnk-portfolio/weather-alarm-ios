import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
	var window: UIWindow?
	var googleMapsApiKey = "AIzaSyAF68_WPiC3WN0YipyyEkyvqoxs708c97s"
	
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		
		// Google API key
		// Settings app value overrides, if present (from Settings plist)
		let settings = UserDefaults.init()
        let settingsGoogleKey = settings.object(forKey: "googleApiKey") as? String
		if (settingsGoogleKey !=  nil) {
			googleMapsApiKey = settingsGoogleKey!
		}
		GMSServices.provideAPIKey(googleMapsApiKey)
		
		// Possibly ask user to allow notifications
        application.registerUserNotificationSettings(UIUserNotificationSettings(types: [UIUserNotificationType.sound, UIUserNotificationType.alert, UIUserNotificationType.badge], categories: nil))
		
		loadTemperatureCache()
		loadAlarms()
		
		// Background fetch, though this is a minimum time; iOS will tend to match app usage
		// Settings app value overrides, if present (from Settings plist)
		var backgroundFetchIntervalSeconds:TimeInterval = 20*60
        let settingsBackgroundFetchMinutes = settings.object(forKey: "BackgroundFetchMinutes") as? String
		if (settingsBackgroundFetchMinutes !=  nil) {
			let scanner = Scanner(string: settingsBackgroundFetchMinutes!)
			var scannedDouble:Double = 0
			if (scanner.scanDouble(&scannedDouble)) {
				backgroundFetchIntervalSeconds = scannedDouble * 60
			}
		}
        UIApplication.shared.setMinimumBackgroundFetchInterval(backgroundFetchIntervalSeconds)
		
		return true
	}
	
	// App is in background -- keep monitoring alarmed stations with Background fetch
    func application(_ application: UIApplication, performFetchWithCompletionHandler
		completionHandler: ((UIBackgroundFetchResult) -> Void)) {
		NSLog("Background Fetch")
		let mvc:MapViewController? = MapViewController.getSingleton
		if (mvc == nil) {
			return
		}

		// Request temperature updates on stations that user has set alarms for
		mvc!.fetchAlarmedStations()
		
		// Tell iOS not to call us again until next interval
        return completionHandler(UIBackgroundFetchResult.newData)
	}
	
    // Before we say goodbye -- save state
    func applicationDidEnterBackground(_ application: UIApplication) {
		saveTemperatureCache()
		saveAlarms()
	}
	
    // Save user's station alarms to disk
	func saveAlarms() {
		var alarmsNSDataIzed:Dictionary<String,NSData> = [:]
		for (id, alarm) in ModelSingletons.alarms {
            alarmsNSDataIzed[id] = NSKeyedArchiver.archivedData(withRootObject: alarm) as NSData
		}
//		let johnk = alarmsNSDataIzed["KCAGOLET18"]
//        let johnk2 = NSKeyedUnarchiver.unarchiveObject(with: johnk! as Data)

        let settings = UserDefaults.init()
        settings.set(alarmsNSDataIzed, forKey:"alarms")
	}
	
	func loadAlarms() {
        let settings = UserDefaults.init()
        let alarmsNSDataIzed = settings.object(forKey: "alarms") as? Dictionary<String,NSData>
		if (alarmsNSDataIzed == nil) {
			return
		}
		for (id, data): (String, NSData) in alarmsNSDataIzed! {
            ModelSingletons.alarms[id] = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? Alarm
        }
	}
	
    // Save recent station temperatures to disk
	func saveTemperatureCache() {
		let mvc:MapViewController? = MapViewController.getSingleton
		if (mvc == nil) {
			return
		}
		
		let stationTemperatureCache:LRUCache<NSString, NSNumber> = mvc!.stationTemperatureCache
		var stationTemperatureDictionary:Dictionary<String, Double> = [:]
		for stationID in stationTemperatureCache.keys  {
			let stationIDString = stationID as! NSString
			let temperature = stationTemperatureCache[stationIDString]
			if (temperature == nil) { continue }
            stationTemperatureDictionary[stationID as! String] = Double(truncating: temperature!)
		}
        let settings = UserDefaults.init()
        settings.set(stationTemperatureDictionary, forKey: "temperatures")
	}                                                                 
	
	func loadTemperatureCache() {
        let settings = UserDefaults.init()
        let temperatures:AnyObject? = settings.object(forKey: "temperatures") as AnyObject?
		if (temperatures == nil) {
			return
		}
		let stationTemperatureDictionary = temperatures! as! Dictionary<String, Double>

		let mvc:MapViewController? = MapViewController.getSingleton
		if (mvc == nil) {
			return
		}
		let stationTemperatureCache:LRUCache<NSString, NSNumber> = mvc!.stationTemperatureCache
		for (stationID, temperature) in stationTemperatureDictionary {
			stationTemperatureCache[stationID as NSString] = temperature as NSNumber
		}
	}
		
}
