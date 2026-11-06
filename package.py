#!/usr/bin/env python3
import os
import zipfile

def build_magisk_zip():
    base_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'module')
    output_zip = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'QProFastCharge-Magisk.zip')
    
    print(f"Packaging Magisk module from: {base_dir}")
    print(f"Output destination: {output_zip}")
    
    with zipfile.ZipFile(output_zip, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(base_dir):
            for file in sorted(files):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, base_dir).replace('\\', '/')
                zipf.write(full_path, rel_path)
                print(f"  + Added: {rel_path}")

    print(f"\n[OK] Successfully created {output_zip} ({os.path.getsize(output_zip)} bytes)")

if __name__ == '__main__':
    build_magisk_zip()
