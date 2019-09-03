//
//  ImageName.swift
//  Images
//
//  Created by r leseberg on 9/3/19.
//  Copyright © 2019 starion. All rights reserved.
//

import Foundation

struct ImageName: Codable {
    let name: String
    let urlString: String
    
    enum CodingKeys: String, CodingKey {
        
        case name
        case urlString = "url"
    }
}
