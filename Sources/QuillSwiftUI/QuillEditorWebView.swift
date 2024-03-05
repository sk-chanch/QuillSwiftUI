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

public struct QuillEditorWebView: UIViewRepresentable {
    let webView = RichEditorWebView()
    
    let placeholder: String
    
    @Binding var dynamicHeight: CGFloat
    @Binding var text: String
    
    public var customFont: UIFont?
    public var onTextChange: ((String)->())?
    
    public init(placeholder: String,
                dynamicHeight: Binding<CGFloat>,
                text: Binding<String>) {
        self.placeholder = placeholder
        self._dynamicHeight = dynamicHeight
        self._text = text
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
                    } else {
                        alertInsertLink(setupText: url.absoluteString, completionHandler: {
                            replaceLink(url: $0)
                        })
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
        webView.loadHTMLString(generateHTML(), baseURL: Bundle.main.bundleURL)
    }

    private func settingWebView(context: Context) {
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        
       
        webView.accessoryView = AccessoryInputView {
            HStack(spacing: 10){
                Button(action: {
                    formatText(style: "bold")
                }, label: {
                    Image(systemName: "bold")
                })
                
                Button(action: {
                    formatText(style: "italic")
                }, label: {
                    Image(systemName: "italic")
                })
                
                Button(action: {
                    formatText(style: "strike")
                }, label: {
                    Image(systemName: "strikethrough")
                })
                
                Button(action: {
                    formatText(style: "underline")
                }, label: {
                    Image(systemName: "underline")
                })
                
                Button(action: {
                    checkLink(completionHandler: { link in
                        alertInsertLink(setupText: link == "false" ? "" : link ?? "", completionHandler: {
                            if link == "false" {
                                insertLink(url: $0)
                            } else {
                                replaceLink(url: $0)
                            }
                        })
                    })
                }, label: {
                    Image(systemName: "link")
                })
                
                Button(action: {
                    toggleList()
                }, label: {
                    Image(systemName: "list.bullet")
                })
                
                Button(action: {
                    toggleListOrder()
                }, label: {
                    Image(systemName: "list.number")
                })
                
                Spacer()
                
                Button(action: {
                    undo()
                }, label: {
                    Image(systemName: "arrow.uturn.backward")
                })
                
                Button(action: {
                    redo()
                }, label: {
                    Image(systemName: "arrow.uturn.forward")
                })
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.white)
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

extension QuillEditorWebView {
    func formatText(style: String) {
        let script = """
 var range = quill.getSelection();
    if (range) {
        var format = quill.getFormat(range);
        if (format['\(style)'] === true) {
            // If the formatting is already applied, remove it
            quill.formatText(range.index, range.length, '\(style)', false);
        } else {
            // If the formatting is not applied, apply it
            quill.formatText(range.index, range.length, '\(style)', true);
        }
    }
"""
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func insertLink(url: String) {
        guard url.count > 0
        else { return }
     
        let script = """
               var range = quill.getSelection();
                        
               // Format the text range as a link
               if (range.length > 0) {
                   quill.formatText(range.index, range.length, 'link', '\(url)');
               } else {
                  var length = quill.getLength();
                  quill.insertText(length - 1, '\(url)', 'link', '\(url)');
               }

               window.webkit.messageHandlers.textDidChange.postMessage(quill.root.innerHTML);
        """
        
        webView.evaluateJavaScript(script, completionHandler: nil)
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
    
    
    func toggleList() {
        let jsCode = """
 var index = quill.getSelection().index || 0;
            quill.insertText(index, '\\n'); // Insert a newline before creating the list
            quill.formatLine(index + 1, 1, 'list', 'bullet'); // Format the line as a bullet list item
"""
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    func toggleListOrder() {
        let jsCode = """
 var index = quill.getSelection().index || 0;
            quill.insertText(index, '\\n'); // Insert a newline before creating the list
            quill.formatLine(index + 1, 1, 'list', 'ordered'); // Format the line as a bullet list item
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
    
    func setHTML() {
        let js = "quill.clipboard.dangerouslyPasteHTML('\(text)');"
        webView.evaluateJavaScript(js, completionHandler: { _,_ in
            UIApplication.shared.endEdit()
        })
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
                      <div id="editor"></div>
                  </BODY>
                  <!-- Include the Quill library -->
                  <script src="https://cdn.jsdelivr.net/npm/quill@2.0.0-rc.2/dist/quill.js"></script>
                  
                  <!-- Initialize Quill editor -->
                  <script>
                      const toolbarOptions = [];
                      var savedRange = null;
                    
                        
                      const quill = new Quill('#editor', {
                          theme: 'snow',
                          modules: {
                              toolbar: false
                          },
                          placeholder: '\(placeholder)'
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
                        var element = document.querySelector('div.ql-editor');
                        var height = element.scrollHeight;
                        window.webkit.messageHandlers.heightDidChange.postMessage(height);
                      }
              
                      quill.on('text-change', function(delta, oldDelta, source) {
                           window.webkit.messageHandlers.textDidChange.postMessage(quill.root.innerHTML);
                            
                           var length = quill.getText().trim().length;
                           if (length === 0) {
                              window.webkit.messageHandlers.heightDidChange.postMessage(0);
                           } else {
                              updateHeight();
                           }
                      });
              
                      function closeLinkTooltip() {
                        var tooltip = document.querySelector('.ql-tooltip');
                        if (tooltip) {
                          tooltip.style.display = 'none';
                        }
                      }
              
                      quill.on('selection-change', function(range, oldRange, source) {
                          if (range) {
                              var formats = quill.getFormat(range.index, range.length);
              
                              if (formats && formats.link) {
                                  savedRange = range;
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
              </HTML>

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
        
        var isFirstUpdate = true
        
        init(parent: QuillEditorWebView) {
            self.parent = parent
        }
       
    }
}

extension QuillEditorWebView.Coordinator: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isFirstUpdate, !parent.text.isEmpty {
            parent.setHTML()
            isFirstUpdate = false
        }
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
      
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == WKNavigationType.linkActivated,
              var url = navigationAction.request.url else {
            decisionHandler(WKNavigationActionPolicy.allow)
            return
        }
        
        print("Clicked URL: \(url)")
        
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
