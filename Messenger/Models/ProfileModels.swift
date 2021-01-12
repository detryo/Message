//
//  ProfileModels.swift
//  Messenger
//
//  Created by Cristian Sedano Arenas on 12/01/2021.
//

import Foundation

enum ProfileViewModelType {
    case info, logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
