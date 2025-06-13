#!/bin/bash

# Containerize the `folio` SvelteKit application. Before building the Docker
# image, ensure that dependencies and application build is up-to-date.

echo
echo "Building SvelteKit application..."

if [ ! -d folio ]; then
    echo "Error: 'folio' directory does not exist."
    exit 1
fi
cd folio
npm install
if [ $? -eq 0 ]; then
    echo "Dependencies installed successfully."
else
    echo "Failed to install dependencies."
    exit 1
fi

npm run build
if [ $? -eq 0 ]; then
    echo "SvelteKit application built successfully."
else
    echo "Failed to build SvelteKit application."
    exit 1
fi
cd ..

echo
echo "Building Docker image..."

docker build -t folio:latest .
if [ $? -eq 0 ]; then
    echo "Docker image built successfully."
else
    echo "Failed to build Docker image."
    exit 1
fi
