//
//  APIKeyViewController.swift
//  weather-alarm
//
//  Created by John Kalstrom on 12/18/18.
//  Copyright © 2018 sbcc.edu. All rights reserved.
//

import Foundation

class APIKeyViewController: UIViewController, UITextFieldDelegate {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @IBOutlet weak var googleMapsAPIKey: UITextField!
    @IBOutlet weak var weatherUndergroundAPIKey: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
}
}

