import Foundation

// MARK: - JSONEncoder

extension JSONEncoder {

    func encodePayload<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encode(value)
        } catch {
            throw EncoderError.encodingFailed(error)
        }
    }
}

// MARK: - JSONDecoder

extension JSONDecoder {

    func decodePayload<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decode(type, from: data)
        } catch {
            throw EncoderError.decodingFailed(error)
        }
    }
}
