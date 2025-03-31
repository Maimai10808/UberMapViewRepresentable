//
//  UberMapViewRepresentable1.swift
//  Uber_Clone
//
//  Created by mac on 3/31/25.
//

import SwiftUI
import MapKit

/// UberMapViewRepresentable 是一个 SwiftUI 视图，用于显示地图。
/// 它封装了 `MKMapView`，并允许用户查看当前位置、选择目标位置并计算路径。
struct UberMapViewRepresentable: UIViewRepresentable {
    
    let mapView = MKMapView()
    let locationManager = LocationManager()  // 管理位置权限和更新
    @Binding var mapState: MapViewState   // 当前地图状态
    @EnvironmentObject var locationViewModel: LocationSearchViewModel  // 获取选中的目标位置

    // 设置初始地图视图
    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        mapView.isRotateEnabled = false   // 禁用地图旋转
        mapView.showsUserLocation = true  // 显示用户当前位置
        mapView.userTrackingMode = .follow // 开启用户位置跟踪
        return mapView
    }

    // 更新地图视图
    func updateUIView(_ uiView: MKMapView, context: Context) {
        if mapState == .noInput {
            context.coordinator.clearMapView()  // 如果没有输入，清空地图
            return
        }
        
        guard let coordinate = locationViewModel.selectedLocationCoordinate else { return }
        print("DEBUG: Map state is \(mapState)")
        print("DEBUG: Updating map with coordinate \(coordinate)")
        
        // 添加并选择目标位置标注
        context.coordinator.addAndSelectAnnotation(withCoordinate: coordinate)
        // 配置路径
        context.coordinator.configurePolyline(withDestinationCoordinate: coordinate)

        // 设置地图区域
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
        uiView.setRegion(region, animated: true)

        // 移除所有现有标注
        uiView.removeAnnotations(uiView.annotations)

        // 添加新的目的地标注
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "目的地"
        uiView.addAnnotation(annotation)
    }

    // 创建 Coordinator 对象，处理地图相关的委托
    func makeCoordinator() -> MapCoordinator {
        return MapCoordinator(parent: self)
    }
}

/// MapCoordinator 作为地图的代理，负责处理地图的各种事件
extension UberMapViewRepresentable {
    class MapCoordinator: NSObject, MKMapViewDelegate {
        
        // MARK: - Properties
        let parent: UberMapViewRepresentable
        var userLocationCoordinate: CLLocationCoordinate2D?
        var currentRegion: MKCoordinateRegion?

        // MARK: - Lifecycle
        init(parent: UberMapViewRepresentable) {
            self.parent = parent
            super.init()
        }

        // MARK: - MKMapViewDelegate
        
        // 更新用户位置时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            self.userLocationCoordinate = userLocation.coordinate
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            
            self.currentRegion = region
            
            mapView.setRegion(region, animated: true)
        }
        
        // 渲染路径
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let polyline = MKPolylineRenderer(overlay: overlay)
            polyline.strokeColor = .systemBlue
            polyline.lineWidth = 6
            return polyline
        }

        // 地图加载失败时调用
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("DEBUG: Map failed to load: \(error.localizedDescription)")
        }
        
        // MARK - Helpers
        
        // 添加目标位置标注并选择
        func addAndSelectAnnotation(withCoordinate coordinate: CLLocationCoordinate2D) {
            parent.mapView.removeAnnotations(parent.mapView.annotations)
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            parent.mapView.addAnnotation(annotation)
            parent.mapView.selectAnnotation(annotation, animated: true)
            
            parent.mapView.showAnnotations(parent.mapView.annotations, animated: true)
        }
        
        // 配置并绘制从当前位置到目标位置的路径
        func configurePolyline(withDestinationCoordinate coordinate: CLLocationCoordinate2D) {
            guard let userLocationCoordinate = self.userLocationCoordinate else { return }
            getDestinationRoute(from: userLocationCoordinate, to: coordinate) { route in
                self.parent.mapView.addOverlay(route.polyline)
                let rect = self.parent.mapView.mapRectThatFits(route.polyline.boundingMapRect,
                                                               edgePadding: .init(top: 64, left: 32, bottom: 500, right: 32))
                self.parent.mapView.setRegion(MKCoordinateRegion(rect), animated: true)
            }
        }
        
        // 获取从当前位置到目标位置的路径
        func getDestinationRoute(from userLocation: CLLocationCoordinate2D,
                                   to destination: CLLocationCoordinate2D, completion: @escaping(MKRoute) -> Void) {
            let userPlacemark = MKPlacemark(coordinate: userLocation)
            let destPlacemark = MKPlacemark(coordinate: destination)
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: userPlacemark)
            request.destination = MKMapItem(placemark: destPlacemark)
            let directions = MKDirections(request: request)
            
            directions.calculate { response, error in
                if let error = error {
                    print("DEBUG: Failed to get directions with error \(error.localizedDescription)")
                    return
                }
                
                guard let route = response?.routes.first else { return }
                completion(route)
            }
        }
        
        // 清空地图视图
        func clearMapView() {
            parent.mapView.removeAnnotations(parent.mapView.annotations)
            parent.mapView.removeOverlays(parent.mapView.overlays)
            
            if let currentRegion = currentRegion {
                parent.mapView.setRegion(currentRegion, animated: true)
            }
        }
    }
}
