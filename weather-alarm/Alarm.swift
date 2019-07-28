//
//  Alarm.swift
//  weather-alarm
//
//  Created by John Kalstrom on 11/30/14.
//  Copyright (c) 2014 sbcc.edu. All rights reserved.
//

import Foundation

@objc(Alarm)
class Alarm : NSObject, NSCopying, NSCoding {
    
	var id : String = ""
	var alarmLow : Double? = nil
	var alarmHigh : Double? = nil
	
	override init() {}
	init(id: String, alarmLow: Double?, alarmHigh: Double?) {
		self.id = id
		self.alarmLow = alarmLow
		self.alarmHigh = alarmHigh
	}
	
	func copy(with zone: NSZone?) -> Any {
		let newInstance = Alarm(id: id, alarmLow: alarmLow, alarmHigh: alarmHigh)
		return newInstance
	}
	
	required init?(coder aDecoder: NSCoder) {
        self.id  = aDecoder.decodeObject(forKey: "id")! as! String
        self.alarmLow = aDecoder.decodeObject(forKey: "alarmLow") as? Double
        self.alarmHigh = aDecoder.decodeObject(forKey: "alarmHigh") as? Double
	}
	
	func encode(with aCoder: NSCoder) {
        aCoder.encode(self.id, forKey: "id")
        if let alarmLow = self.alarmLow {
            aCoder.encode(NSNumber(value:alarmLow), forKey: "alarmLow")
		}
		if let alarmHigh = self.alarmHigh {
            aCoder.encode(NSNumber(value:alarmHigh), forKey: "alarmHigh")
		}
	}
    
    override var description: String {
        return "\(id) low:\(alarmLow ?? 0.0) high:\(alarmHigh ?? 0.0)"
    }
}
