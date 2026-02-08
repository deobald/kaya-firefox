(function () {
  const serverInput = document.getElementById("server");
  const emailInput = document.getElementById("email");
  const passwordInput = document.getElementById("password");
  const saveBtn = document.getElementById("save-btn");
  const testBtn = document.getElementById("test-btn");
  const statusDiv = document.getElementById("status");

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
  }

  async function saveSettings() {
    const server = serverInput.value.trim() || "https://savebutton.com";
    const email = emailInput.value.trim();
    const password = passwordInput.value;

    if (!email) {
      showStatus("Email is required", "error");
      return;
    }

    if (!password) {
      showStatus("Password is required", "error");
      return;
    }

    try {
      await browser.storage.local.set({ server, email });

      const configMessage = {
        message: "config",
        server: server,
        email: email,
        password: password,
      };

      const response = await browser.runtime.sendMessage({
        action: "sendConfig",
        data: configMessage,
      });

      if (response && response.error) {
        showStatus("Error: " + response.error, "error");
      } else {
        showStatus("Settings saved successfully", "success");
        passwordInput.value = "";
      }
    } catch (error) {
      showStatus("Error: " + error.message, "error");
    }
  }

  async function testConnection() {
    const server = serverInput.value.trim() || "https://savebutton.com";
    const email = emailInput.value.trim();
    const password = passwordInput.value;

    if (!email || !password) {
      showStatus("Email and password are required to test connection", "error");
      return;
    }

    showStatus("Testing connection...", "info");

    try {
      const response = await fetch(
        `${server}/api/v1/${encodeURIComponent(email)}/anga`,
        {
          method: "GET",
          headers: {
            Authorization: "Basic " + btoa(`${email}:${password}`),
          },
        },
      );

      if (response.ok) {
        showStatus("Connection successful!", "success");
      } else if (response.status === 401) {
        showStatus(
          "Authentication failed - check your email and password",
          "error",
        );
      } else {
        showStatus(`Server returned status ${response.status}`, "error");
      }
    } catch (error) {
      showStatus("Connection failed: " + error.message, "error");
    }
  }

  saveBtn.addEventListener("click", saveSettings);
  testBtn.addEventListener("click", testConnection);

  loadSettings();
})();
