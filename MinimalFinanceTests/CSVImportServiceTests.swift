import XCTest
@testable import MinimalFinance

final class CSVImportServiceTests: XCTestCase {
    func testParsesTDHeaderlessDebitCreditFormat() {
        let contents = """
        01/05/2024,STARBUCKS #1234,4.50,
        01/06/2024,PAYCHECK DEPOSIT,,1500.00
        """

        let (mapping, rows) = CSVImportService.parse(contents: contents)

        XCTAssertEqual(mapping.formatLabel, "TD")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].merchant, "STARBUCKS #1234")
        XCTAssertEqual(rows[0].amount, 4.50)
        XCTAssertEqual(rows[0].kind, .expense)
        XCTAssertEqual(rows[1].kind, .income)
        XCTAssertEqual(rows[1].amount, 1500.00)
    }

    func testParsesGenericHeaderedDebitCreditFormat() {
        let contents = """
        Date,Description,Debit,Credit
        2024-01-05,Grocery Store,25.00,
        2024-01-06,Refund,,10.00
        """

        let (mapping, rows) = CSVImportService.parse(contents: contents)

        XCTAssertEqual(mapping.formatLabel, "Generic CSV")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].kind, .expense)
        XCTAssertEqual(rows[0].amount, 25.00)
        XCTAssertEqual(rows[1].kind, .income)
        XCTAssertEqual(rows[1].amount, 10.00)
    }

    func testParsesWealthsimpleSignedAmountFormat() {
        let contents = """
        transaction_date,name,net_cash_amount,activity_type,activity_sub_type,direction
        2024-01-05,STARBUCKS,-4.50,SPEND,,out
        2024-01-06,PAYCHECK,1500.00,DEPOSIT,,in
        """

        let (mapping, rows) = CSVImportService.parse(contents: contents)

        XCTAssertEqual(mapping.formatLabel, "Wealthsimple")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].merchant, "STARBUCKS")
        XCTAssertEqual(rows[0].amount, 4.50)
        XCTAssertEqual(rows[0].kind, .expense)
        XCTAssertEqual(rows[1].amount, 1500.00)
        XCTAssertEqual(rows[1].kind, .income)
    }

    func testHandlesQuotedFieldsWithEmbeddedCommas() {
        let contents = """
        Date,Description,Debit,Credit
        2024-01-05,"Coffee, Inc.",5.00,
        """

        let (_, rows) = CSVImportService.parse(contents: contents)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].merchant, "Coffee, Inc.")
    }

    func testIgnoresMetadataRows() {
        let contents = """
        Date,Description,Debit,Credit
        As of 2024-01-07
        2024-01-05,Grocery Store,25.00,
        """

        let (_, rows) = CSVImportService.parse(contents: contents)

        XCTAssertEqual(rows.count, 1)
    }

    func testEmptyContentsProducesNoRows() {
        let (_, rows) = CSVImportService.parse(contents: "")
        XCTAssertTrue(rows.isEmpty)
    }
}
