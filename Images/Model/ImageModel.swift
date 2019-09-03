//
//  ImageModel.swift
//  Images
//
//  Created by r leseberg on 9/3/19.
//  Copyright © 2019 starion. All rights reserved.
//

import Foundation
import UIKit
import CoreData

typealias GetImageCompletion = (_ image: UIImage) -> Void
typealias GetImageCompletionFail = () -> Void
typealias ModelUpdated = () -> Void

class ImageModel: NSObject {
    private var images: [NSManagedObject] = []
    private var modelUpdated: ModelUpdated?
    
    // TODO: explore writing these to files locally
    private let imageCache = NSCache<AnyObject, AnyObject>()
    
    init(updated: ModelUpdated?) {
        super.init()
        modelUpdated = updated
        
        fetchData()
        
        if imageListIsEmpty() {
            downloadImageList()
        }
    }
    
    func imageListIsEmpty() -> Bool {
        return images.isEmpty
    }
    
    func numImages() -> Int {
        return images.count
    }
    
    func getImageName(num: Int) -> String {
        let name = images[num].value(forKey: "name") as? String
        return name ?? "Not Found"
    }
    
    func getImage(num: Int,
                  success: @escaping GetImageCompletion,
                  fail: @escaping GetImageCompletionFail) {
        guard let link = images[num].value(forKey: "url") as? String else {
            return fail()
        }
        if let imageFromCache = imageCache.object(forKey: link as AnyObject),
            let image = imageFromCache as? UIImage {
            
            success(image)
        } else {
            downloadImage(link: link, success: success, fail: fail)
        }
    }
    
    private func addImages(imageList: [ImageName]) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        
        clearDB()
        for i in 0..<imageList.count {
            addImage(i, imageList[i], managedContext)
        }
    }
    
    private func addImage(_ num: Int,_ image: ImageName, _ managedContext: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Images", in: managedContext)!
        
        let anImage = NSManagedObject(entity: entity, insertInto: managedContext)
        
        anImage.setValue(num, forKeyPath: "location")
        anImage.setValue(image.name, forKeyPath: "name")
        anImage.setValue(image.urlString, forKeyPath: "url")
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    private func clearDB() {
        
    }
    
    private func fetchData() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }

        let managedContext = appDelegate.persistentContainer.viewContext
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Images")
        
        do {
            images = try managedContext.fetch(request)
        } catch let error as NSError {
            print("Db request failed. \(error), \(error.userInfo)")
        }
    }
}

extension ImageModel {
    func downloadImageList() {
        guard let url = URL(string: "https://raw.githubusercontent.com/granulartechnical/takehome-mobile/master/list.json") else {
            print ("downloadImageList failed")
            return
        }
        let request = URLRequest(url: url)
        DownloadService.shared.download(request: request,
                                        success: {[weak self] data in
                                            print("downloadImageList completed data received size: \(data.count))")
                                            let decoder = JSONDecoder()
                                            if let images = try? decoder.decode([ImageName].self, from: data) {
                                                DispatchQueue.main.async {
                                                    self?.addImages(imageList: images)
                                                    self?.fetchData()
                                                    self?.modelUpdated?()
                                                }
                                            }
        },
                                        failure: {error in
                                            print("downloadImageList error: \(error.localizedDescription))")
        } )
    }
    
    func downloadImage(link: String,
                       success: @escaping GetImageCompletion,
                       fail: @escaping GetImageCompletionFail) {
        let urlString = "https://raw.githubusercontent.com/granulartechnical/takehome-mobile/master/" + link
        guard let url = URL(string: urlString) else {
            print ("downloadImage failed")
            fail()
            return
        }
        let request = URLRequest(url: url)
        DownloadService.shared.download(request: request,
                                        success: {[weak self] data in
                                            print("downloadImage completed data received size: \(data.count))")
                                            if let image = UIImage(data: data) {
                                                self?.imageCache.setObject(image, forKey: link as AnyObject)
                                                DispatchQueue.main.async {
                                                    success(image)
                                                }
                                            } else {
                                                fail()
                                            }
                                        },
                                        failure: {error in
                                            print("downloadImage error: \(error.localizedDescription))")
                                            fail()
                                        } )
        
    }

}
