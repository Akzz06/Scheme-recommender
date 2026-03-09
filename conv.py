import json
import os

def main():
    # 1. Get the directory where THIS script file is located
    # This will be: A:\New prj\my_app - working version\assets\data\
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # 2. Define Input and Output paths relative to the script
    # We assume the JSON is in the SAME folder as this script
    input_filename = os.path.join(script_dir, 'output_part_1_cleaned.json')
    output_filename = os.path.join(script_dir, 'formatted_schemes.txt')

    print(f"Reading from: {input_filename}")
    
    # Check if input exists before trying to open
    if not os.path.exists(input_filename):
        print(f"ERROR: Could not find file {input_filename}")
        print("Please make sure your JSON file is in the 'assets/data' folder.")
        return

    with open(input_filename, 'r', encoding='utf-8') as f:
        data = json.load(f)

    formatted_documents = []

    # 3. Process the data
    schemes = data.get("schemes", {})
    
    for key, scheme in schemes.items():
        name = scheme.get("scheme_name_en", "Unknown Scheme")
        desc = scheme.get("description_en", "")
        benefits = scheme.get("benefits_en", "")
        eligibility = scheme.get("eligibility_criteria_en", "")
        process = scheme.get("how_to_apply_en", "")
        docs = scheme.get("documents_required_en", "")
        faqs = scheme.get("faqs_en", "")
        tags = ", ".join(scheme.get("tags_en", []))
        
        meta_info = f"""
        - Min Age: {scheme.get('min_age')}
        - Max Age: {scheme.get('max_age')}
        - State: {scheme.get('target_state', ['All'])[0]}
        - Link: {scheme.get('scheme_link')}
        """

        text_entry = f"""
==================================================
SCHEME NAME: {name}
TAGS: {tags}
==================================================

### DESCRIPTION
{desc}

### BENEFITS
{benefits}

### ELIGIBILITY
{eligibility}

### HOW TO APPLY
{process}

### DOCUMENTS REQUIRED
{docs}

### METADATA & LINKS
{meta_info}

### FAQ
{faqs}
"""
        formatted_documents.append(text_entry)

    # 4. Save the output
    print(f"Writing to: {output_filename}")
    with open(output_filename, "w", encoding='utf-8') as f:
        f.write("\n\n".join(formatted_documents))
    
    print(f"Success! Saved {len(formatted_documents)} schemes.")

if __name__ == "__main__":
    main()