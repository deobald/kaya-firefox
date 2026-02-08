const NATIVE_HOST_NAME = "org.savebutton.nativehost";
let nativePort = null;
let knownBookmarkedUrls = new Set();
let pendingResponses = new Map();
let messageId = 0;

function connectToNativeHost() {
  if (nativePort) {
    return nativePort;
  }

  try {
    nativePort = browser.runtime.connectNative(NATIVE_HOST_NAME);

    nativePort.onMessage.addListener((message) => {
      console.log("Received from native host:", message);

      if (message.id && pendingResponses.has(message.id)) {
        const { resolve, reject } = pendingResponses.get(message.id);
        pendingResponses.delete(message.id);

        if (message.error) {
          reject(new Error(message.error));
        } else {
          resolve(message);
        }
      }

      if (message.type === "bookmarks") {
        knownBookmarkedUrls = new Set(message.urls || []);
        updateIconForActiveTab();
      }
    });

    nativePort.onDisconnect.addListener((p) => {
      console.error("Native host disconnected:", p.error);
      nativePort = null;

      for (const [id, { reject }] of pendingResponses) {
        reject(new Error("Native host disconnected"));
      }
      pendingResponses.clear();
    });

    return nativePort;
  } catch (error) {
    console.error("Failed to connect to native host:", error);
    nativePort = null;
    throw error;
  }
}

async function sendToNativeHost(message) {
  const port = connectToNativeHost();

  return new Promise((resolve, reject) => {
    const id = ++messageId;
    message.id = id;

    pendingResponses.set(id, { resolve, reject });

    setTimeout(() => {
      if (pendingResponses.has(id)) {
        pendingResponses.delete(id);
        reject(new Error("Request timed out"));
      }
    }, 30000);

    try {
      port.postMessage(message);
    } catch (error) {
      pendingResponses.delete(id);
      reject(error);
    }
  });
}

function generateTimestamp() {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  const day = String(now.getUTCDate()).padStart(2, "0");
  const hours = String(now.getUTCHours()).padStart(2, "0");
  const minutes = String(now.getUTCMinutes()).padStart(2, "0");
  const seconds = String(now.getUTCSeconds()).padStart(2, "0");
  return `${year}-${month}-${day}T${hours}${minutes}${seconds}`;
}

async function updateIconForActiveTab() {
  try {
    const tabs = await browser.tabs.query({
      active: true,
      currentWindow: true,
    });
    if (tabs.length === 0) return;

    const tab = tabs[0];
    const isBookmarked = tab.url && knownBookmarkedUrls.has(tab.url);

    const iconPath = isBookmarked
      ? {
          48: "icons/icon-48.svg",
          96: "icons/icon-96.svg",
        }
      : {
          48: "icons/icon-grey-48.svg",
          96: "icons/icon-grey-96.svg",
        };

    await browser.browserAction.setIcon({ path: iconPath, tabId: tab.id });
  } catch (error) {
    console.error("Failed to update icon:", error);
  }
}

browser.tabs.onActivated.addListener(updateIconForActiveTab);
browser.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.url || changeInfo.status === "complete") {
    updateIconForActiveTab();
  }
});

browser.contextMenus.create({
  id: "save-to-kaya-text",
  title: "Add to Save Button",
  contexts: ["selection"],
});

browser.contextMenus.create({
  id: "save-to-kaya-image",
  title: "Add to Save Button",
  contexts: ["image"],
});

browser.contextMenus.onClicked.addListener(async (info, tab) => {
  const timestamp = generateTimestamp();

  try {
    if (info.menuItemId === "save-to-kaya-text" && info.selectionText) {
      const filename = `${timestamp}-quote.md`;
      const message = {
        message: "anga",
        filename: filename,
        type: "text",
        text: info.selectionText,
      };

      await sendToNativeHost(message);
      showNotification("Text added to Save Button");
    } else if (info.menuItemId === "save-to-kaya-image" && info.srcUrl) {
      await saveImage(info.srcUrl, timestamp);
    }
  } catch (error) {
    console.error("Failed to save:", error);
    showNotification("Error: " + error.message);
  }
});

async function saveImage(imageUrl, timestamp) {
  try {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error("Failed to fetch image");
    }

    const blob = await response.blob();
    const arrayBuffer = await blob.arrayBuffer();
    const base64 = arrayBufferToBase64(arrayBuffer);

    let filename;
    try {
      const urlObj = new URL(imageUrl);
      const originalFilename = urlObj.pathname.split("/").pop() || "image";
      filename = `${timestamp}-${originalFilename}`;
    } catch (e) {
      const ext = blob.type.split("/")[1] || "png";
      filename = `${timestamp}-image.${ext}`;
    }

    const message = {
      message: "anga",
      filename: filename,
      type: "base64",
      base64: base64,
    };

    await sendToNativeHost(message);
    showNotification("Image added to Save Button");
  } catch (error) {
    console.error("Failed to save image:", error);
    throw error;
  }
}

function arrayBufferToBase64(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function showNotification(message) {
  browser.notifications
    .create({
      type: "basic",
      iconUrl: "icons/icon-96.svg",
      title: "Save Button",
      message: message,
    })
    .catch(console.error);
}

browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "sendToNative") {
    sendToNativeHost(request.data)
      .then((response) => {
        updateIconForActiveTab();
        sendResponse(response);
      })
      .catch((error) => {
        sendResponse({ error: error.message });
      });
    return true;
  }

  if (request.action === "sendConfig") {
    sendToNativeHost(request.data)
      .then((response) => sendResponse(response))
      .catch((error) => sendResponse({ error: error.message }));
    return true;
  }
});

connectToNativeHost();
