#!/bin/bash

# Detect Python
if command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
elif command -v python &> /dev/null; then
    PYTHON_CMD=python
else
    echo "Python is not installed or not found in PATH!"
    exit 1
fi

# Ensure pip is installed
$PYTHON_CMD -m ensurepip --default-pip 2>/dev/null
$PYTHON_CMD -m pip install --upgrade pip 2>/dev/null

# Check if pip works now
if ! $PYTHON_CMD -m pip --version &> /dev/null; then
    echo "pip is not installed or still not found!"
    exit 1
fi

# Install/update the package
$PYTHON_CMD -m pip install --upgrade git+https://github.com/MikiP98/iProperties.git
if [ $? -ne 0 ]; then
    echo "Installation/update failed!"
    exit 1
fi

echo "Installation/update successful!"
