# EmbSegFlu
Z-stack-based automated nuclear segmentation and fluorescence intensity measurements for ImageJ2.

Installation instructions:
Download the .ijm file and run it from a FIJI installation (available here: https://fiji.sc/).

Application instructions:
1. Once ran, the macro must be pointed at a folder. The folder must contain .nd2 files at the top level, since it will further explore the folder structure.
2. After creating the necessary output folders, the macro will ask the user to draw at least 5 background areas. Draw ROIs and add them by pressing (Ctrl +) T.
3. Output can be found in [Output folder]\summaryTable.csv
