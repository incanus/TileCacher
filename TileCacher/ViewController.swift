import UIKit
import Mapbox

class ViewController: UIViewController {

    var map: MGLMapView!

    struct Tile {
        var x = 0
        var y = 0
        var z = 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        map = MGLMapView(frame: view.bounds)
        map.debugActive = true
        view.addSubview(map)
    }

    func zoomToTile(tile: Tile) {
        
    }

}
