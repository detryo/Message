//
//  ViewController.swift
//  Messenger
//
//  Created by Cristian Sedano Arenas on 03/11/2020.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

struct Conversation {
    
    let id: String
    let name: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    
    let date: String
    let messageText: String
    let isRead: Bool
}

class ConversationsVC: UIViewController {
    
    private var loginObserver: NSObjectProtocol?
    private let spinner = JGProgressHUD(style: .dark)
    private var conversations = [Conversation]()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(ConversationCell.self, forCellReuseIdentifier: Identifiers.ConversationCell)
        return tableView
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Conversations"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                            target: self,
                                                            action: #selector(didTapComposeButton))
        
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setupTableView()
        fetchConversations()
        startListenerForConversations()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: { [weak self] _ in
            
            guard let strongSelf = self else {
                return
            }

            strongSelf.startListenerForConversations()
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        validateAuth()
    }
    
    private func startListenerForConversations() {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        print("Start conversation fetch...")
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        DatabaseManager.shared.getAllConversations(for: safeEmail, completion: { [weak self] result in
            
            switch result {
            case .success(let conversations):
                print("successfully got conversation model")
                guard !conversations.isEmpty else {
                    return
                }
                
                self?.conversations = conversations
                
                DispatchQueue.main.async {
                    
                    self?.tableView.reloadData()
                }
                
            case .failure(let error):
                print("failed to get conversation: \(error)")
            }
        })
    }
    
    @objc private func didTapComposeButton() {
        
        let newConversationVC = NewConversationVC()
        
        newConversationVC.complition = { [weak self] result in
            print("\(result)")
            
            guard let strongSelf = self else {
                return
            }
            
            let currentConversation = strongSelf.conversations
            
            if let targetConversation = currentConversation.first(where: {
                
                $0.otherUserEmail == DatabaseManager.safeEmail(emailAddress: result.email)
                
            }) {
                let chatVC = ChatVC(with: targetConversation.otherUserEmail, id: targetConversation.id)
                chatVC.isNewConversation = false
                chatVC.title = targetConversation.name
                chatVC.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(chatVC, animated: true)
                
            } else {
                strongSelf.createNewConversation(result: result)
            }
        }
        
        let navigationController = UINavigationController(rootViewController: newConversationVC)
        present(navigationController, animated: true)
    }
    
    private func createNewConversation(result: SearchResults) {
        
        let name = result.name
        let email = DatabaseManager.safeEmail(emailAddress: result.email)
        
        // check in database if conversation with these two users exists
        // if it does, reuse conversation id
        // otherwise use existing code
        DatabaseManager.shared.conversationExists(witch: email, completion: { [weak self] result in
            
            guard let strongSelf = self else {
                return
            }
            
            switch result {
            case .success(let conversationId):
                let chatVC = ChatVC(with: email, id: conversationId)
                chatVC.isNewConversation = false
                chatVC.title = name
                chatVC.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(chatVC, animated: true)
                
            case .failure(_):
                let chatVC = ChatVC(with: email, id: nil)
                chatVC.isNewConversation = true
                chatVC.title = name
                chatVC.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(chatVC, animated: true)
            }
        })
    }
    
    private func validateAuth() {
        
        if FirebaseAuth.Auth.auth().currentUser == nil {
            
            let viewController = LoginVC()
            let nav = UINavigationController(rootViewController: viewController)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false, completion: nil)
        }
    }
    
    private func setupTableView() {
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func fetchConversations() {
        
        tableView.isHidden = false
    }
}

extension ConversationsVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let model = conversations[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.ConversationCell,
                                                 for: indexPath) as! ConversationCell
        
        cell.configure(with: model)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversation(model)
    }
    
    func openConversation(_ model: Conversation) {
        
        let chatVC = ChatVC(with: model.otherUserEmail, id: model.id)
        chatVC.title = model.name
        chatVC.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(chatVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 100
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            // begin delete
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            
            DatabaseManager.shared.deleteConversation(conversationId: conversationId, completion: { [weak self] success in
                
                if success {
                    self?.conversations.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .left)
                }
            })
            tableView.endUpdates()
        }
    }
}
