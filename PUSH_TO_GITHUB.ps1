## Run these commands in PowerShell to push your code to GitHub
## Replace YOUR_USERNAME with your actual GitHub username

# Step 1: Navigate to the Capture Pro root
cd "E:\Google Antigravity\Capture Pro"

# Step 2: Initialize Git
git init

# Step 3: Stage all files
git add .

# Step 4: Create first commit
git commit -m "Initial commit - Capture Pro Android + iOS"

# Step 5: Link to your GitHub repo (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/CapturePro.git

# Step 6: Push code to GitHub
git branch -M main
git push -u origin main

## After this, go to:
## https://github.com/YOUR_USERNAME/CapturePro/actions
## You will see the iOS build running automatically!
## When it finishes, click the build run, scroll to "Artifacts" at the bottom,
## and download CapturePro-iOS-Unsigned.zip which contains your CapturePro.ipa file
