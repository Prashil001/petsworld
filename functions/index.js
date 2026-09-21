const crypto = require("crypto");
const Razorpay = require("razorpay");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { onRequest } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();

const telegramBotToken = defineSecret("TELEGRAM_BOT_TOKEN");
const telegramChatId = defineSecret("TELEGRAM_CHAT_ID");
const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

/**
 * Safely retrieve Telegram configuration from secrets or process.env fallback.
 */
function getTelegramConfig() {
  let token = "";
  let chatId = "";
  try {
    token = (telegramBotToken.value() || "").trim();
  } catch (_) {}
  try {
    chatId = (telegramChatId.value() || "").trim();
  } catch (_) {}

  if (!token && process.env.TELEGRAM_BOT_TOKEN) {
    token = process.env.TELEGRAM_BOT_TOKEN.trim();
  }
  if (!chatId && process.env.TELEGRAM_CHAT_ID) {
    chatId = process.env.TELEGRAM_CHAT_ID.trim();
  }

  return { token, chatId };
}

/**
 * Safely retrieve Razorpay configuration from secrets or process.env fallback.
 */
function getRazorpayConfig() {
  let keyId = "";
  let keySecret = "";
  try {
    keyId = (razorpayKeyId.value() || "").trim();
  } catch (_) {}
  try {
    keySecret = (razorpayKeySecret.value() || "").trim();
  } catch (_) {}

  if (!keyId && process.env.RAZORPAY_KEY_ID) {
    keyId = process.env.RAZORPAY_KEY_ID.trim();
  }
  if (!keySecret && process.env.RAZORPAY_KEY_SECRET) {
    keySecret = process.env.RAZORPAY_KEY_SECRET.trim();
  }

  return { keyId, keySecret };
}

/**
 * Validates a Razorpay payment signature using timingSafeEqual to prevent timing attacks.
 */
function verifyRazorpaySignature({ orderId, paymentId, signature, secret }) {
  if (!orderId || !paymentId || !signature || !secret) {
    return false;
  }
  try {
    const expectedSignature = crypto
      .createHmac("sha256", secret)
      .update(`${orderId}|${paymentId}`)
      .digest("hex");

    const expectedBuffer = Buffer.from(expectedSignature, "utf8");
    const actualBuffer = Buffer.from(signature, "utf8");
    if (expectedBuffer.length !== actualBuffer.length) {
      return false;
    }
    return crypto.timingSafeEqual(expectedBuffer, actualBuffer);
  } catch (_) {
    return false;
  }
}

/**
 * Truncates message to stay well within Telegram's 4096 character limit.
 */
function truncateTelegramMessage(message, maxLength = 4000) {
  if (!message || message.length <= maxLength) {
    return message || "";
  }
  const suffix = "\n\n<i>[Message truncated]</i>";
  return message.substring(0, maxLength - suffix.length) + suffix;
}

/**
 * Sends a Telegram notification with structured error handling.
 */
async function sendTelegramMessage(text) {
  const { token, chatId } = getTelegramConfig();
  if (!token || !chatId) {
    logger.info(
      "Telegram notification skipped: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not configured.",
    );
    return false;
  }

  const safeText = truncateTelegramMessage(text);

  async function postToTelegram(targetChatId) {
    return fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        chat_id: targetChatId,
        text: safeText,
        parse_mode: "HTML",
        disable_web_page_preview: true,
      }),
    });
  }

  try {
    let response = await postToTelegram(chatId);

    if (!response.ok) {
      const bodyText = await response.text().catch(() => "");
      let parsedBody = null;
      try {
        parsedBody = JSON.parse(bodyText);
      } catch (_) {}

      // Automatically handle group upgrade to supergroup
      if (parsedBody?.parameters?.migrate_to_chat_id) {
        const newChatId = parsedBody.parameters.migrate_to_chat_id;
        logger.info(
          `Telegram group migrated to supergroup ${newChatId}. Resending notification...`,
        );
        const retryResponse = await postToTelegram(newChatId);
        if (retryResponse.ok) {
          logger.info(
            `Telegram notification sent successfully to migrated supergroup ${newChatId}.`,
          );
          return true;
        }
      }

      logger.error("Telegram notification returned non-OK status.", {
        status: response.status,
        body: bodyText,
      });
      return false;
    }

    return true;
  } catch (error) {
    logger.error("Telegram notification failed due to network/fetch error.", {
      error: error?.message || String(error),
    });
    return false;
  }
}

exports.notifyAdminOnNewOrder = onDocumentCreated(
  {
    document: "orders/{orderId}",
    region: "asia-south1",
    secrets: [telegramBotToken, telegramChatId],
  },
  async (event) => {
    const snapshot = event.data;
    const order = snapshot?.data();
    if (!order) {
      logger.warn("Order trigger fired without order data.");
      return;
    }

    if (order.adminNotified === true) {
      logger.info("Admin notification skipped because order was already notified.", {
        orderId: event.params.orderId,
      });
      return;
    }

    if (!shouldNotifyAdminForOrder(order)) {
      logger.info("Admin notification delayed until payment is confirmed.", {
        orderId: event.params.orderId,
      });
      return;
    }

    const message = buildOrderMessage({
      orderId: order.orderId || event.params.orderId,
      customerName:
        order.userName || order.customerName || order.deliveryAddress?.fullName,
      phone: order.userPhone || order.phoneNumber || order.deliveryAddress?.phone,
      total: order.pricing?.totalAmount ?? order.total,
      paymentMethod: order.payment?.paymentMethod ?? order.paymentMethod,
      paymentStatus: order.payment?.paymentStatus ?? order.paymentStatus,
      address:
        order.deliveryAddress?.fullAddress ||
        order.address ||
        composeAddress(order.deliveryAddress),
      items: Array.isArray(order.items) ? order.items : [],
    });

    const sent = await sendTelegramMessage(message);
    if (sent && snapshot?.ref) {
      try {
        await snapshot.ref.update({
          adminNotified: true,
          adminNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info("Telegram notification sent and order marked adminNotified.", {
          orderId: order.orderId || event.params.orderId,
        });
      } catch (err) {
        logger.warn("Could not mark order as adminNotified", {
          orderId: event.params.orderId,
          error: err?.message,
        });
      }
    }
  },
);

exports.notifyAdminOnRazorpayPaymentConfirmed = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-south1",
    secrets: [telegramBotToken, telegramChatId],
  },
  async (event) => {
    const beforeOrder = event.data?.before?.data();
    const afterOrder = event.data?.after?.data();
    if (!afterOrder) {
      logger.warn("Paid order notification skipped because order data is missing.");
      return;
    }

    if (afterOrder.adminNotified === true) {
      return;
    }

    if (
      shouldNotifyAdminForOrder(beforeOrder) ||
      !shouldNotifyAdminForOrder(afterOrder)
    ) {
      return;
    }

    const message = buildOrderMessage({
      orderId: afterOrder.orderId || event.params.orderId,
      customerName:
        afterOrder.userName ||
        afterOrder.customerName ||
        afterOrder.deliveryAddress?.fullName,
      phone:
        afterOrder.userPhone ||
        afterOrder.phoneNumber ||
        afterOrder.deliveryAddress?.phone,
      total: afterOrder.pricing?.totalAmount ?? afterOrder.total,
      paymentMethod:
        afterOrder.payment?.paymentMethod ?? afterOrder.paymentMethod,
      paymentStatus:
        afterOrder.payment?.paymentStatus ?? afterOrder.paymentStatus,
      address:
        afterOrder.deliveryAddress?.fullAddress ||
        afterOrder.address ||
        composeAddress(afterOrder.deliveryAddress),
      items: Array.isArray(afterOrder.items) ? afterOrder.items : [],
    });

    const sent = await sendTelegramMessage(message);
    if (sent && event.data?.after?.ref) {
      try {
        await event.data.after.ref.update({
          adminNotified: true,
          adminNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info("Telegram paid order notification sent and marked adminNotified.", {
          orderId: afterOrder.orderId || event.params.orderId,
        });
      } catch (err) {
        logger.warn("Could not mark order as adminNotified", {
          orderId: event.params.orderId,
          error: err?.message,
        });
      }
    }
  },
);

exports.notifyAdminOnOrderCancelled = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-south1",
    secrets: [telegramBotToken, telegramChatId],
  },
  async (event) => {
    const beforeOrder = event.data?.before?.data();
    const afterOrder = event.data?.after?.data();
    if (!afterOrder) {
      logger.warn("Order update trigger fired without updated order data.");
      return;
    }

    if (afterOrder.cancellationNotified === true) {
      return;
    }

    const beforeStatus = String(
      beforeOrder?.orderStatus || beforeOrder?.status || "",
    ).trim();
    const afterStatus = String(
      afterOrder.orderStatus || afterOrder.status || "",
    ).trim();

    if (afterStatus !== "cancelled" || beforeStatus === "cancelled") {
      return;
    }

    const message = buildOrderCancelledMessage({
      orderId: afterOrder.orderId || event.params.orderId,
      customerName:
        afterOrder.userName ||
        afterOrder.customerName ||
        afterOrder.deliveryAddress?.fullName,
      phone:
        afterOrder.userPhone ||
        afterOrder.phoneNumber ||
        afterOrder.deliveryAddress?.phone,
      total: afterOrder.pricing?.totalAmount ?? afterOrder.total,
      paymentMethod:
        afterOrder.payment?.paymentMethod ?? afterOrder.paymentMethod,
      paymentStatus:
        afterOrder.payment?.paymentStatus ?? afterOrder.paymentStatus,
      address:
        afterOrder.deliveryAddress?.fullAddress ||
        afterOrder.address ||
        composeAddress(afterOrder.deliveryAddress),
      items: Array.isArray(afterOrder.items) ? afterOrder.items : [],
    });

    const sent = await sendTelegramMessage(message);
    if (sent && event.data?.after?.ref) {
      try {
        await event.data.after.ref.update({
          cancellationNotified: true,
          cancellationNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info("Telegram cancellation notification sent and marked cancellationNotified.", {
          orderId: afterOrder.orderId || event.params.orderId,
        });
      } catch (err) {
        logger.warn("Could not mark order as cancellationNotified", {
          orderId: event.params.orderId,
          error: err?.message,
        });
      }
    }
  },
);

exports.decrementProductStockOnNewOrder = onDocumentCreated(
  {
    document: "orders/{orderId}",
    region: "asia-south1",
  },
  async (event) => {
    const snapshot = event.data;
    const order = snapshot?.data();
    if (!snapshot || !order) {
      logger.warn("Stock decrement skipped because order data is missing.");
      return;
    }

    if (!shouldDecrementStockForOrder(order)) {
      logger.info("Stock decrement delayed until payment is confirmed.", {
        orderId: event.params.orderId,
      });
      return;
    }

    if (order.stockDecremented === true) {
      logger.info("Stock decrement skipped because order was already marked.", {
        orderId: event.params.orderId,
      });
      return;
    }

    await decrementStockForOrder({
      orderRef: snapshot.ref,
      order,
      orderId: event.params.orderId,
    });
  },
);

exports.decrementProductStockOnPaymentConfirmed = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-south1",
  },
  async (event) => {
    const beforeOrder = event.data?.before?.data();
    const afterOrder = event.data?.after?.data();
    if (!afterOrder) {
      logger.warn("Paid stock decrement skipped because order data is missing.");
      return;
    }

    if (
      afterOrder.stockDecremented === true ||
      shouldDecrementStockForOrder(beforeOrder) ||
      !shouldDecrementStockForOrder(afterOrder)
    ) {
      return;
    }

    await decrementStockForOrder({
      orderRef: event.data.after.ref,
      order: afterOrder,
      orderId: event.params.orderId,
    });
  },
);

exports.restoreProductStockOnOrderCancelled = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-south1",
  },
  async (event) => {
    const beforeOrder = event.data?.before?.data();
    const afterOrder = event.data?.after?.data();
    if (!afterOrder) {
      logger.warn("Stock restore skipped because updated order data is missing.");
      return;
    }

    const beforeStatus = String(
      beforeOrder?.orderStatus || beforeOrder?.status || "",
    ).trim();
    const afterStatus = String(
      afterOrder.orderStatus || afterOrder.status || "",
    ).trim();

    if (
      afterStatus !== "cancelled" ||
      beforeStatus === "cancelled" ||
      afterOrder.stockDecremented !== true
    ) {
      return;
    }

    const items = Array.isArray(afterOrder.items) ? afterOrder.items : [];
    const itemsByProduct = groupOrderItemsByProduct(items);
    if (itemsByProduct.size === 0) {
      logger.warn("Stock restore skipped because order has no valid items.", {
        orderId: event.params.orderId,
      });
      return;
    }

    const db = admin.firestore();
    const orderRef = event.data.after.ref;

    try {
      await db.runTransaction(async (transaction) => {
        const latestOrderSnapshot = await transaction.get(orderRef);
        const latestOrder = latestOrderSnapshot.data();
        if (
          latestOrder?.stockDecremented !== true ||
          String(latestOrder?.orderStatus || latestOrder?.status || "") !==
            "cancelled"
        ) {
          return;
        }

        const pendingProductUpdates = [];
        for (const [productId, productItems] of itemsByProduct.entries()) {
          const productRef = db.collection("products").doc(productId);
          const productSnapshot = await transaction.get(productRef);
          if (!productSnapshot.exists) {
            continue;
          }

          const product = productSnapshot.data() || {};
          const packOptions = Array.isArray(product.packOptions)
            ? product.packOptions.map((pack) => ({ ...pack }))
            : [];

          if (packOptions.length > 0) {
            pendingProductUpdates.push([
              productRef,
              incrementPackStock({
                product,
                packOptions,
                items: productItems,
              }),
            ]);
          } else {
            const restoreQuantity = productItems.reduce(
              (total, item) => total + item.quantity,
              0,
            );
            pendingProductUpdates.push([
              productRef,
              {
                stockQuantity: toInteger(product.stockQuantity) + restoreQuantity,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            ]);
          }
        }

        for (const [productRef, update] of pendingProductUpdates) {
          transaction.update(productRef, update);
        }

        transaction.update(orderRef, {
          stockDecremented: false,
          stockReservationStatus: "restored",
          stockRestoredAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      logger.info("Stock restore processed for cancelled order.", {
        orderId: event.params.orderId,
      });
    } catch (error) {
      logger.error("Stock restore transaction failed for order.", {
        orderId: event.params.orderId,
        error: error?.message || String(error),
      });
    }
  },
);

async function decrementStockForOrder({ orderRef, order, orderId }) {
  const items = Array.isArray(order?.items) ? order.items : [];
  const itemsByProduct = groupOrderItemsByProduct(items);
  if (itemsByProduct.size === 0) {
    logger.warn("Stock decrement skipped because order has no valid items.", {
      orderId,
    });
    return;
  }

  const db = admin.firestore();

  try {
    await db.runTransaction(async (transaction) => {
      const latestOrderSnapshot = await transaction.get(orderRef);
      const latestOrder = latestOrderSnapshot.data();
      if (
        latestOrder?.stockDecremented === true ||
        !shouldDecrementStockForOrder(latestOrder)
      ) {
        return;
      }

      const pendingProductUpdates = [];
      const stockIssues = [];

      for (const [productId, productItems] of itemsByProduct.entries()) {
        const productRef = db.collection("products").doc(productId);
        const productSnapshot = await transaction.get(productRef);
        if (!productSnapshot.exists) {
          stockIssues.push({
            productId,
            reason: "product_not_found",
          });
          continue;
        }

        const product = productSnapshot.data() || {};
        const packOptions = Array.isArray(product.packOptions)
          ? product.packOptions.map((pack) => ({ ...pack }))
          : [];

        if (packOptions.length > 0) {
          const update = decrementPackStock({
            product,
            packOptions,
            items: productItems,
            productId,
            stockIssues,
          });
          pendingProductUpdates.push([productRef, update]);
        } else {
          const orderedQuantity = productItems.reduce(
            (total, item) => total + item.quantity,
            0,
          );
          const currentStock = toInteger(product.stockQuantity);
          if (currentStock < orderedQuantity) {
            stockIssues.push({
              productId,
              reason: "insufficient_stock",
              available: currentStock,
              requested: orderedQuantity,
            });
          }

          pendingProductUpdates.push([
            productRef,
            {
              stockQuantity: Math.max(0, currentStock - orderedQuantity),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          ]);
        }
      }

      for (const [productRef, update] of pendingProductUpdates) {
        transaction.update(productRef, update);
      }

      transaction.update(orderRef, {
        stockDecremented: true,
        stockReservationStatus:
          stockIssues.length === 0 ? "decremented" : "decremented_with_issues",
        stockReservationIssues: stockIssues,
        stockUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    logger.info("Stock decrement processed for order.", { orderId });
  } catch (error) {
    logger.error("Stock decrement transaction failed for order.", {
      orderId,
      error: error?.message || String(error),
    });
  }
}

function shouldDecrementStockForOrder(order) {
  if (!order) {
    return false;
  }

  const paymentMethod = String(
    order.payment?.paymentMethod || order.paymentMethod || "",
  ).trim();
  const paymentStatus = String(
    order.payment?.paymentStatus || order.paymentStatus || "",
  ).trim();
  const orderStatus = String(order.orderStatus || order.status || "").trim();

  if (orderStatus === "cancelled") {
    return false;
  }

  return paymentMethod !== "razorpay" || paymentStatus === "paid";
}

function shouldNotifyAdminForOrder(order) {
  return shouldDecrementStockForOrder(order);
}

function buildOrderMessage({
  orderId,
  customerName,
  phone,
  total,
  paymentMethod,
  paymentStatus,
  address,
  items,
}) {
  const itemLines = items.length
    ? items
        .slice(0, 10)
        .map((item) => {
          const name = escapeHtml(item.productName || item.name || "Item");
          const qty = item.quantity ?? 1;
          const unitPrice = Number(item.productPrice ?? item.unitPrice ?? item.price ?? 0);
          const lineTotal = Number(item.lineTotal ?? (unitPrice * qty));
          const amount = formatMoney(lineTotal);
          return `• ${name} x${qty} - ${amount}`;
        })
        .join("\n")
    : "• Items not available";

  const extraItems =
    items.length > 10 ? `\n• +${items.length - 10} more item(s)` : "";

  return [
    "🛒 <b>New order received</b>",
    `Order ID: <b>${escapeHtml(orderId || "N/A")}</b>`,
    `Customer: ${escapeHtml(customerName || "N/A")}`,
    `Phone: ${escapeHtml(phone || "N/A")}`,
    `Total: <b>${formatMoney(total)}</b>`,
    `Payment: ${escapeHtml(normalizeLabel(paymentMethod))}`,
    `Payment status: ${escapeHtml(normalizeLabel(paymentStatus))}`,
    "",
    "<b>Delivery address</b>",
    escapeHtml(address || "N/A"),
    "",
    "<b>Items</b>",
    `${itemLines}${extraItems}`,
  ].join("\n");
}

function buildOrderCancelledMessage({
  orderId,
  customerName,
  phone,
  total,
  paymentMethod,
  paymentStatus,
  address,
  items,
}) {
  const itemLines = items.length
    ? items
        .slice(0, 10)
        .map((item) => {
          const name = escapeHtml(item.productName || item.name || "Item");
          const qty = item.quantity ?? 1;
          return `• ${name} x${qty}`;
        })
        .join("\n")
    : "• Items not available";

  const extraItems =
    items.length > 10 ? `\n• +${items.length - 10} more item(s)` : "";

  return [
    "❌ <b>Order cancelled</b>",
    `Order ID: <b>${escapeHtml(orderId || "N/A")}</b>`,
    `Customer: ${escapeHtml(customerName || "N/A")}`,
    `Phone: ${escapeHtml(phone || "N/A")}`,
    `Total: <b>${formatMoney(total)}</b>`,
    `Payment: ${escapeHtml(normalizeLabel(paymentMethod))}`,
    `Payment status: ${escapeHtml(normalizeLabel(paymentStatus))}`,
    "",
    "<b>Delivery address</b>",
    escapeHtml(address || "N/A"),
    "",
    "<b>Items</b>",
    `${itemLines}${extraItems}`,
  ].join("\n");
}

function groupOrderItemsByProduct(items) {
  const grouped = new Map();
  for (const item of items) {
    const productId = String(item?.productId || "").trim();
    const quantity = toInteger(item?.quantity);
    if (!productId || quantity <= 0) {
      continue;
    }

    const normalizedItem = {
      productId,
      quantity,
      selectedOptionId: String(item?.selectedOptionId || "").trim(),
      selectedOptionLabel: String(item?.selectedOptionLabel || "").trim(),
    };
    const productItems = grouped.get(productId) || [];
    productItems.push(normalizedItem);
    grouped.set(productId, productItems);
  }
  return grouped;
}

function decrementPackStock({
  product,
  packOptions,
  items,
  productId,
  stockIssues,
}) {
  let fallbackStockQuantity = toInteger(product.stockQuantity);

  for (const item of items) {
    const packIndex = resolvePackIndex(packOptions, item);
    if (packIndex === -1) {
      if (fallbackStockQuantity < item.quantity) {
        stockIssues.push({
          productId,
          selectedOptionId: item.selectedOptionId,
          reason: "pack_not_found_or_insufficient_top_level_stock",
          available: fallbackStockQuantity,
          requested: item.quantity,
        });
      }
      fallbackStockQuantity = Math.max(0, fallbackStockQuantity - item.quantity);
      continue;
    }

    const currentStock = toInteger(packOptions[packIndex].stockQuantity);
    if (currentStock < item.quantity) {
      stockIssues.push({
        productId,
        selectedOptionId: item.selectedOptionId,
        selectedOptionLabel: item.selectedOptionLabel,
        reason: "insufficient_pack_stock",
        available: currentStock,
        requested: item.quantity,
      });
    }

    packOptions[packIndex] = {
      ...packOptions[packIndex],
      stockQuantity: Math.max(0, currentStock - item.quantity),
    };
  }

  return {
    packOptions,
    stockQuantity: resolvePrimaryPackStock(packOptions, fallbackStockQuantity),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function incrementPackStock({ product, packOptions, items }) {
  let fallbackStockQuantity = toInteger(product.stockQuantity);

  for (const item of items) {
    const packIndex = resolvePackIndex(packOptions, item);
    if (packIndex === -1) {
      fallbackStockQuantity += item.quantity;
      continue;
    }

    packOptions[packIndex] = {
      ...packOptions[packIndex],
      stockQuantity:
        toInteger(packOptions[packIndex].stockQuantity) + item.quantity,
    };
  }

  return {
    packOptions,
    stockQuantity: resolvePrimaryPackStock(packOptions, fallbackStockQuantity),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function resolvePackIndex(packOptions, item) {
  if (!Array.isArray(packOptions) || packOptions.length === 0) {
    return -1;
  }

  const selectedOptionId = String(item?.selectedOptionId || "").trim();
  if (selectedOptionId && selectedOptionId !== "default") {
    const exactIndex = packOptions.findIndex(
      (pack) => String(pack?.id || "").trim() === selectedOptionId,
    );
    if (exactIndex !== -1) {
      return exactIndex;
    }
  }

  const selectedOptionLabel = normalizeComparable(item?.selectedOptionLabel);
  if (selectedOptionLabel) {
    const labelIndex = packOptions.findIndex(
      (pack) => normalizeComparable(pack?.label) === selectedOptionLabel,
    );
    if (labelIndex !== -1) {
      return labelIndex;
    }
  }

  if (!selectedOptionId || selectedOptionId === "default") {
    const defaultIndex = packOptions.findIndex((pack) => pack?.isDefault === true);
    return defaultIndex === -1 ? 0 : defaultIndex;
  }

  return -1;
}

function resolvePrimaryPackStock(packOptions, fallbackStockQuantity) {
  if (!Array.isArray(packOptions) || !packOptions.length) {
    return fallbackStockQuantity;
  }

  const primaryPack =
    packOptions.find((pack) => pack?.isDefault === true) || packOptions[0];
  return toInteger(primaryPack?.stockQuantity);
}

function normalizeComparable(value) {
  return String(value || "").trim().toLowerCase();
}

function toInteger(value) {
  const number = Number(value || 0);
  if (!Number.isFinite(number)) {
    return 0;
  }
  return Math.max(0, Math.trunc(number));
}

function composeAddress(deliveryAddress) {
  if (!deliveryAddress || typeof deliveryAddress !== "object") {
    return "";
  }

  return [
    deliveryAddress.addressLine1,
    deliveryAddress.addressLine2,
    deliveryAddress.city,
    deliveryAddress.state,
    deliveryAddress.pincode,
    deliveryAddress.landmark,
  ]
    .filter(Boolean)
    .join(", ");
}

function normalizeLabel(value) {
  const raw = String(value || "").trim();
  if (!raw) {
    return "N/A";
  }

  return raw
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function formatMoney(value) {
  const amount = Number(value || 0);
  if (!Number.isFinite(amount)) {
    return "Rs 0";
  }
  return `Rs ${amount.toFixed(0)}`;
}

function escapeHtml(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

/**
 * Sanitizes and flattens notes to comply with Razorpay API constraints:
 * - Max 15 key-value pairs
 * - Max 256 characters per key and value
 * - Only string/scalar values (no nested maps or arrays)
 */
function sanitizeRazorpayNotes(rawNotes) {
  if (!rawNotes || typeof rawNotes !== "object") {
    return {};
  }
  const cleanNotes = {};
  let count = 0;
  for (const [key, value] of Object.entries(rawNotes)) {
    if (count >= 15) break;
    if (value === null || value === undefined) continue;

    const safeKey = String(key).trim().substring(0, 40);
    if (!safeKey) continue;

    let safeValue = "";
    if (typeof value === "object") {
      if (key === "shipping_address" && value) {
        safeValue = [
          value.full_name,
          value.phone,
          value.address_line_1,
          value.city,
          value.pincode,
        ]
          .filter(Boolean)
          .join(", ");
      } else if (key === "items" && Array.isArray(value)) {
        safeValue = `${value.length} item(s)`;
      } else {
        continue;
      }
    } else {
      safeValue = String(value).trim();
    }

    if (safeValue) {
      cleanNotes[safeKey] = safeValue.substring(0, 255);
      count++;
    }
  }
  return cleanNotes;
}

async function handleCreateRazorpayOrder(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      error: "Method Not Allowed",
      message: "Only POST requests are supported.",
    });
  }

  const { keyId, keySecret } = getRazorpayConfig();
  if (!keyId || !keySecret) {
    logger.error("Razorpay credentials not configured.");
    return res.status(500).json({
      success: false,
      error: "Configuration Error",
      message: "Razorpay credentials are not configured on the server.",
    });
  }

  const { amount, currency = "INR", receipt, notes } = req.body || {};
  const numericAmount = parseInt(amount, 10);
  if (!numericAmount || numericAmount <= 0) {
    return res.status(400).json({
      success: false,
      error: "Bad Request",
      message: "A valid positive amount in paise is required.",
    });
  }

  if (!receipt || typeof receipt !== "string" || !receipt.trim()) {
    return res.status(400).json({
      success: false,
      error: "Bad Request",
      message: "A valid receipt ID is required.",
    });
  }

  try {
    const razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });

    const order = await razorpay.orders.create({
      amount: numericAmount,
      currency: String(currency || "INR").trim().toUpperCase(),
      receipt: String(receipt).trim().substring(0, 40),
      notes: sanitizeRazorpayNotes(notes),
    });

    logger.info("Razorpay order created successfully.", {
      orderId: order.id,
      receipt: order.receipt,
      amount: order.amount,
    });

    return res.status(200).json({
      success: true,
      orderId: order.id,
      keyId,
      order,
    });
  } catch (error) {
    logger.error("Failed to create Razorpay order.", {
      error: error?.message || String(error),
    });
    return res.status(500).json({
      success: false,
      error: "Order Creation Failed",
      message:
        error?.error?.description ||
        error?.message ||
        "Failed to create Razorpay order.",
    });
  }
}

async function handleVerifyRazorpayPayment(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      error: "Method Not Allowed",
      message: "Only POST requests are supported.",
    });
  }

  const { keySecret } = getRazorpayConfig();
  if (!keySecret) {
    logger.error("Razorpay secret not configured for verification.");
    return res.status(500).json({
      success: false,
      error: "Configuration Error",
      message: "Razorpay secret is not configured on the server.",
    });
  }

  const {
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_signature,
  } = req.body || {};

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return res.status(400).json({
      success: false,
      error: "Bad Request",
      message:
        "Missing required payment verification fields (razorpay_order_id, razorpay_payment_id, razorpay_signature).",
    });
  }

  const isValid = verifyRazorpaySignature({
    orderId: String(razorpay_order_id).trim(),
    paymentId: String(razorpay_payment_id).trim(),
    signature: String(razorpay_signature).trim(),
    secret: keySecret,
  });

  if (!isValid) {
    logger.warn("Razorpay payment signature verification failed.", {
      orderId: razorpay_order_id,
      paymentId: razorpay_payment_id,
    });
    return res.status(400).json({
      success: false,
      error: "Invalid Signature",
      message: "Payment verification failed. Invalid signature.",
    });
  }

  logger.info("Razorpay payment verified successfully.", {
    orderId: razorpay_order_id,
    paymentId: razorpay_payment_id,
  });

  return res.status(200).json({
    success: true,
    message: "Payment verified successfully.",
    orderId: razorpay_order_id,
    paymentId: razorpay_payment_id,
  });
}

const razorpayHttpOptions = {
  region: "asia-south1",
  cors: true,
  secrets: [razorpayKeyId, razorpayKeySecret],
};

exports.createRazorpayOrder = onRequest(razorpayHttpOptions, handleCreateRazorpayOrder);
exports.verifyRazorpayPayment = onRequest(razorpayHttpOptions, handleVerifyRazorpayPayment);

module.exports = {
  ...exports,
  // Export helpers for unit testing
  _test: {
    getTelegramConfig,
    truncateTelegramMessage,
    getRazorpayConfig,
    verifyRazorpaySignature,
    resolvePackIndex,
    resolvePrimaryPackStock,
    shouldDecrementStockForOrder,
    shouldNotifyAdminForOrder,
    buildOrderMessage,
    buildOrderCancelledMessage,
    groupOrderItemsByProduct,
    decrementPackStock,
    incrementPackStock,
    normalizeComparable,
    toInteger,
    composeAddress,
    normalizeLabel,
    formatMoney,
    escapeHtml,
    sanitizeRazorpayNotes,
  },
};
