import Foundation
import Combine

@available(iOS 13, *)
public class DocumentsFolder<T>: ObservableObject where T: Codable, T: CustomStringConvertible {
	
	@Published public private(set) var objects = Array<T>()
	
	public init() {
		guard let url = FM.urls(
			for: .documentDirectory,
			in: .userDomainMask
		).first else { fatalError("Documents Folder Missing") }
		self.url = url
		self.fileExtension = "." + String(describing: T.self).lowercased()
		self.decoder = JSONDecoder()
		self.encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		source = DispatchSource.makeFileSystemObjectSource(
			fileDescriptor: open(url.path, O_EVTONLY),
			eventMask: .all,
			queue: DispatchQueue.global(qos: .utility))
		source.setEventHandler { self.load() }
		source.resume()
		load()
	}
	
	public func copy(from url: URL) throws {
		let localURL = url.appendingPathComponent(url.lastPathComponent)
		if url.path.contains(localURL.path) { return }
		if FM.fileExists(atPath: localURL.path) { try FM.removeItem(at: localURL) }
		try FM.copyItem(at: url, to: localURL)
	}
	
	public func download(from url: URL, fileName: String) throws {
		URLSession.shared.dataTask(with: url) { data, response, error in
			try? data?.write(to: self.url.appendingPathComponent(fileName))
		}.resume()
	}
	
	public func save(_ object: T) throws {
		let data = try encoder.encode(object)
		try data.write(to: url(for: object))
		load()
	}
	
	public func delete(at offsets: IndexSet) {
		offsets.forEach { delete(objects[$0]) }
	}
	
	public func delete(_ object: T) {
		try? FM.removeItem(at: url(for: object))
	}
	
	public func object(_ name: String) -> T? {
		let path = url.appendingPathComponent(name + fileExtension).path
		let data = FM.contents(atPath: path) ?? Data()
		return try? decoder.decode(T.self, from: data)
	}
	
	//MARK: Implementation
	let FM = FileManager.default
	let source: DispatchSourceFileSystemObject
	let url: URL
	let fileExtension: String
	let decoder: JSONDecoder
	let encoder: JSONEncoder
	
	func url(for object: T) -> URL {
		url.appendingPathComponent(object.description + fileExtension)
	}
	
	func load() {
		if let contents = try? FM.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
			DispatchQueue.main.async {
				self.objects = contents
					.filter { $0.lastPathComponent.hasSuffix(self.fileExtension) }
					.compactMap {
						guard let data = FileManager.default.contents(atPath: $0.path) else { return nil }
						return try? JSONDecoder().decode(T.self, from: data)
					}
					.sorted { $0.description < $1.description }
			}
		}
		
	}
}
