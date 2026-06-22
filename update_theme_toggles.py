import os

lib_dir = r"C:\Users\SHAKEER F\Documents\IRIS\lib"

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            
            if "ThemeTogglePill" in content:
                new_content = content.replace("ThemeTogglePill", "ThemeToggleButton")
                
                # Add import for theme_toggle_button.dart if not present
                if "ThemeToggleButton" in new_content and file != "theme_toggle_button.dart":
                    # Figure out relative path to widgets/theme_toggle_button.dart
                    rel_depth = path.replace(lib_dir, "").count(os.sep) - 1
                    prefix = "../" * rel_depth if rel_depth > 0 else "./"
                    import_statement = f"import '{prefix}widgets/theme_toggle_button.dart';"
                    
                    if import_statement not in new_content:
                        # Find the last import and insert after it
                        lines = new_content.split("\n")
                        last_import_idx = -1
                        for i, line in enumerate(lines):
                            if line.startswith("import "):
                                last_import_idx = i
                        if last_import_idx != -1:
                            lines.insert(last_import_idx + 1, import_statement)
                        new_content = "\n".join(lines)
                
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new_content)
                print(f"Updated {file}")
