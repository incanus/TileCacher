import UIKit
import Mapbox

class ViewController: UIViewController, MGLMapViewDelegate {

    var map: MGLMapView!

    var rendered = false
    var waitForRenders = false
    var interactive = true

    struct Tile {
        var z = 0
        var x = 0
        var y = 0
    }

    let masterTile = Tile(z: 11, x: 326, y: 732)

    let earthRadiusMeters: Double = 6378137
    let tileSize: CGFloat = 512
    let maxLatitude = 85.05112878
    let radians2degrees = 180 / M_PI

    override func viewDidLoad() {
        super.viewDidLoad()

        map = MGLMapView(frame: view.bounds)
        map.delegate = self
        view.addSubview(map)

        map.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "toggleInteractive"))
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        toggleInteractive()
    }

    func mapViewDidFinishRenderingMap(mapView: MGLMapView, fullyRendered: Bool) {
        rendered = true
    }

    func kickoffDownloads() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            [unowned self] in
            var numberOfTilesPerSide = 1
            var totalTiles = 0
            for z in self.masterTile.z...15 {
                let factor = Int(pow(Double(2), Double((z - self.masterTile.z))))
                let lowX = self.masterTile.x * factor
                let highX = lowX + numberOfTilesPerSide
                let lowY = self.masterTile.y * factor
                let highY = lowY + numberOfTilesPerSide
                for x in lowX..<highX {
                    for y in lowY..<highY {
                        if !self.interactive {
                            let tile = Tile(z: z, x: x, y: y)
                            dispatch_sync(dispatch_get_main_queue()) {
                                [unowned self] in
                                self.rendered = false
                                self.zoomToTile(tile)
                                totalTiles++
                                print("\(totalTiles): \(tile)")
                            }
                            if self.waitForRenders {
                                var waitTime: NSTimeInterval = 0
                                while !self.rendered && waitTime < 0.5 {
                                    NSThread.sleepForTimeInterval(0.1)
                                    waitTime += 0.1
                                }
                            } else {
                                NSThread.sleepForTimeInterval(0.1)
                            }
                        }
                    }
                }
                numberOfTilesPerSide *= 2
            }
        }
    }

    func toggleInteractive() {
        if interactive {
            map.scrollEnabled = false
            map.zoomEnabled = false
            map.rotateEnabled = false
            map.pitchEnabled = false

            map.frame = CGRect(x: (view.bounds.size.width - tileSize) / 2,
                y: (view.bounds.size.height - tileSize) / 2,
                width: tileSize,
                height: tileSize)

            kickoffDownloads()
        } else {
            map.scrollEnabled = true
            map.zoomEnabled = true
            map.rotateEnabled = true
            map.pitchEnabled = true

            let center = map.centerCoordinate
            let zoom = map.zoomLevel

            map.frame = view.bounds
            map.setCenterCoordinate(center, zoomLevel: zoom, animated: false)
        }

        map.toggleDebug()

        interactive = !interactive
    }

    func zoomToTile(tile: Tile) {

        // cribbed from GL projection.hpp
        func coordinateForProjectedMeters(rect: CGPoint) -> CLLocationCoordinate2D {
            var lat = (2 * atan(exp(Double(rect.y) / earthRadiusMeters)) - (M_PI / 2)) * radians2degrees
            let lon = Double(rect.x) * radians2degrees / earthRadiusMeters
            lat = fmin(fmax(lat, -maxLatitude), maxLatitude)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        // cribbed from prior art in iOS SDK 1.0.0 RMMapView
        func boundingBoxForTile(tile: Tile) -> MGLCoordinateBounds {
            let worldWidthMeters = earthRadiusMeters * M_PI * 2
            let tileMetersPerPixel = worldWidthMeters / (Double(tileSize) * pow(2, Double(tile.z)))
            let bottomLeftProjectedMeters = CGPoint(x: CGFloat(tile.x) * tileSize,
                y: CGFloat(pow(Double(2), Double(tile.z)) - Double(tile.y) - 1) * tileSize)
            let normalizedRect = CGRect(x: bottomLeftProjectedMeters.x * CGFloat(tileMetersPerPixel) - CGFloat(fabs(worldWidthMeters / 2)),
                y: bottomLeftProjectedMeters.y * CGFloat(tileMetersPerPixel) - CGFloat(fabs(worldWidthMeters / 2)),
                width: CGFloat(Double(tileSize) * tileMetersPerPixel),
                height: CGFloat(Double(tileSize) * tileMetersPerPixel))
            let sw = coordinateForProjectedMeters(normalizedRect.origin)
            let ne = coordinateForProjectedMeters(CGPoint(x: normalizedRect.origin.x + normalizedRect.width,
                y: normalizedRect.origin.y + normalizedRect.height))
            return MGLCoordinateBounds(sw: sw, ne: ne)
        }

        let bbox = boundingBoxForTile(tile)
        let middle = CLLocationCoordinate2D(latitude: (bbox.ne.latitude + bbox.sw.latitude) / 2,
            longitude: (bbox.ne.longitude + bbox.sw.longitude) / 2)
        map.setCenterCoordinate(middle, zoomLevel: Double(tile.z), animated: false)
    }

}
