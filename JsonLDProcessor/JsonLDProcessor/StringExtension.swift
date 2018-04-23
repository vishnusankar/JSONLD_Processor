//
//  StringExtension.swift
//  JsonLDProcessor
//
//  Created by Vishnusankar on 01/04/18.
//  Copyright © 2018 global. All rights reserved.
//

import Foundation
import SwiftyJSON

let AbsoluteURI_Regex = "^(((ht|f)tp(s?))\\://)?(www.|[a-zA-Z].)[a-zA-Z0-9\\-\\.]+\\.(com|edu|gov|mil|net|org|biz|info|name|museum|us|ca|uk)(\\:[0-9]+)*(/($|[a-zA-Z0-9\\.\\,\\;\\?\'\\+&amp;%\\$#\\=~_\\-]+))*$"
let CompactIRI_Regex = "\\w[a-zA-Z]*:\\w[a-zA-Z]*"

enum JSONLD_StringType {
    case Null
    case NormalString
    case IRI
    case AbsoluteIRI
    case CompactIRI
    case JsonLD
    case Term
}

extension String {
    func isJsonLDKey() -> Bool {
        if self.first == "@" {
            return true
        }else {
            return false
        }
    }
    
    func keyType(activeContext : JSON) -> JSONLD_StringType {
        
        if self.isAbsoluteIRI() {
            return .AbsoluteIRI
        }
        else if self.isCompactIRI() {
            return .CompactIRI
        }
        else if self.isJsonLDKey() {
            return .JsonLD
        }
        else if self.isTerm(activeContext: activeContext) {
            return .Term
        }
        else if self.isTerm(activeContext: activeContext) == false {
            return .NormalString
        }
        else  {
            return .IRI
        }
    }
    
    func isAbsoluteIRI() -> Bool {
        
        do {
            let regex = try NSRegularExpression(pattern: AbsoluteURI_Regex)
            let range = NSMakeRange(0, self.count)
            let result = regex.firstMatch(in: self, options: .reportProgress, range: range)
            if result != nil {
                return true;
            }else {
                return false;
            }
        } catch let error {
            print("regex invalid \(error.localizedDescription)")
            return false
        }
    }
    
    func isCompactIRI() -> Bool {
        
        do {
            let regex = try NSRegularExpression(pattern: CompactIRI_Regex)
            let range = NSMakeRange(0, self.count)
            let result = regex.firstMatch(in: self, options: .reportProgress, range: range)
            if result != nil {
                return true;
            }else {
                return false;
            }
        } catch let error {
            print("regex invalid \(error.localizedDescription)")
            return false
        }
    }
    
    func isTerm(activeContext: JSON) -> Bool {
        let value = activeContext[self]
        if value == JSON.null {
            return false
        }else {
            return true
        }
    }
    
    func expandKeyTermToAbsoulteIRI(activeContext : Node) -> String? {
        if let index = activeContext.childNodes.index(where: { $0.key == self}) {
            let contextNode = activeContext.childNodes[index]
            switch contextNode.type {
                
            case .array, .dictionary:
                for tempNode in contextNode.childNodes {
                    if tempNode.key == keywords.description(keywordType: .ID) {
                        return tempNode.value
                    }
                }
            case .number, .string, .bool:
                return contextNode.value
            case .unknown, .null:
                return nil
            }
        }
        return nil
    }
    
    func expandKey(activeContext : JSON) -> String? {
        let keyType : JSONLD_StringType = self.keyType(activeContext: activeContext)
        switch keyType {
        case .AbsoluteIRI:
            //Current key string is itself AbsoluteIRI so retrun as it is.
            return self
        case .NormalString:
            //Current key string is not available in Context dict so this is not a valid JSON-LD
            return nil
        case .IRI:
            //Current key string is itself IRI so retrun as it is.
            return self
        case .CompactIRI:
            return self.expandCompactIRI(activeContext:activeContext)
        case .JsonLD: break
        return self
        case .Term:
            //Fetch value from ActiveContext and proccess according with value type
            let value = activeContext["\(self)"]
            if value.null != nil {
                switch value.type {
                    
                case .string:
                    return value.string
                    
                case .null, .bool, .number, .unknown, .dictionary, .array:
                    print("value shouldn't be other than string because key is Term so value should be IRI in string format")
                    return nil
                }
                
            }else {
                print("")
                return nil
            }
        case .Null:
            return nil
        }
        return ""
    }

    
    func expandCompactIRI(activeContext : JSON) -> String? {
        let array = self.components(separatedBy: ":")
        let prefixKeyValue = activeContext[array[0]]
        if prefixKeyValue.null != nil {
            switch prefixKeyValue.type {
            case .string:
                let str = prefixKeyValue.string
                let strType : JSONLD_StringType = (str?.keyType(activeContext: activeContext))!
                if let unWrappedString = str, unWrappedString.isCompactIRI() || unWrappedString.isAbsoluteIRI() {
                    switch strType {
                        
                    case .IRI, .AbsoluteIRI:
                        let suffixkeyValue = array[1]
                        return unWrappedString + suffixkeyValue
                    case .CompactIRI, .NormalString, .JsonLD, .Term, .Null:
                        print("CompactIRI's suffix value shouldn't be compactIRI/NormalString,JsonLD,TermOrScalar")
                        return nil
                    }
                }else {
                    print("CompactIRI's suffix value should be AbsoluteIRI/IRI")
                    return nil
                }
            case .number, .bool, .array, .dictionary, .null, .unknown: //CompactIRI's prefix should be in context dictionary otherwise JSON-LD is valid
                print("CompactIRI's suffix value shouldn't be number/bool,array/dictionary/null/unknown")
                return nil
            }
        }else {
            return nil
        }
    }
    
    func expandCompactIRI(activeContext : Node) -> String? {
        let array = self.components(separatedBy: ":")
        let prefixKeyStr : String = array[0]
        var prefixKeyNode : Node? = nil
        if let index = activeContext.childNodes.index(where: {$0.key == prefixKeyStr}) {
            prefixKeyNode = activeContext.childNodes[index]
            
            if let unwrapNode = prefixKeyNode {
                switch unwrapNode.valueType {
                case .Null, .NormalString, .Term, .CompactIRI, .JsonLD:
                    print("value type should not be .Null, .NormalString, .TermOrScalar, .CompactIRI, .JsonLD")
                    return nil
                case .IRI, .AbsoluteIRI:
                    let suffixkeyValue = array[1]
                    return unwrapNode.value! + suffixkeyValue
                }
            }
        }else {
            print("Prefix key is not available at Context Dictionary")
            return nil
        }
    }
}
