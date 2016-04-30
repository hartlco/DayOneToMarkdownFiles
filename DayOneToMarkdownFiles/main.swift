//
//  main.swift
//  DayOneToMarkdownFiles
//
//  Created by mhaddl on 29/04/16.
//  Copyright © 2016 Martin Hartl. All rights reserved.
//

import Foundation

let dateFormatter = NSDateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"

struct Weather {
    let conditionsDescription: String
    let temperatureCelsius: String
    
    init?(dictionary: [String:AnyObject]) {
        guard let conditionsDescription = dictionary["conditionsDescription"] as? String,
            let temperatureCelsius = dictionary["temperatureCelsius"] as?String else  {
                return nil
        }
        
        self.conditionsDescription = conditionsDescription
        self.temperatureCelsius = temperatureCelsius
        
    }
}

struct Location {
    let localityName: String
    let placeName: String
    
    init?(dictionary: [String:AnyObject]) {
        guard let localityName = dictionary["localityName"] as? String,
        let placeName = dictionary["placeName"] as?String else  {
            return nil
        }
        
        self.localityName = localityName
        self.placeName = placeName
        
    }
    
    static func locatioFromArray(array: [[String:AnyObject]]) -> [Photo] {
        return array.flatMap {
            return Photo(dictionary: $0)
        }
    }
}

struct Photo {
    let identifier: String
    
    init?(dictionary: [String:AnyObject]) {
        guard let identifier = dictionary["identifier"] as? String else  {
            return nil
        }
        
        self.identifier = identifier

    }
    
    static func photosFromArray(array: [[String:AnyObject]]) -> [Photo] {
        return array.flatMap {
            return Photo(dictionary: $0)
        }
    }
}

struct Entry {
    
    let photos: [Photo]?
    let text: String
    let location: Location?
    let weather: Weather?
    let creationDate: NSDate
    
    init?(dictionary: [String:AnyObject]) {
        guard let text = dictionary["text"] as?String,
        let creationDateString = dictionary["creationDate"] as? String,
        let creationDate = dateFormatter.dateFromString(creationDateString) else {
                return nil
        }
        
        self.text = text
        self.creationDate = creationDate
        
        if let photoArray = dictionary["photos"] as? [[String:AnyObject]] {
            self.photos = Photo.photosFromArray(photoArray)
        } else {
            self.photos = nil
        }
        
        if let locationDictionary = dictionary["location"] as? [String:AnyObject] {
            self.location = Location(dictionary: locationDictionary)
        } else {
            self.location = nil
        }
        
        if let weatherDictionary = dictionary["weather"] as? [String:AnyObject] {
            self.weather = Weather(dictionary: weatherDictionary)
        } else {
            self.weather = nil
        }
        
    }
    
    static func entriesFromArray(array: [[String:AnyObject]]) -> [Entry] {
        return array.flatMap {
            return Entry(dictionary: $0)
        }
    }
}

func arrayFromContentsOfFileWithName() -> [Entry] {
    let location = NSString(string:"~/Dropbox/Day One Export/Journal.json").stringByExpandingTildeInPath
    let data = NSData(contentsOfFile: location)
    let dict = try! NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments) as? NSDictionary
    let entries = dict?["entries"] as? [[String:AnyObject]]
    return Entry.entriesFromArray(entries!)
    
}

print(arrayFromContentsOfFileWithName().first)