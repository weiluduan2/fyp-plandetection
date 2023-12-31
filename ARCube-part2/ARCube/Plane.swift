//
//  Plane.swift
//  ARCube
//
//  Created by 张嘉夫 on 2017/7/10.
//  Copyright © 2017年 张嘉夫. All rights reserved.
//Build input file cannot be found: '/Downloads/tron_grid.png'. Did you forget to declare this file as an output of a script phase or custom build rule which produces it?


import UIKit
import SceneKit
import ARKit

class Plane: SCNNode {
    
    var anchor: ARPlaneAnchor!
    var planeGeometry: SCNPlane!
  
    init(withAnchor anchor: ARPlaneAnchor) {
        super.init()
        
        self.anchor = anchor
        
        planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        
        // 相比把网格视觉化为灰色平面，我更喜欢用科幻风的颜色来渲染
        let material = SCNMaterial()

        
        material.lightingModel = .physicallyBased
        planeGeometry.materials = [material]
        
        let planeNode = SCNNode(geometry: planeGeometry)
        planeNode.position = SCNVector3Make(anchor.center.x, anchor.center.y, anchor.center.z)
        planeNode.transform = SCNMatrix4MakeRotation(Float(-.pi / 2.0), 1.0, 0.0, 0.0)
//        planeNode.position = SCNVector3Make(anchor.transform.columns.3.x, 0, anchor.transform.columns.3.z)
        //print("plane position is ", planeNode.position)
        //print("plane position is",planeNode.position)
        // SceneKit 里的平面默认是垂直的，所以需要旋转90度来匹配 ARKit 中的平面
        //print("node transfor beofrem is", planeNode.transform)
        
        //print("node transfor after is", planeNode.transform)
        
        //print("plane position after rotate is ", planeNode.position)
        
        let img = UIImage(named: "swift")
        if anchor.alignment == .horizontal{
            print("this is horizontal",anchor.alignment)
            let img = UIImage(named: "fabric")
            material.diffuse.contents = img
            
     
        }else if anchor.alignment == .vertical {
            print("Detected a vertical plane.")
            let img = UIImage(named: "swift")
            material.diffuse.contents = img
          
            
        }
        setTextureScale()
        addChildNode(planeNode)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func distanceToCamera(cameraPosition:SCNVector3) -> Float {
        let anchorPosition = SCNVector3Make(self.anchor.transform.columns.3.x, self.anchor.transform.columns.3.y, self.anchor.transform.columns.3.z)

        let distance = SCNVector3Make(anchorPosition.x - cameraPosition.x, anchorPosition.y - cameraPosition.y, anchorPosition.z - cameraPosition.z)
        return sqrtf(distance.x * distance.x + distance.y * distance.y + distance.z * distance.z)
    }
    
    func update(anchor: ARPlaneAnchor) {
        // 随着用户移动，平面 plane 的 范围 extend 和 位置 location 可能会更新。
        // 需要更新 3D 几何体来匹配 plane 的新参数。
        planeGeometry.width = CGFloat(anchor.extent.x);
        planeGeometry.height = CGFloat(anchor.extent.z);
        
        // plane 刚创建时中心点 center 为 0,0,0，node transform 包含了变换参数。
        // plane 更新后变换没变但 center 更新了，所以需要更新 3D 几何体的位置
        position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)

        setTextureScale()
    }
    
    func setTextureScale() {
        let width = planeGeometry.width
        let height = planeGeometry.height
        
        // 平面的宽度/高度 width/height 更新时，我希望 tron grid material 覆盖整个平面，不断重复纹理。
        // 但如果网格小于 1 个单位，我不希望纹理挤在一起，所以这种情况下通过缩放更新纹理坐标并裁剪纹理
        let material = planeGeometry.materials.first
        material?.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(width), Float(height), 1)
        material?.diffuse.wrapS = .repeat
        material?.diffuse.wrapT = .repeat
    }
}
