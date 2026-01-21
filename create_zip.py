#!/usr/bin/env python3
import os
import zipfile

def create_submission_zip():
    zip_name = "id1_id2.zip"
    
    with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Add client files
        zipf.write('client/makefile', 'client/makefile')
        
        # Create empty bin directory
        zipf.writestr('client/bin/', '')
        
        # Add all client source files
        for root, dirs, files in os.walk('client/src'):
            for file in files:
                if file.endswith('.cpp'):
                    path = os.path.join(root, file)
                    zipf.write(path, path)
        
        # Add all client header files
        for root, dirs, files in os.walk('client/include'):
            for file in files:
                if file.endswith('.h') or file.endswith('.hpp'):
                    path = os.path.join(root, file)
                    zipf.write(path, path)
        
        # Add client data files
        for root, dirs, files in os.walk('client/data'):
            for file in files:
                if file.endswith('.json'):
                    path = os.path.join(root, file)
                    zipf.write(path, path)
        
        # Add server pom.xml
        zipf.write('server/pom.xml', 'server/pom.xml')
        
        # Add SQL server script
        if os.path.exists('data/sql_server.py'):
            zipf.write('data/sql_server.py', 'data/sql_server.py')
        
        # Add all server Java source files
        for root, dirs, files in os.walk('server/src'):
            # Skip target directory
            if 'target' in root:
                continue
            for file in files:
                if file.endswith('.java'):
                    path = os.path.join(root, file)
                    zipf.write(path, path)
    
    print(f"Created {zip_name}")
    # Print contents
    with zipfile.ZipFile(zip_name, 'r') as zipf:
        print(f"\nZip contains {len(zipf.namelist())} files:")
        for name in sorted(zipf.namelist())[:20]:
            print(f"  {name}")
        if len(zipf.namelist()) > 20:
            print(f"  ... and {len(zipf.namelist()) - 20} more files")

if __name__ == '__main__':
    create_submission_zip()
