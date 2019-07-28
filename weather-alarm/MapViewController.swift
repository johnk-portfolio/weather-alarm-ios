//
//  MapViewController.swift
//
// Code source credits:
//  Google Maps: derived from tutorial (c) 2014 Ron Kliffer
//    http://www.raywenderlich.com/81103/introduction-google-maps-ios-sdk-swift
//  JSON parser  (c) 2014 Ruoyu Fu, Pinglin Tang
//    https://github.com/lingoer/SwiftyJSON
//  JSON populate object  Andrei Puni
//    https://github.com/andrei512/magic
//  LRU Cache   
//    http://stackoverflow.com/questions/25970415/standard-implementation-of-an-lru-cache#25973177
//  Screenshot for Google Maps Markers
//     http://stackoverflow.com/questions/7964153/ios-whats-the-fastest-most-performant-way-to-make-a-screenshot-programaticall#18925563
//
// Weather Underground API documentation:
//		http://www.wunderground.com/weather/api/d/docs?d=data/index
//		http://www.wunderground.com/weather/api/d/docs?d=resources/logo-usage-guide

// TODO refactor: separate classes for
//   temperature cache -- LRU has to be NSNumber, but I only want to see double
//   WU network requests -- do not belong in a GUI class, could use singletons
//   station data / model -- do not belong in a GUI class
// cache and WU would isolate us more from these implementations, in case we want to drop in another solution

import UIKit
import Foundation

let defaultLat:Double = 34.3
let defaultLon:Double = -119.3

private var _MapViewControllerSingleton:MapViewController? = nil

class MapViewController: UIViewController, GMSMapViewDelegate {
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		_MapViewControllerSingleton = self
	}
	class var getSingleton:MapViewController? {
		return _MapViewControllerSingleton
	}
	
  @IBOutlet weak var mapView: GMSMapView!
	@IBOutlet weak var favoriteSegmented: UISegmentedControl!
  //@IBOutlet weak var mapCenterPinImage: UIImageView!
  //@IBOutlet weak var pinImageVerticalConstraint: NSLayoutConstraint!
	
    // API
	var wuApiKey:String = "4a29625c3656bb93" //"6bd812ba4375be5d"
	let apiThrottle:Int = 4					// limits temperature requests
	let apiMinuteCountMax:Int = 10	        // limits overall requests per minute
    var apiFromDisk:Bool = true             // use saved API responses
    var apiToDisk:Bool = true               // save API responses
    var jsonDirectory:String = ""
    let fileManager:FileManager = FileManager.default
	
	// Would put these where they are used but swift doesn't support statics yet
	var apiMinuteCount:Int = 0
	var scheduledTimeToZeroCount:NSDate = NSDate(timeIntervalSinceNow:60)
	
	// Location of user -- initially map is centered here
	var geoLocation:CLLocationCoordinate2D = CLLocationCoordinate2DMake(34.407,-119.696)  // SBCC
	
	// Stations near center of map
	var geoStations = Dictionary<String, Station>()
	var stationMarkers = Dictionary<String, StationMarker>()
	
	// Temperature of current stations, but may include recent stations that have scrolled off
	// This allows user to scroll a little and press refresh without paying for full load of
	//   weather data
	// TODO: timestamp so cache can be flushed every 20-minutes (since user pressed refresh)
	var stationTemperatureCache = LRUCache<NSString, NSNumber>()
	
	// Marker that user just clicked, for passing to MapDetailVC
	// I wish performSegue had a way to pass this; have to wait until prepareSegue
	var clickedStation:Station? = nil
	
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // save / load JSON
    if let docDir:URL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        jsonDirectory = docDir.relativePath
    }
    jsonDirectory = jsonDirectory + "/json/"
    let savedJsonURL:URL? = Bundle.main.resourceURL?.appendingPathComponent("WUjson")
    do {
        if !fileManager.fileExists(atPath: jsonDirectory)
        {
            try fileManager.createDirectory(atPath: jsonDirectory, withIntermediateDirectories: false, attributes: nil)
        }
        copyFiles(pathFromBundle: (savedJsonURL?.path)!, pathDestDocs: jsonDirectory)
    } catch {
        print("Can't set up JSON cache:" + error.localizedDescription);
    }
		
    // Weather Underground API key
    // Settings app value overrides, if present (from Settings plist)
    let settings = UserDefaults.standard
    let settingsWuKey = settings.object(forKey: "WuApiKey") as? String
    if (settingsWuKey !=  nil) {
        wuApiKey = settingsWuKey!
    }
    
    let settingsAPIFromDiskKey = settings.object(forKey: "APIFromDisk") as? Bool
    if (settingsAPIFromDiskKey != nil) {
        apiFromDisk = settingsAPIFromDiskKey!
    }
    
    let settingsAPIToDisk = settings.object(forKey: "APIToDisk") as? Bool
    if (settingsAPIToDisk != nil) {
        apiToDisk = settingsAPIToDisk!
    }
        
        // Set up station cache limit

    // Set up station cache limit
    stationTemperatureCache.countLimit = 500
    
    // Subscribe to mapview click events
    mapView.delegate = self
    mapView.camera = GMSCameraPosition(target: geoLocation, zoom: 11, bearing: 0, viewingAngle: 0)
		
    // Get weather stations near our location
    queryWU(query: "autoip")
  }

    func copyFiles(pathFromBundle : String, pathDestDocs: String) {
        let fileManagerIs = fileManager
        do {
            let filelist = try fileManagerIs.contentsOfDirectory(atPath: pathFromBundle)
//            try? fileManagerIs.copyItem(atPath: pathFromBundle, toPath: pathDestDocs)
            
            for filename in filelist {
                let srcPath:String = "\(pathFromBundle)/\(filename)"
                if !fileManagerIs.fileExists(atPath: srcPath) {
                    try? fileManagerIs.copyItem(atPath: srcPath, toPath: "\(pathDestDocs)/\(filename)")
                }
            }
        } catch {
            print("\nError\n")
        }
    }

	// May be returning from detail view controller; update markers
    override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		updateAllMarkers()
	}
	
	func queryWU(query: String) -> Bool {
		// Throttle API request to 10 per minute
        if (NSDate().compare(scheduledTimeToZeroCount as Date) == ComparisonResult.orderedDescending) {
			apiMinuteCount = 0
			scheduledTimeToZeroCount = NSDate(timeIntervalSinceNow: 60)
		}
		
        print("QUERY = \(query)", terminator:" ")
		var url:NSURL!
		switch (query as NSString) {
        case let x where x.range(of: "pws:").length != 0:
			url = NSURL(string: "http://api.wunderground.com/api/\(wuApiKey)/conditions/q/\(query).json")
		default:   // including "autoip", "lat,lon"
			url = NSURL(string: "http://api.wunderground.com/api/\(wuApiKey)/geolookup/q/\(query).json")
		}
        
        var jsonData:Data? = nil
        
        // Weather Underground has shut down
        // To keep app running use cached JSON responses
        var pathWrite:String? = nil
        if (apiFromDisk || apiToDisk) {
            var path:String? = nil
            
            // autoip -- convert to SB
            // http://api.wunderground.com/api/\(wuApiKey)/geolookup/q/autoip
            if (query.range(of: "autoip") != nil) {
                path = jsonDirectory + "\(defaultLat),\(defaultLon).json"
                pathWrite = path
            }
            
            // Search for file near geo at coordinates
            // http://api.wunderground.com/api/\(wuApiKey)/geolookup/q/34.28000000301759,-119.28000010550024
            // latitude, longitude query -- round to nearest tenth
            if (query.range(of: ",") != nil) {
                path = jsonDirectory + roundOffLatLon(query: query) + ".json"
                pathWrite = path
                if path == nil /* || !fileManager.fileExists(atPath: path ?? "") */ {
                    path = jsonDirectory + "\(defaultLat),\(defaultLon).json"
                }
            }
            
            // Search for file querying station
            // http://api.wunderground.com/api/\(wuApiKey)/conditions/q/pws:KCAVENTU35
            if let range = query.range(of: "pws:") {
                let station:Substring = query[range.upperBound...]
                path = jsonDirectory + station + ".json"
                pathWrite = path
            }

            // If file exists process JSON within it
            if (apiFromDisk) {
                do {
                    jsonData = try NSData(contentsOfFile:path!, options: .mappedIfSafe) as Data?
                    //                processWU(jsonData:jsonData, query: query)
                    //                return true
                } catch { }
                
                // Pass JSON for processing
                if (jsonData != nil) {
                    processWU(jsonData:jsonData, query: query)
                    print(" (from disk)")
                    return true
                }
            }
        }
       
        // API request
        apiMinuteCount += 1
        if (apiMinuteCount >= apiMinuteCountMax) {
            print("API overage")
            return false
        }
        print(" send request")
        let request:URLRequest = URLRequest(url: url as URL)
        
        //     open func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
        let task:URLSessionDataTask = URLSession.shared.dataTask(with: request, completionHandler:{ (jsonData: Data?, response: URLResponse?, error: Error?) -> Void in

            // No response
			if (response == nil) {
                print("error \(query): \(error!.localizedDescription)")
				return
			}
            
            // Small response
            if (jsonData?.count ?? 0 < 300) {
                  return
            }
            
            // Unparsable JSON or error node in response
            do {
                let jsonParsed = try JSONSerialization.jsonObject(with: jsonData!, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
                let jsonErrorNode = jsonParsed?.value(forKeyPath:"response.error") as? NSDictionary
                if (jsonErrorNode != nil) {
                    let errorDescription = jsonErrorNode?.value(forKeyPath:"description") as? String
                    print("API error: " + (errorDescription ?? ""))
                    return
                }
            } catch let error as NSError {
                print(error)
                return
            }

            
            // Save JSON to disk (if enabled)
            if (self.apiToDisk && pathWrite != nil) {
                do {
                    let url:URL = URL(fileURLWithPath: pathWrite ?? "", isDirectory: false)
                    try jsonData?.write(to: url)
                }
                catch {
                    print("error:", error)
                }
            }
			
			// var jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as NSDictionary
            self.processWU(jsonData:jsonData, query:query)
          })
        task.resume()
        return true
    }
    
    // Round to nearest tenth
    func roundOffLatLon(query:String) -> String {
        let latlon = query.components(separatedBy: ",")
        if (latlon.count < 2) { return "\(defaultLat),\(defaultLon)" }
        let lat = round((Double(latlon[0]) ?? defaultLat) * 10.0) / 10.0
        let lon = round((Double(latlon[1]) ?? defaultLon) * 10.0) / 10.0
        print("Round \(latlon[0]),\(latlon[1]) -> \(lat),\(lon)")
        return "\(lat),\(lon)"
    }
    
    func processWU(jsonData: Data?, query: String) {

            var jsonParsed = NSDictionary()
            do {
                jsonParsed = try JSONSerialization.jsonObject(with: jsonData!, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            } catch let error as NSError {
                print(error)
                return
            }


		//let json = JSON(data:jsonData!)
		
		// Process elsewhere based on type of query
        // Switch to main thread as we will be doing UI
        DispatchQueue.main.async {
            switch (query as NSString) {
            case let x where x.range(of: "pws:").length != 0:
                self.processTemperature(jsonParsed: jsonParsed)
            default:     // including "autoip", "lat,lon"
                self.processStations(jsonParsed: jsonParsed)
            }
        }
	}

	// Process API response for all nearby stations
	func processStations(jsonParsed: NSDictionary) {
		// Store current location
        let jsonLocationNode = jsonParsed.value(forKeyPath: "location")
        if (jsonLocationNode == nil) {
            return
        }
		let jsonLocation = jsonLocationNode as! Dictionary<String,AnyObject>
		geoLocation = CLLocationCoordinate2DMake((jsonLocation["lat"] as! NSString).doubleValue, (jsonLocation["lon"] as! NSString).doubleValue)
		
		// Store nearby stations
		//let jsonStations:Array<JSON> = json["location"]["nearby_weather_stations"]["pws"]["station"].arrayValue!
        let jsonStations = jsonParsed.value(forKeyPath: "location.nearby_weather_stations.pws.station") as! Array<NSDictionary>
		self.geoStations = [:]
		var geoStationIdsInGeoOrder:Array<String> = []
//var count2:Int = 0   // debugging limit number of stations on map
		for element in jsonStations {/*
            guard let stationData:Data = try JSONSerialization.data(withJSONObject: element) else { continue }
            guard let station = try JSONDecoder().decode(Station.self, from:stationData) else { continue } */
            let station = Station.fromJson(jsonInfo: element)
			self.geoStations[station.id] = station
			geoStationIdsInGeoOrder += [station.id]
//if (count2++ > 2) {break}  // debugging limit number of stations on map
	  }
		
		// Center google map on geo location
        // Don't change user's current zoom level
        mapView.camera = GMSCameraPosition.camera(withTarget:geoLocation, zoom:mapView.camera.zoom)
		
		// Erase all stations from map
		mapView.clear()
		
		// If station temperature is in cache, add it to map
		// Else make temperature API request, if we aren't past our API limit
		// Also make request is station is alarmed´
//		var count:Int = 0
		for stationID in geoStationIdsInGeoOrder {
            let temperature:NSNumber? = stationTemperatureCache[stationID as NSString]
			if (temperature != nil && ModelSingletons.alarms[stationID] == nil) {
                let doubleTemperature = Double(truncating: temperature!)
                showStation(station: geoStations[stationID]!, temperature: doubleTemperature)
			} else {
//                count += 1
//				if (count < apiThrottle) {
                if (!queryWU(query: "pws:" + stationID)) {
//				} else {
                    showStation(station: geoStations[stationID]!, temperature: nil)
				}
			}
		}
	}
	
	// Background fetch (timer) to check if alarmed stations have gone out of range
	func fetchAlarmedStations() {
		for (stationID, alarm) in ModelSingletons.alarms {
			if (alarm.alarmLow != nil || alarm.alarmHigh != nil) {
                queryWU(query: "pws:" + stationID)
			}
		}
	}

	// Process API response for a station's temperature
  func processTemperature(jsonParsed: NSDictionary) {
    guard let stationIDOpt = jsonParsed.value(forKeyPath: "current_observation.station_id"),
            !(stationIDOpt is NSNull),
        let temperatureOpt = jsonParsed.value(forKeyPath: "current_observation.temp_f"),
            !(temperatureOpt is NSNull),
        let neighborhoodOpt = jsonParsed.value(forKeyPath: "current_observation.observation_location.full"),
            !(neighborhoodOpt is NSNull)
        else { return }
    let stationID:String = stationIDOpt as! String
    let temperature:Double = temperatureOpt as! Double
    let neighborhood:String = neighborhoodOpt as! String
    print("\(stationID)(\(neighborhood)) = \(temperature)")
		//NSLog("%@ (%@) = %f", stationID, neighborhood, temperature)
		stationTemperatureCache[stationID as NSString] = temperature as NSNumber
		if (geoStations[stationID] != nil) {
            showStation(station: geoStations[stationID]!, temperature:temperature)
		}
	}
	
	func showStation(station:Station, temperature:Double?) {
		let stationID:String = station.id
		let alarm:Alarm? = ModelSingletons.alarms[stationID]
		let isFavorite:Bool = alarm?.alarmLow != nil || alarm?.alarmHigh != nil
		let isAlarm:Bool = isFavorite && temperature != nil &&
            (alarm?.alarmLow != nil && temperature! < (alarm?.alarmLow)! ||
                alarm?.alarmHigh != nil && temperature! > (alarm?.alarmHigh)!)
		let filterFavorite:Bool = favoriteSegmented.selectedSegmentIndex == 1
		
		// Debug
		if (isAlarm) {
			print("showStation -- \(stationID) is in alarm")
		}
		
		// Update marker if it already exists
		var marker:StationMarker
		if (stationMarkers[stationID] != nil) {
			marker = stationMarkers[stationID]!
            marker.updateIcon(temperature: temperature, isFavorite: isFavorite, isAlarm: isAlarm, superView:self.view)
		} else {
			marker = StationMarker(stationID: station.id, description: station.neighborhood, temperature: temperature, isFavorite: isFavorite, isAlarm: isAlarm, position: CLLocationCoordinate2DMake(station.lat, station.lon))
			stationMarkers[stationID] = marker
		}
		
		// If user is filtering for favorites, check if we should hide station
		if (filterFavorite && !isFavorite) {
			marker.map = nil
		} else {
			marker.map = self.mapView
		}
	}
	
	func updateAllMarkers() {
		for (stationID, _) in stationMarkers {
			let station = geoStations[stationID]
			if (station != nil) {
				var temperature:Double? = nil
				if (stationTemperatureCache[stationID as NSString] != nil) {
                    temperature = Double(truncating: stationTemperatureCache[stationID as NSString]!)
				}
                showStation(station: station!, temperature:temperature)
			}
		}
	}
	
	// Pass station ID into detail view controller
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "MapDetailView" {
        let detailViewController = segue.destination as! MapDetailViewController
			detailViewController.station = clickedStation
    }
  }
  
/*
	func didTapMyLocationButtonForMapView(mapView: GMSMapView!) -> Bool {
		mapView.selectedMarker = nil
		return false
	}

	func mapView(mapView: GMSMapView!, didTapMarker marker: GMSMarker!) -> Bool {
		//mapCenterPinImage.fadeOut(0.25)
		return false
	}
*/
	
	// Push detail view controller
    func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
		let marker = mapView.selectedMarker as! StationMarker
		clickedStation = geoStations[marker.stationID]!
		clickedStation!.temperature = marker.temperature
        performSegue(withIdentifier: "MapDetailView", sender:self)
  }
	
	
	// TODO: queryWU geolookup from current google maps location
	@IBAction func refreshPlaces(sender: AnyObject) {
		let mapCenter = mapView.camera.target
        queryWU(query: "\(mapCenter.latitude),\(mapCenter.longitude)")
	}
	
  // MARK: - Types Controller Delegate
  // TODO: only display user's favorite stations
	@IBAction func mapTypeSegmentPressed(_ sender: AnyObject) {
		updateAllMarkers()
	}
	
	func sendNotification() {
		let localNotification:UILocalNotification = UILocalNotification()
		localNotification.alertAction = "Testing"
		localNotification.alertBody = "Hello World!"
		localNotification.fireDate = Date(timeIntervalSinceNow: 1)
        UIApplication.shared.scheduleLocalNotification(localNotification)
	}

}


var error: NSError?
