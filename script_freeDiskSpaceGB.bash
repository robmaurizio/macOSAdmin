#!/bin/bash

# Get free disk space rounded down to nearest GB
freeDiskSpace=$(diskutil info /|awk '/Free Space|Available Space/ {print int($4)}')
