import Foundation

enum ReaderDisplayMode:String,CaseIterable,Identifiable { case read, original; var id:Self{self}; var title:String{self == .read ? "Read" : "Original"} }
struct ReadableBlock:Identifiable,Equatable { enum Kind:Equatable{case heading,paragraph,bullet,code}; let id=UUID(); let kind:Kind; let text:String }
struct ReadablePage:Equatable {
    let pageIndex:Int
    let blocks:[ReadableBlock]
    var sourceIntegrityPassed = false
    var spokenText:String{blocks.map(\.text).joined(separator:". ")}
}
