//
//  JsonLDNode.swift
//  JsonLDProcessor
//
//  Created by Vishnusankar on 28/03/18.
//  Copyright © 2018 global. All rights reserved.
//

import Foundation
import SwiftyJSON

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
        case .IRI, .AbsoluteIRI, .JsonLD, .NormalString:
            tempKey = currentNode.key
            tempValue = self.expandValue(currentNode: currentNode, contextNode: contextNode)
        case .CompactIRI:
            tempKey = currentNode.key?.expandCompactIRI(activeContext: contextNode)
            tempValue = self.expandValue(currentNode: currentNode, contextNode: contextNode)
        case .TermOrScalar:
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
    
    class func expandValue(currentNode:Node, contextNode:Node) -> Any? {
        var array = [Dictionary<String, Any>]()
        var dict = Dictionary<String, Any>()
        
        switch currentNode.type {
        
        case .array, .dictionary:
            if currentNode.childNodes.count > 0 {
                for node in currentNode.childNodes {
                    
                    switch node.valueType {
                    case .NormalString, .TermOrScalar:
                        if let value = node.value {
                            dict["@value"] = value
                        }
                    case .IRI, .AbsoluteIRI:
                        if let value = node.value {
                            dict["@id"] = value
                        }
                    case .CompactIRI:
                        if let value = node.value?.expandCompactIRI(activeContext: contextNode) {
                            dict["@id"] = value
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
                    let keyContextNode = keyContextNode.childNodes[index]
                    dict["@type"] = keyContextNode.value
                }
            case .number, .bool, .string, .null, .unknown:
                break
            }
        }
        if dict != nil {
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

extension String {
    func expandCompactIRI(activeContext : Node) -> String? {
        let array = self.components(separatedBy: ":")
        let prefixKeyStr : String = array[0]
        var prefixKeyNode : Node? = nil
        if let index = activeContext.childNodes.index(where: {$0.key == prefixKeyStr}) {
            prefixKeyNode = activeContext.childNodes[index]
            
            if let unwrapNode = prefixKeyNode {
                switch unwrapNode.valueType {
                case .Null, .NormalString, .TermOrScalar, .CompactIRI, .JsonLD:
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
