//
//
//

import Foundation

@objcMembers class Station : NSObject /* Decodable*/ {
  var category : String = "pws"
  var neighborhood : String = ""
  var city : String = ""
  var state : String = ""
  var country : String = ""
  var id : String = ""
  var lat : Double = 0
  var lon : Double = 0
  var distance_km : Double = 0
  var distance_mi : Double = 0

  var temperature : Double? = nil		// TODO: duplicating stationTemperatureCache
    
    enum CodingKeys: String, CodingKey {
        case category
        case neighborhood
        case city
        case state
        case country
        case id
        case lat
        case lon
        case distance_km
        case distance_mi
    }

  override var description: String {
    return "pws:\(self.id) lat:\(self.lat) lon:\(self.lon)"
  }
}
