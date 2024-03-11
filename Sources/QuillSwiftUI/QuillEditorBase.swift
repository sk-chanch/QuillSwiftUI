//
//  QuillEditorBase.swift
//
//
//  Created by Chanchana Koedtho on 4/3/2567 BE.
//

import Foundation
import Combine
import SwiftUI

public protocol QuillEditorBase: View {
    var customFont: UIFont? { get set }
    var onTextChange: ((String)->())? { get set }
    
    func customFont(font: UIFont?) -> Self
    func onTextChange(_ perform: ((String)->())?) -> Self
}

public extension QuillEditorBase {
    func customFont(font: UIFont?) -> Self {
        var copy = self
        copy.customFont = font
        return copy
    }
    
    func onTextChange(_ perform: ((String)->())?) -> Self {
        var copy = self
        copy.onTextChange = perform
        return copy
    }
}
