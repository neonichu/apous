//
//  main.swift
//  apous
//
//  Created by David Owens on 7/4/15.
//  Copyright © 2015 owensd.io. All rights reserved.
//

import Foundation

let CartfileConfig = "Cartfile"
let PodfileConfig = "Podfile"

let ApousScriptFile = ".apous.swift"

// TODO(owensd): Pull this from a proper versioning tool.
let Version = "0.1.1"
let Branch = "master"

func printUsage() {
    print("OVERVIEW: Apous Swift Script Runner (build: \(Version)-\(Branch))")
    print("")
    print("USAGE: apous [<script_file>|<path/to/scripts>]")
}


//
// The body of the script.
//

let arguments = NSProcessInfo.processInfo().arguments

if arguments.contains("-help") {
    printUsage()
    exit(0)
}

// This is used to enable more verbose logging.
let DebugOutputEnabled = arguments.contains("-debug")

// NOTE(owensd): This method is a workaround because of Swift bugs and code in the top-level scope.
func run() throws {
    let scriptItem = arguments[1..<arguments.count].filter() { $0 != "-debug" }
    if scriptItem.count != 1 {
        print("Invalid usage.")
        printUsage()
        exit(ErrorCode.InvalidUsage)
    }

    let path = try canonicalPath(scriptItem[0])
    let fileManager = NSFileManager.defaultManager()

    // The tools need to be run under the context of the script directory.
    fileManager.changeCurrentDirectoryPath(path)

    if fileManager.fileExistsAtPath(path.stringByAppendingPathComponent(CartfileConfig)) {
        guard let carthage = CarthageTool() else {
            print("Carthage does not seem to be installed or in your path.")
            exit(.CarthageNotInstalled)
        }
        
        carthage.run("update")
    }

    if fileManager.fileExistsAtPath(path.stringByAppendingPathComponent(PodfileConfig)) {
        guard let pods = CocoaPodsTool() else {
            print("CocoaPods does not seem to be installed or in your path.")
            exit(.CocoaPodsNotInstalled)
        }

        pods.run("install", "--no-integrate")
    }

    let files = Set(filesAtPath(path) + [scriptItem[0]])

    let hashBangRegex = try NSRegularExpression(pattern: "^#!.*", options: .CaseInsensitive)
    var script = ""
    for f in files {
        var fileContents = try String(contentsOfFile: f, encoding: NSUTF8StringEncoding)
        fileContents = hashBangRegex.stringByReplacingMatchesInString(fileContents, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, fileContents.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)), withTemplate: "")
        script += "// file: \(f)\n" + fileContents + "\n"
    }

    let scriptPath = path.stringByAppendingPathComponent(ApousScriptFile)
    try script.writeToFile(scriptPath, atomically: true, encoding: NSUTF8StringEncoding)

    guard let swift = SwiftTool() else {
        print("Unable to find a version of Swift in your path.")
        exit(.SwiftNotInstalled)
    }

    swift.run("-F", "Carthage/Build/Mac", "-F", "Rome", scriptPath)
}

try run()

