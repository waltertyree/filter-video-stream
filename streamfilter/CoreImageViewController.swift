//
//  CoreImageViewController.swift
//  streamfilter
//
//  Created by Walter Tyree on 11/3/21.
//

import UIKit
import AVFoundation
import CoreImage

class CoreImageViewController: UIViewController {

  @IBOutlet var videoView: UIImageView!

  @IBOutlet var filterSlider: UISlider!

  //this sample stream does not use https so there is a change to the TLS settings in the info.plist to make the phone use the link. If you change the url to another stream that does not have https you will need to update the TLS settings in info plist.
  //let streamURL = URL(string: "http://iphone-streaming.ustream.tv/uhls/17074538/streams/live/iphone/playlist.m3u8")

  //this sample stream is a Blender movie called "Sintel"
  let streamURL = URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")

  let playerItemVideoOutput = AVPlayerItemVideoOutput()

  lazy var displayLink: CADisplayLink =
  CADisplayLink(target: self, selector: #selector(displayLinkFired(link:)))


  var statusObserver: NSKeyValueObservation?
  var player: AVPlayer?

  var context: CIContext? = CIContext()


  var currentFrame: CIImage?



  override func viewDidLoad() {
    super.viewDidLoad()



    //create a player
    let videoItem = AVPlayerItem(url: streamURL!)
    self.player = AVPlayer(playerItem: videoItem)

//*important* add the display link and the output only after it is ready to play
  self.statusObserver = videoItem.observe(\.status,
      options: [.new, .old],
      changeHandler: { playerItem, change in
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
        pixelate.setValue(self.filterSlider.value, forKey: kCIInputScaleKey)
        pixelate.setValue(CIVector(x: frameImage.extent.midX, y: frameImage.extent.midY), forKey: kCIInputCenterKey)
        let newFrame = pixelate.outputImage!.cropped(to: frameImage.extent)

        self.videoView.image = UIImage(ciImage: newFrame)
      }
    }
  }
}

