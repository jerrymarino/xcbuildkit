import Foundation

// Credits to: https://gist.github.com/ngbaanh/7c437d99bea75161a59f5af25be99de4
public class BPlistConverter {
    struct PlistMimeType {
        static let xmlPlist    = "text/x-apple-plist+xml"
        static let binaryPlist = "application/x-apple-binary-plist"
    }

    //// Visible Stuffs ////////////////////////////////////////////////////////
    public convenience init?(binaryData: Data, quiet: Bool = true) {
        self.init(binaryData, format: .binaryFormat_v1_0, quiet: quiet)
    }

    public convenience init?(xml: String, quiet: Bool = true) {
        guard let xmlData = xml.data(using: .utf8) else { return nil }
        self.init(xmlData, format: .xmlFormat_v1_0, quiet: quiet)
    }

    public func convertToXML() -> String? {
        guard let xmlData = convert(to: .xmlFormat_v1_0) else { return nil }
        return String.init(data: xmlData, encoding: .utf8)
    }

    public func convertToBinary() -> Data? {
        return convert(to: .binaryFormat_v1_0)
    }

    ////////////////////////////////////////////////////////////////////////////
    //// Private ///////////////////////////////////////////////////////////////
    private var plist: CFPropertyList?                                        //
                                                                              //
    private init?(_ data: Data,                                               //
                    format: CFPropertyListFormat,                             //
                    quiet: Bool = true) {                                     //
        var dataBytes = Array(data)                                           //
        let plistCoreData = CFDataCreate(kCFAllocatorDefault,                 //
                                         &dataBytes, dataBytes.count)         //
                                                                              //
        var error: Unmanaged<CFError>?                                        //
        var inputFormat = format                                              //
        let options = CFPropertyListMutabilityOptions                         //
                            .mutableContainersAndLeaves.rawValue              //
        plist = CFPropertyListCreateWithData(kCFAllocatorDefault,             //
                                             plistCoreData,                   //
                                             options,                         //
                                             &inputFormat,                    //
                                             &error)?.takeUnretainedValue()   //
        guard plist != nil, nil == error else {                               //
            if !quiet {                                                       //
                print("Error on CFPropertyListCreateWithData : ",             //
                  error!.takeUnretainedValue(), "Return nil")                 //
            }                                                                 //
            error?.release()                                                  //
            return nil                                                        //
        }                                                                     //
        error?.release()                                                      //
    }                                                                         //
                                                                              //
    private func convert(to format: CFPropertyListFormat) -> Data? {          //
        var error: Unmanaged<CFError>?                                        //
        let binary = CFPropertyListCreateData(kCFAllocatorDefault,            //
                                              plist, format,                  //
                                              0, // unused, set 0             //
                                              &error)?.takeUnretainedValue()  //
        let data = Data.init(bytes: CFDataGetBytePtr(binary),                 //
                             count: CFDataGetLength(binary))                  //
        error?.release()                                                      //
        return data                                                           //
    }                                                                         //
                                                                              //
    ////////////////////////////////////////////////////////////////////////////
}