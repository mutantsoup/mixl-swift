import XCTest
@testable import Mixl

final class ToolCallingTests: XCTestCase {
    struct WeatherArguments: Codable, Equatable {
        let city: String
        let unit: String?
    }
    
    func testJSONSchemaEncoding() throws {
        // Declare a JSONSchema for a weather lookup tool
        let schema = JSONSchema(
            type: .object,
            description: "Weather parameters",
            properties: [
                "city": JSONSchema(type: .string, description: "City name"),
                "unit": JSONSchema(type: .string, enumValues: ["celsius", "fahrenheit"])
            ],
            required: ["city"]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(schema)
        
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\"type\":\"object\""))
        XCTAssertTrue(jsonString!.contains("\"required\":[\"city\"]"))
        XCTAssertTrue(jsonString!.contains("\"properties\":{"))
    }
    
    func testFunctionCallArgumentDecoding() throws {
        let functionCall = FunctionCall(
            name: "get_weather",
            arguments: "{\"city\":\"Paris\",\"unit\":\"celsius\"}"
        )

        let decodedArgs = try functionCall.decodeArguments(as: WeatherArguments.self)

        XCTAssertEqual(decodedArgs.city, "Paris")
        XCTAssertEqual(decodedArgs.unit, "celsius")
    }

    func testResponseFormatJSONSchemaEncoding() throws {
        let schema = JSONSchema(
            type: .object,
            properties: [
                "city": JSONSchema(type: .string),
                "country": JSONSchema(type: .string)
            ],
            required: ["city", "country"]
        )

        let responseFormat = ResponseFormat.jsonSchema(schema, strict: true)
        let data = try JSONEncoder().encode(responseFormat)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"type\":\"json_schema\""))
        XCTAssertTrue(json.contains("\"json_schema\""))
        XCTAssertTrue(json.contains("\"strict\":true"))
    }
}
