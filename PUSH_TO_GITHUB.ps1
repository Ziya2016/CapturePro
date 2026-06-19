##############################################################
##  CAPTURE PRO — PUSH TO GITHUB & TRIGGER iOS BUILD
##  Run this script in PowerShell (step by step)
##  Replace YOUR_GITHUB_USERNAME with your actual GitHub username
##############################################################

# ── STEP 1: Navigate to the project folder ───────────────────
cd "E:\Google Antigravity\Capture Pro"

# ── STEP 2: Verify you are on the right branch ───────────────
git status
# Should say: "On branch main, nothing to commit, working tree clean"

# ── STEP 3: Link your GitHub repository ──────────────────────
# Only run this ONCE. Replace YOUR_GITHUB_USERNAME below:
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/CapturePro.git

# ── STEP 4: Push all commits to GitHub ───────────────────────
git push -u origin main

##############################################################
##  AFTER PUSHING — WHAT HAPPENS NEXT:
##
##  1. Open your browser and go to:
##     https://github.com/YOUR_GITHUB_USERNAME/CapturePro/actions
##
##  2. You will see a workflow called "Build iOS IPA" running.
##     It has 8 steps with emoji labels so you can track progress.
##     The entire build takes about 5-10 minutes.
##
##  3. Once ALL steps show a GREEN checkmark ✅, click on the
##     completed workflow run.
##
##  4. Scroll to the bottom of the page to find "Artifacts".
##
##  5. Click "CapturePro-iOS-Unsigned" to download a ZIP file.
##     Inside that ZIP is your CapturePro.ipa file!
##
##############################################################
##  HOW TO INSTALL THE .IPA ON AN iPHONE (Windows):
##
##  Use Sideloadly (FREE):
##  1. Download from: https://sideloadly.io/
##  2. Connect your iPhone via USB
##  3. Drag CapturePro.ipa into Sideloadly
##  4. Enter your Apple ID email → click Start
##  5. On iPhone: Settings → General → VPN & Device Management
##     → tap your Apple ID → tap Trust
##  6. Launch Capture Pro from your iPhone home screen!
##############################################################

# ── TO PUSH FUTURE UPDATES ───────────────────────────────────
# After any code change, run these two commands:
#   git add .
#   git commit -m "describe your change here"
#   git push
# The build will start automatically again on GitHub.
