//
//  main.swift
//  DenBlocklists
//
//  Created by Garrett Johnson on 1/24/24.
//  Copyright © 2023 Garrett Johnson
//
//  SPDX-License-Identifier: GPL-3.0-only
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

import ArgumentParser
import ContentBlockerConverter

enum ProgramError: Error {
    case outputDirectoryDoesNotExist
    case failedToLoadInputFile
    case failedToEncodeManifest
    case failedToWriteManifest
}

struct Blocklist: Decodable {
    var name: String
    var slug: String
    var description: String
    var sourceURL: URL
    var supportURL: URL
}

struct Result: Encodable {
    var name: String
    var filename: String
    var description: String
    var sourceURL: String
    var supportURL: String
    var fetchSuccessful: Bool = false
    var conversionSuccessful: Bool = false
    var convertedCount: Int = 0
    var errorsCount: Int = 0
    var overLimit: Bool = false
}

let converter = ContentBlockerConverter()

func convertBlocklist(_ blocklist: Blocklist, outputDirectoryURL: URL) -> Result {
    let outputFilename = "\(blocklist.slug).json"
    
    var result = Result(
        name: blocklist.name,
        filename: outputFilename,
        description: blocklist.description,
        sourceURL: blocklist.sourceURL.absoluteString,
        supportURL: blocklist.supportURL.absoluteString
    )
  
    guard let data = try? Data(contentsOf: blocklist.sourceURL) else { return result }
    result.fetchSuccessful = true
    
    let rulesString = String(decoding: data, as: UTF8.self)
    let rulesArray = rulesString.split(whereSeparator: \.isNewline).map { String($0) }
    let converterResult = converter.convertArray(rules: rulesArray)
    let outputURL = outputDirectoryURL.appendingPathComponent(outputFilename)
    do {
        try converterResult.converted.write(
            to: outputURL,
            atomically: true,
            encoding: String.Encoding.utf8
        )
    } catch {
        return result
    }
    
    result.conversionSuccessful = true
    result.convertedCount = converterResult.convertedCount
    result.errorsCount = converterResult.errorsCount
    result.overLimit = converterResult.overLimit
    
    return result
}

func convertBlocklists(_ blocklists: [Blocklist], outputDirectoryURL: URL) -> [Result] {
    blocklists.map { blocklist in
        convertBlocklist(blocklist, outputDirectoryURL: outputDirectoryURL)
    }
}

struct DenBlocklists: ParsableCommand {
    @Argument var inputFile: String
    @Argument var outputDirectory: String
    
    mutating func run() throws {
        let outputDirectoryURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        var isDir: ObjCBool = true
        
        guard FileManager.default.fileExists(
            atPath: outputDirectoryURL.path,
            isDirectory: &isDir
        ) else {
            throw ProgramError.outputDirectoryDoesNotExist
        }
        
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: inputFile)),
            let blocklists: [Blocklist] = try? JSONDecoder().decode([Blocklist].self, from: data)
        else {
            throw ProgramError.failedToLoadInputFile
        }
        
        // Process blocklists
        let results = convertBlocklists(blocklists, outputDirectoryURL: outputDirectoryURL)
        
        // Write manifest file
        let manifestURL = outputDirectoryURL.appendingPathComponent("manifest.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let manifestData = try? encoder.encode(results) else {
            throw ProgramError.failedToEncodeManifest
        }
        
        do {
            try manifestData.write(to: manifestURL)
        } catch {
            throw ProgramError.failedToWriteManifest
        }
        
        print("Finished processing blocklists! \(manifestURL.absoluteString)")
    }
}

DenBlocklists.main()
