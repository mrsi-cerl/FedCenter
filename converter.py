import csv
import os
import re

def clean_filename(name):

    # Removes characters that are invalid for filenames across most OS platforms.

    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def csv_to_markdown(csv_filepath, output_dir="output_markdown"):

    # Reads a CSV file and generates a Markdown file for each row.

    # Create the output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created directory: {output_dir}")

    try:
        with open(csv_filepath, mode='r', encoding='utf-8') as csv_file:
            # Use DictReader to automatically map headers to row values
            reader = csv.DictReader(csv_file)
            headers = reader.fieldnames

            if not headers:
                print("Error: The CSV file is empty or missing headers.")
                return

            print(f"Reading {csv_filepath}... Found headers: {', '.join(headers)}")

            for index, row in enumerate(reader, start=1):
                # 1. Determine a unique filename for the markdown file
                # We try using the first column's value (e.g., 'Title' or 'ID').
                # If it is empty, we fall back to 'row_index'.
                first_column_value = row[headers[0]]
                title = row[headers[1]]
                if first_column_value:
                    base_filename = clean_filename(str(title))
                else:
                    base_filename = f"row_{index}"

                filename = f"{base_filename}.md"
                filepath = os.path.join(output_dir, filename)

                # 2. Structure the Markdown Content
                markdown_lines = ['---']

                # Metadata / Attributes list
                for header in headers:
                    if header == 'body':
                        continue
                    val = row[header]
                    # Escape basic markdown characters to avoid breaking syntax
                    safe_val = str(val).replace("*", "\\*").replace("_", "\\_").replace('"','\\"')
                    if header == 'pubDate':
                        markdown_lines.append(f"{header}: {safe_val}")
                    else:
                        markdown_lines.append(f"{header}: \"{safe_val}\"")

                markdown_lines.append('---')

                markdown_lines.append(row[headers[2]])

                # Combine everything with newlines
                markdown_content = "\n".join(markdown_lines) + "\n"

                # 3. Write the markdown file
                with open(filepath, mode='w', encoding='utf-8') as md_file:
                    md_file.write(markdown_content)

                print(f"Generated: {filepath}")

            print(f"\n Success! All rows have been processed and saved to '{output_dir}'.")

    except FileNotFoundError:
        print(f"Error: The file '{csv_filepath}' was not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # --- CONFIGURATION ---
    # Replace 'input_data.csv' with the path to your actual CSV file
    CSV_FILE_PATH = "C:/Users/rdcerdtb/tmp/_select_i_id_as_item_id_i_title_as_item_i_body_as_body_pp_title__202607241256.csv"
    # Replace 'markdown_results' with your desired output directory name
    OUTPUT_DIRECTORY = "C:/Users/rdcerdtb/tmp"

    csv_to_markdown(CSV_FILE_PATH, OUTPUT_DIRECTORY)
