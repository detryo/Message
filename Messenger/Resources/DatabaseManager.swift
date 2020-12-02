//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Cristian Sedano Arenas on 09/11/2020.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

struct ChatAppUser {
    
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
// MARK: - Account Management
extension DatabaseManager {
    
    public func userExists(with email: String, complition: @escaping ((Bool) -> Void)) {
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            
            guard snapshot.value as? String != nil else {
                complition(false)
                return
            }
            complition(true)
        })
    }
    
    /// Insert new users to  database
    public func insertUser(with user: ChatAppUser, complition: @escaping (Bool) -> Void) {
        
        database.child(user.safeEmail).setValue(["first_name": user.firstName, "last_name": user.lastName], withCompletionBlock: { error, _ in
            
            guard error == nil else {
                print("failed to write to database")
                complition(false)
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                
                if var usersCollection = snapshot.value as? [[String : String]] {
                    // Append to user dictionary
                    let newElement = ["name": user.firstName + " " + user.lastName,
                                      "email": user.safeEmail]
                    
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        
                        guard error == nil else {
                            complition(false)
                            return
                        }
                        complition(true)
                    })
                    
                } else {
                    // Create that array
                    let newCollection: [[String : String]] = [["name": user.firstName + " " + user.lastName,
                                                               "email": user.safeEmail]]
                    
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        
                        guard error == nil else {
                            complition(false)
                            return
                        }
                        complition(true)
                    })
                }
            })
        })
    }
    
    public func getAllUsers(complition: @escaping (Result<[[String : String]], Error>) -> Void) {
        
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            
            guard let value = snapshot.value as? [[String : String]] else {
                
                complition(.failure(DatabaseError.failedToFetch))
                return
            }
            complition(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        
        case failedToFetch
    }
}

// MARK: - Sending messages / conversation
extension DatabaseManager {
    
    /// Create a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String,
                                           firstMessage: Message,
                                           complition: @escaping (Bool) -> Void) {
        
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value, with: { snapshot in
            
            guard var userNode = snapshot.value as? [String : Any] else{
                
                complition(false)
                print("user not found")
                return
            }
            
            let messageData = firstMessage.sentDate
            let dataString = ChatVC.dateFormatter.string(from: messageData)
            
            var message = ""
            
            switch firstMessage.kind {
            
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String : Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "latest_message": [
                    "date": dataString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            if var conversations = userNode["conversations"] as? [[String : Any]] {
                
                // conversations array exits for current user
                // you should append
                conversations.append(newConversationData)
                
                userNode["conversations"] = conversations
                
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    
                    guard error == nil else {
                        complition(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID,
                                                    firstMessage: firstMessage,
                                                    complition: complition)
                })
                
            } else {
                // Conversation array doesn't exist
                // create it
                userNode["conversations"] = [ newConversationData ]
                
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    
                    guard error == nil else {
                        complition(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID,
                                                    firstMessage: firstMessage,
                                                    complition: complition)
                })
            }
        })
        
    }
    // nueva funcion
    private func finishCreatingConversation(conversationID: String,
                                            firstMessage: Message,
                                            complition: @escaping (Bool) -> Void) {
        
        let messageData = firstMessage.sentDate
        let dataString = ChatVC.dateFormatter.string(from: messageData)
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String  else {
            
            complition(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        var message = ""
        
        switch firstMessage.kind {
        
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let collectionMessage: [String : Any] = [ "id": firstMessage.messageId,
                                        "type": firstMessage.kind.messageKindString,
                                        "content": message,
                                        "date": dataString,
                                        "sender_email": currentUserEmail,
                                        "is_read": false
        ]
        
        let value: [String : Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        print("adding conversation: \(conversationID)")
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
            
            guard error == nil else {
                complition(false)
                return
            }
            complition(true)
        })
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, complition: @escaping (Result<String, Error>) -> Void) {
        
        
    }
    /// Get all messages  for a given conversation
    public func getAllMessagesForConversation(with id: String, complition: @escaping (Result<String, Error>) -> Void) {
        
        
    }
    /// Send a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, complition: @escaping (Bool) -> Void) {
        
        
    }
}
