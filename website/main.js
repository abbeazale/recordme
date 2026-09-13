window.va =
  window.va ||
  function queueAnalyticsEvent(...event) {
    window.vaq = window.vaq || [];
    window.vaq.push(event);
  };

const demo = document.querySelector("#demo");
const message = document.querySelector("#demo-message");
const recordButton = document.querySelector("#record-button");
const recordLabel = document.querySelector("#record-label");
const recordingChip = document.querySelector("#recording-chip");
const previewTime = document.querySelector("#preview-time");
const appStatus = document.querySelector("#app-status");
let recordingTimer;

document.querySelectorAll("button[data-source]").forEach((button) => {
  button.addEventListener("click", () => {
    const source = button.dataset.source;
    demo.dataset.source = source;
    document.querySelectorAll("button[data-source]").forEach((sourceButton) => {
      sourceButton.setAttribute(
        "aria-pressed",
        String(sourceButton === button),
      );
    });
    message.textContent =
      source === "window"
        ? "Just the window. Everything around it stays out of the picture."
        : "The whole display, ready for your next walkthrough.";
  });
});

document.querySelectorAll(".option-button").forEach((button) => {
  button.addEventListener("click", () => {
    const enabled = button.getAttribute("aria-pressed") !== "true";
    button.setAttribute("aria-pressed", String(enabled));
    if (button.id === "camera-toggle") {
      document.querySelector("#camera-preview").hidden = !enabled;
    }
    const label = button.getAttribute("aria-label").replace(" preview", "");
    message.textContent = `${label} ${enabled ? "on" : "off"} in the preview. No device access is requested.`;
  });
});

function stopPreview() {
  clearInterval(recordingTimer);
  demo.dataset.recording = "false";
  recordButton.setAttribute("aria-pressed", "false");
  recordingChip.hidden = true;
  recordLabel.textContent = "Try again";
  appStatus.textContent = "Ready when you are";
  message.textContent =
    "That’s the idea. Download RecordMe to make your first real recording.";
}

recordButton.addEventListener("click", () => {
  if (demo.dataset.recording === "true") {
    stopPreview();
    return;
  }
  const startedAt = Date.now();
  demo.dataset.recording = "true";
  recordButton.setAttribute("aria-pressed", "true");
  recordingChip.hidden = false;
  recordLabel.textContent = "Stop preview";
  appStatus.textContent = "Preview in progress";
  previewTime.textContent = "00:00";
  message.textContent =
    "Imagine your next walkthrough here. This demo doesn’t record or save anything.";
  recordingTimer = setInterval(() => {
    const elapsed = Math.floor((Date.now() - startedAt) / 1000);
    if (elapsed >= 60) {
      stopPreview();
      return;
    }
    previewTime.textContent = `00:${String(elapsed).padStart(2, "0")}`;
  }, 250);
});

function revealLinkedAnswer() {
  if (window.location.hash === "#installation") {
    document.querySelector("#installation").open = true;
  }
}
window.addEventListener("hashchange", revealLinkedAnswer);
revealLinkedAnswer();

document.querySelectorAll("button[data-background]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelector("#style-demo").dataset.background =
      button.dataset.background;
    document.querySelector("#canvas-status").textContent =
      button.getAttribute("aria-label");
    document.querySelectorAll("button[data-background]").forEach((swatch) => {
      swatch.setAttribute("aria-pressed", String(swatch === button));
    });
  });
});

document
  .querySelector("#click-preview-button")
  .addEventListener("click", (event) => {
    const button = event.currentTarget;
    const enabled = button.getAttribute("aria-pressed") !== "true";
    button.setAttribute("aria-pressed", String(enabled));
    document
      .querySelector("#style-demo")
      .classList.toggle("show-click", enabled);
    document.querySelector("#canvas-status").textContent = enabled
      ? "Click highlight visible in the preview"
      : `${document.querySelector('.swatch[aria-pressed="true"]').getAttribute("aria-label")}`;
  });
