import Driver
import SwiftyLLVM
import XCTest

final class TargetSpecificationTests: XCTestCase {

  func testDriverCreation() throws {
    let driver = try Driver(targetSpecification: .host())
    XCTAssertFalse(driver.target.cpu.isEmpty)
  }

  func testDriverWithOptions() throws {
    let driver = try Driver(
      targetSpecification: .host(),
      optimization: .aggressive,
      relocation: .pic,
      codeModel: .small)
    XCTAssertEqual(driver.optimization, .aggressive)
    XCTAssertEqual(driver.relocation, .pic)
    XCTAssertEqual(driver.codeModel, .small)
  }

}
