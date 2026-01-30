#!/bin/bash

# Script to find unmigrated error handling in CTModels.jl
# Searches for usages of CTBase exceptions and generic error() calls

echo "=================================================================="
echo "🔍 Searching for unmigrated exceptions in src/ directory..."
echo "=================================================================="

total_count=0

# Function to search and count
search_and_count() {
    local title="$1"
    local pattern="$2"
    local exclude="$3"
    
    echo ""
    echo "$title"
    echo "-------------------------------------------"
    
    if [ -z "$exclude" ]; then
        matches=$(grep -n "$pattern" -r src/ | grep "\.jl")
    else
        matches=$(grep -n "$pattern" -r src/ | grep "\.jl" | grep -v "$exclude")
    fi
    
    if [ -z "$matches" ]; then
        count=0
        echo "No matches found."
    else
        echo "$matches"
        # wc -l produces spaces on some systems, xargs trims them
        count=$(echo "$matches" | wc -l | xargs)
    fi
    
    echo "👉 Count: $count"
    total_count=$((total_count + count))
}

# 1. CTBase.IncorrectArgument
search_and_count "🔴 Checking for CTBase.IncorrectArgument..." "CTBase.IncorrectArgument"

# 2. CTBase.UnauthorizedCall
search_and_count "🔴 Checking for CTBase.UnauthorizedCall..." "CTBase.UnauthorizedCall"

# 3. CTBase.NotImplemented
search_and_count "🔴 Checking for CTBase.NotImplemented..." "CTBase.NotImplemented"

# 4. Generic error() calls
# Excluding showerror, MethodError, ArgumentError
echo ""
echo "🟠 Checking for generic error() calls..."
echo "----------------------------------------"
# Complex exclusion needs specific handling, not using the function for this one to be safe/clear
matches=$(grep -n "error(" -r src/ | grep "\.jl" | grep -v "showerror" | grep -v "MethodError" | grep -v "ArgumentError")

if [ -z "$matches" ]; then
    count=0
    echo "No matches found."
else
    echo "$matches"
    count=$(echo "$matches" | wc -l | xargs)
fi
echo "👉 Count: $count"
total_count=$((total_count + count))


echo ""
echo "=================================================================="
echo "✅ Search complete. Total unmigrated errors found: $total_count"
echo "=================================================================="
