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
