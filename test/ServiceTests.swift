import Foundation
import MessagePack

// TODO: port this to Bazel test. It's mostly a collection of raw testing
// functions with no assertions

static func dumpDebug(_ values: [XCBRawValue]) {
    values.forEach {
        print($0)
    }
}

func testSerialization() {
    let implicitValue: XCBRawValue = [nil, "Inspiration...", -1.0, true]
    let data = pack(implicitValue)
    print(data.hbytes())
}

func getExample(path: String) -> Data {
    let basePath = "" // TODO
    return try! Data(contentsOf: URL(fileURLWithPath:basePath + "/" + path))
}

func testParseEntireOutputStream() {
    let result = Unpacker.unpackAll(getExample(path:
        "example_output/clean-end-to-end/xcbuild.out"))
    print(result.count) // 586
}

func testParseEntireInputStream() {
    let result = Unpacker.unpackAll(getExample(path:
        "example_output/clean-end-to-end/xcbuild.in"))
    print(result.count) // 108
    dumpDebug(result)
}

func testParseEntireInputStream2() {
    var data = try! Data(contentsOf: URL(fileURLWithPath:"//tmp/xcbuild.in"))
    let result = Unpacker.unpackAll(data)
    print(result.count) // 108
    dumpDebug(result)
}

// TODO: come up with a way to test fragments
func testResponseCompletion() {
    //let v = BasicResponseHandler.completeResponse2([XCBRawValue]().makeIterator())
    //XCBService.write(v)
}

