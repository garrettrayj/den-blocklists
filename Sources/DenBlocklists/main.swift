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

struct SourceBlocklist: Decodable {
    var id: String
    var name: String
    var description: String
    var sourceURL: URL
    var supportURL: URL
}

struct SourceCollection: Decodable {
    var id: String
    var name: String
    var website: URL
    var filterLists: [SourceBlocklist]
}

struct ManifestBlocklist: Encodable {
    var id: String
    var name: String
    var description: String
    var convertedURL: URL
    var sourceURL: URL
    var supportURL: URL
    var convertedCount: Int = 0
    var errorsCount: Int = 0
}

struct ManifestCollection: Encodable {
    var id: String
    var name: String
    var website: URL
    var filterLists: [ManifestBlocklist]
}

let converter = ContentBlockerConverter()

func convertBlocklist(_ blocklist: SourceBlocklist, outputDirectoryURL: URL) -> ManifestBlocklist? {
    let outputFilename = "\(blocklist.id).json"
    
    var result = ManifestBlocklist(
        id: blocklist.id,
        name: blocklist.name,
        description: blocklist.description,
        convertedURL: URL(string: "https://blocklists.den.io/\(outputFilename)")!,
        sourceURL: blocklist.sourceURL,
        supportURL: blocklist.supportURL
    )
  
    guard let data = try? Data(contentsOf: blocklist.sourceURL) else { return nil }
    
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
        return nil
    }
    
    result.convertedCount = converterResult.convertedCount
    result.errorsCount = converterResult.errorsCount
    
    return result
}

func convertBlocklists(_ blocklists: [SourceBlocklist], outputDirectoryURL: URL) -> [ManifestBlocklist] {
    blocklists.compactMap { blocklist in
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
            let collections: [SourceCollection] = try? JSONDecoder().decode(
                [SourceCollection].self,
                from: data
            )
        else {
            throw ProgramError.failedToLoadInputFile
        }
        
        // Process blocklists
        var results: [ManifestCollection] = []
        for collection in collections {
            results.append(ManifestCollection(
                id: collection.id,
                name: collection.name,
                website: collection.website,
                filterLists: convertBlocklists(
                    collection.filterLists,
                    outputDirectoryURL: outputDirectoryURL
                )
            ))
        }
        
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
