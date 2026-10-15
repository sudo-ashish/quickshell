function promptLooksFingerprint(text) {
  var s = String(text || "").toLowerCase()
  return s.indexOf("finger") !== -1 || s.indexOf("fprint") !== -1 || s.indexOf("swipe") !== -1
}

function fingerprintConfiguredFromPamConfig(raw) {
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/^\s+|\s+$/g, "")
    if (!line || line.charAt(0) === "#") continue
    if (!line.match(/^auth\s+/)) continue
    if (line.indexOf("pam_fprintd.so") !== -1) return true
  }
  return false
}

function authorizationLabel(message) {
  var text = String(message || "").trim();
  if (!text) return "Authentication Required";
  var match = text.match(/^Authentication is (?:needed|required) to run [`']?([^`']+)['`]? as /i);
  if (match) return "Authorize running '" + match[1] + "'";
  match = text.match(/^Authentication is (?:needed|required) to ([^.]+)/i);
  if (match) return "Authorize: " + match[1].trim();
  return text.endsWith(".") ? text.slice(0, -1) : text;
}

if (typeof module !== "undefined") {
  module.exports = {
    promptLooksFingerprint: promptLooksFingerprint,
    fingerprintConfiguredFromPamConfig: fingerprintConfiguredFromPamConfig,
    authorizationLabel: authorizationLabel
  }
}
