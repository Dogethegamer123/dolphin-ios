// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

class JitWaitViewController: UIViewController {
  @objc weak var delegate: JitWaitViewControllerDelegate?
  
  var timer: Timer?
  var isShowingError: Bool = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkJit), userInfo: nil, repeats: true)
    
    if #available(iOS 26.0, *) {
      self.requestJITFromStikDebug()
    } else {
      JitManager.shared().acquireJitByAltServer()
      JitManager.shared().acquireJitByJitStreamer()
    }
  }

  private func requestJITFromStikDebug() {
    let manager = JitManager.shared()

    // SideStore appends the free provisioning team ID to the installed
    // bundle identifier. StikDebug must receive this full installed ID so
    // it can bring the already-running DolphiniOS process back to the front.
    let bundleIdentifier = "me.oatmealdome.dolphinios-njb.7BPRV54685"

    var components = URLComponents()
    components.scheme = "stikdebug"
    components.host = "enable-jit"
    components.queryItems = [
      URLQueryItem(name: "bundle-id", value: bundleIdentifier),
      URLQueryItem(name: "pid", value: String(ProcessInfo.processInfo.processIdentifier))
    ]

    if manager.deviceHasTxm {
      components.queryItems?.append(
        URLQueryItem(name: "script-name", value: "legacy.js")
      )
    }

    guard let url = components.url else {
      manager.acquisitionError = "Could not create the StikDebug JIT request."
      return
    }

    UIApplication.shared.open(url, options: [:]) { success in
      if !success {
        manager.acquisitionError = "StikDebug could not be opened. Make sure StikDebug is installed."
      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    self.showAcquisitionErrorIfNecessary()
  }
  
  @objc func checkJit() {
    if (self.isShowingError) {
      return
    }
    
    let manager = JitManager.shared()
    
    manager.recheckIfJitIsAcquired()
    
    if (manager.acquiredJit) {
      self.timer?.invalidate()
      self.delegate?.didFinishJitScreen(result: .jitAcquired, sender: self)
      
      return
    }
    
    self.showAcquisitionErrorIfNecessary()
  }
  
  func showAcquisitionErrorIfNecessary() {
    let manager = JitManager.shared()
    
    if let error = manager.acquisitionError {
      manager.acquisitionError = nil
      self.isShowingError = true
      
      let alertController = UIAlertController(title: DOLCoreLocalizedString("Error"), message: error, preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: DOLCoreLocalizedString("OK"), style: .default, handler: {_ in
        self.isShowingError = false
      }))
      
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  @IBAction func helpPressed(_ sender: Any) {
    let url = URL.init(string: "https://dolphinios.oatmealdome.me/jit-help")
    UIApplication.shared.open(url!, options: [:], completionHandler: nil)
  }
  
  @IBAction func noJitPressed(_ sender: Any) {
    self.timer?.invalidate()
    self.delegate?.didFinishJitScreen(result: .noJitRequested, sender: self)
  }
  
  @IBAction func cancelPressed(_ sender: Any) {
    self.timer?.invalidate()
    self.delegate?.didFinishJitScreen(result: .cancel, sender: self)
  }
}
