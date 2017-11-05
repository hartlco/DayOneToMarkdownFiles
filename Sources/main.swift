#!/usr/bin/swift
//
//  Created by hartlco on 29/04/16.
//  Copyright © 2016 Martin Hartl. All rights reserved.
//

import Foundation

let jsonDateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
let fileNameDateFormat = "yyyy-MM-dd"
let headerDateFormat = "yyyy-MM-dd EEEE"
let postFileFormat = "dd.MM.yyyy"

let siteURL = "{{ site.url }}"

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = jsonDateFormat

let fileManager = FileManager.default

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
    let longitude: Double
    let latitude: Double

    init?(dictionary: [String:AnyObject]) {
        guard let localityName = dictionary["localityName"] as? String,
            let placeName = dictionary["placeName"] as? String,
            let longitude = dictionary["longitude"] as? Double,
            let latitude = dictionary["latitude"] as? Double else  {
                return nil
        }

        self.localityName = localityName
        self.placeName = placeName
        self.longitude = longitude
        self.latitude = latitude
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

func renamePhoto(photo: Photo, atPath path: NSString, folderName: String,  withCreationDate date: Date) {
    dateFormatter.dateFormat = fileNameDateFormat
    var filename = dateFormatter.string(from: date)
    var photoPath = path.appendingPathComponent(folderName + "/assets/" + filename + ".jpeg")
    while fileManager.fileExists(atPath: photoPath) {
        filename = fileNameForDuplication(filename: filename)
        photoPath = path.appendingPathComponent(folderName + "/assets/" + filename + ".jpeg")
    }

    let originalPath = path.appendingPathComponent("photos/" + photo.md5 + ".jpeg")
    let newPath = photoPath

    do {
        try fileManager.moveItem(atPath: originalPath, toPath: newPath)
    } catch {
        print("Couldtn move photo to path" + newPath)
    }
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

    dateFormatter.dateFormat = postFileFormat
    var string = "# Datum: \(dateFormatter.string(from: entry.creationDate)) "
    if let location = entry.location {
        string = string + "Ort: \(location.localityName)"
    }

    string = string + "\n" + newString + "\n"

    if let photos = entry.photos {
        dateFormatter.dateFormat = fileNameDateFormat
        for i in (0..<photos.count) {
            string = string + "\n"
            if i == 0 {
                string = string + "![](assets/\(dateFormatter.string(from: entry.creationDate)).jpeg)\n"
            } else {
                string = string + "![](assets/\(fileNameForDuplication(filename: (dateFormatter.string(from: entry.creationDate)))).jpeg)\n"
            }
        }
    }

    return string
}

func saveMarkdownFileForEntry(entry: Entry, atPath path: URL) -> String {
    dateFormatter.dateFormat = fileNameDateFormat
    var foldername = dateFormatter.string(from: entry.creationDate)

    do {
        try fileManager.createDirectory(atPath: path.path + "/" + foldername + ".textbundle", withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: path.path + "/" + foldername + ".textbundle/assets", withIntermediateDirectories: false)
    } catch {
        do {
            foldername = fileNameForDuplication(filename: foldername)
            try fileManager.createDirectory(atPath: path.path + "/" + foldername + ".textbundle", withIntermediateDirectories: true)
            try fileManager.createDirectory(atPath: path.path + "/" + foldername + ".textbundle/assets", withIntermediateDirectories: false)
            print("Created folder because of duplication: " + foldername)
        } catch {
            print("Couldnt create folder name: " + foldername)
        }
    }

    let markdownString = markdownStringForEntry(entry: entry)
    let markdownData = markdownString.data(using: .utf8)
    let fileURL = path.appendingPathComponent(foldername + ".textbundle/" + "text.markdown")
    fileManager.createFile(atPath: fileURL.path, contents: markdownData, attributes: nil)

    return foldername
}

func saveTextbundlePlist(at path: URL, inFolder folder: String) {
    let info = [
        "creatorURL" : "file:///Applications/DayOneToMarkdown.app/",
        "transient" : false,
        "type" : "net.daringfireball.markdown",
        "creatorIdentifier" : "com.ulyssesapp.mac",
        "version" : 2
        ] as [String : Any]

    let data = try! JSONSerialization.data(withJSONObject: info, options: .prettyPrinted)
    let fileURL = path.appendingPathComponent(folder + ".textbundle/" + "info.json")
    fileManager.createFile(atPath: fileURL.path, contents: data, attributes: nil)
}

let dayOneExportFolderPath = URL(fileURLWithPath: CommandLine.arguments[1])

let jsonURL = dayOneExportFolderPath.appendingPathComponent("Journal.json", isDirectory: false)
if !fileManager.fileExists(atPath: jsonURL.path) {
    print("No Journal.json file contained in folder")
    exit(EXIT_FAILURE)
}

let entriesArray = arrayFromContentsOfFileAtPath(url: jsonURL)
print("Converting \(entriesArray.count) entries")
for entry in entriesArray {
    let folderName = saveMarkdownFileForEntry(entry: entry, atPath: dayOneExportFolderPath)
    saveTextbundlePlist(at: dayOneExportFolderPath, inFolder: folderName)

    if let photos = entry.photos {
        for photo in photos {
            renamePhoto(photo: photo, atPath:dayOneExportFolderPath.path as NSString, folderName: folderName + ".textbundle", withCreationDate: entry.creationDate)
        }
    }
}

print("Done")
exit(EXIT_SUCCESS)
