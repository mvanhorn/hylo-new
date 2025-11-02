import Archivist
import FrontEnd
import XCTest

final class ProgramTests: XCTestCase {

  func testSelectAll() throws {
    let p = Program.test
    XCTAssertEqual(p.select(.all).count, 8)
  }

  func testSelectByModule() throws {
    let p = Program.test
    let m = p.identity(module: .init("M0"))!
    XCTAssertEqual(p.select(from: m, .all).count, 4)
  }

  func testSelectByTag() throws {
    let p = Program.test
    XCTAssertEqual(p.select(.tag(AssociatedTypeDeclaration.self)).count, 4)
  }

  func testFormat() throws {
    let p = Program.test
    let v = AnyTypeIdentity.void
    XCTAssertEqual(p.format("> xy <", []), "> xy <")
    XCTAssertEqual(p.format("> %S, %S <", [10, true]), "> 10, true <")
    XCTAssertEqual(p.format("> %T <", [v]), "> Void <")
    XCTAssertEqual(p.format("> %T* <", [[v, v]]), "> Void, Void <")
    XCTAssertEqual(p.format("> %% <", [v]), "> % <")
  }

  func testArchiveConsistency() throws {
    let p = Program.test
    let m = p.moduleIdentities.first!

    var w1 = WriteableArchive(BinaryBuffer())
    try p.write(module: m, to: &w1)
    var w2 = WriteableArchive(BinaryBuffer())
    try p.write(module: m, to: &w2)
    XCTAssertEqual(w1.finalize(), w2.finalize())
  }

  func testSerializationRoundTrip() throws {
    let p = Program.test
    let m = p.moduleIdentities.first!
    let a = try p.archive(module: m)

    var q = Program()
    let (loaded, n) = try q.load(module: p[m].name, from: a)

    // Syntax trees should have the same identities.
    XCTAssert(loaded)
    XCTAssertEqual(p[m].name, q[n].name)
    for (l, r) in zip(p.select(from: m, .all), q.select(from: n, .all)) {
      assertIsomorphic(l, r)
    }

    /// Asserts that `l` and `r`, which are in `p` and `q` respectively, are equal up to renaming
    /// of tree identities.
    func assertIsomorphic(_ l: AnySyntaxIdentity, _ r: AnySyntaxIdentity) {
      XCTAssert(p[l].equals(q[r]))
    }
  }

  func testVisitSourceFile() async throws {
    struct Collector: SyntaxVisitor {
      var entered: [SyntaxTag] = []
      var exited: [SyntaxTag] = []

      mutating func willEnter(_ node: AnySyntaxIdentity, in program: Program) -> Bool {
        entered.append(program.tag(of: node))
        return true
      }

      mutating func willExit(_ node: AnySyntaxIdentity, in program: Program) {
        exited.append(program.tag(of: node))
      }
    }

    var p = Program()
    let m = p.demandModule(.init("TestModule"))
    let (_, f) = p[m].addSource(
      """
      trait P {
        type X
        type Y
      }
      """)
    for mod in p.moduleIdentities { await p.assignScopes(mod) }

    var collector = Collector()
    p.visit(f, calling: &collector)

    // Pre-order traversal: TraitDeclaration first, then its two AssociatedTypeDeclaration members.
    XCTAssertEqual(
      collector.entered,
      [
        SyntaxTag(TraitDeclaration.self),
        SyntaxTag(AssociatedTypeDeclaration.self),
        SyntaxTag(AssociatedTypeDeclaration.self),
      ])
    
    XCTAssertEqual(
      collector.exited,
      [
        SyntaxTag(AssociatedTypeDeclaration.self),
        SyntaxTag(AssociatedTypeDeclaration.self),
        SyntaxTag(TraitDeclaration.self),
      ])
  }

  func testSerializationWithDependencies() throws {
    let p = Program.test

    var archives: [(identity: Module.ID, data: BinaryBuffer)] = []
    for m in p.moduleIdentities {
      try archives.append((m, p.archive(module: m)))
    }

    var q = Program()

    // Re-load modules out of order.
    var loaded = false
    (loaded, _) = try q.load(module: p[archives[0].identity].name, from: archives[0].data)
    XCTAssert(loaded)
    (loaded, _) = try q.load(module: p[archives[2].identity].name, from: archives[2].data)
    XCTAssert(loaded)
    (loaded, _) = try q.load(module: p[archives[1].identity].name, from: archives[1].data)
    XCTAssert(loaded)
  }

}
