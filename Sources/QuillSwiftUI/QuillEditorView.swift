//
//  File.swift
//  
//
//  Created by Chanchana Koedtho on 4/3/2567 BE.
//

import Foundation
import SwiftUI

public struct QuillEditorView: QuillEditorBase {
    let placeholder: String
    
    public var customFont: UIFont?
    public var onTextChange: ((String) -> ())?
    
    @State private var dynamicHeight: CGFloat = 0
    
    @Binding var text: String
    
    public init(_ placeholder: String = "", text: Binding<String>) {
        self._text = text
        self.placeholder = placeholder
    }
    
    public var body: some View {
        QuillEditorWebView(placeholder: placeholder, 
                           dynamicHeight: $dynamicHeight,
                           text: $text)
            .customFont(font: customFont)
            .onTextChange(onTextChange)
            .padding(.bottom, 10)
            .frame(minHeight: dynamicHeight)
    }
}
