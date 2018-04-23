//
//  JsonLDNode.swift
//  JsonLDProcessor
//
//  Created by Vishnusankar on 28/03/18.
//  Copyright © 2018 global. All rights reserved.
//

import Foundation
import SwiftyJSON

enum keywords : String {
    case CONTEXT = "@context"
    case ID = "@id"
    case VALUE = "@value"
    case LANGUAGE = "@language"
    case TYPE = "@type"
    case CONTAINER = "@container"
    case LIST = "@list"
    case SET = "@set"
    case GRAPH = "@graph"
    case REVERSE = "@reverse"
    case BASE = "@base"
    case VOCAB = "@vocab"
    case INDEX = "@index"
    case NULL = "@null"

    static func description(keywordType: keywords) -> String {
        switch keywordType {
        case .CONTEXT:
            return "@context"
        case .ID:
            return "@id"
        case .VALUE:
            return "@value"
        case .LANGUAGE:
            return "@language"
        case .TYPE:
            return "@type"
        case .CONTAINER:
            return "@container"
        case .LIST:
            return "@list"
        case .SET:
            return "@set"
        case .GRAPH:
            return "@id"
        case .REVERSE:
            return "@reverse"
        case .BASE:
            return "@base"
        case .VOCAB:
            return "@vocab"
        case .INDEX:
            return "@index"
        case .NULL:
            return "@null"
        }
    }
}

enum NodeType {
    case null
    case array
    case dictionary
    case number
    case string
    case bool
    case unknown
}

class Node  {
    
    var parentId : Node? = nil
    var type : NodeType = .null
    var keyType : JSONLD_StringType = .Null
    var key : String? = nil
    var value : String? = nil
    var valueType : JSONLD_StringType = .Null
    var childNodes : [Node] = [Node]()
    
    func expandNode(activeContext : Node) -> Dictionary<String,Any>? {
        var dict : Dictionary<String,Any>? = Dictionary<String,Any>()
        
        //Check Node type
        switch type {
        
        case .array, .dictionary:
            if self.key != keywords.description(keywordType: .CONTEXT) {
            var childDictArray = Array<Dictionary<String,Any>>()
            for node in self.childNodes {
                if let childDict = node.expandNode(activeContext: activeContext) {
                    childDictArray.append(childDict)
                }
            }
                dict![self.key!] = childDictArray
                return dict
            }else {
                return nil
            }
        case .number, .bool, .string:
            //Expand key based on keyType
            var expandedKey : String?
            var expandedValue : Array<Any>? = Array<Any>()

            //Expand values
            switch valueType {
                
            case .Null:
                dict = nil
                return dict
            case .NormalString, .IRI, .AbsoluteIRI, .JsonLD, .Term:
                var tempDict = Dictionary<String,Any>()
                tempDict[keywords.description(keywordType: .VALUE)] = self.value
                expandedValue?.append(tempDict as Any)
            case .CompactIRI:
                if let tempExpandValue = self.value?.expandCompactIRI(activeContext: activeContext) {
                    expandedValue?.append(tempExpandValue)
                }
            }

            switch keyType {
                
            case .Null:
                if (expandedValue?.count)! > 0 {
                    dict![keywords.description(keywordType: .ID)] = expandedValue
                }else {
                    dict = nil
                    return dict
                }
            case .NormalString, .IRI, .AbsoluteIRI, .JsonLD:
                expandedKey = key
            case .CompactIRI:
                expandedKey = key?.expandCompactIRI(activeContext: activeContext)
            case .Term:
                expandedKey = key?.expandKeyTermToAbsoulteIRI(activeContext: activeContext)
            }
            
            if let unWrappedExpandedKey = expandedKey {
                dict![unWrappedExpandedKey] = expandedValue
            }
        case .unknown, .null:
            dict = nil
            return dict
        }
        
        return dict
    }
    
    class func jsonLdToNodeStructure(json: JSON, key : String?, activeContext : JSON) -> Node {
        
        let currentNode : Node =  Node()
        currentNode.key = key
        if let keyStr = key {
            let keyType : JSONLD_StringType = keyStr.keyType(activeContext: activeContext)
            currentNode.keyType = keyType
        }
        switch json.type {
            
        case .string:
            currentNode.type = .string
            currentNode.value = json.stringValue
            let valueStr = json.stringValue
            currentNode.valueType = valueStr.keyType(activeContext: activeContext)
            break
        case .number:
            currentNode.type = .number
            currentNode.value = json.stringValue
            break
        case .bool:
            currentNode.type = .bool
            currentNode.value = json.stringValue
            break
        case .array:
            currentNode.type = .array
            let array = json.arrayValue
            for element in array {
                let childNode = self.jsonLdToNodeStructure(json: element, key: nil, activeContext: activeContext)
                childNode.parentId = currentNode
                currentNode.childNodes.append(childNode)
            }
        case .dictionary:
            currentNode.type = .dictionary
            for (key, value) in json.dictionaryValue {
                let childNode = self.jsonLdToNodeStructure(json: value, key: key, activeContext: activeContext)
                childNode.parentId = currentNode
                currentNode.childNodes.append(childNode)
            }
        case .null, .unknown:
            break
        }

        return currentNode
    }

    class func expandNode(currentNode:Node, contextNode:Node) -> Dictionary<String, Any>? {
        var currentDict : Dictionary<String, Any> = Dictionary<String, Any>()
        var tempKey : String? = nil
        var tempValue : Any? = nil
        
        //First expand key of the currentNode
        switch currentNode.keyType {
        
        case .Null:
            return nil
        case .IRI, .AbsoluteIRI, .NormalString:
            tempKey = currentNode.key
            tempValue = self.expandValue(currentNode: currentNode, contextNode: contextNode)
        case .JsonLD:
            tempKey = currentNode.key
            tempValue = self.expandValue(currentNode: currentNode, contextNode: contextNode)
            if tempValue is Array<Dictionary<String,Any>> {
                let valueInArray = tempValue as! Array<Dictionary<String,Any>>
                for element in valueInArray {
                    if element is Dictionary<String,Any> {
                        let valueInDict = element
                        tempValue = valueInDict["@value"]
                    }
                }
            }
        case .CompactIRI:
            tempKey = currentNode.key?.expandCompactIRI(activeContext: contextNode)
            tempValue = self.expandValue(currentNode: currentNode, contextNode: contextNode)
        case .Term:
            tempKey = self.expandKey(currentNode: currentNode, contextNode: contextNode)
            tempValue = self.expandValue(currentNode: currentNode, contextNode: contextNode)
        }
        
        if let key = tempKey, let value = tempValue {
            currentDict[key] = value
            return currentDict
        }else {
            return nil
        }
}
    
    /**
     Expanded format's value should be in Array, so every expandValue return object is in Array
 **/
    class func expandValue(currentNode:Node, contextNode:Node) -> Any? {
        var array = [Dictionary<String, Any>]()
        var dict = Dictionary<String, Any>()
        
        switch currentNode.type {
        
        case .array, .dictionary:
            if currentNode.childNodes.count > 0 {
                for node in currentNode.childNodes {
                    
                    switch node.valueType {
                    case .NormalString, .Term:
                        if let value = node.value {
                            dict["@value"] = value
                            array.append(dict)
                        }
                    case .IRI, .AbsoluteIRI:
                        if let value = node.value {
                            dict["@id"] = value
                            array.append(dict)
                        }
                    case .CompactIRI:
                        if let value = node.value?.expandCompactIRI(activeContext: contextNode) {
                            dict["@id"] = value
                            array.append(dict)
                        }
                    case .JsonLD, .Null:
                        print("value shouldn't be as JsonLD / Null")
                    }
                }
            }else {
                print("currentNode's type is array/dictionary but doesn't have child nodes so expand operation failed.")
            }

        case .number, .string, .bool:
            if let value = currentNode.value {
                dict["@value"] = value
                
            }else {
                print("currentNode's value is null so expand operation failed.")
            }
        case .unknown, .null:
            print("value shouldn't be as unknown / Null")

        }
        
        //Parse Context Node's value and if value is Dict/Array
        if let index = contextNode.childNodes.index(where: {$0.key == currentNode.key} ) {
            let keyContextNode = contextNode.childNodes[index]
            switch keyContextNode.type {
            case .array, .dictionary:
                if let index = keyContextNode.childNodes.index(where: {$0.key == "@type"}) {
                    let typeNode = keyContextNode.childNodes[index]
                    if typeNode.valueType == .CompactIRI {
                        dict["@type"] = typeNode.value?.expandCompactIRI(activeContext: contextNode)
                    }else if typeNode.valueType == .JsonLD && typeNode.value != "@id"{
                        dict["@type"] = typeNode.value
                    }
                }
            case .number, .bool, .string, .null, .unknown:
                break
            }
        }
        
        if dict.count > 0 {
            array.append(dict)
        }
        return array
    }
    
    class func expandKey(currentNode:Node, contextNode:Node) -> String? {
        if let index = contextNode.childNodes.index(where: {$0.key == currentNode.key}) {
            let keyContextNode = contextNode.childNodes[index]
            switch keyContextNode.type {
                
            case .array, .dictionary:
                if let index = keyContextNode.childNodes.index(where: {$0.key == "@id"}) {
                    let keyContextNode = keyContextNode.childNodes[index]
                    return keyContextNode.value
                }
            case .number, .bool, .string:
                return keyContextNode.value
            case .null, .unknown:
                return nil
            }
        }
        return nil
    }
}
