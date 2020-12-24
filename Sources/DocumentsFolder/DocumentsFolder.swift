import Foundation
import Combine

@available(iOS 13, *)
class DocumentsFolder<T>: ObservableObject where T: Codable, T: CustomStringConvertible {
	
	//MARK: Interface
	@Published private(set) var objects = Array<T>()
	
	init(fileExtension: String) {
		guard let documents = FM.urls(
			for: .documentDirectory,
			in: .userDomainMask
		).first else { fatalError("Documents Folder Missing") }
		self.documents = documents
		self.fileExtension = fileExtension
		let fileDescriptor = open(documents.path, O_EVTONLY)
		source = DispatchSource.makeFileSystemObjectSource(
			fileDescriptor: fileDescriptor,
			eventMask: .all,
			queue: DispatchQueue.global(qos: .utility))
		source.setEventHandler { self.load() }
		source.resume()
		load()
	}
	
	func importFile(from url: URL) throws {
		let localURL = documents.appendingPathComponent(url.lastPathComponent)
		if url.path.contains(localURL.path) { return }
		if FM.fileExists(atPath: localURL.path) { try FM.removeItem(at: localURL) }
		try FM.copyItem(at: url, to: localURL)
	}
	
	func downloadFile(from url: URL, fileName: String) throws {
		URLSession.shared.dataTask(with: url) { data, response, error in
			guard let data = data else { return }
			try? data.write(to: self.documents.appendingPathComponent(fileName))
		}.resume()
	}
	
	func save(_ object: T) throws {
		let data = try JSONEncoder().encode(object)
		try data.write(to: documents.appendingPathComponent(object.description + "." + fileExtension))
		load()
	}
	
	func delete(at offsets: IndexSet) {
		for index in offsets {
			let object = objects[index]
			try? FM.removeItem(at: documents.appendingPathComponent(object.description + "." + fileExtension))
		}
	}
	
	//MARK: Implementation
	private let FM = FileManager.default
	private let source: DispatchSourceFileSystemObject
	private let documents: URL
	private let fileExtension: String
	
	private func load() {
		guard let contents = try? FM.contentsOfDirectory(
			at: documents,
			includingPropertiesForKeys: nil,
			options: .skipsHiddenFiles
		) else { return }
		DispatchQueue.main.async {
			self.objects = contents
				.filter { $0.lastPathComponent.hasSuffix("." + self.fileExtension) }
				.compactMap {
					guard let data = FileManager.default.contents(atPath: $0.path) else { return nil }
					return try? JSONDecoder().decode(T.self, from: data)
				}
				.sorted { $0.description < $1.description }
		}
	}
}
