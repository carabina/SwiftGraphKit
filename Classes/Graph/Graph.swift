//
//  Graph.swift
//  GraphView
//
//  Created by Charles Bessonnet on 17/08/2017.
//  Copyright © 2017 Charles Bessonnet. All rights reserved.
//

import UIKit

public protocol BKGraphDataSource: class {
    func graph(graph: Graph, requestDataBetween minX: CGFloat, maxX: CGFloat, completion: @escaping (([GraphPoint]) -> (Void)))
}

public class Graph: CALayer, CALayerDelegate {
    public var points: [GraphPoint] = []
    public weak var dataSource: BKGraphDataSource?
    
    //MARK: Object lifecycle
    
    public override init() {
        super.init()
        self.delegate = self
    }
    
    public override init(layer: Any) {
        super.init(layer: layer)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    //MARK: Data management
    
    public func removeAllPoints() {
        points.removeAll()
    }
    
    public func addData(data: [GraphPoint]) {
        let existingPoints = self.points.compactMap({ $0.x })
        let newPoints = data.filter({ !existingPoints.contains($0.x) })
        
        self.points.append(contentsOf: newPoints)
        self.points.sort(by: { $0.x < $1.x})
    }
    
    
    // MARK: - Draw
    
    func drawGraph(in graphView: DrawerView) {
        self.sublayers = nil
        
        self.drawPoints(in: graphView)
    }
    
    func drawPoints(in graphView: DrawerView) {
        self.fetchRequiredPoints(in: graphView)
        
        for point in points {
            if !point.isVisible(inFrame: graphView.dataFrame) {
                continue
            }
            if point.superlayer == nil {
                addSublayer(point)
            }
            point.drawPoint(in: graphView)
        }
    }
    
    
    // MARK: - Fetch (dataSource)
    
    func fetchRequiredPoints(in graphView: DrawerView) {
        guard let dataSource = self.dataSource else { return }
        guard var (min, max) = self.missingPoints(in: graphView.dataFrame) else { return }
        
        // check validity of (min, max) with data area
        min = CGFloat.maximum(min, graphView.dataArea.minX)
        max = CGFloat.minimum(max, graphView.dataArea.maxX)
        
        dataSource.graph(graph: self, requestDataBetween: min, maxX: max) { (points) -> (Void) in
            self.addData(data: points)
            graphView.forceToRedraw = true
        }
    }
    
    private func missingPoints(in area: CGRect) -> (CGFloat, CGFloat)? {
        let minX = floor(area.minX)
        let maxX = ceil(area.maxX)
        
        guard let minPointX = self.points.first?.x else { return (minX, maxX) }
        guard let maxPointX = self.points.last?.x else { return (minX, maxX) }
        
        if minPointX <= minX && maxX <= maxPointX {
            // having all points, no need to reask
            return nil
        } else if minPointX > minX && maxX <= maxPointX {
            // missing some data on left
            return (minX, minPointX)
        } else if minPointX <= minX && maxX > maxPointX{
            // missing some data on right
            return (maxPointX, maxX)
        } else {
            // missing data on right & on left
            return (minX, maxX)
        }
    }
    
    
    // MARK: - Selection
    
    func changeOfSelectedPoint(dataPoint: CGPoint, in graphView: DrawerView, norm: BKNorm) -> GraphPoint? {
        // deselect current selected point
        let selectedPoint = self.points.first(where: { $0.selected == true })
        selectedPoint?.selected = false
        
        // selected the more near point
        let newSelectedPoint = self.moreNearPoint(from: dataPoint, in: graphView, norm: norm)
        newSelectedPoint?.selected = true
        
        if selectedPoint?.point != newSelectedPoint?.point {
            return newSelectedPoint
        }
        return nil
    }
    
    private func moreNearPoint(from dataPoint: CGPoint, in graphView: DrawerView, norm: BKNorm) -> GraphPoint? {
        var visiblePoints = self.points
        
        if norm == .quadratic {
            visiblePoints = self.points.filter({ $0.isVisible(inFrame: graphView.dataFrame )})
        }
        
        var minDistance: CGFloat = .greatestFiniteMagnitude
        var selectedPoint: GraphPoint? = nil
        
        for point in visiblePoints {
            let distance = dataPoint.distance(to: point.point, norm: norm, dataFrame: graphView.dataFrame)
            
            if distance < minDistance {
                selectedPoint = point
                minDistance = distance
            }
        }
        
        return selectedPoint
    }
    
    
    // MARK: - MinMax
    
    func minMax(dataFrame: CGRect) -> (CGFloat, CGFloat) {
        let pointsOnFrame = self.points.filter({ dataFrame.minX <= $0.x && $0.x <= dataFrame.maxX })
        let mins = pointsOnFrame.map({ $0.min })
        let maxs = pointsOnFrame.map({ $0.max })
        
        return (mins.min() ?? CGFloat.greatestFiniteMagnitude, maxs.max() ?? CGFloat.leastNormalMagnitude)
    }
    
    // MARK: - CALayerDelegate
    
    public func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return NSNull()
    }
}
