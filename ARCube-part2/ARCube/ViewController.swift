//
//  ViewController.swift
//  ARCube
//
//  Created by 张嘉夫 on 2017/7/9.
//  Copyright © 2017年 张嘉夫. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate{
    @IBOutlet weak var wether_stair: UILabel!
    @IBOutlet var sceneView: ARSCNView!
    var planes = [UUID:Plane]() // 字典，存储场景中当前渲染的所有平面
    var lower_planes = [UUID:Plane]()
    var stairs=[UUID:Plane]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        wether_stair.text=""

        wether_stair.isHidden=false

        
        setupScene()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupSession()

        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        //sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    func setupScene() {
        // 设置 ARSCNViewDelegate——此协议会提供回调来处理新创建的几何体
        sceneView.delegate = self
        
        // 显示统计数据（statistics）如 fps 和 时长信息
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
        
        // 开启 debug 选项以查看世界原点并渲染所有 ARKit 正在追踪的特征点
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        
        let scene = SCNScene()
        sceneView.scene = scene
    }
    
    func setupSession() {
        // 创建 session 配置（configuration）实例
        let configuration = ARWorldTrackingConfiguration()
        
        // 明确表示需要追踪水平面。设置后 scene 被检测到时就会调用 ARSCNViewDelegate 方法
        configuration.planeDetection = [.horizontal,.vertical]
        
        // 运行 view 的 session
        sceneView.session.run(configuration)
    }

    // MARK: - ARSCNViewDelegate
    
    /**
     实现此方法来为给定 anchor 提供自定义 node。
     
     @discussion 此 node 会被自动添加到 scene graph 中。
     如果没有实现此方法，则会自动创建 node。
     如果返回 nil，则会忽略此 anchor。
     @param renderer 将会用于渲染 scene 的 renderer。
     @param anchor 新添加的 anchor。
     @return 将会映射到 anchor 的 node 或 nil。
     */
//    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
//        return nil
//    }
    
    /**
     将新 node 映射到给定 anchor 时调用。
     
     @param renderer 将会用于渲染 scene 的 renderer。
     @param node 映射到 anchor 的 node。
     @param anchor 新添加的 anchor。
     */
    // A CNN predict will be occur every 18 frames
    let bodyheight=Float(1.40)
    let thres = Float(-1.4)
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else {
            return
        }
        

        //lllprint("anchor xyz is ",anchor.center.x,anchor.center.y,anchor.center.z)
        // 检测到新平面时创建 SceneKit 平面以实现 3D 视觉化
        let plane = Plane(withAnchor: anchor)
        planes[anchor.identifier] = plane
        //sceneView.scene.rootNode.addChildNode(plane)
        node.addChildNode(plane)
        addplane(x:anchor.transform.columns.3.x,y:anchor.transform.columns.3.y,z:anchor.transform.columns.3.z,node:sceneView.scene.rootNode,color:UIColor.green)
        //        addplane(x:anchor.center.x,y:anchor.center.y,z:anchor.center.z,node:sceneView.scene.rootNode)


    }
    

    /**
     使用给定 anchor 的数据更新 node 时调用。
     
     @param renderer 将会用于渲染 scene 的 renderer。
     @param node 更新后的 node。
     @param anchor 更新后的 anchor。
     */
    var frameCount: UInt64 = 0
    let checkEveryFrame: UInt64 = 100
    var ini_ground : UInt64 = 0
    var ground_y = Float(0)
   
    //let ground : SCNNode
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let plane = planes[anchor.identifier] else {
            return
        }
  
        
        // anchor 更新后也需要更新 3D 几何体。例如平面检测的高度和宽度可能会改变，所以需要更新 SceneKit 几何体以匹配
        plane.update(anchor: anchor as! ARPlaneAnchor)
        if frameCount == 100{
            
            if let ground = lowestPlane(planes:planes){
                ground_y = ground.anchor.transform.columns.3.y
                frameCount += 1
                print("initialize ground plane",ground.anchor.transform.columns.3," and ground is ",ground_y)
                addplane(x: ground.anchor.transform.columns.3.x, y: ground.anchor.transform.columns.3.y, z: ground.anchor.transform.columns.3.z, node:sceneView.scene.rootNode , color: UIColor.brown)
            }
        }

        if frameCount % checkEveryFrame == 0 && frameCount != 0{
            if let lower = checkLower(planes: planes, ground_y: ground_y) {
                
                
                
                if let currentFrame = sceneView.session.currentFrame{
                    let cameraTransform = currentFrame.camera.transform
                    let cameraWorldPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
                    
                    // 现在，cameraWorldPosition 包含了摄像头的世界坐标
//                    print("Camera World Position: \(cameraWorldPosition)")
//                    addplane(x:cameraTransform.columns.3.x,y:cameraTransform.columns.3.y, z:cameraTransform.columns.3.z,node:sceneView.scene.rootNode,color:UIColor.black)
                    let sorted_lower=sortPlanesByDistance(planes: lower, cameraPosition: cameraWorldPosition)
                    let yDifferenceThreshold: Float = 0.05  // 你可以根据实际情况调整这个阈值
                    let minConsecutiveStairs: Int = 2  // 至少有多少组 yDifference 小于阈值才认为是楼梯
                                
                    var consecutiveStairsCount = 0
                    for i in 0..<sorted_lower.count - 1 {
                        let currentPlane = sorted_lower[i]
                        let nextPlane = sorted_lower[i + 1]
                        
                        // 获取当前平面和下一个平面的 y 值
                        let currentY = currentPlane.anchor.center.y
                        let nextY = nextPlane.anchor.center.y
                        
                        // 计算 y 值差值
                        let yDifference = abs(currentY - nextY)
                        
                        // 如果 y 值差值在阈值范围内，则认为构成楼梯
                        if yDifference <= yDifferenceThreshold {
                            consecutiveStairsCount += 1
                            print("Difference out of threshold")
                        }
                        
                        // 如果连续楼梯的数量超过阈值，认为构成楼梯
                        
                    }
                    if consecutiveStairsCount >= minConsecutiveStairs {
                        print("Staircase detected!")
                        DispatchQueue.main.async {
                                // 在这里更新UILabel的文本
                            self.wether_stair.text="stairs"
                            }
                        wether_stair.isHidden=false
                        wether_stair.text="stairs"
                        
                        // 进行楼梯检测后的操作...
                    }else{
                        DispatchQueue.main.async {
                                // 在这里更新UILabel的文本
                            self.wether_stair.text=""
                            }
                        print("no stair")
              
                        wether_stair.isHidden=true
                     
                    }
       
                    
                    
                }
            }

            
//            if let lower = checkLower(planes: planes, ground_y:ground_y){
//                for (id,lower_plane) in lower{
//                    if(lower_plane.anchor.transform.columns.3.y < ground_y && lower_plane.anchor.alignment == .horizontal)  {
//                        print("there is a lower layer",lower_plane.anchor.transform.columns.3.y)
//                        addplane(x: lower_plane.anchor.transform.columns.3.x, y: lower_plane.anchor.transform.columns.3.y, z: lower_plane.anchor.transform.columns.3.z, node:sceneView.scene.rootNode , color: UIColor.magenta)
//                    }
//                }
//                
//
//            }
        }
        frameCount += 1
        if frameCount >= 9223372036854775805 {
            frameCount = 0
        }

    }
    func sortPlanesByDistance(planes: [UUID: Plane], cameraPosition: SCNVector3) -> [Plane] {
        let sortedPlanes = planes.values.sorted { (plane1, plane2) -> Bool in
            let distance1 = plane1.distanceToCamera(cameraPosition: cameraPosition)
            let distance2 = plane2.distanceToCamera(cameraPosition: cameraPosition)
            return distance1 < distance2
        }
        return sortedPlanes
    }
    func checkLower(planes: [UUID: Plane], ground_y:Float) -> [UUID: Plane]? {
        var lowerPlanes: [UUID: Plane] = [:]

        for (id, plane) in planes {
            let planeHeight = plane.anchor.transform.columns.3.y

            if planeHeight < ground_y && plane.anchor.alignment == .horizontal {
                lowerPlanes[id] = plane
                print("there is a lower layer",plane.anchor.transform.columns.3.y)
                addplane(x: plane.anchor.transform.columns.3.x, y: plane.anchor.transform.columns.3.y, z: plane.anchor.transform.columns.3.z, node:sceneView.scene.rootNode , color: UIColor.magenta)
            }
        }

        return lowerPlanes.isEmpty ? nil : lowerPlanes
    }
    func lowestPlane(planes: [UUID: Plane]) -> Plane? {
        var lowestHeight: Float = Float.greatestFiniteMagnitude
        var ground: Plane?

        for (_, plane) in planes {
            let planeHeight = plane.anchor.transform.columns.3.y

            if planeHeight < lowestHeight && plane.anchor.alignment == .horizontal {
                lowestHeight = planeHeight
                
                ground = plane
            }
        }

        return ground
    }
    /**
     从 scene graph 中移除与给定 anchor 映射的 node 时调用。
     
     @param renderer 将会用于渲染 scene 的 renderer。
     @param node 被移除的 node。
     @param anchor 被移除的 anchor。
     */
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // 如果多个独立平面被发现共属某个大平面，此时会合并它们，并移除这些 node
        planes.removeValue(forKey: anchor.identifier)
        print("*****remove some plane",anchor.identifier)
    }
    func detectstairs(_ planes: [UUID:Plane]){
//        for plane in planes{
//            
//        }
    }
    /**。
     将要用给定 anchor 的数据来更新时 node 调用。
     
     @param renderer 将会用于渲染 scene 的 renderer。
     @param node 即将更新的 node。
     @param anchor 被更新的 anchor。
     */
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
        
    }
    func session(_ session: ARSession) {
        print("1111111111111111")
        
    }

    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        print("1111111111111111")
        
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        print("1111111111111111")
        
    }
    func addplane(x:Float32,y:Float32,z:Float32,node:SCNNode,color:UIColor){
        let plane1 = SCNPlane(width: 0.3, height: 0.1)
        let planeNode = SCNNode(geometry: plane1)
        //guard let cameraNode = sceneView.pointOfView else {
            //return
        //}

        let position = SCNVector3(x: 0, y: 0, z: 0)
        //let cameraPosition = cameraNode.position
        //let planeCenterInCameraSpace = sceneView.scene.rootNode.convertPosition(position , to: cameraNode)
        //planeNode.position = planeCenterInCameraSpace
        planeNode.position=position
        //print("position of world is *****",sceneView.scene.rootNode.position)
        //print("position of camera is *****",cameraNode.position)
        //print("position of plane is *****",planeNode.position)
     
        planeNode.eulerAngles=SCNVector3(0 ,Float.pi / 4, Float.pi / 4)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue.withAlphaComponent(0.5) // Blue with some transparency
        let img = UIImage(named: "fabric")
        material.diffuse.contents = img
        material.lightingModel = .physicallyBased
        plane1.materials = [material]// Adjust the position as needed
        let plane2 = SCNPlane(width: 0.2, height: 0.23)
        let planeNode2 = SCNNode(geometry: plane2)
        planeNode2.position = SCNVector3(x: 0, y: 0.6, z: 0)
        plane2.materials = [material]
        
        
        let sphere = SCNSphere(radius: 0.02)
        let materia_sph = SCNMaterial()
        materia_sph.diffuse.contents = color
        sphere.materials = [materia_sph]

            // Create a node for the sphere and position it at the center of the plane
        let centerNode = SCNNode(geometry: sphere)
        centerNode.position = SCNVector3(x,y,z)

        sceneView.scene.rootNode.addChildNode(centerNode)
        //sceneView.scene.rootNode.addChildNode(centerNode2)
        
        
    }
}
