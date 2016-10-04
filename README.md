# TopoTools
These are a series of matlab functions written by Adam M. Forte (aforte 'at' asu.edu) that build upon the functionality of TopoToolbox (https://topotoolbox.wordpress.com/). Each function contains a header with basic functionality info along with expected inputs and possible outputs. This readme compiles some of that information and lays out possible workflows. Discussions of workflows and tools assume a basic familiarity with the TopoToolbox data classes and Matlab functions.

# Getting Started
The first step in most processing workflows is going to the 'MakeStreams' function, which takes a georeferenced DEM file as either a GeoTiff or ascii and produces the basic TopoToolbox datasets (DEM as a GRIDobj, flow direction as FLOWobj, flow accumulation as GRIDobj, and stream network as STREAMobj). All other functions require outputs from this function.


# Ksn and Chi Maps (Batch Mode)
If you want to make maps of normalized channel steepness (ksn) or chi for all streams identified in 'MakeStreams', use the 'KSN_Chi_Batch' function. This function can be used to produce streams colored by ksn or chi (sensu Willett al al, 2014, Science) or alternatively a continuous grid of chi. Note that for ksn, this function produce shapefiles suitable for use in ArcGIS, where as the chi options produce ascii files importable as rasters into ArcGIS. This is because of the way Matlab deals with shapefiles, so to produce a shapefile of a chi map, import your ascii into ArcGIS and then use the raster to polyline tool.

# Interactive Ksn Definition
The function 'KSN_Profiler' is designed to mimic the majority of the core functionality of Profiler_51 (Wobus et al, 2006) but without any interaction with ArcGIS and some added features. The user selects channel heads on a map and after the selection of each channel head is able to pick segments of the stream. The user can choose to either choose segments on the basis of chi-z plots or longitudinal stream profiles. Additionally, the user can choose whether to avoid fitting the same portion of a trunk stream multiple times (i.e. any overlapping portion of a stream network that has already been fit is excluded from the rest of the analysis).

# Watershed Statistics and Clipping
One of the powerful aspects of TopoToolbox is to automate otherwise tedious processes (i.e. things that are annoying to do in Arc). One of those groups of tasks is to select a series of watersheds, clip them out, and calculate statistics. The 'ProcessRiverBasins' function is designed to do just this. To use this tool, you will need to have run 'MakeStreams' but also have a list of basin mouths (i.e. pour points) for your basins of interest. It is strongly recommended that you use the output shapefile of the stream network from 'MakeStreams' to pick basin mouths in Arc. DO NOT use a shapefile made from the hydrologic processing in Arc because the flow routing between Arc and TopoToolbox is slightly different, thus coordinates will not necessarily be the same. Once you have your matrix of river mouths, the 'ProcessRiverBasins' function will iteratively go through and clip out the DEM above this pour point and recalculate the stream network and produce various maps (e.g. chi map, ksn, etc) along with basin averaged statistics (e.g. ksn, gradient, etc). Ultimately you may want to include additional rasters (e.g. a precipitation dataset, landcover, etc) to clip and calculate statistics and it should be straight forward to plug in bits of codes for additional rasters. 

A companion function 'SubDivideBigBasins' is designed to be run after successfully running 'ProcessRiverBasins'. This function will find any resulting basin from the first function with a drainage area over a user defined threshold  (e.g. 100 km^2) and subdivide it down to smaller basins. Outputs from both 'ProcessRiverBasins' and 'SubDivideBigBasins' are written as individual mat files for each watershed, identified by the river number within the original pour points matrix.

# Further Processing of Outputs from Watershed Clipping
To make a GRIDobj of just the extents of your clipped watersheds from the 'ProcessRiverBasins' and 'SubDivideBigBasins' functions, use 'ExtentRaster'. The 'BasinValueRaster' is designed to produce a similar GRIDobj but with each watershed assigned a specified value (e.g. the mean ksn of that watershed). The 'PlotIndividualBasins' function will iterate through all results from 'ProcessRiverBasins' and 'SubDivideBigBasins' and plot a three panel figure with the longitudinal profile, chi-elevation, and slope-area plots. Each figure will be saved as a separate pdf.

# Interactive Selection 
Several functions are designed to allow interactive selection of river profiles or basins. 'PickBasin' allows the user to interactively select a pour point and export a clipped DEM of that watershed. 'DetritalSamplePicker' is similar to 'PickBasin', but it allows the user to select an arbitrarily large number of basins. This function is designed to aid a user in selecting watersheds that meet certain criteria, e.g. if you are looking for basins that are a certain size and are well adjusted for sampling for cosmo. For each basin selected, the function will dislplay a chi-z relationship along with the stream profile and allow you to either accept (i.e. save) or reject (i.e. don't save) the basin you picked. 'FindKnicks' is an interactive picker for knickpoints on a basin file from 'ProcessRiverBasins' or 'SubDivideBigBasins' which allows the user to select knickpoints on chi-elevation plots. 'SegmentPicker' allows the user to choose multiple individual drainage networks (above selected pour points) or multiple individual channels (down from selected channel heads) from a selected basin file. 'SegmentPlotter' will plot the specified results of using the 'SegmentPicker' function.

# Other Functions
There are several other functions in the folder, many of these are helper functions used by some of the above functions (i.e. put the whole folder and all of its subfolders on your path or things will break!). There is a folder called 'SwathTools' which contains some functions that wrap TopoToolbox's existing and (powerful) SWATHobj functions.

# Dependencies
These codes make use of several other Matlab toolboxes, which are freely available from the Matlab file exchange but I have not included here as a courtesy to the developers of those toolboxes. These are the toolboxes:
-hline and vline
-real2rgb
-cbrewer
