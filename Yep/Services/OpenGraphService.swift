//
//  OpenGraphService.swift
//  Yep
//
//  Created by nixzhu on 16/1/12.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import Alamofire
import Kanna

struct OpenGraph {

    var siteName: String?

    var title: String?
    var description: String?

    var previewImageURLString: String?
    var previewVideoURLString: String?
    var previewAudioURLString: String?

    init() {
    }

    static func fromHTMLString(HTMLString: String) -> OpenGraph? {

        if let doc = Kanna.HTML(html: HTMLString, encoding: NSUTF8StringEncoding) {

            var openGraph = OpenGraph()

            if let metaSet = doc.head?.css("meta") {

                var openGraphInfo = [String: String]()

                for meta in metaSet {
                    if let property = meta["property"]?.lowercaseString {
                        if property.hasPrefix("og:") {
                            if let content = meta["content"] {
                                openGraphInfo[property] = content
                            }
                        }
                    }
                }

                openGraph.siteName = openGraphInfo["og:site_name"]
                openGraph.title = openGraphInfo["og:title"]
                openGraph.description = openGraphInfo["og:description"]
                openGraph.previewImageURLString = openGraphInfo["og:image"]
            }

            return openGraph
        }

        return nil
    }
}

func openGraphWithURLString(URLString: String, failureHandler: ((Reason, String?) -> Void)?, completion: OpenGraph -> Void) {

    Alamofire.request(.GET, URLString, parameters: nil, encoding: .URL).responseString { response in

        let error = response.result.error

        guard error == nil else {

            if let failureHandler = failureHandler {
                failureHandler(.Other(error), nil)
            } else {
                defaultFailureHandler(.Other(error), errorMessage: nil)
            }

            return
        }

        if let HTMLString = response.result.value {
            println("\n openGraphWithURLString: \(URLString)\n\(HTMLString)")

            if let openGraph = OpenGraph.fromHTMLString(HTMLString) {

                var openGraph = openGraph

                if let URL = response.response?.URL, host = URL.host {

                    switch host {

                    case "itunes.apple.com":

                        if let lookupID = URL.yep_iTunesArtworkID {
                            iTunesLookupWithID(lookupID, inCountry: .China, failureHandler: nil, completion: { info in
                                println("iTunesLookupWithID: \(lookupID), \(info)")

                                if let artworkInfo = (info["results"] as? [JSONDictionary])?.first {

                                    if let kind = artworkInfo["kind"] as? String {

                                        switch kind {
                                        case "song":
                                            openGraph.previewAudioURLString = artworkInfo["previewUrl"] as? String

                                        default:
                                            break
                                        }
                                    }
                                }

                                completion(openGraph)
                            })
                        }

                    default:
                        completion(openGraph)
                    }
                }

                return
            }
        }

        if let failureHandler = failureHandler {
            failureHandler(.CouldNotParseJSON, nil)
        } else {
            defaultFailureHandler(.CouldNotParseJSON, errorMessage: nil)
        }
    }
}

private enum iTunesCountry: String {
    case China = "cn"
    case USA = "us"
}

private func iTunesLookupWithID(lookupID: String, inCountry country: iTunesCountry, failureHandler: ((Reason, String?) -> Void)?, completion: JSONDictionary -> Void) {

    let lookUpURLString = "https://itunes.apple.com/lookup?id=\(lookupID)&country=\(country.rawValue)"

    Alamofire.request(.GET, lookUpURLString).responseJSON { response in

        if let JSON = response.result.value as? JSONDictionary {
            completion(JSON)
        }
    }
}

