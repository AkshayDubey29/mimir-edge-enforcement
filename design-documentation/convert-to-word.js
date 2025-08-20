#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Simple markdown to HTML converter
function markdownToHtml(markdown) {
    let html = markdown;
    
    // Convert headers
    html = html.replace(/^### (.*$)/gim, '<h3>$1</h3>');
    html = html.replace(/^## (.*$)/gim, '<h2>$1</h2>');
    html = html.replace(/^# (.*$)/gim, '<h1>$1</h1>');
    
    // Convert bold
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    
    // Convert italic
    html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');
    
    // Convert code blocks
    html = html.replace(/```(\w+)?\n([\s\S]*?)```/g, '<pre><code>$2</code></pre>');
    
    // Convert inline code
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
    
    // Convert lists
    html = html.replace(/^- (.*$)/gim, '<li>$1</li>');
    html = html.replace(/^(\d+)\. (.*$)/gim, '<li>$2</li>');
    
    // Convert paragraphs
    html = html.replace(/\n\n/g, '</p><p>');
    
    // Wrap in HTML structure
    html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Mimir Edge Enforcement - Comprehensive Documentation</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 40px;
            color: #333;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #34495e;
            border-bottom: 2px solid #ecf0f1;
            padding-bottom: 5px;
            margin-top: 30px;
        }
        h3 {
            color: #7f8c8d;
            margin-top: 25px;
        }
        code {
            background-color: #f8f9fa;
            padding: 2px 4px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        pre {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            border-left: 4px solid #3498db;
        }
        pre code {
            background-color: transparent;
            padding: 0;
        }
        li {
            margin-bottom: 5px;
        }
        p {
            margin-bottom: 15px;
        }
        .toc {
            background-color: #ecf0f1;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 30px;
        }
        .toc h2 {
            border-bottom: none;
            margin-top: 0;
        }
        .toc ul {
            list-style-type: none;
            padding-left: 0;
        }
        .toc li {
            margin-bottom: 8px;
        }
        .toc a {
            text-decoration: none;
            color: #2c3e50;
        }
        .toc a:hover {
            color: #3498db;
        }
        .highlight {
            background-color: #fff3cd;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #ffc107;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f8f9fa;
        }
    </style>
</head>
<body>
    ${html}
</body>
</html>`;
    
    return html;
}

// Main conversion function
function convertMarkdownToWord() {
    console.log('🔄 Starting markdown to Word conversion...');
    
    const inputFile = 'MIMIR_EDGE_ENFORCEMENT_COMPREHENSIVE_DOCUMENTATION.md';
    const outputFile = 'Mimir_Edge_Enforcement_Documentation.html';
    
    try {
        // Read the markdown file
        console.log(`📖 Reading markdown file: ${inputFile}`);
        const markdown = fs.readFileSync(inputFile, 'utf8');
        
        // Convert to HTML
        console.log('🔄 Converting markdown to HTML...');
        const html = markdownToHtml(markdown);
        
        // Write HTML file
        console.log(`💾 Writing HTML file: ${outputFile}`);
        fs.writeFileSync(outputFile, html);
        
        console.log('✅ Conversion completed successfully!');
        console.log('');
        console.log('📋 Next steps:');
        console.log('1. Open the HTML file in your web browser');
        console.log('2. Use "Print" or "Save as PDF" from your browser');
        console.log('3. Or open the HTML file directly in Microsoft Word');
        console.log('');
        console.log('📁 Files created:');
        console.log(`   - ${outputFile} (HTML version)`);
        console.log('');
        console.log('💡 Alternative methods:');
        console.log('   - Copy the HTML content and paste into Word');
        console.log('   - Use browser "Print to PDF" then convert to Word');
        console.log('   - Install pandoc: brew install pandoc');
        
    } catch (error) {
        console.error('❌ Error during conversion:', error.message);
        process.exit(1);
    }
}

// Run the conversion
convertMarkdownToWord();
