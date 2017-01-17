//
//  ViewController.swift
//  PeertalkManual-iOS
//
//  Created by Kiran Kunigiri on 1/7/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    // Outlets
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var imageButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    let imagePicker = UIImagePickerController()
    
    // Properties
    weak var serverChannel: PTChannel?
    weak var peerChannel: PTChannel?
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // UI Setup
        addButton.layer.cornerRadius = addButton.frame.height/2
        imageButton.layer.cornerRadius = imageButton.frame.height/2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup imagge picker
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
        // Create a channel and start listening
        let channel = PTChannel(delegate: self)
        channel?.listen(onPort: in_port_t(PORT_NUMBER), iPv4Address: INADDR_LOOPBACK, callback: { (error) in
            if error != nil {
                print("ERROR (Listening to post): \(error?.localizedDescription)")
            } else {
                self.serverChannel = channel
            }
        })
        
    }
    
    // Add 1 to our counter label and send the data if the device is connected
    @IBAction func addButtonTapped(_ sender: UIButton) {
        if isConnected() {
            
            // Get the new counter number
            let num = "\(Int(label.text!)! + 1)"
            self.label.text = num
            
            // Convert and send the number as dispatch data
            let data = "\(num)".dispatchData
            self.sendData(data: data, type: PTFrame.count)
        }
    }
    
    // Present the image picker if the device is connected
    @IBAction func imageButtonTapped(_ sender: UIButton) {
        if isConnected() {
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    /** Checks if the device is connected, and presents an alert view if it is not */
    func isConnected() -> Bool {
        if peerChannel == nil {
            let alert = UIAlertController(title: "Disconnected", message: "Please connect to a device first", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        return peerChannel != nil
    }
    
    
    
    /** Closes the USB connectin */
    func closeConnection() {
        self.serverChannel?.close()
    }
    
    /** Sends data to the connected device */
    func sendData(data: NSData, type: PTFrame) {
        if peerChannel != nil {
            peerChannel?.sendFrame(ofType: type.rawValue, tag: PTFrameNoTag, withPayload: data.createReferencingDispatchData(), callback: { (error) in
                print(error?.localizedDescription ?? "Sent data")
            })
        }
    }
    
    /** Sends data to the connected device */
    func sendData(data: DispatchData, type: PTFrame) {
        if peerChannel != nil {
            peerChannel?.sendFrame(ofType: type.rawValue, tag: PTFrameNoTag, withPayload: data as __DispatchData!, callback: { (error) in
                print(error?.localizedDescription ?? "Sent data")
            })
        }
    }

}



// MARK: - Channel Delegate
extension ViewController: PTChannelDelegate {
    
    func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        
        // Check if the channel is our connected channel; otherwise ignore it
        // Optional: Check the frame type and optionally reject it
        if channel != peerChannel {
            return false
        } else {
            return true
        }
    }
    
    
    func ioFrameChannel(_ channel: PTChannel!, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
        
        // Creates the data
        let dispatchData = payload.dispatchData as DispatchData
        
        // Check frame type
        if type == PTFrame.count.rawValue {
            let message = String(bytes: dispatchData, encoding: .utf8)
            self.label.text = message
        } else if type == PTFrame.image.rawValue {
            let data = NSData(contentsOfDispatchData: dispatchData as __DispatchData) as Data
            let image = UIImage(data: data)
            self.imageView.image = image
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error?) {
        print("ERROR (Connection ended): \(error?.localizedDescription)")
        self.statusLabel.text = "Status: Disconnected"
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didAcceptConnection otherChannel: PTChannel!, from address: PTAddress!) {
        
        // Cancel any existing connections
        if (peerChannel != nil) {
            peerChannel?.cancel()
        }
        
        // Update the peer channel and information
        peerChannel = otherChannel
        peerChannel?.userInfo = address
        print("SUCCESS (Connected to channel)")
        self.statusLabel.text = "Status: Connected"
    }
}



extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Get the image and send it
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        // Get the picked image
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        // Update our UI on the main thread
        self.imageView.image = image
        
        // Send the data on the background thread to make sure the UI does not freeze
        DispatchQueue.global(qos: .background).async {
            let data = UIImageJPEGRepresentation(image, 1.0)!
            self.sendData(data: data as NSData, type: PTFrame.image)
        }
        
        // Dismiss the image picker
        dismiss(animated: true, completion: nil)
    }
    
    // Dismiss the view
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}












