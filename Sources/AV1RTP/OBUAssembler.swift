import Foundation

/// Reassembles fragmented OBU elements from multiple RTP packets.
///
/// Tracks in-progress fragments using Z/Y flags from the aggregation header.
/// Detects packet loss via sequence number gaps and triggers recovery.
///
/// v0.1.0: Stub — fragmentation support (Z/Y) arrives in v0.2.0.
/// Currently only handles complete (non-fragmented) OBU elements.
public final class OBUAssembler: Sendable {

    public init() {}

    /// Extract OBU elements from an RTP payload.
    ///
    /// - Parameters:
    ///   - payload: RTP payload data (after the 12-byte RTP header)
    ///   - header: Parsed aggregation header (first byte of payload)
    /// - Returns: Array of raw OBU element data (each starts with OBU header byte)
    public func extractElements(payload: Data, header: AggregationHeader) throws -> [Data] {
        guard payload.count > 1 else {
            throw OBUAssemblerError.emptyPayload
        }

        // Skip the aggregation header byte
        let elementData = payload[payload.startIndex + 1..<payload.endIndex]

        if header.w == 0 {
            return try extractVariableLengthElements(elementData)
        } else {
            return try extractFixedCountElements(elementData, count: Int(header.w))
        }
    }

    /// W=0: All elements have leb128 size prefixes.
    private func extractVariableLengthElements(_ data: Data) throws -> [Data] {
        var elements = [Data]()
        var offset = 0

        while offset < data.count {
            let (size, bytesRead) = try LEB128.decode(data, offset: offset)
            offset += bytesRead

            let elementSize = Int(size)
            guard offset + elementSize <= data.count else {
                throw OBUAssemblerError.elementOverflow
            }

            let element = data[data.startIndex + offset..<data.startIndex + offset + elementSize]
            elements.append(Data(element))
            offset += elementSize
        }

        return elements
    }

    /// W=1/2/3: Fixed count of elements. Last element's size is implicit (to end of payload).
    private func extractFixedCountElements(_ data: Data, count: Int) throws -> [Data] {
        guard count >= 1 && count <= 3 else {
            throw OBUAssemblerError.invalidElementCount(count)
        }

        var elements = [Data]()
        var offset = 0

        // For W>1, all elements except the last have leb128 size prefixes
        for i in 0..<count {
            if i < count - 1 {
                // Non-last element: has leb128 size
                let (size, bytesRead) = try LEB128.decode(data, offset: offset)
                offset += bytesRead

                let elementSize = Int(size)
                guard offset + elementSize <= data.count else {
                    throw OBUAssemblerError.elementOverflow
                }

                let element = data[data.startIndex + offset..<data.startIndex + offset + elementSize]
                elements.append(Data(element))
                offset += elementSize
            } else {
                // Last element: implicit size (everything remaining)
                guard offset < data.count else {
                    throw OBUAssemblerError.elementOverflow
                }
                let element = data[data.startIndex + offset..<data.endIndex]
                elements.append(Data(element))
            }
        }

        return elements
    }
}

public enum OBUAssemblerError: Error, Equatable {
    case emptyPayload
    case elementOverflow
    case invalidElementCount(Int)
}
