//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Cristian Sedano Arenas on 09/11/2020.
//

import Foundation
import FirebaseDatabase

/// Manager object to read and write data to real time firebase database
final class DatabaseManager {
    
    /// Shared instance of classextension DatabaseManager
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
    
    /// Checks if user exists for given email
    /// Parameters
    /// - `email`:              Target email to be checked
    /// - `completion`:   Async closure to return with result
    public func userExists(with email: String, complition: @escaping ((Bool) -> Void)) {
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
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
        
        database.child(user.safeEmail).setValue(["first_name": user.firstName, "last_name": user.lastName], withCompletionBlock: { [weak self] error, _ in
            
            guard let strongSelf = self else {
                return
            }
            
            guard error == nil else {
                print("failed to write to database")
                complition(false)
                return
            }
            
            strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                
                if var usersCollection = snapshot.value as? [[String : String]] {
                    // Append to user dictionary
                    let newElement = ["name": user.firstName + " " + user.lastName,
                                      "email": user.safeEmail]
                    
                    usersCollection.append(newElement)
                    
                    strongSelf.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        
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
                    
                    strongSelf.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        
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
                                      name: String,
                                      firstMessage: Message,
                                      complition: @escaping (Bool) -> Void) {
        
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            
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
                "name": name,
                "latest_message": [
                    "date": dataString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String : Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "name": "Self",
                "latest_message": [
                    "date": dataString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            // Update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                
                if var conversations = snapshot.value as? [[String : Any]] {
                    // append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue([conversations])
                } else {
                    // create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            
            // Update current user conversation entry
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
                    self?.finishCreatingConversation(name: name,
                                                     conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: complition)
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
                    self?.finishCreatingConversation(name: name,
                                                     conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: complition)
                })
            }
        })
        
    }
    // nueva funcion
    private func finishCreatingConversation(name: String,
                                            conversationID: String,
                                            firstMessage: Message,
                                            completion: @escaping (Bool) -> Void) {
        
        let messageData = firstMessage.sentDate
        let dataString = ChatVC.dateFormatter.string(from: messageData)
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String  else {
            
            completion(false)
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
                                        "is_read": false,
                                        "name": name
        ]
        
        let value: [String : Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        print("adding conversation: \(conversationID)")
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
            
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            
            guard let value = snapshot.value as? [[String: Any]] else{
                
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                    let name = dictionary["name"] as? String,
                    let otherUserEmail = dictionary["other_user_email"] as? String,
                    let latestMessage = dictionary["latest_message"] as? [String: Any],
                    let date = latestMessage["date"] as? String,
                    let message = latestMessage["message"] as? String,
                    let isRead = latestMessage["is_read"] as? Bool else {
                        return nil
                }

                let latestMmessageObject = LatestMessage(date: date,
                                                         messageText: message,
                                                         isRead: isRead)
                return Conversation(id: conversationId,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMmessageObject)
            })

            completion(.success(conversations))
        })
    }
    
    /// Get all messages  for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            
            guard let value = snapshot.value as? [[String: Any]] else{
                
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            let messages: [Message] = value.compactMap({ dictionary in
               
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatVC.dateFormatter.date(from: dateString) else {
                    return nil
                }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: .text(content))
            })

            completion(.success(messages))
        })
    }
    /// Send a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, complition: @escaping (Bool) -> Void) {
        
        
    }
}
