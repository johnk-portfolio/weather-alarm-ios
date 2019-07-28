//
//  MapDetailViewController.swift
//  weather-alarm
//
//  Created by John Kalstrom on 11/27/14.
//  Copyright (c) 2014 sbcc.edu. All rights reserved.
//

import Foundation

class MapDetailViewController: UIViewController, UITextFieldDelegate {
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	@IBOutlet weak var temperatureLabel: UILabel!
	@IBOutlet weak var alarmLowTextField: UITextField!
	@IBOutlet weak var alarmHighTextField: UITextField!
	
	var station:Station? = nil
	var alarm:Alarm = Alarm()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		if (station == nil) {
			return
		}
		let stationID:String = station!.id
        alarm.id = stationID
		
		// Populate GUI from station, which was seeded by prepareForSegue
		title = station?.neighborhood
		if (station!.temperature != nil) {
			temperatureLabel.text = NSString(format:"%.1f F", station!.temperature!) as String
		} else {
			temperatureLabel.text = "--.- F"
		}
		
		// Load alarms (if any) from model
		var alarms:Dictionary<String,Alarm> = ModelSingletons.alarms
        if let savedAlarm = alarms[stationID] { alarm = savedAlarm }
		alarmLowTextField.text = ""
		alarmHighTextField.text = ""
        if (alarm.alarmLow != nil) {
            alarmLowTextField.text = NSString(format:"%.1f", alarm.alarmLow!) as String
		}
		if (alarm.alarmHigh != nil) {
			alarmHighTextField.text = NSString(format:"%.1f", alarm.alarmHigh!) as String
		}
		
		// Highlight active alarms
		highlightAlarms()
		
		// Dismiss keyboard when user taps background
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(dismissKeyboard))
		self.view.addGestureRecognizer(tap)
	}
	
    @objc func dismissKeyboard() {
		self.view.endEditing(true)
	}
	
	func validateDouble(value: NSString, scannedDouble: UnsafeMutablePointer<Double>) -> Bool {
        let scanner = Scanner(string: value as String)
		return scanner.scanDouble(scannedDouble)
	}
	
	// MARK: Textfield delegate methods
	
	// Validate user-entered temperature alarm value, as they type it
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		// What string will be if we allow edit
        let newString = (textField.text as NSString?)!.replacingCharacters(in: range, with: string)

		// Blank is OK -- store nil
		if (newString.count == 0) {
			switch (textField) {
			case alarmLowTextField:
				alarm.alarmLow = nil
			default:
				alarm.alarmHigh = nil
			}
			ModelSingletons.alarms[station!.id] = alarm
			highlightAlarms()
			return true
		}
		
		// Is it a valid number?
		var scannedDouble: Double = 0
        if (!validateDouble(value: newString as NSString, scannedDouble: &scannedDouble)) {
			return false
		}
		
		// Don't allow negative
		if (scannedDouble < 0) {
			return false
		}
		
		// Don't allow more than 1 decimal
        let decimalLocation:Range? = newString.range(of:".")
		if (decimalLocation != nil) {
            let decimalPortion = newString[decimalLocation!]
			if (decimalPortion.count > 2) {
				return false
			}
		}
		
		// Store new alarm temperature
		switch (textField) {
		case alarmLowTextField:
			alarm.alarmLow = scannedDouble
		default:
			alarm.alarmHigh = scannedDouble
		}
		//var alarms:Dictionary<String,Alarm> = ModelSingletons.alarms
		ModelSingletons.alarms[station!.id] = alarm
		highlightAlarms()
		return true
	}

	func highlightAlarms() {
		if (station!.temperature == nil) {
			return
		}
		let showLowAlarm:Bool = alarm.alarmLow != nil && station!.temperature! < alarm.alarmLow!
        alarmLowTextField.backgroundColor = showLowAlarm ? UIColor.red : UIColor.clear
		let showHighAlarm:Bool = alarm.alarmHigh != nil && station!.temperature! > alarm.alarmHigh!
        alarmHighTextField.backgroundColor = showHighAlarm ? UIColor.red : UIColor.clear
	}
}
