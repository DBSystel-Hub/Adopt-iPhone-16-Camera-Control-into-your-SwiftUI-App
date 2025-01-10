//
//  CameraView.swift
//  CameraControlAPI
//
//  Created by Balaji Venkatesh on 07/10/24.
//

import SwiftUI
import AVKit

/// Camera Permission
enum CameraPermission: String {
    case granted = "Permission Granted"
    case idle = "Not Decided"
    case denied = "Permission Denied"
}

@MainActor
@Observable
class Camera: NSObject, AVCaptureSessionControlsDelegate {
    /// Camera Properties
    private let queue: DispatchSerialQueue = .init(label: "com.yourApp.sessionQueue")
    let session: AVCaptureSession = .init()
    var cameraPosition: AVCaptureDevice.Position = .back
    let cameraOutput: AVCapturePhotoOutput = .init()
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var permission: CameraPermission = .idle
    
    override init() {
        super.init()
        checkCameraPermission()
    }
    
    /// Checking and asking for camera permission
    private func checkCameraPermission() {
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                /// Permission Granted
                permission = .granted
                setupCamera()
            case .notDetermined:
                /// Asking Camera Permission
                if await AVCaptureDevice.requestAccess(for: .video) {
                    setupCamera()
                }
            case .denied, .restricted:
                /// Permission Denied
                permission = .denied
            @unknown default: break
            }
        }
    }
    
    /// Setting up camera
    private func setupCamera() {
        do {
            session.beginConfiguration()
            
            guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: cameraPosition).devices.first else {
                print("Couldn't Find Back Camera")
                session.commitConfiguration()
                return
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input), session.canAddOutput(cameraOutput) else {
                print("Cannot add camera output")
                session.commitConfiguration()
                return
            }
            
            session.addInput(input)
            session.addOutput(cameraOutput)
            setupCameraControl(device)
            session.commitConfiguration()
            startSession()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        /// Session Start/Stop must run on background thread not on main thread.
        Task.detached(priority: .background) {
            await self.session.startRunning()
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        /// Session Start/Stop must run on background thread not on main thread.
        Task.detached(priority: .background) {
            await self.session.stopRunning()
        }
    }
    
    /// Sets up Camera Control Actions for iPhone 16+ Models
    private func setupCameraControl(_ device: AVCaptureDevice) {
        /// Checking if the device is eligible for camera control
        guard session.supportsControls else { return }
        session.setControlsDelegate(self, queue: queue)
        
        /// Removing any previously added controls, if any
        for control in session.controls {
            session.removeControl(control)
        }
        
        let modes: [String] = ["Story", "Reels", "Live"]
        let modeControl = AVCaptureIndexPicker("Content", symbolName: "iphone.rear.camera", localizedIndexTitles: modes)
        modeControl.setActionQueue(queue) { index in
            print("Selected Mode: ", modes[index])
            /// Update Camera
        }
        
        /// Default Controls
        let zoomControl = AVCaptureSystemZoomSlider(device: device) { scaleFactor in
            print("Updated Scale Factor: ", scaleFactor)
        }
        
        /// Custom Controls
        let lightingControl = AVCaptureSlider("Lighting", symbolName: "light.max", in: 0...1)
        lightingControl.setActionQueue(queue) { progress in
            print(progress)
            /// Update Camera
        }
        
        let filters: [String] = ["None", "B/W", "Vivid", "Comic", "Humid"]
        let filterControl = AVCaptureIndexPicker("Filters", symbolName: "camera.filters", localizedIndexTitles: filters)
        filterControl.setActionQueue(queue) { index in
            print("Selected Filter: ", filters[index])
            /// Update Camera
        }
        
        let controls: [AVCaptureControl] = [modeControl, zoomControl, lightingControl, filterControl]
        
        for control in controls {
            /// Always check whether the control can be added to a session
            if session.canAddControl(control) {
                session.addControl(control)
            } else {
                print("Control can't be added")
            }
        }
    }
    
    /// Camera Control Protocols
    nonisolated func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {
        
    }
    
    nonisolated func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {
        
    }
    
    nonisolated func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {
        
    }
    
    nonisolated func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {
        
    }
    
    func capturePhoto() {
        print("Capture Photo")
    }
}

struct CameraView: View {
    var camera: Camera = .init()
    @Environment(\.scenePhase) private var scene
    var body: some View {
        GeometryReader {
            let size = $0.size
            
            CameraLayerView(size: size)
        }
        .ignoresSafeArea()
        .environment(camera)
        .onChange(of: scene) { oldValue, newValue in
            if newValue == .active {
                camera.startSession()
            } else {
                camera.stopSession()
            }
        }
    }
}

struct CameraLayerView: UIViewRepresentable {
    var size: CGSize
    @Environment(Camera.self) private var camera
    func makeUIView(context: Context) -> UIView {
        let frame = CGRect(origin: .zero, size: size)
        
        let view = UIView(frame: frame)
        view.backgroundColor = .clear
        view.clipsToBounds = true
        
        /// AVCamera Layer
        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.videoGravity = camera.videoGravity
        layer.frame = frame
        layer.masksToBounds = true
        
        view.layer.addSublayer(layer)
        setupCameraInteraction(view)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {  }
    
    func setupCameraInteraction(_ view: UIView) {
        let cameraControlInteraction = AVCaptureEventInteraction { event in
            if event.phase == .ended {
                /// Camera button is clicked completely
                camera.capturePhoto()
            }
        }
        
        view.addInteraction(cameraControlInteraction)
    }
}

#Preview {
    CameraView()
}
