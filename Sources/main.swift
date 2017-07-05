#!/usr/bin/swift
//
//  main.swift
//  DayOneToMarkdownFiles
//
//  Created by hartlco on 29/04/16.
//  Copyright © 2016 Martin Hartl. All rights reserved.
//

import Foundation

let jsonDateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
let fileNameDateFormat = "yyyy-MM-dd"
let headerDateFormat = "yyyy-MM-dd EEEE"

let dateFormatter = DateFormatter()
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
    let creationDate: Date

    init?(dictionary: [String:AnyObject]) {
        guard let text = dictionary["text"] as?String,
            let creationDateString = dictionary["creationDate"] as? String,
            let creationDate = dateFormatter.date(from: creationDateString) else {
                return nil
        }

        self.text = text
        self.creationDate = creationDate

        if let photoArray = dictionary["photos"] as? [[String:AnyObject]] {
            self.photos = Photo.photosFromArray(array :photoArray)
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

func arrayFromContentsOfFileAtPath(url: URL) -> [Entry] {
    let data = try! Data(contentsOf: url)
    let dict = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as? NSDictionary
    let entries = dict?["entries"] as? [[String:AnyObject]]
    return Entry.entriesFromArray(array: entries!)

}

func renamePhoto(photo: Photo, atPath path: NSString, withCreationDate date: Date) {
    dateFormatter.dateFormat = fileNameDateFormat
    var filename = dateFormatter.string(from: date)
    var photoPath = path.appendingPathComponent("photos/" + filename + ".jpeg")
    while FileManager.default.fileExists(atPath: photoPath) {
        filename = fileNameForDuplication(filename: filename)
        photoPath = path.appendingPathComponent("photos/" + filename + ".jpeg")
    }

    let originalPath = path.appendingPathComponent("photos/" + photo.md5 + ".jpeg")
    let newPath = path.appendingPathComponent("photos/" + filename + ".jpeg")

    _ = try? FileManager.default.moveItem(atPath: originalPath, toPath: newPath)

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

    let regex = try! NSRegularExpression(pattern: imagePattern, options: .caseInsensitive)
    let newString = regex.stringByReplacingMatches(in: entry.text, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, entry.text.characters.count), withTemplate: "")

    dateFormatter.dateFormat = headerDateFormat
    var string = "#\(dateFormatter.string(from: entry.creationDate))\n\n"
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
                string = string + "![](photos/\(dateFormatter.string(from: entry.creationDate)).jpeg)\n"
            } else {
                string = string + "![](photos/\(fileNameForDuplication(filename: (dateFormatter.string(from: entry.creationDate)))).jpeg)\n"
            }
        }
    }

    return string
}

func saveMarkdownFileForEntry(entry: Entry, atPath path: NSString) {
    dateFormatter.dateFormat = fileNameDateFormat
    var filename = dateFormatter.string(from: entry.creationDate)
    let markdownString = markdownStringForEntry(entry: entry)
    let markdownData = markdownString.data(using: .utf8)
    var filePath = path.appendingPathComponent(filename + ".md")
    while FileManager.default.fileExists(atPath: filePath) {
        filename = fileNameForDuplication(filename: filename)
        filePath = path.appendingPathComponent(filename + ".md")
    }
    filePath = path.appendingPathComponent(filename + ".md")
    FileManager.default.createFile(atPath: filePath, contents: markdownData, attributes: nil)

}

let dayOneExportFolderPath = CommandLine.arguments[1] as NSString

let jsonPath = dayOneExportFolderPath.appendingPathComponent("Journal.json")
if !FileManager.default.fileExists(atPath: jsonPath) {
    print("No Journal.json file contained in folder")
    exit(EXIT_FAILURE)
}

let entriesArray = arrayFromContentsOfFileAtPath(url: URL(fileURLWithPath: jsonPath))
print("Converting \(entriesArray.count) entries")
for entry in entriesArray {
    if let photos = entry.photos {
        for photo in photos {
            renamePhoto(photo: photo, atPath:dayOneExportFolderPath, withCreationDate: entry.creationDate)
        }
    }
    saveMarkdownFileForEntry(entry: entry, atPath: dayOneExportFolderPath)

}
print("Done")
exit(EXIT_SUCCESS)
