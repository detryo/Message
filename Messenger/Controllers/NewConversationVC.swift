//
//  NewConversationVC.swift
//  Messenger
//
//  Created by Cristian Sedano Arenas on 03/11/2020.
//

import UIKit
import JGProgressHUD

class NewConversationVC: UIViewController {
    
    public var complition: ((SearchResults) -> (Void))?
    private let spinner = JGProgressHUD(style: .dark)
    private var users = [[String : String]]()
    private var results = [SearchResults]()
    private var hasFetched = false

    private let searchBar: UISearchBar = {
        let search = UISearchBar()
        search.placeholder = "Search for Useras"
        return search
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(NewConversationCell.self, forCellReuseIdentifier: Identifiers.NewConversationCell)
        return tableView
    }()
    
    private let noResulsLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.text = "No Results"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(noResulsLabel)
        view.addSubview(tableView)
        
        tableView.delegate = self
        tableView.dataSource = self

        searchBar.delegate = self
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = view.bounds
        
        noResulsLabel.frame = CGRect(x: view.width / 4,
                                     y: (view.height - 200) / 2,
                                     width: view.width / 2,
                                     height: 200)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
}

extension NewConversationVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        
        searchBar.resignFirstResponder()
        
        results.removeAll()
        spinner.show(in: view)
        
        searchUsers(query: text)
    }
    
    func searchUsers(query: String) {
        // check if array has firebase result
        if hasFetched {
            // if it does: filter
            filterUsers(with: query)
            
        } else {
            // if not, fetch then filter
            DatabaseManager.shared.getAllUsers(complition: { [weak self] result in
                
                switch result {
                case .success(let userCollections):
                    
                    self?.hasFetched = true
                    self?.users = userCollections
                    self?.filterUsers(with: query)
                    
                case .failure(let error):
                print("Failed to get users: \(error)")
                }
            })
        }
    }
    //
    func filterUsers(with term: String) {
        // update the UI: either show results or show no results
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String, hasFetched else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        self.spinner.dismiss()
        
        let results: [SearchResults] = self.users.filter({
            
            guard let email = $0["email"], email != safeEmail else {
                return false
            }
            
            guard let name = $0["name"]?.lowercased() else {
                return false
            }
            
            return name.hasPrefix(term.lowercased())
            
        }).compactMap({
            
            guard let email = $0["email"],
                  let name = $0["name"] else {
                return nil
            }
            
            return SearchResults(name: name, email: email)
        })
        
        self.results = results
        updateUI()
    }
    
    func updateUI() {
        
        if results.isEmpty {
            
            self.noResulsLabel.isHidden = false
            self.tableView.isHidden = true
            
        } else {
            
            self.noResulsLabel.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
}

extension NewConversationVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let model = results[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.NewConversationCell,
                                                 for: indexPath) as! NewConversationCell
        
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // start conversation
        let targetUserData = results[indexPath.row]

        dismiss(animated: true, completion: { [weak self] in
            self?.complition?(targetUserData)
        })
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 90
    }
}

struct SearchResults {
    
    let name: String
    let email: String
}
