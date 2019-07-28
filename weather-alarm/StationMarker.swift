//
//
//

import Foundation

// Take screenshot of a view
// http://stackoverflow.com/questions/7964153/ios-whats-the-fastest-most-performant-way-to-make-a-screenshot-programaticall#18925563
extension UIView {
	func pb_takeSnapshot() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.main.scale);
		
		// iOS7 view render.  But it's not working reliably -- status is false
		// after startup
		//let status = self.drawViewHierarchyInRect(self.bounds, afterScreenUpdates: true)
		//if (!status) { println("StationMarker.pb_takeSnapshot = FAIL") }
		
		// iOS6 render
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
		
		let image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
        return image!;
	}
}

class StationMarker: GMSMarker {
  let stationID: String
	var temperature: Double?		// TODO: duplicating stationTemperatureCache

	init(stationID: String, description: String, temperature: Double?, isFavorite: Bool, isAlarm: Bool, position: CLLocationCoordinate2D) {
		self.stationID = stationID
    super.init()
		
    self.position = position
		self.snippet = description

        updateIcon(temperature: temperature, isFavorite: isFavorite, isAlarm: isAlarm, superView:nil)
		
    groundAnchor = CGPoint(x: 0.5, y: 1)
   //appearAnimation = kGMSMarkerAnimationPop
  }
	
	// Update marker's icon
	func updateIcon(temperature: Double?, isFavorite: Bool, isAlarm: Bool, superView: UIView?) {
		self.temperature = temperature
		
		// Icon is round or star for favorites
		let baseImage = UIImage(named: isFavorite ?
			(isAlarm ? "star_alarm_icon" : "star_icon")
			: "round_icon")
		
		// If we have a temperature, create a screenshot image
		if (temperature != nil) {
			let baseImageView = UIImageView(image: baseImage)
			let containerView = UIView(frame: baseImageView.frame)
			containerView.addSubview(baseImageView)
			
			let label = UILabel(frame:baseImageView.frame)
            label.textAlignment = NSTextAlignment.center
			label.text = String(Int(temperature!))
			containerView.addSubview(label)
			icon = containerView.pb_takeSnapshot()
		} else {
			icon = baseImage
		}
	}
}
