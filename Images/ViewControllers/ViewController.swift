//
//  ViewController.swift
//  Images
//
//  Created by r leseberg on 9/3/19.
//  Copyright © 2019 starion. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    // TODO: Inject ImageModel
    var model: ImageModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        model = ImageModel(updated: {[weak self] in
            self?.tableView.reloadData()
        })
    }
}

// TODO: add prefetchRowsAt and cancelPrefetching and cancel download image requests that have not started.

// TODO: Need to confirm the image returned is for the correct cell. Fast scrolling can cause the
// wrong image to appear on the cell
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model?.numImages() ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ImageCell", for: indexPath) as! ImageCell
        
        let name = model?.getImageName(num: indexPath.row) ?? ""
        cell.imageName.text = name
        cell.cellImage.image = nil
        
        model?.getImage(num: indexPath.row,
                        success: {[cell] (image) in
                            cell.cellImage?.image = image
                        },
                        fail: {
                            // TODO: handle fail
                        })
        return cell
    }
}

