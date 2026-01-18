#!/bin/bash

# v4 Repo Scaffold

echo "🚀 Initializing NodeArmyMonolith-v4 structure..."

# Create folders
mkdir -p contracts scripts src/components src/pages src/utils test

# Create blank starter files
touch README.md
touch .env
touch package.json
touch hardhat.config.js

# Front-end starter files
touch src/pages/index.jsx
touch src/utils/web3.js

# Scripts
touch scripts/deploy.js

# Tests
touch test/NodeArmyMonolith.test.js

# Optional: Git init if not done
if [ ! -d ".git" ]; then
    git init
    git add .
    git commit -m "Initial v4 scaffold"
fi

echo "✅ Scaffold complete. Drop your smart contract in contracts/ and start coding!"
