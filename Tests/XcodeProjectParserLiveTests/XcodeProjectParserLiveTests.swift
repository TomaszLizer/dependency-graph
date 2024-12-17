@testable import XcodeProject
@testable import XcodeProjectParserLive
import FileSystemLive
import XCTest

final class XcodeProjectParserLiveTests: XCTestCase {
    func testParsesProjectName() throws {
        let parser = XcodeProjectParserLive(fileSystem: FileSystemMock())
        let xcodeProject = try parser.parseProject(at: URL.Mock.exampleXcodeProject)
        XCTAssertEqual(xcodeProject.name, "Example.xcodeproj")
    }

    func testParsesTargets() throws {
        let parser = XcodeProjectParserLive(fileSystem: FileSystemMock())
        let xcodeProject = try parser.parseProject(at: URL.Mock.exampleXcodeProject)
        let exampleTarget = xcodeProject.targets.first { $0.name == "Example" }
        let exampleTestsTarget = xcodeProject.targets.first { $0.name == "ExampleTests" }
        let exampleUITestsTarget = xcodeProject.targets.first { $0.name == "ExampleUITests" }
        XCTAssertNotNil(exampleTarget)
        XCTAssertNotNil(exampleTestsTarget)
        XCTAssertNotNil(exampleUITestsTarget)
    }

    func testParsesTargetPackageProductDependencies() throws {
        let parser = XcodeProjectParserLive(fileSystem: FileSystemMock())
        let xcodeProject = try parser.parseProject(at: URL.Mock.exampleXcodeProject)
        let exampleTarget = xcodeProject.targets.first { $0.name == "Example" }
        let packageProductDependencies = exampleTarget?.packageProductDependencies ?? []
        XCTAssertTrue(packageProductDependencies.contains("Runestone"))
        XCTAssertTrue(packageProductDependencies.contains("TreeSitterJSONRunestone"))
        XCTAssertTrue(packageProductDependencies.contains("TreeSitterJavaScriptRunestone"))
        XCTAssertTrue(packageProductDependencies.contains("ExampleLibraryA"))
        XCTAssertTrue(packageProductDependencies.contains("ExampleLibraryB"))
    }

    func testSwiftPackageCount() throws {
        // The example project contains 5 Swift packages:
        // 2 remote and 3 local (2 of which are nested in group)
        let parser = XcodeProjectParserLive(fileSystem: FileSystemLive())
        let xcodeProject = try parser.parseProject(at: URL.Mock.exampleXcodeProject)
        XCTAssertEqual(xcodeProject.swiftPackages.count, 5)
    }

    func testParsesLocalSwiftPackage() throws {
        let parser = XcodeProjectParserLive(fileSystem: FileSystemMock())
        let xcodeProject = try parser.parseProject(at: URL.Mock.exampleXcodeProject)
        let swiftPackage = xcodeProject.swiftPackages.first { $0.name == "ExamplePackageA" }
        XCTAssertNotNil(swiftPackage)
        if case let .local(parameters) = swiftPackage {
            XCTAssertEqual(parameters.name, "ExamplePackageA")
            let fileURLHasPackageSwiftSuffix = parameters.fileURL.absoluteString.hasSuffix("ExamplePackageA/Package.swift")
            XCTAssertTrue(fileURLHasPackageSwiftSuffix, "Expected file URL to end with the package name and Package.swift")
        } else {
            XCTFail("Expected ExamplePackageA to be a local package")
        }
    }
    
    func testParsesLocalSwiftPackageInNestedGroupDirectory() throws {
        let parser = XcodeProjectParserLive(fileSystem: FileSystemLive())
        let xcodeProject = try parser.parseProject(at: URL.Mock.exampleXcodeProject)
        let swiftPackage = xcodeProject.swiftPackages.first { $0.name == "ExamplePackageB" }
        XCTAssertNotNil(swiftPackage)
        if case let .local(parameters) = swiftPackage {
            XCTAssertEqual(parameters.name, "ExamplePackageB")
            let fileURLHasPackageSwiftSuffix = parameters.fileURL.absoluteString.hasSuffix("NestedPackages/ExamplePackageB/Package.swift")
            XCTAssertTrue(fileURLHasPackageSwiftSuffix, "Expected file URL to end with the package name and Package.swift")
        } else {
            XCTFail("Expected ExamplePackageB to be a local package")
        }
    }

    func testParsesRemoteSwiftPackageWithSingleProduct() throws {
        let parser = XcodeProjectParserLive(fileSystem: FileSystemMock())
        let xcodeProject = try parser.parseProject(at: URL.Mock.exampleXcodeProject)
        let swiftPackage = xcodeProject.swiftPackages.first { $0.name == "Runestone" }
        XCTAssertNotNil(swiftPackage)
        if case let .remote(parameters) = swiftPackage {
            XCTAssertEqual(parameters.name, "Runestone")
            XCTAssertEqual(parameters.repositoryURL, URL(string: "https://github.com/simonbs/Runestone"))
            XCTAssertEqual(parameters.products, ["Runestone"])
        } else {
            XCTFail("Expected Runestone to be a remote package")
        }
    }

    func testParsesRemoteSwiftPackageWithMultipleProducts() throws {
        let parser = XcodeProjectParserLive(fileSystem: FileSystemMock())
        let xcodeProject = try parser.parseProject(at: URL.Mock.exampleXcodeProject)
        let swiftPackage = xcodeProject.swiftPackages.first { $0.name == "TreeSitterLanguages" }
        XCTAssertNotNil(swiftPackage)
        if case let .remote(parameters) = swiftPackage {
            XCTAssertEqual(parameters.name, "TreeSitterLanguages")
            XCTAssertEqual(parameters.repositoryURL, URL(string: "git@github.com:simonbs/TreeSitterLanguages.git"))
            XCTAssertTrue(parameters.products.contains("TreeSitterJSONRunestone"))
            XCTAssertTrue(parameters.products.contains("TreeSitterJavaScriptRunestone"))
        } else {
            XCTFail("Expected TreeSitterLanguages to be a remote package")
        }
    }
}

private extension URL {
    enum Mock {
        static let exampleXcodeProject = Bundle.module.url(forResource: "Example/Example", withExtension: "xcodeproj")!
    }
}
