
import Firebase
import MessageKit
import FirebaseFirestore

struct Message: MessageType {
    
  let kind: MessageKind
  let id: String?
  let content: String
  let sentDate: Date
  let sender: SenderType
  
  var messageId: String {
    return id ?? UUID().uuidString
  }
  
  var image: UIImage? = nil
  var downloadURL: URL? = nil
  
  init(user: User, content: String) {
    sender = Sender(id: user.uid, displayName: AppSettings.displayName)
    self.content = content
    self.kind = .text(content)
    sentDate = Date()
    id = nil
  }
  
  init(user: User, image: UIImage) {
    sender = Sender(id: user.uid, displayName: AppSettings.displayName)
    self.image = image
    content = ""
    self.kind = .text(content)
    sentDate = Date()
    id = nil
  }
  
  init?(document: QueryDocumentSnapshot) {
    let data = document.data()
    guard let timestamp = data["created"] as? Timestamp else {
      return nil
    }
    guard let senderID = data["senderID"] as? String else {
      return nil
    }
    guard let senderName = data["senderName"] as? String else {
      return nil
    }
    
    id = document.documentID
    
    self.sentDate = timestamp.dateValue()
    sender = Sender(id: senderID, displayName: senderName)
    
    if let content = data["content"] as? String {
      self.content = content
      downloadURL = nil
    } else if let urlString = data["url"] as? String, let url = URL(string: urlString) {
      downloadURL = url
      content = ""
    } else {
      return nil
    }
    self.kind = .text(content)
  }
  
}

extension Message: DatabaseRepresentation {
  
  var representation: [String : Any] {
    var rep: [String : Any] = [
      "created": sentDate,
      "senderID": sender.senderId,
      "senderName": sender.displayName
    ]
    
    if let url = downloadURL {
      rep["url"] = url.absoluteString
    } else {
      rep["content"] = content
    }
    
    return rep
  }
  
}

extension Message: Comparable {
  
  static func == (lhs: Message, rhs: Message) -> Bool {
    return lhs.id == rhs.id
  }
  
  static func < (lhs: Message, rhs: Message) -> Bool {
    return lhs.sentDate < rhs.sentDate
  }
  
}
