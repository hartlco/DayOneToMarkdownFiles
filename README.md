# DayOneToMarkdownFiles

It's possible to export all your DayOne entries into a zip file containing a json file with all your entries and a folder `photos` with all your photos.

This quick and dirty command line tool works on the extracted folder to rename the images into something reasonable and creates markdown file for every entry in the json file.

## Usage

- the exported DayOne zip file needs to be extracted
- make the main.swift file runnable: `chmod +x main.swift`
- run the script with the DayOne folder as the first command line argument: `./main.swift ~/Desktop/DayOne/`
- Look at all the created markdown files in the DayOne folder