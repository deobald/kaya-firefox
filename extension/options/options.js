(function () {
  const serverInput = document.getElementById("server");
  const emailInput = document.getElementById("email");
  const passwordInput = document.getElementById("password");
  const saveBtn = document.getElementById("save-btn");
  const testBtn = document.getElementById("test-btn");
  const statusDiv = document.getElementById("status");

  const PASSWORD_SENTINEL = "••••••••";
  let passwordChanged = false;

  passwordInput.addEventListener("input", () => {
    passwordChanged = true;
  });

  function showStatus(message, type) {
    statusDiv.textContent = message;
    statusDiv.className = type;
  }

  async function loadSettings() {
    try {
      const result = await browser.storage.local.get(["server", "email"]);
      if (result.server) {
        serverInput.value = result.server;
      } else {
        serverInput.value = "https://savebutton.com";
      }
      if (result.email) {
        emailInput.value = result.email;
      }
    } catch (error) {
      console.error("Failed to load settings:", error);
    }

    try {
      const status = await browser.runtime.sendMessage({
        action: "checkConfigStatus",
      });
      if (status && status.has_password) {
        passwordInput.value = PASSWORD_SENTINEL;
        passwordChanged = false;
      }
    } catch (error) {
      console.error("Failed to check config status:", error);
    }
  }

  async function saveSettings() {
    const server = serverInput.value.trim() || "https://savebutton.com";
    const email = emailInput.value.trim();

    if (!email) {
      showStatus("Email is required", "error");
      return;
    }

    if (passwordChanged && !passwordInput.value) {
      showStatus("Password is required", "error");
      return;
    }

    try {
      await browser.storage.local.set({ server, email });

      const configMessage = {
        message: "config",
        server: server,
        email: email,
      };

      if (passwordChanged) {
        configMessage.password = passwordInput.value;
      }

      const response = await browser.runtime.sendMessage({
        action: "sendConfig",
        data: configMessage,
      });

      if (response && response.error) {
        showStatus("Error: " + response.error, "error");
      } else {
        showStatus("Settings saved successfully", "success");
        passwordInput.value = PASSWORD_SENTINEL;
        passwordChanged = false;
      }
    } catch (error) {
      showStatus("Error: " + error.message, "error");
    }
  }

  async function testConnection() {
    const server = serverInput.value.trim() || "https://savebutton.com";
    const email = emailInput.value.trim();

    if (!email) {
      showStatus("Email is required to test connection", "error");
      return;
    }

    if (passwordChanged && !passwordInput.value) {
      showStatus("Password is required to test connection", "error");
      return;
    }

    showStatus("Testing connection...", "info");

    try {
      const data = {
        message: "test_connection",
        server: server,
        email: email,
      };

      if (passwordChanged) {
        data.password = passwordInput.value;
      }

      const response = await browser.runtime.sendMessage({
        action: "testConnection",
        data: data,
      });

      if (response && response.error) {
        showStatus("Connection failed: " + response.error, "error");
      } else if (response && response.success) {
        showStatus("Connection successful!", "success");
      } else {
        showStatus("Connection failed: no response from daemon", "error");
      }
    } catch (error) {
      showStatus("Connection failed: " + error.message, "error");
    }
  }

  saveBtn.addEventListener("click", saveSettings);
  testBtn.addEventListener("click", testConnection);

  loadSettings();
})();
