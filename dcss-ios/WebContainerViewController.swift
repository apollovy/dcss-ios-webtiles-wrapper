//
//  WebContainerViewController.swift
//  dcss-ios
//
//  Created by Jonathan Lazar on 11/25/21.
//

import UIKit
import WebKit

final class WebContainerViewController: UIViewController, UITextFieldDelegate {

    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    private let serverURL: URL
    
    private let webView = WKWebView()
    private let invisibleTextField = UITextField()
    private var keyCommandView: UIView?
    
    private var keyCommandViewConstraints = [NSLayoutConstraint]()
    
    private var defaultScrollViewBottomContentInset: CGFloat {
        KeyCommandsView.LayoutConstants.height
    }

    init(serverURL: URL) {
        self.serverURL = serverURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        invisibleTextField.delegate = self
        invisibleTextField.autocorrectionType = .no
        invisibleTextField.autocapitalizationType = .none
        invisibleTextField.inputAssistantItem.leadingBarButtonGroups = []
        invisibleTextField.inputAssistantItem.trailingBarButtonGroups = []

        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: defaultScrollViewBottomContentInset, right: 0)
        
        layoutViews()
        attachChildViewControllers()
        configureKeyboardObservations()

        webView.load(URLRequest(url: serverURL))
    }
    
    @objc func sendCommand() {
        invisibleTextField.becomeFirstResponder()
    }
    
    private func layoutViews() {
        webView
            .addAsSubview(to: view)
        constraintWebView()

        invisibleTextField
            .addAsSubview(to: view)
    }
    
    private func constraintWebView() {
        guard let superview = webView.superview else {
            return
        }
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            webView.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor),
            webView.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -defaultScrollViewBottomContentInset)
        ])
    }
    
    private func attachChildViewControllers() {
        let kcvc = KeyCommandsViewController(onKeyCommandTapped: { [weak self] keyCommand in
            self?.webView.evaluateJavaScript(keyCommand.executableJavascript)
            
            // it's nicer to automatically enter text and press enter to avoid auto magnification problems
            if keyCommand.id == KeypressWithControlCommand.f.id {
                let alertController = UIAlertController(title: "Search for what?", message: nil, preferredStyle: .alert)
                alertController.addTextField()
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    let script = JSBridge.cancelFind()
                    self?.webView.evaluateJavaScript(script)
                }
                let okAction = UIAlertAction(title: "Search", style: .default) { [weak alertController] _ in
                    if let text = alertController?.textFields?.first?.text {
                        let script = JSBridge.enterTextInFindAndPressEnter(text)
                        self?.webView.evaluateJavaScript(script)
                    }
                }
                alertController.addAction(cancelAction)
                alertController.addAction(okAction)
                self?.present(alertController, animated: true)
            }
        }, onKeyboardTapped: { [weak self] in
            guard let self = self else {
                return
            }
            if self.invisibleTextField.isFirstResponder {
                self.invisibleTextField.resignFirstResponder()
            } else {
                self.invisibleTextField.becomeFirstResponder()
            }
        })
        let kcView = kcvc.view!
        keyCommandView = kcView
        
        kcvc.willMove(toParent: self)
        addChild(kcvc)
        kcView.addAsSubview(to: view)
        kcView.translatesAutoresizingMaskIntoConstraints = false
        configureKeyCommandViewConstraints(keyboardVisible: false)
        kcvc.didMove(toParent: self)
    }
    
    private func configureKeyCommandViewConstraints(keyboardVisible: Bool, keyboardHeight: CGFloat = 0) {
        guard let kcView = keyCommandView else {
            return
        }
        
        NSLayoutConstraint.deactivate(keyCommandViewConstraints)
        defer { NSLayoutConstraint.activate(keyCommandViewConstraints) }

        if keyboardVisible {
            keyCommandViewConstraints = [
                kcView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                kcView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                kcView.topAnchor.constraint(equalTo: webView.bottomAnchor),
                kcView.heightAnchor.constraint(equalToConstant: KeyCommandsView.LayoutConstants.height)
            ]
        } else {
            keyCommandViewConstraints = [
                kcView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                kcView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                kcView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -KeyCommandsView.LayoutConstants.height),
                kcView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
        }
    }
    
    private func configureKeyboardObservations() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        guard
            let curve = notification.keyboardAnimationCurve,
            let duration = notification.keyboardAnimationDuration,
            let keyboardHeight = notification.keyboardHeight else {
                return
            }

        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: curve
        ) {
            self.view?.frame = CGRect(x: self.view.frame.origin.x, y: self.view.frame.origin.y, width: self.view.window!.frame.width, height: self.view.window!.frame.height - keyboardHeight)
            self.webView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height - self.defaultScrollViewBottomContentInset)
            self.configureKeyCommandViewConstraints(keyboardVisible: true, keyboardHeight: keyboardHeight)
            self.view?.layoutIfNeeded()
        }
        
        animator.startAnimation()
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        guard
            let curve = notification.keyboardAnimationCurve,
            let duration = notification.keyboardAnimationDuration else {
                return
            }

        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: curve
        ) {
            self.view?.frame = self.view.window!.frame
            self.webView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
            self.configureKeyCommandViewConstraints(keyboardVisible: false)
            self.view?.layoutIfNeeded()
        }
        
        animator.startAnimation()
    }
}

// MARK: - UITextFieldDelegate

extension WebContainerViewController {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let script = JSBridge.sendKeyPressed(string)
        webView.evaluateJavaScript(script)
        return false
    }
}

private extension NSNotification {
    var keyboardAnimationCurve: UIView.AnimationCurve? {
        let curveKey = UIResponder.keyboardAnimationCurveUserInfoKey
        guard let curveValue = userInfo?[curveKey] as? Int else {
            return nil
        }
        return UIView.AnimationCurve(rawValue: curveValue)
    }
    
    var keyboardAnimationDuration: Double? {
        let durationKey = UIResponder.keyboardAnimationDurationUserInfoKey
        return userInfo?[durationKey] as? Double
    }
    
    var keyboardHeight: CGFloat? {
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        let keyboardFrameValue = userInfo?[frameKey] as? NSValue
        return keyboardFrameValue?.cgRectValue.height
    }
}
