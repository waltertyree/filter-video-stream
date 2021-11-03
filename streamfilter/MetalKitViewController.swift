//
//  ViewController.swift
//  streamfilter
//
//  Created by Walter Tyree on 11/1/21.
//

import UIKit
import AVFoundation
import MetalKit
import CoreImage


class MetalKitViewController: UIViewController {

  @IBOutlet var videoView: MTKView!

  @IBOutlet var saturationSlider: UISlider!

  //this sample stream does not use https so there is a change to the TLS settings in the info.plist to make the phone use the link. If you change the url to another stream that does not have https you will need to update the TLS settings in info plist.
  //let streamURL = URL(string: "http://iphone-streaming.ustream.tv/uhls/17074538/streams/live/iphone/playlist.m3u8")

  //this sample stream is a Blender movie called "Sintel"
  let streamURL = URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")

  let playerItemVideoOutput = AVPlayerItemVideoOutput()

  lazy var displayLink: CADisplayLink =
  CADisplayLink(target: self, selector: #selector(displayLinkFired(link:)))


  var statusObserver: NSKeyValueObservation?
  var player: AVPlayer?

  var commandQueue: MTLCommandQueue?
  var context: CIContext?


  var currentFrame: CIImage?


  override func viewDidLoad() {
    super.viewDidLoad()

    // Set up the metalkit view
    videoView.device =  MTLCreateSystemDefaultDevice()
    self.commandQueue = videoView.device?.makeCommandQueue()
    videoView.delegate = self
    videoView.framebufferOnly = false

    context = CIContext(mtlDevice: videoView.device!)


    //create a player
    let videoItem = AVPlayerItem(url: streamURL!)
    self.player = AVPlayer(playerItem: videoItem)

    //*important* add the display link and the output only after it is ready to play
    self.statusObserver = videoItem.observe(\.status, options: [.new, .old], changeHandler: { playerItem, change in
      if playerItem.status == .readyToPlay {
        playerItem.add(self.playerItemVideoOutput)
        self.displayLink.add(to: .main, forMode: .common)
        self.player?.play()

      }
    })

  }

  @objc func displayLinkFired(link: CADisplayLink) {
    let currentTime = playerItemVideoOutput.itemTime(forHostTime: CACurrentMediaTime())
    if playerItemVideoOutput.hasNewPixelBuffer(forItemTime: currentTime) {
      if let buffer = playerItemVideoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
        let frameImage = CIImage(cvImageBuffer: buffer)

        //apply pipeline of filters to ciImage
        let pixelate = CIFilter(name: "CIPixellate")!
        pixelate.setValue(frameImage, forKey: kCIInputImageKey)
        pixelate.setValue(self.saturationSlider.value, forKey: kCIInputScaleKey)
        pixelate.setValue(CIVector(x: frameImage.extent.midX, y: frameImage.extent.midY), forKey: kCIInputCenterKey)
        self.currentFrame = pixelate.outputImage!.cropped(to: frameImage.extent)

        //when using metal we also need to tell it to draw
        //if we were using UIImageView we could just assign the image
        self.videoView.draw()
      }
    }
  }
}

// - MetalKit Delegate
extension MetalKitViewController: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    //not used in this demo
  }

  func draw(in view: MTKView) {
    //*important* when rendering on the simulator, MTKViews render upside down. Test on an actual device.
    //create command buffer for ciContext to use to encode it's rendering instructions to our GPU
    guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
      return
    }

    //make sure we actually have a ciImage to work with
    guard let ciImage = currentFrame else {
      return
    }

    //make sure the current drawable object for this metal view is available (it's not in use by the previous draw cycle)
    guard let currentDrawable = view.currentDrawable else {
      return
    }
    let scaleX = view.drawableSize.width / ciImage.extent.width
    let scaleY = view.drawableSize.height / ciImage.extent.height

    //manually calculate an "Aspect Fit" scale and apply it to both axises
    let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: min(scaleX, scaleY), y: min(scaleX, scaleY)))


    //render into the metal texture
    self.context?.render(scaledImage,
                         to: currentDrawable.texture,
                         commandBuffer: commandBuffer,
                         bounds: CGRect(origin: .zero, size: view.drawableSize),
                         colorSpace: CGColorSpaceCreateDeviceRGB())

    //register where to draw the instructions in the command buffer once it executes
    commandBuffer.present(currentDrawable)
    //commit the command to the queue so it executes
    commandBuffer.commit()
  }
}


