//
//  QuillEditorWebView.swift
//  QuillSwiftUI
//
//  Created by Chanchana Koedtho on 2/3/2567 BE.
//

import Foundation
import SwiftUI
import WebKit
import SwifterSwift
import SafariServices

public class QuillEditorWebViewConfiguration: ObservableObject {
    @Published var currentFormat = [String: Any]()
}

public struct QuillEditorWebView: UIViewRepresentable {
    private var logHandler: ((_ result: Any?, _ error: Error?)->()) = { _, e in
        if let e = e {
            print(e.localizedDescription)
        } else {
            print("success inject")
        }
    }
    
    @StateObject private var configuration = QuillEditorWebViewConfiguration()
    
    
    let webView = RichEditorWebView()
    
    let placeholder: String
    let html: String
    let width: CGFloat
    
    @Binding var dynamicHeight: CGFloat
    @Binding var text: String
    
    public var customFont: UIFont?
    public var onTextChange: ((String)->())?
    
    public init(placeholder: String,
                html: String = "",
                width: CGFloat,
                dynamicHeight: Binding<CGFloat>,
                text: Binding<String>) {
        self.placeholder = placeholder
        self._dynamicHeight = dynamicHeight
        self._text = text
        self.html = html
        self.width = width
    }
    
    public func makeUIView(context: Context) -> some WKWebView {
        settingWebView(context: context)
     
        webView.didReceive = { message in
            
            guard message.name != "log"
            else {
                print(message.body)
                return
            }
            
            guard message.name != "heightDidChange"
            else {
                DispatchQueue.main.async {
                    dynamicHeight = (message.body as? CGFloat) ?? 0
                }
                return
            }
            
            guard message.name != "currentFormat"
            else {
                configuration.currentFormat = (message.body as? [String: Any]) ?? [:]
                print(configuration.currentFormat)
                return
            }
            
            print(message.body)
            
            if message.name == "editLink",
                var url = (message.body as? String)?.url {
                if url.scheme == nil {
                    guard let httpsURL = URL(string: "https://\(url.absoluteString)") else {
                        return
                    }
                    url = httpsURL
                }
                
                alertEditLink(completionHandler: {
                    if $0 == 0 {
                        let root = UIApplication.shared.currentWindow?.rootViewController
                        root?.present(SFSafariViewController(url: url), animated: true, completion: nil)
                    } else if $0 == 1 {
                        alertInsertLink(setupText: url.absoluteString, completionHandler: {
                            replaceLink(url: $0)
                        })
                    } else {
                        deleteTextFromSelection()
                    }
                })
            } else {
                let changeText = (message.body as? String) ?? ""
                text = changeText
                onTextChange?(changeText)
            }
        }
        
        loadEditor()
        
        return webView
    }
    
    private func loadEditor() {
        DispatchQueue.main.async {
            webView.loadHTMLString(generateHTML(), baseURL: Bundle.main.bundleURL)
        }
    }

    private func settingWebView(context: Context) {
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.width = width
       
        webView.accessoryView = AccessoryInputView {
            QuillEditorToolbarView(action: {
                switch $0 {
                case .bold:
                    formatText(style: "bold")
                case .italic:
                    formatText(style: "italic")
                case .strike:
                    formatText(style: "strike")
                case .underline:
                    formatText(style: "underline")
                case .link:
                    checkLink(completionHandler: { link in
                        alertInsertLink(setupText: link == "false" ? "" : link ?? "", completionHandler: {
                            if link == "false" {
                                insertLink(url: $0)
                            } else {
                                replaceLink(url: $0)
                            }
                        })
                    })
                case .bullet:
                    toggleListFormat(style: "bullet")
                case .ordered:
                    toggleListFormat(style: "ordered")
                case .undo:
                    undo()
                case .redo:
                    redo()
                }
            })
            .environmentObject(configuration)
        }
    }
    
    public func updateUIView(_ uiView: UIViewType, context: Context) {
        // Check if it's the first update
        print("update richtext")
    }
    
    public func makeCoordinator() -> Coordinator {
        return .init(parent: self)
    }
}

enum QuillEditorToolbarAction {
    case bold
    case italic
    case strike
    case underline
    case link
    case bullet
    case ordered
    case undo
    case redo
}

struct QuillEditorToolbarView: View {
    @EnvironmentObject private var configuration: QuillEditorWebViewConfiguration
    var action: ((QuillEditorToolbarAction)->())?
    
    var body: some View {
        HStack(spacing: 10){
            Button(action: {
                action?(.bold)
            }, label: {
                let isBold = configuration.currentFormat.contains(where: { $0.key == "bold" && ($0.value as? Bool) ?? false})
                Image(systemName: "bold")
                    .foregroundColor(isBold ? .blue : .black)
            })
            
            Button(action: {
                action?(.italic)
            }, label: {
                let isItalic = configuration.currentFormat.contains(where: { $0.key == "italic" && ($0.value as? Bool) ?? false})
                Image(systemName: "italic")
                    .foregroundColor(isItalic ? .blue : .black)
            })
            
            Button(action: {
                action?(.strike)
            }, label: {
                let isStrike = configuration.currentFormat.contains(where: { $0.key == "strike" && ($0.value as? Bool) ?? false})
                Image(systemName: "strikethrough")
                    .foregroundColor(isStrike ? .blue : .black)
            })
            
            Button(action: {
                action?(.underline)
            }, label: {
                let isUnderline = configuration.currentFormat.contains(where: { $0.key == "underline" && ($0.value as? Bool) ?? false})
                Image(systemName: "underline")
                    .foregroundColor(isUnderline ? .blue : .black)
            })
            
            Button(action: {
                action?(.link)
            }, label: {
                let isLink = configuration.currentFormat.contains(where: { $0.key == "link" })
                Image(systemName: "link")
                    .foregroundColor(isLink ? .blue : .black)
            })
            
            Button(action: {
                action?(.bullet)
            }, label: {
                let isBullet = configuration.currentFormat.contains(where: { $0.key == "list" && ($0.value as? String) == "bullet" })
                Image(systemName: "list.bullet")
                    .foregroundColor(isBullet ? .blue : .black)
            })
            
            Button(action: {
                action?(.ordered)
            }, label: {
                let isOrdered = configuration.currentFormat.contains(where: { $0.key == "list" && ($0.value as? String) == "ordered" })
                Image(systemName: "list.number")
                    .foregroundColor(isOrdered ? .blue : .black)
            })
            
            Spacer()
            
            Button(action: {
                action?(.undo)
            }, label: {
                Image(systemName: "arrow.uturn.backward")
            })
            
            Button(action: {
                action?(.redo)
            }, label: {
                Image(systemName: "arrow.uturn.forward")
            })
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.white)
    }
}

extension QuillEditorWebView {
    func formatText(style: String) {
        let script = """
    var range = quill.getSelection();
    if (range && range.length > 0 ) {
        var format = quill.getFormat(range);
        if (format['\(style)'] === true) {
            // If the formatting is already applied, remove it
            quill.formatText(range.index, range.length, '\(style)', false);
        } else {
            // If the formatting is not applied, apply it
            quill.formatText(range.index, range.length, '\(style)', true);
        }
    } else {
        quill.format('\(style)', !quill.getFormat()['\(style)']);
    }
    
    updateCurrentFormat();
"""
        webView.evaluateJavaScript(script, completionHandler: logHandler)
    }
    
    func insertLink(url: String) {
        guard url.count > 0
        else { return }
     
        let script = """
               var range = quill.getSelection();
        
               if ( range === null ) {
                  range = savedRange;
               }
                        
               // Format the text range as a link
               if (range.length > 0) {
                   quill.formatText(range.index, range.length, 'link', '\(url)');
               } else {
                  var length = quill.getLength();
                  quill.insertText(length - 1, '\(url)', 'link', '\(url)');
               }

               window.webkit.messageHandlers.textDidChange.postMessage(quill.root.innerHTML);
        """
        
        webView.evaluateJavaScript(script, completionHandler: logHandler)
    }
    
    private func replaceLink(url: String) {
        let script = "replaceURL('\(url)');"
        
        webView.evaluateJavaScript(script, completionHandler: { result, e in
            if let e = e {
                print(e.localizedDescription)
            }
        })
    }
    
    func checkLink(completionHandler: ((String?)->())?) {
        let script = """
           var range = quill.getSelection();
           if (range) {
                var formats = quill.getFormat(range.index, range.length);
               if (formats && formats.link)  {
                    formats.link
               } else {
                   'false';
               }
           }
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error evaluating JavaScript: \(error)")
            } else {
                completionHandler?(result as? String)
            }
        }
    }
    
    func toggleListFormat(style: String) {
        let jsCode = """
            var selection = quill.getSelection();
            var format = quill.getFormat(selection.index, selection.length);
            if ( format['list'] === '\(style)' ) {
                quill.removeFormat(selection.index, selection.length);
            } else {
                quill.formatLine(selection.index, selection.length, 'list', '\(style)'); // Format the line as a bullet list item
            }

            updateCurrentFormat();
"""
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    func undo() {
        let jsCode = "quill.history.undo();"
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    func redo() {
        let jsCode = "quill.history.redo();"
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    func updateHeight() {
        let js = "updateHeight();";
        webView.evaluateJavaScript(js, completionHandler: logHandler)
    }
    
    func focus(){
        let js = "quill.focus();"
        webView.evaluateJavaScript(js, completionHandler: logHandler)
    }
    
    func deleteTextFromSelection() {
        let js = """
            var selection = quill.getSelection();

            if ( selection === null ) {
               selection = savedRange;
            }

            if (selection) {
                if (selection.length === 0) {
                    selection = expandSelectionToWord(selection);
                }
                
                quill.deleteText(selection.index, selection.length);
            }
          """
        webView.evaluateJavaScript(js, completionHandler: logHandler)
    }
    
    func generateHTML() -> String {
          return """
              <HTML>
                  <head>
                      <meta name='viewport' content='width=device-width, shrink-to-fit=YES, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no'>
                  </head>
                  <!-- Include stylesheet -->
                  <link href="https://cdn.jsdelivr.net/npm/quill@2.0.0-rc.2/dist/quill.snow.css" rel="stylesheet" />
                  
                \(generateCSS())
                  
                  <!-- Create the editor container -->
                  <BODY>
                      <div id="editor">\(html)</div>
                  </BODY>
                  <!-- Include the Quill library -->
                  <script src="https://cdn.jsdelivr.net/npm/quill@2.0.0-rc.2/dist/quill.js"></script>
                  
                  <!-- Initialize Quill editor -->
                  \(generateJS())
              </HTML>

              """
      }
    
    func generateJS() -> String {
        return """
      <script>
          const toolbarOptions = [];
          var savedRange = null;
          var contentHasBeenSet = false;
            
          const quill = new Quill('#editor', {
              theme: 'snow',
              modules: {
                  toolbar: false
              },
              placeholder: '\(placeholder)'
          });
        
          //remove format text on paste
          quill.clipboard.addMatcher(Node.ELEMENT_NODE, (node, delta) => {
            let ops = []
            delta.ops.forEach(op => {
              if (op.insert && typeof op.insert === 'string') {
                ops.push({
                  insert: op.insert
                })
              }
            })
            delta.ops = ops
            return delta
          });
  
          var Link = Quill.import('formats/link');
          Link.sanitize = function(url) {
            // prefix default protocol.
            let protocol = url.slice(0, url.indexOf(':'));
            if (this.PROTOCOL_WHITELIST.indexOf(protocol) === -1) {
              url = 'http://' + url;
            }
            // Link._sanitize function
            let anchor = document.createElement('a');
            anchor.href = url;
            protocol = anchor.href.slice(0, anchor.href.indexOf(':'));
            return (this.PROTOCOL_WHITELIST.indexOf(protocol) > -1) ? url : this.SANITIZED_URL;
          }
          Quill.register(Link, true);
  
  
          function updateHeight() {
            window.webkit.messageHandlers.heightDidChange.postMessage(quill.root.offsetHeight);
          }
  
          quill.on('text-change', function(delta, oldDelta, source) {
               window.webkit.messageHandlers.textDidChange.postMessage(quill.root.innerHTML);
                
               var length = quill.getText().trim().length;
               if (length === 0) {
                  window.webkit.messageHandlers.heightDidChange.postMessage(0);
               } else {
                  updateHeight();
               }
                
               updateCurrentFormat();
          });
 
          function updateCurrentFormat() {
               var selection = quill.getSelection();
               var formats = quill.getFormat(selection.index, selection.length);
               window.webkit.messageHandlers.currentFormat.postMessage(formats);
          }
  
          function closeLinkTooltip() {
            var tooltip = document.querySelector('.ql-tooltip');
            if (tooltip) {
              tooltip.style.display = 'none';
            }
          }
  
          quill.on('selection-change', function(range, oldRange, source) {
              if (range) {
                  var formats = quill.getFormat(range.index, range.length);
                  savedRange = range;
                  window.webkit.messageHandlers.currentFormat.postMessage(formats);
 
                  if (formats && formats.link) {
                      closeLinkTooltip();
                                    
                      // Check if the selection includes a link
                      if (!oldRange || !oldRange || !oldRange.length || !oldRange.length && !oldRange.index) {
                          window.webkit.messageHandlers.editLink.postMessage(formats.link);
                      }
                  }
              }
          });
    
          function expandSelectionToWord(selection) {
              var index = selection.index;
              var length = selection.length;

              // Expand selection to the beginning of the word
              while (index > 0 && !/\\s/.test(quill.getText(index - 1, 1))) {
                  index--;
                  length++;
              }

              // Expand selection to the end of the word
              while (index + length < quill.getLength() && !/\\s/.test(quill.getText(index + length, 1))) {
                  length++;
              }

              return {
                  index: index,
                  length: length
              };
          }
  
          function replaceURL(newLink) {
              var selection = quill.getSelection();
  
              if ( selection === null ) {
                 selection = savedRange;
              }
  
              if (selection) {
                  if (selection.length === 0) {
                      selection = expandSelectionToWord(selection);
                  }

                  var format = quill.getFormat(selection.index, selection.length); // Get format at selection
                  if (format && format.link) {
                      var link = format.link;
                      if (newLink !== null) {
                          quill.formatText(selection.index, selection.length, 'link', newLink, Quill.sources.USER);
                      }
                  } else {
                     window.webkit.messageHandlers.log.postMessage("No link found at the current selection.");
                  }
              }
          }
 
  
      </script>
   
 """
    }
    
    func generateCSS() -> String {
        var fontFaceString = ""
        var fontBodyString = ""
        
        if let customFont = self.customFont {
            fontFaceString = """
             @font-face {
                 font-family: '\(customFont.fontName)';
                 src: url("\(customFont.fontName).ttf") format('truetype'); // name of your font in Info.plist
             }
"""
            fontBodyString = """
                font-family: '\(customFont.fontName)';
                font-size: \(customFont.pointSize)px;
"""
        }
        
        return """
          <style type='text/css'>
            \(fontFaceString)
        
            /* CSS to remove border */
            .ql-container, .ql-toolbar {
                border: none !important;
                        
                \(fontBodyString)
            }
        
              .ql-toolbar {
                  padding: 0
              }
        
              
              body {
                margin: 0;
                padding: 0;
              }
            
             div.ql-editor {
                overflow: hidden;
                margin-left: 0;
                margin-ritht: 0;
                padding-left: 0;
                padding-right: 0;
            }
        
            .ql-container, .ql-editor{
              height: auto;
            }
              
          </style>
        """
    }
    
    private func alertInsertLink(setupText: String, completionHandler: ((String)->())?) {
        // Create an alert controller
        let alertController = UIAlertController(title: "เพิ่มลิงค์", message: nil, preferredStyle: .alert)
        
        // Add a text field to the alert controller
        alertController.addTextField { (textField) in
            textField.placeholder = "https://www.abc.com"
            textField.text = setupText
        }
        
        // Add actions to the alert controller
        let cancelAction = UIAlertAction(title: "ยกเลิก", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let okayAction = UIAlertAction(title: "ตกลง", style: .default) { (_) in
            // Handle okay action, for example, get the text from the text field
            if let textField = alertController.textFields?.first, 
                let text = textField.text {
                completionHandler?(text)
            }
            
            focus()
        }
        alertController.addAction(okayAction)
        
        guard let root = UIApplication.shared.currentWindow?.rootViewController
        else { return }
        
        // Present the alert controller
        root.present(alertController, animated: true, completion: nil)
    }
    
    private func alertEditLink(completionHandler: ((Int)->())?) {
        // Create an alert controller
        let alertController = UIAlertController(title: "ตั้งค่า", message: nil, preferredStyle: .actionSheet)
        
        // Add an action (button)
        alertController.addAction(UIAlertAction(title: "เปิดลิงค์", style: .default, handler: {_ in
            completionHandler?(0)
        }))
        
        // Add an action (button)
        alertController.addAction(UIAlertAction(title: "แก้ไข", style: .default, handler: {_ in
            completionHandler?(1)
        }))
        
        // Add an action (button)
        alertController.addAction(UIAlertAction(title: "ลบ", style: .default, handler: {_ in
            completionHandler?(2)
        }))
        
        // Add an action (button)
        alertController.addAction(UIAlertAction(title: "ยกเลิก", style: .cancel, handler: nil))
        
        guard let root = UIApplication.shared.currentWindow?.rootViewController
        else { return }
        
        // Present the alert controller
        root.present(alertController, animated: true, completion: nil)
    }
}

extension QuillEditorWebView: QuillEditorBase {
   
}

extension QuillEditorWebView {
    public class Coordinator: NSObject {
       
        let parent: QuillEditorWebView
        
        init(parent: QuillEditorWebView) {
            self.parent = parent
        }
       
    }
}

extension QuillEditorWebView.Coordinator: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.parent.updateHeight()
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
      
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == WKNavigationType.linkActivated,
              var url = navigationAction.request.url else {
            decisionHandler(WKNavigationActionPolicy.allow)
            return
        }
    
        if url.scheme == nil {
            guard let httpsURL = URL(string: "https://\(url.absoluteString)") else {
                decisionHandler(WKNavigationActionPolicy.cancel)
                return
            }
            url = httpsURL
        }
        
        let root = UIApplication.shared.currentWindow?.rootViewController
        root?.present(SFSafariViewController(url: url), animated: true, completion: nil)
        
        decisionHandler(WKNavigationActionPolicy.cancel)
    }
}

//https://stackoverflow.com/a/58001395
class RichEditorWebView: WKWebView {

    var accessoryView: UIView?

    var didReceive: ((_ message: WKScriptMessage)->())?
    
    override var inputAccessoryView: UIView? {
        // remove/replace the default accessory view
        return accessoryView
    }
    
    init() {
        let contentController = WKUserContentController()
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        super.init(frame: .zero, configuration: config)
        
        contentController.add(self, name: "textDidChange")
        contentController.add(self, name: "editLink")
        contentController.add(self, name: "log")
        contentController.add(self, name: "heightDidChange")
        contentController.add(self, name: "currentFormat")
        
        //https://stackoverflow.com/a/63136483
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RichEditorWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        didReceive?(message)
    }
}

//https://stackoverflow.com/a/77775004
class AccessoryInputView<AccessoryContent: View>: UIInputView {
    private let controller: UIHostingController<AccessoryContent>
    
    init(_ accessoryViewBuilder: () -> AccessoryContent ) {
        controller = UIHostingController<AccessoryContent>(rootView: accessoryViewBuilder())
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 44), inputViewStyle: .default)
        
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = UIColor.clear
        addSubview(controller.view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var safeAreaInsets: UIEdgeInsets {
        .zero
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalTo: controller.view.widthAnchor),
            heightAnchor.constraint(equalTo: controller.view.heightAnchor),
            centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
        ])
    }
}
