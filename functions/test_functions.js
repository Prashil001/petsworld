const assert = require("assert");
const { _test } = require("./index.js");

console.log("Running Firebase Functions unit tests...\n");

// 1. resolvePackIndex tests
const packOptions = [
  { id: "opt_1", label: "1kg", stockQuantity: 10, isDefault: true },
  { id: "opt_2", label: "5kg", stockQuantity: 5, isDefault: false },
  { id: "opt_3", label: "10kg", stockQuantity: 2, isDefault: false },
];

// Test 1a: selectedOptionId is "default" -> should match isDefault pack (index 0)
const defaultResult = _test.resolvePackIndex(packOptions, { selectedOptionId: "default" });
assert.strictEqual(defaultResult, 0, "Failed: 'default' should resolve to isDefault pack");
console.log("✓ resolvePackIndex resolves 'default' to isDefault pack (index 0)");

// Test 1b: selectedOptionId is "" -> should match isDefault pack (index 0)
const emptyResult = _test.resolvePackIndex(packOptions, { selectedOptionId: "" });
assert.strictEqual(emptyResult, 0, "Failed: empty selectedOptionId should resolve to isDefault pack");
console.log("✓ resolvePackIndex resolves empty selectedOptionId to isDefault pack");

// Test 1c: exact ID match
const exactResult = _test.resolvePackIndex(packOptions, { selectedOptionId: "opt_2" });
assert.strictEqual(exactResult, 1, "Failed: exact ID should match index 1");
console.log("✓ resolvePackIndex resolves exact ID match");

// Test 1d: label match when ID is unknown
const labelResult = _test.resolvePackIndex(packOptions, { selectedOptionId: "unknown", selectedOptionLabel: "10kg" });
assert.strictEqual(labelResult, 2, "Failed: label match should resolve to index 2");
console.log("✓ resolvePackIndex resolves label fallback match");

// Test 1e: unknown ID and unknown label
const unknownResult = _test.resolvePackIndex(packOptions, { selectedOptionId: "unknown", selectedOptionLabel: "unknown" });
assert.strictEqual(unknownResult, -1, "Failed: unknown option should return -1");
console.log("✓ resolvePackIndex returns -1 for unknown option");

// 2. truncateTelegramMessage tests
const shortMsg = "Short test message";
assert.strictEqual(_test.truncateTelegramMessage(shortMsg), shortMsg);
console.log("✓ truncateTelegramMessage leaves short messages untouched");

const longMsg = "A".repeat(5000);
const truncated = _test.truncateTelegramMessage(longMsg, 4000);
assert(truncated.length <= 4000, "Truncated message should be <= 4000 chars");
assert(truncated.includes("[Message truncated]"), "Truncated message should include note");
console.log("✓ truncateTelegramMessage safely caps messages at limit");

// 3. shouldDecrementStockForOrder tests
assert.strictEqual(
  _test.shouldDecrementStockForOrder({ paymentMethod: "cod", paymentStatus: "pending" }),
  true,
  "COD orders should decrement stock immediately"
);
assert.strictEqual(
  _test.shouldDecrementStockForOrder({ paymentMethod: "razorpay", paymentStatus: "pending" }),
  false,
  "Pending Razorpay orders should NOT decrement stock"
);
assert.strictEqual(
  _test.shouldDecrementStockForOrder({ paymentMethod: "razorpay", paymentStatus: "paid" }),
  true,
  "Paid Razorpay orders should decrement stock"
);
assert.strictEqual(
  _test.shouldDecrementStockForOrder({ paymentMethod: "cod", orderStatus: "cancelled" }),
  false,
  "Cancelled orders should NOT decrement stock"
);
console.log("✓ shouldDecrementStockForOrder handles COD, pending Razorpay, paid Razorpay, and cancelled correctly");

// 4. getTelegramConfig tests
process.env.TELEGRAM_BOT_TOKEN = "test_token";
process.env.TELEGRAM_CHAT_ID = "test_chat_id";
const config = _test.getTelegramConfig();
assert.strictEqual(config.token, "test_token");
assert.strictEqual(config.chatId, "test_chat_id");
delete process.env.TELEGRAM_BOT_TOKEN;
delete process.env.TELEGRAM_CHAT_ID;
console.log("✓ getTelegramConfig safely falls back to environment variables without throwing");

// 5. decrementPackStock and incrementPackStock tests
const product = { id: "p1", stockQuantity: 10, packOptions: [
  { id: "opt_1", label: "1kg", stockQuantity: 10, isDefault: true },
  { id: "opt_2", label: "5kg", stockQuantity: 5, isDefault: false },
]};
const stockIssues = [];
const decResult = _test.decrementPackStock({
  product,
  packOptions: product.packOptions.map(p => ({ ...p })),
  items: [{ selectedOptionId: "default", quantity: 3 }],
  productId: "p1",
  stockIssues,
});

assert.strictEqual(decResult.packOptions[0].stockQuantity, 7, "Default pack stock should be 7");
assert.strictEqual(decResult.stockQuantity, 7, "Primary pack stockQuantity should be updated to 7");
assert.strictEqual(stockIssues.length, 0, "No stock issues should be logged");
console.log("✓ decrementPackStock accurately decrements default pack stock");

const incResult = _test.incrementPackStock({
  product,
  packOptions: decResult.packOptions.map(p => ({ ...p })),
  items: [{ selectedOptionId: "default", quantity: 3 }],
});
assert.strictEqual(incResult.packOptions[0].stockQuantity, 10, "Default pack stock should be restored to 10");
assert.strictEqual(incResult.stockQuantity, 10, "Primary pack stockQuantity should be restored to 10");
// 6. Razorpay configuration and signature verification tests
process.env.RAZORPAY_KEY_ID = "rzp_test_123";
process.env.RAZORPAY_KEY_SECRET = "secret_key_456";
const rzpConfig = _test.getRazorpayConfig();
assert.strictEqual(rzpConfig.keyId, "rzp_test_123");
assert.strictEqual(rzpConfig.keySecret, "secret_key_456");
delete process.env.RAZORPAY_KEY_ID;
delete process.env.RAZORPAY_KEY_SECRET;
console.log("✓ getRazorpayConfig safely retrieves credentials from env fallback");

const crypto = require("crypto");
const testOrderId = "order_123456";
const testPaymentId = "pay_789012";
const testSecret = "my_razorpay_secret";
const validSignature = crypto
  .createHmac("sha256", testSecret)
  .update(`${testOrderId}|${testPaymentId}`)
  .digest("hex");

assert.strictEqual(
  _test.verifyRazorpaySignature({
    orderId: testOrderId,
    paymentId: testPaymentId,
    signature: validSignature,
    secret: testSecret,
  }),
  true,
  "Valid signature should be accepted"
);
console.log("✓ verifyRazorpaySignature validates correct HMAC-SHA256 signature");

assert.strictEqual(
  _test.verifyRazorpaySignature({
    orderId: testOrderId,
    paymentId: testPaymentId,
    signature: "invalid_signature_hex",
    secret: testSecret,
  }),
  false,
  "Invalid signature should be rejected"
);
console.log("✓ verifyRazorpaySignature rejects invalid signature");

assert.strictEqual(
  _test.verifyRazorpaySignature({
    orderId: "",
    paymentId: testPaymentId,
    signature: validSignature,
    secret: testSecret,
  }),
  false,
  "Missing orderId should be rejected"
);
console.log("✓ verifyRazorpaySignature rejects empty inputs");

// 7. sanitizeRazorpayNotes tests
const rawNotes = {
  receipt: "ORD-12345",
  user_id: "user_abc",
  amount: 150000,
  shipping_address: {
    full_name: "John Doe",
    phone: "9876543210",
    address_line_1: "123 Street",
    city: "Solapur",
    pincode: "413001",
  },
  items: [
    { name: "Dog Food", quantity: 2 },
    { name: "Shampoo", quantity: 1 },
  ],
};
const cleanNotes = _test.sanitizeRazorpayNotes(rawNotes);
assert.strictEqual(cleanNotes.receipt, "ORD-12345");
assert.strictEqual(cleanNotes.user_id, "user_abc");
assert.strictEqual(cleanNotes.amount, "150000");
assert.strictEqual(cleanNotes.shipping_address, "John Doe, 9876543210, 123 Street, Solapur, 413001");
assert.strictEqual(cleanNotes.items, "2 item(s)");
assert(typeof cleanNotes.shipping_address === "string");
console.log("✓ sanitizeRazorpayNotes flattens nested objects and formats scalar strings correctly");

// 8. buildOrderMessage tests
const orderMsg = _test.buildOrderMessage({
  orderId: "ORD-999",
  customerName: "Alice",
  phone: "9999999999",
  total: 1500,
  paymentMethod: "razorpay",
  paymentStatus: "paid",
  address: "Solapur",
  items: [
    { productName: "Dog Food", quantity: 3, productPrice: 500 },
  ],
});
assert(orderMsg.includes("Dog Food x3 - Rs 1500"), "Line total should be 3 x 500 = 1500");
console.log("✓ buildOrderMessage accurately calculates and formats lineTotal in Telegram alert");

// 9. shouldMarkCodOrderPaidOnDelivered tests
assert.strictEqual(
  _test.shouldMarkCodOrderPaidOnDelivered({
    orderStatus: "delivered",
    paymentMethod: "cod",
    paymentStatus: "pending",
  }),
  true,
  "Delivered COD order with pending status should be marked paid"
);
assert.strictEqual(
  _test.shouldMarkCodOrderPaidOnDelivered({
    orderStatus: "delivered",
    payment: { paymentMethod: "cod", paymentStatus: "pending" },
  }),
  true,
  "Delivered COD order with nested payment pending should be marked paid"
);
assert.strictEqual(
  _test.shouldMarkCodOrderPaidOnDelivered({
    orderStatus: "delivered",
    paymentMethod: "cod",
    paymentStatus: "paid",
  }),
  false,
  "Already paid COD order should not be marked paid again"
);
assert.strictEqual(
  _test.shouldMarkCodOrderPaidOnDelivered({
    orderStatus: "shipped",
    paymentMethod: "cod",
    paymentStatus: "pending",
  }),
  false,
  "Shipped COD order should remain pending"
);
assert.strictEqual(
  _test.shouldMarkCodOrderPaidOnDelivered({
    orderStatus: "delivered",
    paymentMethod: "razorpay",
    paymentStatus: "paid",
  }),
  false,
  "Razorpay order should not be affected by COD rule"
);
console.log("✓ shouldMarkCodOrderPaidOnDelivered identifies delivered COD orders needing paid status");

console.log("\nAll Firebase Functions unit tests passed successfully!");

