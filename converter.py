import csv
import os
import re
import frontmatter
from pathlib import Path


def clean_filename(name):

    # Removes characters that are invalid for filenames across most OS platforms.

    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def csv_to_markdown(csv_filepath, output_dir="output_markdown"):

    #############################################################
    # THIS CHUNK OF CODE DELETES ALL .md FILES IN THE DIRECTORY #
    # THIS IS USEFUL WHEN RUNNING CODE REPEATEDLY               #
    # md_dir_path = Path(OUTPUT_DIRECTORY)                        #
    # for file_path in md_dir_path.glob("*.md"):                  #
    #     if file_path.is_file():                                 #
    #         file_path.unlink()                                  #
    #         print(f"Deleted: {file_path}")                      #
    # BUT PROBABLY SHOULD NOT BE RAN WHEN FINISHED              #
    # MAKE SURE TO COMMENT THIS OUT EVENTUALLY                  #
    #############################################################
    # Reads a CSV file and generates a Markdown file for each row.
    # Create the output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created directory: {output_dir}")

    try:
        with open(csv_filepath, mode='r', encoding='utf-8-sig') as csv_file:
            # Use DictReader to automatically map headers to row values
            reader = csv.DictReader(csv_file)
            headers = reader.fieldnames
            print('headers: ', headers)
            if not headers:
                print("Error: The CSV file is empty or missing headers.")
                return

            # print(f"Reading {csv_filepath}... Found headers: {', '.join(headers)}")

            for index, row in enumerate(reader, start=1):

                # if index > 200:
                #     break
                # 1. Determine a unique filename for the markdown file
                # We try using the first column's value (e.g., 'Title' or 'ID').
                # If it is empty, we fall back to 'row_index'.
                first_column_value = row[headers[0]]
                title = row[headers[1]]
                id = row['item_id']
                if first_column_value:
                    base_filename = clean_filename(str(title))
                else:
                    base_filename = f"row_{index}"

                filename = f"{base_filename}_{id}.md"
                filepath = os.path.join(output_dir, filename)

                # Does this file already exist?
                if os.path.exists(filepath):
                    # If so, that means there are two entries in our DB with different programAreas/Subcategories for this item
                    with open(filepath) as inputFile:
                        # We're going to need to get the data that's already in the file and ADD to it
                        post = frontmatter.loads(inputFile.read())
                else:
                    # If this file doesn't already exist we'll set up an empty object to add data to
                    post = frontmatter.Post("")
                    # also make sure to set up an empty array so we can append to it later
                    post.metadata['programAreas'] = []

                print('processing: ', row['item_id'])

                # Metadata / Attributes list
                # 0 - title
                # 1 - body
                # 2 - subCategory
                # 3 - programArea
                # 4 - publishDate
                # 5 - externalURL
                # 6 - expiryDate

                # Set up each property
                id = int(row['item_id'])
                programArea = row['programArea']
                title = row['title']
                subcategory = row['subCategory']
                body = row['body']
                publishDate = row['publishDate']
                externalURL = row['externalUrl']
                expiryDate = row['expiryDate'] if row['expiryDate'] != 'NULL' else None

                # add properties
                post.metadata['itemId'] = id
                post.metadata['title'] = title
                post.metadata['publishDate'] = publishDate
                post.metadata['externalURL'] = externalURL
                post.metadata['expiryDate'] = expiryDate
                post.content = body

                # we fetch this from the existing metadata, because this may need to be updated
                programAreas = post.metadata['programAreas']
                # we need to make a dict for the programAreas we could be adding
                programAreasDict = {programArea : []}

                # if the file does NOT yet have a program area, we are going to be adding this one
                if len(programAreas) == 0:
                        programAreas.append(programAreasDict)
                # if the file DOES have existing programAreas, we need to check to see if this one exists before adding it
                for item in programAreas:
                    if programArea not in item:
                        programAreas.append(programAreasDict)

                # we don't need to make the same checks as above for subcategories, because our data should never have duplicated subcategories in it
                for item in programAreas:
                    if programArea in item:
                        item[programArea].append(subcategory)


                #     val = row[header]
                #     # Escape basic markdown characters to avoid breaking syntax
                #     safe_val = str(val).replace("*", "\\*").replace("_", "\\_").replace('"','\\"')

                # 3. Write the markdown file
                with open(filepath, mode='w', encoding='utf-8') as md_file:
                    md_file.write(frontmatter.dumps(post))

            print(f"\n Success! All rows have been processed and saved to '{output_dir}'.")

    except FileNotFoundError:
        print(f"Error: The file '{csv_filepath}' was not found.")
    except UnicodeDecodeError as e:
        print(f"Error: Unicode character: {e}")
        print(row)
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # --- CONFIGURATION ---
    # Replace 'data_cleaned_subcategories_trimmed.csv' with the path to your actual CSV file
    CSV_FILE_PATH = "C:/Users/rdcerdtb/tmp/fedcenter_data_pull_20aug2026.csv"
    # Replace 'tmp' with your desired output directory name
    OUTPUT_DIRECTORY = "C:/Users/rdcerdtb/tmp"

    csv_to_markdown(CSV_FILE_PATH, OUTPUT_DIRECTORY)
