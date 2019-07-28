//
//  ModelSingletons.swift
//  weather-alarm
//
//  Created by John Kalstrom on 12/2/14.
//  Copyright (c) 2014 sbcc.edu. All rights reserved.
//

import Foundation

private let _ModelSingletons = ModelSingletons()
private var _Alarms = Dictionary<String, Alarm>()

class ModelSingletons {
	class var getInstance: ModelSingletons {
		return _ModelSingletons
	}
	class var alarms: Dictionary<String, Alarm> {
		get { return _Alarms }
		set {
			_Alarms = newValue
			
			// Clean out empty alarms
			for (id, alarm) in _Alarms {
				if (alarm.alarmLow == nil && alarm.alarmHigh == nil) {
                    _Alarms.removeValue(forKey:id)
				}
			}
		}
	}
	
}
