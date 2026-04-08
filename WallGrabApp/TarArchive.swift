import Foundation

struct TarArchive {
    enum ArchiveError: LocalizedError {
        case invalidData
        case missingEntry(String)

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "The Apple resources archive could not be read."
            case .missingEntry(let name):
                return "The archive did not contain \(name)."
            }
        }
    }

    private let data: Data

    init(data: Data) {
        self.data = data
    }

    func data(for path: String) throws -> Data {
        var offset = 0

        while offset + 512 <= data.count {
            let header = data[offset..<(offset + 512)]
            if header.allSatisfy({ $0 == 0 }) {
                break
            }

            let name = string(in: header, offset: 0, length: 100)
            let sizeString = string(in: header, offset: 124, length: 12)
            let size = Int(sizeString.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), radix: 8) ?? 0

            let bodyOffset = offset + 512
            let paddedSize = ((size + 511) / 512) * 512
            guard bodyOffset + paddedSize <= data.count else {
                throw ArchiveError.invalidData
            }

            if name == path {
                return data.subdata(in: bodyOffset..<(bodyOffset + size))
            }

            offset = bodyOffset + paddedSize
        }

        throw ArchiveError.missingEntry(path)
    }

    private func string(in header: Data.SubSequence, offset: Int, length: Int) -> String {
        let start = header.index(header.startIndex, offsetBy: offset)
        let end = header.index(start, offsetBy: length)
        let slice = header[start..<end].prefix { $0 != 0 }
        return String(decoding: slice, as: UTF8.self)
    }
}
