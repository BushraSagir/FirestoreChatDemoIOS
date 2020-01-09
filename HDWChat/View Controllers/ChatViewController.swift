
import UIKit
import Firebase
import MessageKit
import FirebaseFirestore
import InputBarAccessoryView

final class ChatViewController: MessagesViewController {
  
  private let user: User
  private let channel: Channel
  private var messages: [Message] = []
  private var messageListener: ListenerRegistration?
  private let db = Firestore.firestore()
  private var reference: CollectionReference?

  init(user: User, channel: Channel) {
    self.user = user
    self.channel = channel
    super.init(nibName: nil, bundle: nil)
    
    title = channel.name
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    guard let id = channel.id else {
      navigationController?.popViewController(animated: true)
      return
    }

    reference = db.collection(["channels", id, "thread"].joined(separator: "/"))

    navigationItem.largeTitleDisplayMode = .never
    
    maintainPositionOnKeyboardFrameChanged = true
    messageInputBar.inputTextView.tintColor = .primary
    messageInputBar.sendButton.setTitleColor(.primary, for: .normal)
    
    messageInputBar.delegate = self
    messagesCollectionView.messagesDataSource = self
    messagesCollectionView.messagesLayoutDelegate = self
    messagesCollectionView.messagesDisplayDelegate = self
  
    messageListener = reference?.addSnapshotListener { querySnapshot, error in
      guard let snapshot = querySnapshot else {
        print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
        return
      }
      
      snapshot.documentChanges.forEach { change in
        self.handleDocumentChange(change)
      }
    }

    if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
    layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
    layout.textMessageSizeCalculator.incomingAvatarSize = .zero
    }
  }

  // MARK: - Helpers
  private func save(_ message: Message) {
    reference?.addDocument(data: message.representation) { error in
      if let e = error {
        print("Error sending message: \(e.localizedDescription)")
        return
      }
      
      self.messagesCollectionView.scrollToBottom()
    }
  }

  private func insertNewMessage(_ message: Message) {
    guard !messages.contains(message) else {
      return
    }
    
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

  private func handleDocumentChange(_ change: DocumentChange) {
    guard let message = Message(document: change.document) else {
      return
    }

    switch change.type {
    case .added:
      insertNewMessage(message)

    default:
      break
    }
  }

  deinit {
    messageListener?.remove()
  }
}
// MARK: - MessagesDataSource

extension ChatViewController: MessagesDataSource {
    func currentSender() -> SenderType {
        return Sender(id: user.uid, displayName: AppSettings.displayName)
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
  func messageForItem(at indexPath: IndexPath,
    in messagesCollectionView: MessagesCollectionView) -> MessageType {

    return messages[indexPath.section]
  }

  func cellTopLabelAttributedText(for message: MessageType,
    at indexPath: IndexPath) -> NSAttributedString? {

    let name = message.sender.displayName
    return NSAttributedString(
      string: name,
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .caption1),
        .foregroundColor: UIColor(white: 0.3, alpha: 1)
      ]
    )
  }
}

// MARK: - MessagesLayoutDelegate

extension ChatViewController: MessagesLayoutDelegate {

  func heightForLocation(message: MessageType, at indexPath: IndexPath,
    with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    return 0
  }

    func footerViewSize(for section: Int, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return CGSize(width: 0, height: 8)
    }

    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 10.0
    }

}

// MARK: - MessagesDisplayDelegate

extension ChatViewController: MessagesDisplayDelegate {
  
  func backgroundColor(for message: MessageType, at indexPath: IndexPath,
    in messagesCollectionView: MessagesCollectionView) -> UIColor {
    return isFromCurrentSender(message: message) ? .primary : .incomingMessage
  }

  func shouldDisplayHeader(for message: MessageType, at indexPath: IndexPath,
    in messagesCollectionView: MessagesCollectionView) -> Bool {

    return false
  }

  func messageStyle(for message: MessageType, at indexPath: IndexPath,
    in messagesCollectionView: MessagesCollectionView) -> MessageStyle {

    let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft

    return .bubbleTail(corner, .curved)
  }
}
// MARK: - MessageInputBarDelegate

extension ChatViewController: InputBarAccessoryViewDelegate {
    
 func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {

    let message = Message(user: user, content: text)

    save(message)

    inputBar.inputTextView.text = ""
  }
}

// MARK: - UIImagePickerControllerDelegate

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
}
