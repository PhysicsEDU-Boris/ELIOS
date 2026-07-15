import os
import re
from pathlib import Path

def extract_info(filepath):
    exports = []
    imports = []
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # extract imports
    for match in re.finditer(r'''import\s+['"]([^'"]+)['"]''', content):
        imp = match.group(1)
        if not imp.startswith('dart:') and not imp.startswith('package:flutter/'):
            imports.append(imp)
            
    # extract classes
    for match in re.finditer(r'class\s+([A-Za-z0-9_]+)', content):
        exports.append(match.group(1))
        
    # extract enums
    for match in re.finditer(r'enum\s+([A-Za-z0-9_]+)', content):
        exports.append(match.group(1))
        
    # extract top level variables (providers)
    for match in re.finditer(r'final\s+([A-Za-z0-9_]+)\s*=\s*(?:[A-Za-z0-9_]+)?Provider', content):
        exports.append(match.group(1))
        
    # generate a simple purpose
    name = os.path.basename(filepath)
    purpose = name.replace('.dart', '').replace('_', ' ').capitalize() + " implementation"
    if "provider" in name:
        purpose = "State management for " + name.replace('_provider.dart', '').replace('_', ' ')
    elif "model" in name or str(filepath).startswith('lib/models/'):
        purpose = "Data structure for " + name.replace('.dart', '').replace('_model', '').replace('_', ' ')
    elif "screen" in name or "page" in name:
        purpose = "UI screen for " + name.replace('.dart', '').replace('_screen', '').replace('_page', '').replace('_', ' ')
    elif "service" in name:
        purpose = "Business logic/API for " + name.replace('_service.dart', '').replace('_', ' ')
        
    return {
        'exports': exports,
        'imports': imports,
        'purpose': purpose
    }

def main():
    lib_dir = Path('lib')
    files = list(lib_dir.rglob('*.dart'))
    files.sort()
    
    # group by top level folder
    top_level = {}
    for f in files:
        parts = f.parts
        if len(parts) > 1:
            top = parts[1]
            if top.endswith('.dart'):
                top = 'root'
        else:
            top = 'root'
            
        if top not in top_level:
            top_level[top] = []
        top_level[top].append(f)
        
    with open('FILE_MAP.md', 'w') as out:
        out.write("# `lib/` Inventory\n\n")
        out.write("## Folder Tree\n```\n")
        os.system("tree lib >> tree_output.txt 2>/dev/null || find lib -print | sort >> tree_output.txt")
        if os.path.exists("tree_output.txt"):
            with open("tree_output.txt", "r") as t:
                out.write(t.read())
            os.remove("tree_output.txt")
        else:
            out.write("(Tree not available)\n")
        out.write("```\n\n")
        
        for top, flist in top_level.items():
            if top == 'root':
                folder_name = 'lib/'
            else:
                folder_name = f"lib/{top}/"
                
            out.write(f"## {folder_name}\n\n")
            
            # check flags
            if len([f for f in flist if len(f.parts) == 3]) > 8:
                 out.write(f"**FLAG**: This folder has >8 files sitting flat and is a reorganization candidate.\n\n")
                 
            out.write("| File | Exports | Purpose | Depends on |\n")
            out.write("|---|---|---|---|\n")
            
            for f in flist:
                info = extract_info(f)
                rel_path = str(f)
                exports_str = ", ".join(info['exports']) if info['exports'] else "-"
                deps = [imp for imp in info['imports'] if imp.startswith('package:elio/') or not imp.startswith('package:')]
                deps_str = "<br>".join(deps) if deps else "-"
                purpose = info['purpose']
                out.write(f"| `{rel_path}` | {exports_str} | {purpose} | {deps_str} |\n")
            out.write("\n")

if __name__ == '__main__':
    main()
