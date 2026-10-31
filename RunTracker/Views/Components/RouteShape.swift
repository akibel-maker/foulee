import SwiftUI
import MapKit

/// Dessine un tracé (sans carte), pour les vignettes de l'historique.
struct RouteShape: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard coordinates.count > 1 else { return path }
        let points = coordinates.map { MKMapPoint($0) }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return path }
        let width = max(maxX - minX, 1e-9)
        let height = max(maxY - minY, 1e-9)
        let scale = min(rect.width / width, rect.height / height)
        let offsetX = rect.minX + (rect.width - width * scale) / 2
        let offsetY = rect.minY + (rect.height - height * scale) / 2
        func convert(_ p: MKMapPoint) -> CGPoint {
            CGPoint(x: offsetX + (p.x - minX) * scale, y: offsetY + (p.y - minY) * scale)
        }
        path.move(to: convert(points[0]))
        for p in points.dropFirst() { path.addLine(to: convert(p)) }
        return path
    }
}
