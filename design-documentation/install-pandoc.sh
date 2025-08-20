#!/bin/bash

# Script to install pandoc and convert markdown to Word format

echo "🔧 Mimir Edge Enforcement - Document Conversion Setup"
echo "=================================================="

# Check if pandoc is already installed
if command -v pandoc &> /dev/null; then
    echo "✅ Pandoc is already installed"
    PANDOC_INSTALLED=true
else
    echo "📦 Pandoc not found. Installing..."
    PANDOC_INSTALLED=false
fi

# Install pandoc if needed
if [ "$PANDOC_INSTALLED" = false ]; then
    # Check if Homebrew is available
    if command -v brew &> /dev/null; then
        echo "🍺 Installing pandoc via Homebrew..."
        brew install pandoc
        if [ $? -eq 0 ]; then
            echo "✅ Pandoc installed successfully via Homebrew"
            PANDOC_INSTALLED=true
        else
            echo "❌ Failed to install pandoc via Homebrew"
        fi
    else
        echo "❌ Homebrew not found. Please install pandoc manually:"
        echo "   Visit: https://pandoc.org/installing.html"
        echo "   Or install Homebrew first: https://brew.sh/"
    fi
fi

# Convert to Word if pandoc is available
if [ "$PANDOC_INSTALLED" = true ]; then
    echo ""
    echo "🔄 Converting markdown to Word format..."
    
    # Check if the markdown file exists
    if [ -f "MIMIR_EDGE_ENFORCEMENT_COMPREHENSIVE_DOCUMENTATION.md" ]; then
        echo "📖 Found markdown file, converting..."
        
        # Convert to Word format
        pandoc MIMIR_EDGE_ENFORCEMENT_COMPREHENSIVE_DOCUMENTATION.md \
            -o Mimir_Edge_Enforcement_Documentation.docx \
            --toc \
            --number-sections \
            --metadata title="Mimir Edge Enforcement - Comprehensive Documentation" \
            --metadata author="Development Team" \
            --metadata date="$(date +%Y-%m-%d)"
        
        if [ $? -eq 0 ]; then
            echo "✅ Word document created successfully!"
            echo "📁 File: Mimir_Edge_Enforcement_Documentation.docx"
            echo ""
            echo "🎉 Conversion complete! You can now:"
            echo "   - Open the .docx file in Microsoft Word"
            echo "   - Edit and format as needed"
            echo "   - Share with stakeholders"
        else
            echo "❌ Failed to convert to Word format"
        fi
    else
        echo "❌ Markdown file not found. Please run ./consolidate-docs.sh first"
    fi
else
    echo ""
    echo "📋 Alternative conversion methods:"
    echo "1. Use the HTML version: Mimir_Edge_Enforcement_Documentation.html"
    echo "2. Open the HTML file in Microsoft Word"
    echo "3. Use online converters"
    echo "4. Install pandoc manually"
fi

echo ""
echo "📚 Available files:"
ls -la *.md *.html *.docx 2>/dev/null | grep -E "\.(md|html|docx)$" || echo "No conversion files found"

echo ""
echo "🔗 Helpful links:"
echo "   - Pandoc installation: https://pandoc.org/installing.html"
echo "   - Homebrew installation: https://brew.sh/"
echo "   - Online markdown to Word converters available"
