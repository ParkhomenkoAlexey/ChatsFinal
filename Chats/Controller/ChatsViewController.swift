//
//  ChatsViewController.swift
//  Chats
//
//  Created by Алексей Пархоменко on 21.01.2020.
//  Copyright © 2020 Алексей Пархоменко. All rights reserved.
//

import Foundation
import UIKit
import MessageKit
import FirebaseFirestore
import InputBarAccessoryView
import Photos

class ChatsViewController: MessagesViewController {
    
    private var isSendingPhoto = false {
      didSet {
        DispatchQueue.main.async {
            self.messageInputBar.leftStackViewItems.forEach { (item) in
                item.inputBarAccessoryView?.isUserInteractionEnabled = !self.isSendingPhoto
            }
        }
      }
    }
    
    private let user: MUser
    private let chat: MChat
    
    init(user: MUser, chat: MChat) {
        self.user = user
        self.chat = chat
        super.init(nibName: nil, bundle: nil)
        
        title = chat.friendUsername
    }
    
    private var messages: [MMessage] = []
    private var messageListener: ListenerRegistration?
    
    let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    deinit {
      messageListener?.remove()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // убираем avatarVIew
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.textMessageSizeCalculator.incomingAvatarSize = .zero
            layout.photoMessageSizeCalculator.incomingAvatarSize = .zero
            layout.photoMessageSizeCalculator.outgoingAvatarSize = .zero
        }
        
        messagesCollectionView.backgroundColor = .mainWhite()
        
        maintainPositionOnKeyboardFrameChanged = true
        configureMessageInputBar()
        
        messageInputBar.delegate = self
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        
        messageListener = ListenerService.shared.messagesObserve(chat: chat, completion: { (result) in
            switch result {
            case .success(var message):
                if let url = message.downloadURL {
                    StorageService.shared.downloadImage(url: url) { [weak self] (result) in
                        guard let self = self else { return }
                        switch result {
                        case .success(let image):
                            message.image = image
                            self.insertNewMessage(message: message)
                        case .failure(let error):
                            self.showAlert(with: "Ошибка!", and: error.localizedDescription)
                        }
                    }
                } else {
                    self.insertNewMessage(message: message)
                }
                
            case .failure(let error):
                self.showAlert(with: "Ошибка!", and: error.localizedDescription)
            }
        })
    }
    
    //MARK: - Business Logic
    
    private func insertNewMessage(message: MMessage) {
        guard !messages.contains(message) else { return }
        
        messages.append(message)
        messages.sort()
        
        let isLatestMessage = messages.firstIndex(of: message) == (messages.count - 1)
        let shouldScrollToBottom = messagesCollectionView.isAtBottom && isLatestMessage
        
        messagesCollectionView.reloadData()
        
        if shouldScrollToBottom {
            DispatchQueue.main.async {
                self.messagesCollectionView.scrollToBottom(animated: true)
            }
        }
    }
    
    private func sendPhoto(image: UIImage) {
        isSendingPhoto = true
        
        StorageService.shared.uploadImageMessage(photo: image, to: chat) { [weak self] (result) in
            guard let self = self else { return }
            self.isSendingPhoto = false
            switch result {
                
            case .success(let url):
                var message = MMessage(user: self.user, image: image)
                message.downloadURL = url
                
                FirestoreService.shared.sendMessage(chat: self.chat, message: message) { (result) in
                    switch result {
                        case .success:
                            self.messagesCollectionView.scrollToBottom()
//                        self.showAlert(with: "Успешно!", and: "Изображение доставлено.")
                        case .failure(_):
                            self.showAlert(with: "Ошибка!", and: "Изображение не доставлено")
                    }
                }
            case .failure(let error):
                self.showAlert(with: "Ошибка!", and: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Actions

    @objc private func cameraButtonPressed() {
      let picker = UIImagePickerController()
      picker.delegate = self

      if UIImagePickerController.isSourceTypeAvailable(.camera) {
        picker.sourceType = .camera
      } else {
        picker.sourceType = .photoLibrary
      }

      present(picker, animated: true, completion: nil)
    }
}


// MARK: - ConfigureMessageInputBar
extension ChatsViewController {
    func configureMessageInputBar() {

        messageInputBar.isTranslucent = true
        messageInputBar.separatorLine.isHidden = true
        messageInputBar.backgroundView.backgroundColor = .mainWhite()
        messageInputBar.inputTextView.backgroundColor = .white
        messageInputBar.inputTextView.placeholderTextColor = #colorLiteral(red: 0.7411764706, green: 0.7411764706, blue: 0.7411764706, alpha: 1)
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 14, left: 30, bottom: 14, right: 36)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 14, left: 36, bottom: 14, right: 36)
        messageInputBar.inputTextView.layer.borderColor = #colorLiteral(red: 0.7411764706, green: 0.7411764706, blue: 0.7411764706, alpha: 0.4033635232)
        messageInputBar.inputTextView.layer.borderWidth = 0.2
        messageInputBar.inputTextView.layer.cornerRadius = 18.0
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        
        
        messageInputBar.layer.shadowColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        messageInputBar.layer.shadowRadius = 5
        messageInputBar.layer.shadowOpacity = 0.3
        messageInputBar.layer.shadowOffset = CGSize(width: 0, height: 4)
        configureSendButton()
        configureCameraIcon()
    }
    
    func configureSendButton() {
        messageInputBar.sendButton.setImage(UIImage(named: "Sent"), for: .normal)
        messageInputBar.sendButton.applyGradients(cornerRadius: 10)
        messageInputBar.setRightStackViewWidthConstant(to: 56, animated: false)
        messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 6, right: 30)
        messageInputBar.sendButton.setSize(CGSize(width: 48, height: 48), animated: false)
        messageInputBar.middleContentViewPadding.right = -38
    }
    
    func configureCameraIcon() {
        let cameraItem = InputBarButtonItem(type: .system)
        cameraItem.tintColor = #colorLiteral(red: 0.7882352941, green: 0.631372549, blue: 0.9411764706, alpha: 1)
        let cameraImage = UIImage(systemName: "camera")!
        cameraItem.image = cameraImage
        
        cameraItem.addTarget(
          self,
          action: #selector(cameraButtonPressed),
          for: .primaryActionTriggered
        )
        cameraItem.setSize(CGSize(width: 60, height: 30), animated: false)

        messageInputBar.leftStackView.alignment = .center
        messageInputBar.setLeftStackViewWidthConstant(to: 50, animated: false)

        messageInputBar.setStackViewItems([cameraItem], forStack: .left, animated: false)
    }
}

// MARK: - MessagesDataSource
extension ChatsViewController: MessagesDataSource {
    func currentSender() -> SenderType {
        return Sender(senderId: user.identifier, displayName: user.username)
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.item]
    }
    
    func numberOfItems(inSection section: Int, in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return 1
    }
    
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if indexPath.item % 4 == 0 {
            return NSAttributedString(string: MessageKitDateFormatter.shared.string(from: message.sentDate), attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
        }
        return nil
    }
}

// MARK: - MessagesLayoutDelegate
extension ChatsViewController: MessagesLayoutDelegate {
    
    func footerViewSize(for section: Int, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return CGSize(width: 0, height: 8)
    }
    
    func heightForLocation(message: MessageType, at indexPath: IndexPath, with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 0
    }
    
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if (indexPath.item) % 4 == 0 {
            return 30
        }
        return 0
    }
}

// MARK: - MessagesDisplayDelegate
extension ChatsViewController: MessagesDisplayDelegate {
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : #colorLiteral(red: 0.7882352941, green: 0.631372549, blue: 0.9411764706, alpha: 1)
    }
    
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? #colorLiteral(red: 0.2392156863, green: 0.2392156863, blue: 0.2392156863, alpha: 1) : .white
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        avatarView.isHidden = true
        
    }
    
    func headerViewSize(for section: Int, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return .zero
    }
     
    
    func avatarSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return .zero
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {

        return .bubble
    }
    
}

// MARK: - InputBarAccessoryViewDelegate
extension ChatsViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        let message = MMessage(user: user, content: text)
        FirestoreService.shared.sendMessage(chat: chat, message: message) { (result) in
            switch result {
            case .success:
                self.messagesCollectionView.scrollToBottom()
            case .failure(let error):
                self.showAlert(with: "Ошибка!", and: error.localizedDescription)
            }
        }
        
        inputBar.inputTextView.text = ""
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ChatsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
      picker.dismiss(animated: true, completion: nil)
      
    
      if let asset = info[.phAsset] as? PHAsset {
        let size = CGSize(width: 500, height: 500)
        PHImageManager.default().requestImage(
          for: asset,
          targetSize: size,
          contentMode: .aspectFit,
          options: nil) { result, info in
            
          guard let image = result else {
            return
          }
          
            self.sendPhoto(image: image)
        }

      } else if let image = info[.originalImage] as? UIImage {
        sendPhoto(image: image)
      }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - SwiftUI
import SwiftUI
struct ChatsProvider: PreviewProvider {
    static var previews: some View {
        ContainterView().edgesIgnoringSafeArea(.all)
    }
    
    struct ContainterView: UIViewControllerRepresentable {
        
        let chatsVC: ChatsViewController = ChatsViewController(
            user: MUser(username: "Abla",avatarStringURL: "human1", email: "3232", description: "3232", sex: "male"),
            chat: MChat(friendUsername: "ffrfr", friendAvatarStringURL: "fefe", friendIdentifier: "fefe", lastMessageContent: "fdf"))
        func makeUIViewController(context: UIViewControllerRepresentableContext<ChatsProvider.ContainterView>) -> ChatsViewController {
            return chatsVC
        }
        
        func updateUIViewController(_ uiViewController: ChatsProvider.ContainterView.UIViewControllerType, context: UIViewControllerRepresentableContext<ChatsProvider.ContainterView>) {
            
        }
    }
}
