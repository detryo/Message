//
//  StorageManager.swift
//  Messenger
//
//  Created by Cristian Sedano Arenas on 17/11/2020.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    
    static let shared = StorageManager()
    private let storage = Storage.storage().reference()
    public typealias UploadPictureComplition = (Result<String, Error>) -> Void
    
    /// Upload picture to firebase storage and return complition with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, complition: @escaping UploadPictureComplition) {
        
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metadata, error in
            
            guard error == nil else {
                // Failed
                print("failed to upload data to firebase for picture")
                complition(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL(completion: { url, error in
                
                guard let url = url else {
                    print("Failed to get download url")
                    complition(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                complition(.success(urlString))
            })
        })
    }
    
    public enum StorageErrors: Error {
        
        case failedToUpload
        case failedToGetDownloadURL
    }
    
    public func downloadURL(for path: String, complition: @escaping (Result<URL, Error>) -> Void) {
        
        let reference = storage.child(path)
        
        reference.downloadURL(completion: { url, error in
            
            guard let url = url, error == nil else {
                complition(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            complition(.success(url))
        })
    }
}
