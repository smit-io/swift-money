// Example usage of MoneyKit
// This file demonstrates common use cases and patterns

import Foundation
import MoneyKit

// MARK: - Basic Usage

func basicExamples() throws {
    print("=== Basic Usage ===\n")

    // Create money values
    let price = try Money(amount: 1999, currency: .USD)
    print("Product price: \(price.formatted)")  // $19.99

    // From currency code
    let shipping = try Money(amount: 500, currencyCode: "USD")
    print("Shipping: \(shipping.formatted)")  // $5.00

    // From decimal amount
    let tax = try Money(decimalAmount: 1.59, currency: .USD)
    print("Tax: \(tax.formatted)\n")  // $1.59
}

// MARK: - E-commerce Checkout

func ecommerceCheckout() throws {
    print("=== E-commerce Checkout ===\n")

    let productPrice = try Money(amount: 4999, currency: .USD)
    let shipping = try Money(amount: 500, currency: .USD)
    let subtotal = try productPrice + shipping

    print("Product: \(productPrice.formatted)")
    print("Shipping: \(shipping.formatted)")
    print("Subtotal: \(subtotal.formatted)")

    // Calculate tax (8%)
    let taxRate = Decimal(0.08)
    let tax = try subtotal.percentage(taxRate)
    print("Tax (8%): \(tax.formatted)")

    // Calculate total
    let total = try subtotal + tax
    print("Total: \(total.formatted)\n")
}

// MARK: - Payment API Integration

func paymentApiIntegration() throws {
    print("=== Payment API Integration ===\n")

    let orderTotal = try Money(decimalAmount: 49.99, currency: .USD)

    // Prepare payment charge parameters
    let chargeAmount = orderTotal.amount  // 4999 (cents)
    let chargeCurrency = orderTotal.currency.code.lowercased()  // "usd"

    print("Payment charge amount: \(chargeAmount)")
    print("Payment charge currency: \(chargeCurrency)")

    // Calculate processing fees (2.9% + $0.30)
    let percentageFee = try orderTotal.percentage(0.029)
    let fixedFee = try Money(amount: 30, currency: .USD)
    let totalFee = try percentageFee + fixedFee

    print("Processing fee: \(totalFee.formatted)")

    let netAmount = try orderTotal - totalFee
    print("Net amount: \(netAmount.formatted)\n")
}

// MARK: - Bill Splitting

func billSplitting() throws {
    print("=== Bill Splitting ===\n")

    let billTotal = try Money(amount: 15273, currency: .USD)
    print("Bill total: \(billTotal.formatted)")

    // Split equally among 4 people
    let split = try billTotal.distribute(into: 4)

    print("Split among 4 people:")
    for (index, amount) in split.enumerated() {
        print("  Person \(index + 1): \(amount.formatted)")
    }

    // Verify sum
    let sum = try split.reduce(try Money(amount: 0, currency: .USD)) { try $0 + $1 }
    print("Verification - Sum equals total: \(sum == billTotal)\n")
}

// MARK: - Revenue Sharing

func revenueSharing() throws {
    print("=== Revenue Sharing ===\n")

    let revenue = try Money(amount: 100000, currency: .USD)
    print("Total revenue: \(revenue.formatted)")

    // Allocate: 60% company, 30% partner, 10% affiliate
    let allocation = try revenue.allocate(by: [60, 30, 10])

    print("Company (60%): \(allocation[0].formatted)")
    print("Partner (30%): \(allocation[1].formatted)")
    print("Affiliate (10%): \(allocation[2].formatted)\n")
}

// MARK: - Multi-Currency Example

func multiCurrency() throws {
    print("=== Multi-Currency Example ===\n")

    // Different currencies with different decimal places
    let usd = try Money(amount: 1999, currency: .USD)  // 2 decimals
    let jpy = try Money(amount: 1000, currency: .JPY)  // 0 decimals
    let kwd = try Money(amount: 1234, currency: .KWD)  // 3 decimals

    print("USD amount: \(usd.formatted) (\(usd.decimalAmount))")
    print("JPY amount: \(jpy.formatted) (\(jpy.decimalAmount))")
    print("KWD amount: \(kwd.formatted) (\(kwd.decimalAmount))")

    // Safe operations across currencies
    if let result = usd.tryAdd(jpy) {
        print("Sum: \(result.formatted)")
    } else {
        print("Cannot add USD and JPY (different currencies)\n")
    }
}

// MARK: - Discount Calculations

func discountCalculations() throws {
    print("=== Discount Calculations ===\n")

    let originalPrice = try Money(amount: 10000, currency: .USD)
    print("Original price: \(originalPrice.formatted)")

    // 20% off
    let discountRate = Decimal(0.20)
    let discount = try originalPrice.percentage(discountRate)
    print("Discount (20%): \(discount.formatted)")

    let salePrice = try originalPrice - discount
    print("Sale price: \(salePrice.formatted)\n")
}

// MARK: - Subscription Pricing

func subscriptionPricing() throws {
    print("=== Subscription Pricing ===\n")

    let monthlyPrice = try Money(amount: 999, currency: .USD)
    print("Monthly: \(monthlyPrice.formatted)")

    // Annual pricing (12 months with 2 months free)
    let annualPrice = try monthlyPrice * 10
    print("Annual (10 months): \(annualPrice.formatted)")

    let monthlySavings = try monthlyPrice * 2
    print("Annual savings: \(monthlySavings.formatted)\n")
}

// MARK: - Bulk Discount

func bulkDiscount() throws {
    print("=== Bulk Discount ===\n")

    let unitPrice = try Money(amount: 2500, currency: .USD)
    let quantity = 5

    let subtotal = try unitPrice * quantity
    print("Unit price: \(unitPrice.formatted)")
    print("Quantity: \(quantity)")
    print("Subtotal: \(subtotal.formatted)")

    // 10% bulk discount
    let discount = try subtotal.percentage(0.10)
    let total = try subtotal - discount

    print("Bulk discount (10%): \(discount.formatted)")
    print("Total: \(total.formatted)\n")
}

// MARK: - Currency Formatting

func currencyFormatting() throws {
    print("=== Currency Formatting ===\n")

    let amount = try Money(amount: 123456, currency: .USD)

    // Different locales
    let usLocale = Locale(identifier: "en_US")
    let deLocale = Locale(identifier: "de_DE")
    let jpLocale = Locale(identifier: "ja_JP")

    print("US format: \(amount.formatted(locale: usLocale))")
    print("German format: \(amount.formatted(locale: deLocale))")
    print("Japanese format: \(amount.formatted(locale: jpLocale))")
    print("Numeric only: \(amount.numericString)\n")
}

// MARK: - Main

func runExamples() {
    do {
        try basicExamples()
        try ecommerceCheckout()
        try paymentApiIntegration()
        try billSplitting()
        try revenueSharing()
        try multiCurrency()
        try discountCalculations()
        try subscriptionPricing()
        try bulkDiscount()
        try currencyFormatting()
    } catch {
        print("Error: \(error)")
    }
}

// Uncomment to run examples:
// runExamples()
