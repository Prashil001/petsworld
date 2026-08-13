const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();

const telegramBotToken = defineSecret("TELEGRAM_BOT_TOKEN");
const telegramChatId = defineSecret("TELEGRAM_CHAT_ID");

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

    if (!shouldNotifyAdminForOrder(order)) {
      logger.info("Admin notification delayed until payment is confirmed.", {
        orderId: event.params.orderId,
      });
      return;
    }

    const token = telegramBotToken.value().trim();
    const chatId = telegramChatId.value().trim();
    if (!token || !chatId) {
      logger.error(
        "Telegram notification skipped because TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is missing.",
      );
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

    const response = await fetch(
      `https://api.telegram.org/bot${token}/sendMessage`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          chat_id: chatId,
          text: message,
          parse_mode: "HTML",
          disable_web_page_preview: true,
        }),
      },
    );

    if (!response.ok) {
      const body = await response.text();
      logger.error("Telegram notification failed.", {
        status: response.status,
        body,
      });
      return;
    }

    logger.info("Telegram notification sent for order.", {
      orderId: order.orderId || event.params.orderId,
    });
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

    if (
      shouldNotifyAdminForOrder(beforeOrder) ||
      !shouldNotifyAdminForOrder(afterOrder)
    ) {
      return;
    }

    const token = telegramBotToken.value().trim();
    const chatId = telegramChatId.value().trim();
    if (!token || !chatId) {
      logger.error(
        "Telegram paid order notification skipped because TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is missing.",
      );
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

    const response = await fetch(
      `https://api.telegram.org/bot${token}/sendMessage`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          chat_id: chatId,
          text: message,
          parse_mode: "HTML",
          disable_web_page_preview: true,
        }),
      },
    );

    if (!response.ok) {
      const body = await response.text();
      logger.error("Telegram paid order notification failed.", {
        status: response.status,
        body,
      });
      return;
    }

    logger.info("Telegram paid order notification sent for order.", {
      orderId: afterOrder.orderId || event.params.orderId,
    });
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

    const beforeStatus = String(
      beforeOrder?.orderStatus || beforeOrder?.status || "",
    ).trim();
    const afterStatus = String(
      afterOrder.orderStatus || afterOrder.status || "",
    ).trim();

    if (afterStatus !== "cancelled" || beforeStatus === "cancelled") {
      return;
    }

    const token = telegramBotToken.value().trim();
    const chatId = telegramChatId.value().trim();
    if (!token || !chatId) {
      logger.error(
        "Telegram cancellation notification skipped because TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is missing.",
      );
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

    const response = await fetch(
      `https://api.telegram.org/bot${token}/sendMessage`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          chat_id: chatId,
          text: message,
          parse_mode: "HTML",
          disable_web_page_preview: true,
        }),
      },
    );

    if (!response.ok) {
      const body = await response.text();
      logger.error("Telegram cancellation notification failed.", {
        status: response.status,
        body,
      });
      return;
    }

    logger.info("Telegram cancellation notification sent for order.", {
      orderId: afterOrder.orderId || event.params.orderId,
    });
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

    const items = Array.isArray(order.items) ? order.items : [];
    const itemsByProduct = groupOrderItemsByProduct(items);
    if (itemsByProduct.size === 0) {
      logger.warn("Stock decrement skipped because order has no valid items.", {
        orderId: event.params.orderId,
      });
      return;
    }

    const db = admin.firestore();
    const orderRef = snapshot.ref;

    await db.runTransaction(async (transaction) => {
      const latestOrderSnapshot = await transaction.get(orderRef);
      const latestOrder = latestOrderSnapshot.data();
      if (latestOrder?.stockDecremented === true) {
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
        stockDecremented: pendingProductUpdates.length > 0,
        stockReservationStatus:
          stockIssues.length === 0 ? "decremented" : "decremented_with_issues",
        stockReservationIssues: stockIssues,
        stockUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    logger.info("Stock decrement processed for order.", {
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
  },
);

async function decrementStockForOrder({ orderRef, order, orderId }) {
  const items = Array.isArray(order.items) ? order.items : [];
  const itemsByProduct = groupOrderItemsByProduct(items);
  if (itemsByProduct.size === 0) {
    logger.warn("Stock decrement skipped because order has no valid items.", {
      orderId,
    });
    return;
  }

  const db = admin.firestore();

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
      stockDecremented: pendingProductUpdates.length > 0,
      stockReservationStatus:
        stockIssues.length === 0 ? "decremented" : "decremented_with_issues",
      stockReservationIssues: stockIssues,
      stockUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  logger.info("Stock decrement processed for order.", {
    orderId,
  });
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
          const amount = formatMoney(item.lineTotal ?? item.productPrice ?? 0);
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
  const selectedOptionId = String(item.selectedOptionId || "").trim();
  if (selectedOptionId) {
    const exactIndex = packOptions.findIndex(
      (pack) => String(pack?.id || "").trim() === selectedOptionId,
    );
    if (exactIndex !== -1) {
      return exactIndex;
    }
  }

  const selectedOptionLabel = normalizeComparable(item.selectedOptionLabel);
  if (selectedOptionLabel) {
    const labelIndex = packOptions.findIndex(
      (pack) => normalizeComparable(pack?.label) === selectedOptionLabel,
    );
    if (labelIndex !== -1) {
      return labelIndex;
    }
  }

  if (!selectedOptionId) {
    const defaultIndex = packOptions.findIndex((pack) => pack?.isDefault === true);
    return defaultIndex === -1 ? 0 : defaultIndex;
  }

  return -1;
}

function resolvePrimaryPackStock(packOptions, fallbackStockQuantity) {
  if (!packOptions.length) {
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
