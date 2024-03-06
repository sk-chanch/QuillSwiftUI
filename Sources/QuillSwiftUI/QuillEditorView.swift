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
    let html: String
    public var customFont: UIFont?
    public var onTextChange: ((String) -> ())?
    
    @State private var dynamicHeight: CGFloat = 0
    
    @Binding var text: String
    
    public init(_ placeholder: String = "",
                html: String = "",
                text: Binding<String>) {
        self._text = text
        self.placeholder = placeholder
        self.html = html
    }
    
    public var body: some View {
        GeometryReader{ proxy in
            QuillEditorWebView(placeholder: placeholder,
                               html: html,
                               width: proxy.size.width,
                               dynamicHeight: $dynamicHeight,
                               text: $text)
                .customFont(font: customFont)
                .onTextChange(onTextChange)
                .padding(.bottom, 10)
        }
        .frame(minHeight: dynamicHeight)
    }
}
