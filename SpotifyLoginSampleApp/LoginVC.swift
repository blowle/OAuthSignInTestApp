//
//  LoginVC.swift
//  SpotifyLoginSampleApp
//
//  Created by YONGCHEOL LEE on 2021/11/19.
//

import UIKit
import GoogleSignIn
import AuthenticationServices
import FirebaseAuth
import CryptoKit

class LoginVC: UIViewController {
    
    @IBOutlet weak var emailLoginButton: UIButton!
    @IBOutlet weak var googleLoginButton: GIDSignInButton!
    @IBOutlet weak var appleLoginButton: UIButton!
    
    fileprivate var currentNonce: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        [emailLoginButton, googleLoginButton,
         appleLoginButton].forEach {
            $0?.layer.borderWidth = 1
            $0?.layer.borderColor = UIColor.white.cgColor
            $0?.layer.cornerRadius = 30
         }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // hide navigation Bar
        navigationController?.navigationBar.isHidden = true
    }
    
    @IBAction func googleLoginButtonTapped(_ sender: Any) {
        // Google Sign In
        GIDSignIn.sharedInstance.signIn(
            with: (UIApplication.shared.delegate as! AppDelegate).GIDSignInConfig!,
            presenting: self,
            callback: { user, error in
                guard error == nil else {
                    print(error!.localizedDescription)
                    return
                }
                guard let user = user else { return }
                
                user.authentication.do { authentication, error in
                    guard error == nil else {
                        print(error!.localizedDescription)
                        return
                    }
                    guard let authentication = authentication else { return }
                    let idToken = authentication.idToken!
                    let accessToken = authentication.accessToken
                    let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                    
                    Auth.auth().signIn(with: credential) { [weak self] _, _ in
                        self?.showMainViewController()
                    }
                }
            }
        )
    }
    
    @IBAction func appleLoginButtonTapped(_ sender: Any) {
        startSignInWithAppleFlow()
    }
    
    private func showMainViewController() {
        let storyboard  = UIStoryboard(name: "Main", bundle: Bundle.main)
        let mainVC = storyboard.instantiateViewController(identifier: "MainViewController")

        mainVC.modalPresentationStyle = .fullScreen
        UIApplication.shared.windows.first?.rootViewController?.show(mainVC, sender: nil)
    }
}

extension LoginVC: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        /*
         Nonce 란?
         - 암호화된 임의의 난수
         - 단 한번만 사용할 수 있는 값
         - 주로 암호화 통신을 할 때 활용
         - 동일한 요청을 짧은 시간에 여러번 보내는 릴레이 공격 방지
         - 정보 탈취 없이 안전하게 인증 정보 전달을 위한 안전장치.
         */
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error = error {
                    print ("Error Apple sign in: %@", error)
                    return
                }

                self?.showMainViewController()
            }
        }
    }
}

extension LoginVC {
    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        let appleIdProvider = ASAuthorizationAppleIDProvider()
        let request = appleIdProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)

        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}

extension LoginVC : ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}
