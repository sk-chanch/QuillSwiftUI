//
//  UIApplication+.swift
//  JERTAM
//
//  Created by Chanchana Koedtho on 15/11/2566 BE.
//

import Foundation
import UIKit


extension UIApplication{
  
    var currentWindow: UIWindow? {
        connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .flatMap {
                $0.windows
            }
            .first {
                $0.isKeyWindow
            }
    }
    
    func endEdit(){
        self.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
