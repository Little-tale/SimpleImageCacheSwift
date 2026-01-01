//
//  ViewController.swift
//  SimpleImageCachingDemo
//
//  Created by Jae hyung Kim on 12/28/25.
//

import UIKit
import SwiftUI
import SimpleImageCachingSwift
import SwiftImageCompressor
import os

class ViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let moveSwiftUIButton = UIButton()
    private let clearUIButton = UIButton()
    
    private let imageURLs: [String] = (1...120).map { index in
        eTagBaseUrlString + eTagTrailingUrlStrings[index] // TMDB Have ETag
//        "https://picsum.photos/id/\(index)/200/300" // picsum No Have ETag
    }
    
    override func loadView() {
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
    }
}

// MARK: - TableView
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        imageURLs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ImageCell.reuseID) as? ImageCell
            ?? ImageCell(style: .default, reuseIdentifier: ImageCell.reuseID)
        cell.configure(urlString: imageURLs[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Selected: \(indexPath.row)")
    }
}

// MARK: - UI
extension ViewController {
    private func setUI() {
        navigationItem.title = "Image List From UIKit"
        
        moveSwiftUIButton.setTitleColor(.black, for: .normal)
        moveSwiftUIButton.backgroundColor = .lightGray
        moveSwiftUIButton.setTitle("Move SwiftUI", for: .normal)
        
        view.addSubview(moveSwiftUIButton)
        moveSwiftUIButton.translatesAutoresizingMaskIntoConstraints = false
        
        clearUIButton.setTitle("Clear All Cache", for: .normal)
        clearUIButton.setTitleColor(.white, for: .normal)
        clearUIButton.backgroundColor = .red
        
        moveSwiftUIButton.addAction(
            UIAction(handler: { [weak self] _ in
                guard let self else { return }
                let vc = UIHostingController(rootView: TestSwiftUIView())
                navigationController?.pushViewController(vc, animated: true)
            })
            , for: .touchUpInside)
        
        clearUIButton.addAction(
            UIAction(handler: { _ in
                Task {
                    await SimpleCacheManager.coordinator.clear()
                }
            })
            , for: .touchUpInside)
        
        view.addSubview(clearUIButton)
        clearUIButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.backgroundColor = .white
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 120
        tableView.register(ImageCell.self, forCellReuseIdentifier: ImageCell.reuseID)

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            moveSwiftUIButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            moveSwiftUIButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            clearUIButton.topAnchor.constraint(equalTo: moveSwiftUIButton.bottomAnchor, constant: 8),
            clearUIButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            tableView.topAnchor.constraint(equalTo: clearUIButton.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - Cell
final class ImageCell: UITableViewCell {
    static let reuseID = "ImageCell"
    private let demoImageView = UIImageView()
    
    private var imageTask: SimpleDownloadTask? = nil

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        SimpleLog.ui.info("prepareForReuse")
        imageTask?.cancel()
        demoImageView.image = nil
    }
    

    func configure(urlString: String) {
        let task = demoImageView.sic.setImage(
            urlString: urlString,
            placeholder: UIImage(systemName: "photo"),
            priority: .userInitiated,
            options: [
                .cacheOption(.diskAndMemory),
                .resize(type: .jpeg, targetMB: 0.1)
            ]
        )
        imageTask = task
    }

    private func setup() {
        demoImageView.contentMode = .scaleAspectFill
        demoImageView.clipsToBounds = true

        contentView.addSubview(demoImageView)
        demoImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            demoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            demoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            demoImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            demoImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
}
