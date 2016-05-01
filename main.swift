#!/usr/bin/swift
//
//  main.swift
//  DayOneToMarkdownFiles
//
//  Created by mhaddl on 29/04/16.
//  Copyright © 2016 Martin Hartl. All rights reserved.
//

import Foundation

let jsonDateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
let fileNameDateFormat = "yyyy-MM-dd"
let headerDateFormat = "yyyy-MM-dd EEEE"

let dateFormatter = NSDateFormatter()
dateFormatter.dateFormat = jsonDateFormat

struct Weather {
    let conditionsDescription: String
    let temperatureCelsius: Int
    
    init?(dictionary: [String:AnyObject]) {
        guard let conditionsDescription = dictionary["conditionsDescription"] as? String,
            let temperatureCelsius = dictionary["temperatureCelsius"] as? Int else  {
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
    let md5: String
    
    init?(dictionary: [String:AnyObject]) {
        guard let identifier = dictionary["identifier"] as? String,
            let md5 = dictionary["md5"] as? String else  {
                return nil
        }
        
        self.identifier = identifier
        self.md5 = md5
        
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

func arrayFromContentsOfFileAtPath(path: String) -> [Entry] {
    let data = NSData(contentsOfFile: path)
    let dict = try! NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments) as? NSDictionary
    let entries = dict?["entries"] as? [[String:AnyObject]]
    return Entry.entriesFromArray(entries!)
    
}

func renamePhoto(photo: Photo, atPath path: NSString, withCreationDate date: NSDate) {
    dateFormatter.dateFormat = fileNameDateFormat
    var filename = dateFormatter.stringFromDate(date)
    var photoPath = path.stringByAppendingPathComponent("photos/" + filename + ".jpeg")
    while NSFileManager.defaultManager().fileExistsAtPath(photoPath) {
        filename = fileNameForDuplication(filename)
		photoPath = path.stringByAppendingPathComponent("photos/" + filename + ".jpeg")
    }
    
    let originalPath = path.stringByAppendingPathComponent("photos/" + photo.md5 + ".jpeg")
    let newPath = path.stringByAppendingPathComponent("photos/" + filename + ".jpeg")
    
    _ = try? NSFileManager.defaultManager().moveItemAtPath(originalPath, toPath: newPath)
    
}

func fileNameForDuplication(filename: String) ->String {
    let splittedName = filename.characters.split{$0 == "_"}.map(String.init)
    if splittedName.count > 1 {
        let lastDigit = Int(splittedName[1])
        if let lastDigit = lastDigit {
            return "\(splittedName.first!)_\(lastDigit+1)"
        }
        
    }
    
    return filename + "_1"
}

func markdownStringForEntry(entry: Entry) -> String {
    
    let imagePattern = "\\n?!\\[]\\(.*\\)\\n?\\n?"
    
    let regex = try! NSRegularExpression(pattern: imagePattern, options: .CaseInsensitive)
    let newString = regex.stringByReplacingMatchesInString(entry.text, options: NSMatchingOptions.ReportProgress, range: NSMakeRange(0, entry.text.characters.count), withTemplate: "")
    
    dateFormatter.dateFormat = headerDateFormat
    var string = "#\(dateFormatter.stringFromDate(entry.creationDate))\n\n"
    if let location = entry.location {
        string = string + "\t\(location.placeName), \(location.localityName)\n"
    }
    
    if let weather = entry.weather {
        string = string + "\t\(weather.conditionsDescription), \(weather.temperatureCelsius)°C\n"
    }
    
    string = string + "\n"
    
    string = string + newString + "\n"
    
    if let photos = entry.photos {
        dateFormatter.dateFormat = fileNameDateFormat
        for i in (0..<photos.count) {
            string = string + "\n"
            if i == 0 {
                string = string + "![](photos/\(dateFormatter.stringFromDate(entry.creationDate)).jpeg)\n"
            } else {
                string = string + "![](photos/\(fileNameForDuplication((dateFormatter.stringFromDate(entry.creationDate)))).jpeg)\n"
            }
        }
    }
    
    return string
}

func saveMarkdownFileForEntry(entry: Entry, atPath path: NSString) {
    dateFormatter.dateFormat = fileNameDateFormat
    var filename = dateFormatter.stringFromDate(entry.creationDate)
    let markdownString = markdownStringForEntry(entry)
    let markdownData = markdownString.dataUsingEncoding(NSUTF8StringEncoding)
    var filePath = path.stringByAppendingPathComponent(filename + ".md")
	while NSFileManager.defaultManager().fileExistsAtPath(filePath) {
		filename = fileNameForDuplication(filename)
		filePath = path.stringByAppendingPathComponent(filename + ".md")
	}
    filePath = path.stringByAppendingPathComponent(filename + ".md")
    NSFileManager.defaultManager().createFileAtPath(filePath, contents: markdownData, attributes: nil)
    
}

let dayOneExportFolderPath = Process.arguments[1] as NSString

let jsonPath = dayOneExportFolderPath.stringByAppendingPathComponent("Journal.json")
if !NSFileManager.defaultManager().fileExistsAtPath(jsonPath) {
    print("No Journal.json file contained in folder")
    exit(EXIT_FAILURE)
}

let entriesArray = arrayFromContentsOfFileAtPath(jsonPath)
print("Converting \(entriesArray.count) entries")
for entry in entriesArray {
    if let photos = entry.photos {
        for photo in photos {
            renamePhoto(photo, atPath:dayOneExportFolderPath, withCreationDate: entry.creationDate)
        }
    }
    saveMarkdownFileForEntry(entry, atPath: dayOneExportFolderPath)
    
}
print("Done")
exit(EXIT_SUCCESS)
