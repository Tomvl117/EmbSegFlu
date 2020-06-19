// path of the folder that contains the set of images in nd2 format, ask the user for directory
pathImgDir = getDirectory("Choose a Directory...");

imagesList = getFileList(pathImgDir); // analyze each file of the folder
for(content=0; content<imagesList.length; content++) {
	file = pathImgDir+imagesList[content];

	if (endsWith(file, ".nd2")) { // First quickly peek into the file to determine the number of series inside
		run("Bio-Formats", "open=[" + file + "] color_mode=Default open_all_series view=Hyperstack stack_order=XYCZT use_virtual_stack"); // Open the image as a virtual stack to save computing power
		
		aux = getList("image.titles"); // Index all the open images, creating an array of both the image titles and the total number of series contained within the file
		
		run("Close All");
		
		for (i = 0; i < aux.length; i++) {
			currentSeries = i+1; // Because i starts at 0, and series start at 1, we have to use a different index
			
			outPath = pathImgDir+"segmentation-analysis_"+aux[i]+"\\"; // Create output path based on the analyzed file
			File.makeDirectory(outPath);
			
			if(File.isDirectory(outPath)!=1){ // Check if the directory has actually been made, otherwise make a new directory with a MacOS-compatible directory
				outPath = pathImgDir+"segmentation-analysis_"+aux[i]+"/";
				File.makeDirectory(outPath);
			}
		
			run("Bio-Formats Importer", "open=[" + file + "] autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_"+currentSeries+""); // The "series" parameter will be ignored if there is only a single series
		
			/****** saving montage and merging channels ******/
			run("Duplicate...", "duplicate");
			rename("temp");
			selectWindow("temp");
			run("Split Channels");
			selectWindow("C4-temp");
			run("Grays");
			selectWindow("C2-temp");
			run("Blue");
			selectWindow("C1-temp");
			run("Red");
			run("Merge Channels...", "c1=C1-temp c2=C2-temp c3=C3-temp c4=C4-temp create keep");
			run("Z Project...", "projection=[Max Intensity]"); // Create and save a maximum intensity projection
			
			save(outPath+"MAX_temp.tif");
			save(outPath+"MAX_temp.jpg");
			run("Make Montage...", "columns=4 rows=1 scale=0.50");
			save(outPath+"Montage.tif");
			save(outPath+"Montage.jpg");
			selectWindow("MAX_temp");
			run("Split Channels");
			
			selectWindow("C4-MAX_temp");
			selectWindow("C1-MAX_temp");
			run("Merge Channels...", "c1=C1-MAX_temp c4=C4-MAX_temp create keep");
			save(outPath+"C1_C4.tif");
			save(outPath+"C1_C4.jpg");
			selectWindow("C2-MAX_temp");
			run("Merge Channels...", "c2=C2-MAX_temp c4=C4-MAX_temp create keep");
			save(outPath+"C2_C4.tif");
			save(outPath+"C2_C4.jpg");
			selectWindow("C3-MAX_temp");
			run("Merge Channels...", "c3=C3-MAX_temp c4=C4-MAX_temp create keep");
			save(outPath+"C3_C4.tif");
			save(outPath+"C3_C4.jpg");
			selectWindow("C2-MAX_temp");
			run("Merge Channels...", "c2=C2-MAX_temp c3=C3-MAX_temp c4=C4-MAX_temp create keep");
			save(outPath+"C2_C3_C4.tif");
			save(outPath+"C2_C3_C4.jpg");
			run("Close All");
			
			/*************************************************/
			 
			run("Bio-Formats Importer", "open=[" + outPath + "MAX_temp.tif] autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT"); // Open the Maximum Intensity Projection of the image
			rename("MAX_temp.tif"); // Because opening the MIP would sometimes give the image a slightly different title
			run("In [+]"); // Zoom
			// This section will let the user draw ROIs for background subtraction
			// Note that the MIP will only be used for drawing the ROIs, not for the actual background readings
			
			Dialog.create("Background Subtraction");
			Dialog.addMessage("Please draw and add at least 5 ROIs for background subtraction.\nYou will be prompted once 5 ROIs have been detected.\nNote: The background will not be read from this Maximum Intensity Projection,\nbut the ROIs defined here will be used in the raw 3D stacks.");
			Dialog.addCheckbox("Skip this image", false); // Inspired by a faulty image that ended up taking half an hour to run, this checkbox will let the user skip the current image
			Dialog.show();
			skip = Dialog.getCheckbox();

			if(skip!=1){
				run("Set Measurements...", "mean redirect=None decimals=3"); // Prepare for background subtraction by the user
				run("ROI Manager...");
				roiManager("Show all with labels");
				setTool("Freehand");
				selectWindow("MAX_temp.tif");
				
				backgroundCount = roiManager("count"); // backgroundCount will count the number of ROIs drawn
				
				while(backgroundCount < 5){ // Once 5 ROIs have been drawn, the user will be prompted to continue adding or to continue the macro
					backgroundCount = roiManager("count");
				}
				
				waitForUser("Minimum of 5 ROIs reached. Draw any number of additional ROIs, then press OK to continue.\nYou can continue working with this prompt open.");
				
				backgroundCount = roiManager("count"); // Count the number of ROIs finally drawn by the user and close the image
				run("Close All");
				
				run("Bio-Formats Importer", "open=[" + file + "] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT series_"+currentSeries+""); // Open the complete stack
				
				run("Duplicate...", "title=image duplicate"); // Duplicate the image and split channels
				selectWindow("image");
				run("Split Channels");
	
				selectWindow("C1-image"); // In each channel, the mean gray values inside the defined ROIs will be analyzed, averaged and subtracted from the overall image
				roiManager("Multi Measure");
				run("Summarize"); // Will append 4 new rows to the results section, the 1st of which is the Mean of all measurements over the slices
				
				for(j=0; j<backgroundCount; j++){ // The number of columns is determined by the number of ROIs, so we cycle through the columns using the backgroundCount as an index
					column = j+1; // Since the column name starts at 1 and the index at 0, we use a different column index
					meanBackgroundC1 += getResult("Mean"+column, nResults-4); // nResults-4 will always give us the row with the mean
				}
				
				meanBackgroundC1 = meanBackgroundC1/backgroundCount; // Divide over the number of columns, so we have a mean of means. Used meanBackground values can be found in the final CSV output
				run("Subtract...", "value="+meanBackgroundC1+" stack"); // Subtract over the entire channel stack
				run("Clear Results");
				
				selectWindow("C2-image");
				roiManager("Multi Measure");
				run("Summarize");
				
				for(j=0; j<backgroundCount; j++){
					column = j+1;
					meanBackgroundC2 += getResult("Mean"+column, nResults-4);
				}
				
				meanBackgroundC2 = meanBackgroundC2/backgroundCount;
				run("Subtract...", "value="+meanBackgroundC2+" stack");
				run("Clear Results");
				
				selectWindow("C3-image");
				roiManager("Multi Measure");
				run("Summarize");
				
				for(j=0; j<backgroundCount; j++){
					column = j+1;
					meanBackgroundC3 += getResult("Mean"+column, nResults-4);
				}
				
				meanBackgroundC3 = meanBackgroundC3/backgroundCount;
				run("Subtract...", "value="+meanBackgroundC3+" stack");
				run("Clear Results");
				
				selectWindow("C4-image");
				roiManager("Multi Measure");
				run("Summarize");
				
				for(j=0; j<backgroundCount; j++){
					column = j+1;
					meanBackgroundC4 += getResult("Mean"+column, nResults-4);
				}
				
				meanBackgroundC4 = meanBackgroundC4/backgroundCount;
				// Since we will use the 4th channel (Hoechst) for creating the masks and we will need as much information retained for that as possible, we will not subtract the background for C4
				run("Clear Results");
				
				roiManager("Delete"); // Rinse the ROI manager and continue
	
				/*************************************************/
				
				selectWindow("C4-image");
				run("Grays"); // Convert Hoechst channel LUT to Grays
				run("Duplicate...", "title=C4-image-overlay duplicate");
				selectWindow("C4-image");
				
				run("Gaussian Blur 3D...", "x=1.0 y=1.0 z=0.5"); // TODO: Improve blurring
				
				run("Duplicate...", "title=C4-image-gaussian duplicate");
				selectWindow("C4-image");
				
				setOption("ScaleConversions", true); // Auto threshold the image using the Default/IsoData algorithm
				run("Auto Threshold", "method=Default ignore_black white stack use_stack_histogram");
				
				run("Duplicate...", "title=C4-image-gaussian-threshold duplicate");
				selectWindow("C4-image");
				save(outPath+"C4-image_binary.tif");
				
				run("3D Distance Map", "map=EDT image=C4-image mask=Same threshold=1"); // Create a distance map for the thresholded image
				selectWindow("EDT");
				rename("C4-image-gaussian-threshold-EDT");
				
				run("3D Maxima Finder", "radiusxy=6 radiusz=3 noise=100"); // Calculate peaks of the distance map, which should result in an overview of all individual objects of the original image, even when objects are visually merged
				run("3D Watershed", "seeds_threshold=0 image_threshold=0 image=C4-image seeds=peaks radius=0"); // Watershed the thresholded image with the calculated peaks, dividing the areas of the thresholded image over the calculated peaks
				
				selectWindow("watershed"); // Prepare the watershedded image for visualization
				rename("C4-watershed");
				run("glasbey_on_dark");
				run("Duplicate...", "title=C4-image-gaussian-threshold-watershed duplicate");
				
				selectWindow("C4-watershed");
				save(outPath+"3D-labeling.tif");
				run("Merge Channels...", "c1=C4-image-overlay c2=C4-watershed create keep");
				save(outPath+"C4-image_overlay.tif");
				close("Composite");
				
				selectWindow("C4-watershed");
				run("3D Manager Options", "volume integrated_density mean_grey_value std_dev_grey_value minimum_grey_value maximum_grey_value mode_grey_value drawing=Contour");
				run("3D Manager");			 
				Ext.Manager3D_AddImage();
				Ext.Manager3D_Count(nb);
				print(nb);
				
				Ext.Manager3D_Measure();
				Ext.Manager3D_SaveResult("M",outPath+"Measures3D.csv");
				Ext.Manager3D_CloseResult("M");
				
				selectWindow("C4-image-overlay");
				Ext.Manager3D_Quantif();
				Ext.Manager3D_SaveResult("Q",outPath+"C4-Quantif3D.csv");
				Ext.Manager3D_CloseResult("Q");
				
				selectWindow("C1-image");
				run("Grays");
				Ext.Manager3D_Quantif();
				Ext.Manager3D_SaveResult("Q",outPath+"C1-Quantif3D.csv");
				Ext.Manager3D_CloseResult("Q");
				selectWindow("C1-image");
				run("Merge Channels...", "c1=C1-image c2=C4-watershed create keep");
				save(outPath+"C1-image_overlay.tif");
				close("Composite");
				
				selectWindow("C2-image");
				run("Grays");
				Ext.Manager3D_Quantif();
				Ext.Manager3D_SaveResult("Q",outPath+"C2-Quantif3D.csv");
				Ext.Manager3D_CloseResult("Q");
				selectWindow("C2-image");
				run("Merge Channels...", "c1=C2-image c2=C4-watershed create keep");
				save(outPath+"C2-image_overlay.tif");
				close("Composite");
				
				selectWindow("C3-image");
				run("Grays");
				Ext.Manager3D_Quantif();
				Ext.Manager3D_SaveResult("Q",outPath+"C3-Quantif3D.csv");
				Ext.Manager3D_CloseResult("Q");
				selectWindow("C3-image");
				run("Merge Channels...", "c1=C3-image c2=C4-watershed create keep");
				save(outPath+"C3-image_overlay.tif");
				close("Composite");
				
				updateResults();
				Ext.Manager3D_Select(0);
				Ext.Manager3D_DeselectAll();
				
				Ext.Manager3D_Reset();
				Ext.Manager3D_Close();
				
				run("Close All");
				
				selectWindow("Results");
				run("Close");
				
				//////////////////////////////////////////////////
				
				// creating the summary of the results
				summaryPath = outPath + "summaryTable.csv";
				if(File.exists(summaryPath)) {
					File.delete(summaryPath);
				}
				
				summaryFile = File.open(summaryPath);
				print(summaryFile, "Obj,Label,sizeOutlier,Vol(pix),IntDen_C1,Min_C1,Max_C1,Mean_C1,Sigma_C1,Mode_C1,Bkgrnd_C1,IntDen_C2,Min_C2,Max_C2,Mean_C2,Sigma_C2,Mode_C2,Bkgrnd_C2,IntDen_C3,Min_C3,Max_C3,Mean_C3,Sigma_C3,Mode_C3,Bkgrnd_C3,IntDen_C4,Min_C4,Max_C4,Mean_C4,Sigma_C4,Mode_C4,Bkgrnd_C4," + "\n");
				
				//////////////////////////////////////////////////
				
				// summary of the results
				path0 = outPath+"M_Measures3D.csv";
				path1 = outPath+"Q_C1-Quantif3D.csv";
				path2 = outPath+"Q_C2-Quantif3D.csv";
				path3 = outPath+"Q_C3-Quantif3D.csv";
				path4 = outPath+"Q_C4-Quantif3D.csv";
				
				csvFile0 = File.openAsString(path0);
				csvFile1 = File.openAsString(path1);
				csvFile2 = File.openAsString(path2);
				csvFile3 = File.openAsString(path3);
				csvFile4 = File.openAsString(path4);
				
				rows0 = split(csvFile0, "\n");
				rows1 = split(csvFile1, "\n");
				rows2 = split(csvFile2, "\n");
				rows3 = split(csvFile3, "\n");
				rows4 = split(csvFile4, "\n");
				
				if(rows0.length == rows1.length && rows1.length == rows2.length && rows2.length == rows3.length && rows3.length == rows4.length) {
					totalObjects = 0;
					for(x=1; x<rows0.length; x++) {
\
						columns0 = split(rows0[x], ",");
						columns1 = split(rows1[x], ",");
						columns2 = split(rows2[x], ",");
						columns3 = split(rows3[x], ",");
						columns4 = split(rows4[x], ",");		
						
						if(parseInt(columns0[5])>=25){ // If volume (columns0[5]) is less than 25, the object is considered an outlier and gets value 0
							sizeOutlier = 1;
							totalObjects++;
						}else{
							sizeOutlier = 0;
						}
				
						print(summaryFile, columns0[1] + "," + columns0[3] + "," + sizeOutlier + "," + columns0[5] + "," + 
						columns1[5] + "," + columns1[6] + "," + columns1[7] + "," + columns1[8] + "," + columns1[9] + "," + columns1[10] + "," + meanBackgroundC1 + "," + 
						columns2[5] + "," + columns2[6] + "," + columns2[7] + "," + columns2[8] + "," + columns2[9] + "," + columns2[10] + "," + meanBackgroundC2 + "," + 
						columns3[5] + "," + columns3[6] + "," + columns3[7] + "," + columns3[8] + "," + columns3[9] + "," + columns3[10] + "," + meanBackgroundC3 + "," + 
						columns4[5] + "," + columns4[6] + "," + columns4[7] + "," + columns4[8] + "," + columns4[9] + "," + columns4[10] + "," + meanBackgroundC4 + "," + "\n");
					}
					print(summaryFile, ",," + totalObjects);
				} else {
					print("csv files have different sizes");
				}
				
				File.delete(path0);
				File.delete(path1);
				File.delete(path2);
				File.delete(path3);
				File.delete(path4);
				
				File.close(summaryFile);
				selectWindow("Log");
				run("Close");
			}else{
				run("Close All");
			}
		}
	}
}
print("Finished directory:");
print(pathImgDir);
