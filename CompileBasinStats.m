function [T]=CompileBasinStats(location_of_data_files,varargin)
	% Function to take the outputs from 'ProcessRiverBasins' and 'SubDivideBigBasins' and produce a single shapefile showing the outlines of polygons
	% 	and with commonly desired attributes from the results of 'ProcessRiverBasins' etc. See below for a full list of fields that the output shapefile
	% 	will include. If additional grids were provided to 'ProcessRiverBasins', mean and standard error values for those grids will be auto-populated in
	% 	the shapefile and the name of the fields will be the character array provided in the second column of additional grids input. This function also
	% 	allows you to input a list of additional fields you wish to include (see Optional Inputs below). If you would rather create a GRIDobj with specified
	% 	values, use 'Basin2Raster'.
	%
	% Required Inputs:
	% 		location_of_data_files - full path of folder which contains the mat files from 'ProcessRiverBasins'
	%
	% Optional Inputs:
	%		include ['all'] - parameter to specify which basins to include in building the shapfile. The default 'all' will include all basin mat files in the 
	%			folder you specify. Providing 'subdivided' will check to see if a given main basin was subdivided using 'SubdivideBigBasins' and then only include 
	%			the subdivided versions of that basin (i.e. the original main basin for those subbasins will not be included in the table). Providing 'bigonly'
	%			will only include the original basins produced by 'ProcessRiverBasins' even if 'SubDivideBigBasins' was run. If 'SubDivideBigBasins' was never run,
	%			result of 'all' and 'bigonly' will be the same.
	%		extra_field_values [] - cell array of extra field values you wish to include. The first column in this cell array must be the river basin number
	%			(i.e. the identifying number in the third column of the RiverMouth input to ProcessRiverBasins or the number generated for the basin in
	%			SubDivideBigBasins). Only one row per river basin number is allowed and ALL river basin numbers in the basins being processed must have a value
	%			associated with them. Additional columns are interpreted as the values with which you wish to populate the extra fields. These can either be character
	%			arrays or numbers, other values will results in an error. 
	%		extra_field_names [] - a 1 x m cell array of field names, as characters (no spaces as this won't work with shapefile attributes), associated with the field values. 
	%			These must be in the same order as values are given in extra_field_values. If for example your extra_field_values cell array is 3 columns with the river number, 
	%			sample name, and erosion rate then your extra_field_names cell array should include entries for 'sample_name' and 'erosion_rate' in that order. 
	%		uncertainty ['se'] - parameter to control which measure of uncertainty is included, expects 'se' for standard error (default), 'std' for standard deviation, or 'both'
	%			to include both standard error and deviation.
	%		filter_by_category [false] - logical flag to recalculate selected mean values based on filtering by particular categories within a categorical grid (provided to
	%			ProcessRiverBasins as 'add_cat_grids'). Requires entries to 'filter_type', 'cat_grid', and 'cat_values'. Will produce filtered values for channel steepness, gradient,
	%			and mean  elevation by default along with any additonal grids present (i.e. grids provided with 'add_grids' to ProcessRiverBasins).
	%		filter_type ['exclude'] - behavior of filter, if 'filter_by_categories' is set to true. Valid inputs are 'exclude' and 'include'. If set to 'exclude', the filtered means
	%			will be calculated excluding any portions of grids have the values of 'cat_values' in the 'cat_grid'. If set to 'include', filtered means will only be calculated 
	%			for portions of grids that are within specified categories (see examples).
	%		cat_grid [] - name of categorical grid to use as filter, must be the same as the name provided to ProcessRiverBasins (i.e. third column in the cell array provided to
	%			'add_cat_grids').
	%		cat_values [] - 1xm cell array of categorical values of interest to use in filter. These must match valid categories in the lookup table as output from CatPoly2GRIDobj
	%			(i.e. second colmun in cell array provided to 'add_cat_grids')
	%		populate_categories [false] - logical flag to add entries that indicate the percentage of a watershed occupied by each category from a categorical grid, e.g. if you
	%			provided an entry for 'add_cat_grids' to ProcessRiverBasins that was a geologic map that had three units, 'Q', 'Mz', and 'Pz' and you set 'populate_categories' 
	%			to true there will be field names in the resulting shapefile named 'Q', 'Mz', and 'Pz' and the values stored in those columns will correspond to the percentage 
	%			of each basin covered by each unit for each basin. Setting populate_categories to true will not have any effect if no entry was provided to 'add_cat_grids' when
	%			running ProcessRiverBasins.
	%		means_by_category [] - method to calculate means of various continuous values within by categories. Requires that a categorical grid(s) was input to ProcessRiverBasins.
	%			Expects a cell 1 x m cell array where the first entry is the name of the category to use (i.e. name for categorical grid you provided to ProcessRiverBasins) and
	%			following entries are names of grids you wish to use to find means by categories, e.g. an example array might be {'geology','ksn','rlf2500','gradient'} if you 
	%			were interested in looking for patterns in channel steepness, 2.5 km^2 relief, and gradient as a function of rock type/age. Valid inputs for the grid names are:
	%				'ksn' - uses interpolated channel steepness grid
	%				'gradient' - uses gradient grid
	%				'rlf####' - where #### is the radius you provided to ProcessRiverBasins (requires that 'calc_relief' was set to true when running ProcessRiverBasins
	%				'NAME' - where NAME is the name of an additional grid provided with the 'add_grids' option to ProcessRiverBasins
	%
	% Output:
	%		Outputs a table (T) with the following default fields:
	%			river_mouth - river mouth number provided to ProcessRiverBasins
	%			drainage_area - drainage area of basin in km^2
	%			out_x - x coordinate of basin mouth
	%			out_y - y coordinate of basin mouth
	%			center_x - x coordinate of basin in projected coordinates
	%			center_y - y coordinate of basin in projected coordinates
	%			outlet_elevation - elevation of pour point in m
	%			mean_el - mean elevation of basin in meters
	%			max_el - maximum elevation of basin in meters
	%			mean_ksn - mean channel steepenss
	%			mean_gradient - mean gradient
	%		Either standard errors, standard deviations or both will be populated for elevation, ksn, and gradient depending on value of 'uncertainty'
	%		Mean and standard error / standard deviation / both values will be populated for any additional grids
	%
	% 
	% Examples:
	%		[T]=CompileBasinStats('/Users/You/basin_files');
	%		[T]=CompileBasinStats('/Users/You/basin_files','means_by_category',{'geology','gradient','rlf2500','rlf5000'})
	%
	%		To recalculate means excluding any area of watersheds that are mapped as either 'Q' or 'Water' in the geology dataset provided to ProcessRiverBasins
	%		[T]=CompileBasinStats('/Users/You/basin_files','filter_by_categories',true,'cat_grid','geology','cat_values',{'Q','Water'},'filter_type','exclude'); 
	%
	%		To recalculate means only in the areas mapped as 'grMZ', 'grPz', or 'grpC' in the geology dataset provided to ProcessRiverBasins
	%		[T]=CompileBasinStats('/Users/You/basin_files','filter_by_categories',true,'cat_grid','geology','cat_values',{'grMz','grPz','grpC'},'filter_type','include');
	%
	% Notes
	%		-If you use 'filter_by_category' to create filtered means and uncertainites, note that the filtered value for channel steepness is calcuated using the 
	%		interpolated 'KsnOBJc', not the stream values like the the value reported in mean_ksn in the output table.
	%		
	%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Function Written by Adam M. Forte - Last Revised Spring 2018 %
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	

	% Parse Inputs
	p = inputParser;
	p.FunctionName = 'CompileBasinStats';
	addRequired(p,'location_of_data_files',@(x) isdir(x));

	addParamValue(p,'include','all',@(x) ischar(validatestring(x,{'all','subdivided','bigonly'})));
	addParamValue(p,'extra_field_values',[],@(x) isa(x,'cell'));
	addParamValue(p,'extra_field_names',[],@(x) isa(x,'cell') && size(x,1)==1);
	addParamValue(p,'uncertainty','se',@(x) ischar(validatestring(x,{'se','std','both'})));
	addParamValue(p,'populate_categories',false,@(x) isscalar(x) && islogical(x))
	addParamValue(p,'means_by_category',[],@(x) isa(x,'cell') && size(x,2)>=2);
	addParamValue(p,'filter_by_category',false,@(x) isscalar(x) && islogical(x));
	addParamValue(p,'filter_type','exclude',@(x) ischar(validatestring(x,{'exclude','include'})));
	addParamValue(p,'cat_grid',[],@(x) ischar(x));
	addParamValue(p,'cat_values',[],@(x) isa(x,'cell') && size(x,1)==1);


	parse(p,location_of_data_files,varargin{:});
	location_of_data_files=p.Results.location_of_data_files;

	include=p.Results.include;
	efv=p.Results.extra_field_values;
	efn=p.Results.extra_field_names;
	uncertainty=p.Results.uncertainty;
	pc=p.Results.populate_categories;
	mbc=p.Results.means_by_category;
	fbc=p.Results.filter_by_category;
	ft=p.Results.filter_type;
	cgn=p.Results.cat_grid;
	cgv=p.Results.cat_values;

	% Check required entries
	if fbc && isempty(cgn) | isempty(cgv)
		error('If "filtery_by_category" is set to true, entries must be provided for both "cat_grid" and "cat_values"');
	end

	current=pwd;
	cd(location_of_data_files);

	% Switch for which basins to include
	switch include
	case 'all'
		FileList=dir('Basin*.mat');
		num_files=numel(FileList);
	case 'bigonly'
		FileList=dir('*_Data.mat');
		num_files=numel(FileList);
	case 'subdivided'
		AllFullFiles=dir('*_Data.mat');
		num_basins=numel(AllFullFiles);
		basin_nums=zeros(num_basins,1);
		for jj=1:num_basins
			fileName=AllFullFiles(jj,1).name;
			basin_nums(jj)=sscanf(fileName,'%*6s %i'); %%%
		end

		FileCell=cell(num_basins,1);
		for kk=1:num_basins
			basin_num=basin_nums(kk);
			SearchAllString=['*_' num2str(basin_num) '_Data.mat'];
			SearchSubString=['*_' num2str(basin_num) '_DataSubset*.mat'];

			if numel(dir(SearchSubString))>0
				Files=dir(SearchSubString);
			else
				Files=dir(SearchAllString);
			end

			FileCell{kk}=Files;
		end
		FileList=vertcat(FileCell{:});
		num_files=numel(FileList);
	end

	% Initiate Table
	T=table;

	if ~isempty(mbc)
		w1=waitbar(0,'Compiling table and calculating means by categories');
	elseif fbc
		w1=waitbar(0,'Compiling table and calculating filtered means');
	else
		w1=waitbar(0,'Compiling table');
	end

	warning off
	for ii=1:num_files;
		FileName=FileList(ii,1).name;

		load(FileName,'DEMoc','RiverMouth','drainage_area','out_el','KSNc_stats','Zc_stats','Gc_stats','Centroid');
		waitbar(ii/num_files,w1,['Working on basin ' num2str(RiverMouth(3))]);
		% Populate default fields in Table
		T.ID(ii)=ii;
		T.river_mouth(ii)=RiverMouth(3);
		T.out_x(ii)=RiverMouth(1);
		T.out_y(ii)=RiverMouth(2);
		T.center_x(ii)=Centroid(1);
		T.center_y(ii)=Centroid(2);
		T.drainage_area(ii)=drainage_area;
		T.outlet_elevation(ii)=out_el;
		T.mean_el(ii)=Zc_stats(1);
		T.max_el(ii)=Zc_stats(5);
		switch uncertainty
		case 'se'
			T.se_el(ii)=Zc_stats(2);
		case 'std'
			T.std_el(ii)=Zc_stats(3);
		case 'both'
			T.se_el(ii)=Zc_stats(2);
			T.std_el(ii)=Zc_stats(3);
		end

		T.mean_ksn(ii)=KSNc_stats(1);
		switch uncertainty
		case 'se'
			T.se_ksn(ii)=KSNc_stats(2);
		case 'std'
			T.std_ksn(ii)=KSNc_stats(3);
		case 'both'
			T.se_ksn(ii)=KSNc_stats(2);
			T.std_ksn(ii)=KSNc_stats(3);
		end

		T.mean_gradient(ii)=Gc_stats(1);
		switch uncertainty
		case 'se'
			T.se_gradient(ii)=Gc_stats(2);
		case 'std'
			T.std_gradient(ii)=Gc_stats(3);
		case 'both'
			T.se_gradient(ii)=Gc_stats(2);
			T.std_gradient(ii)=Gc_stats(3);
		end

		% Check for additional grids within the process river basins output
		VarList=whos('-file',FileName);
		AgInd=find(strcmp(cellstr(char(VarList.name)),'AGc'));
		RlfInd=find(strcmp(cellstr(char(VarList.name)),'rlf'));
		AcgInd=find(strcmp(cellstr(char(VarList.name)),'ACGc'));

		if ~isempty(AgInd)
			load(FileName,'AGc','AGc_stats');
			num_grids=size(AGc,1);

			for kk=1:num_grids
				mean_prop_name=['mean_' AGc{kk,2}];		
				T.(mean_prop_name)(ii)=double(AGc_stats(kk,1));

				switch uncertainty
				case 'se'
					se_prop_name=['se_' AGc{kk,2}];
					T.(se_prop_name)(ii)=double(AGc_stats(kk,2));
				case 'std'
					std_prop_name=['std_' AGc{kk,2}];
					T.(std_prop_name)(ii)=double(AGc_stats(kk,3));
				case 'both'
					se_prop_name=['se_' AGc{kk,2}];
					T.(se_prop_name)(ii)=double(AGc_stats(kk,2));
					std_prop_name=['std_' AGc{kk,2}];
					T.(std_prop_name)(ii)=double(AGc_stats(kk,3));
				end
			end
		end		


		if ~isempty(RlfInd)
			load(FileName,'rlf','rlf_stats');
			num_grids=size(rlf,1);

			for kk=1:num_grids
				mean_prop_name=['mean_rlf' num2str(rlf{kk,2})];
				T.(mean_prop_name)(ii)=double(rlf_stats(kk,1));

				switch uncertainty
				case 'se'
					se_prop_name=['se_rlf' num2str(rlf{kk,2})];
					T.(se_prop_name)(ii)=double(rlf_stats(kk,2));
				case 'std'
					std_prop_name=['std_rlf' num2str(rlf{kk,2})];
					T.(std_prop_name)(ii)=double(rlf_stats(kk,3));
				case 'both'
					se_prop_name=['se_rlf' num2str(rlf{kk,2})];
					T.(se_prop_name)(ii)=double(rlf_stats(kk,2));
					std_prop_name=['std_rlf' num2str(rlf{kk,2})];
					T.(std_prop_name)(ii)=double(rlf_stats(kk,3));
				end
			end
		end		

		% Calculate filtered values

		if fbc & ~isempty(AcgInd)
			load(FileName,'ACGc');
			% Isolate Cat Grid and lookup table of interest
			cix=find(strcmp(ACGc(:,3),cgn));
			CG=ACGc{cix,1};
			cgt=ACGc{cix,2};
			% Find entries that match values of interest
			vcix=ismember(cgt.Categories,cgv);
			vnix=cgt.Numbers(vcix);
			% Create filter 
			F=GRIDobj(CG,'logical');
			F.Z=ismember(CG.Z,vnix);
			if strcmp(ft,'exclude')
				F=~F;
			end
			% Apply filter
			load(FileName,'DEMoc','Goc','MSNc');

			T.mean_el_f(ii)=nanmean(DEMoc.Z(F.Z));
			switch uncertainty
			case 'se'
				T.se_el_f(ii)=nanstd(DEMoc.Z(F.Z))/sqrt(sum(~isnan(DEMoc.Z(F.Z))));
			case 'std'
				T.std_el_f(ii)=nanstd(DEMoc.Z(F.Z));
			case 'both'
				T.se_el_f(ii)=nanstd(DEMoc.Z(F.Z))/sqrt(sum(~isnan(DEMoc.Z(F.Z))));
				T.std_el_f(ii)=nanstd(DEMoc.Z(F.Z));
			end

			T.mean_gradient_f(ii)=nanmean(Goc.Z(F.Z));
			switch uncertainty
			case 'se'
				T.se_gradient_f(ii)=nanstd(Goc.Z(F.Z))/sqrt(sum(~isnan(Goc.Z(F.Z))));
			case 'std'
				T.std_gradient_f(ii)=nanstd(Goc.Z(F.Z));
			case 'both'
				T.se_gradient_f(ii)=nanstd(Goc.Z(F.Z))/sqrt(sum(~isnan(Goc.Z(F.Z))));
				T.std_gradient_f(ii)=nanstd(Goc.Z(F.Z));
			end

			KSNG=GRIDobj(CG);
			KSNG.Z(:,:)=NaN;
			for kk=1:numel(MSNc)
				ix=coord2ind(CG,MSNc(kk).X,MSNc(kk).Y);
				KSNG.Z(ix)=MSNc(kk).ksn;
			end

			T.mean_ksn_f(ii)=nanmean(KSNG.Z(F.Z));
			switch uncertainty
			case 'se'
				T.se_ksn_f(ii)=nanstd(KSNG.Z(F.Z))/sqrt(sum(~isnan(KSNG.Z(F.Z))));
			case 'std'
				T.std_ksn_f(ii)=nanstd(KSNG.Z(F.Z));
			case 'both'
				T.se_ksn_f(ii)=nanstd(KSNG.Z(F.Z))/sqrt(sum(~isnan(KSNG.Z(F.Z))));
				T.std_ksn_f(ii)=nanstd(KSNG.Z(F.Z));
			end

			ag_grids=size(AGc,1);
			for kk=1:ag_grids
				agG=AGc{kk,1};
				mean_prop_name=['mean_' AGc{kk,2} '_f'];		
				T.(mean_prop_name)(ii)=nanmean(agG.Z(F.Z));

				switch uncertainty
				case 'se'
					se_prop_name=['se_' AGc{kk,2} '_f'];
					T.(se_prop_name)(ii)=nanstd(agG.Z(F.Z))/sqrt(sum(~isnan(agG.Z(F.Z))));
				case 'std'
					std_prop_name=['std_' AGc{kk,2} '_f'];
					T.(std_prop_name)(ii)=nanstd(agG.Z(F.Z));
				case 'both'
					se_prop_name=['se_' AGc{kk,2} '_f'];
					T.(se_prop_name)(ii)=nanstd(agG.Z(F.Z))/sqrt(sum(~isnan(agG.Z(F.Z))));
					std_prop_name=['std_' AGc{kk,2} '_f'];
					T.(std_prop_name)(ii)=nanstd(agG.Z(F.Z));
				end
			end

			rlf_grids=size(rlf,1);
			for kk=1:rlf_grids
				rlfG=rlf{kk,1};
				mean_prop_name=['mean_rlf' num2str(rlf{kk,2}) '_f'];
				T.(mean_prop_name)(ii)=nanmean(rlfG.Z(F.Z));

				switch uncertainty
				case 'se'
					se_prop_name=['se_rlf' num2str(rlf{kk,2}) '_f'];
					T.(se_prop_name)(ii)=nanstd(rlfG.Z(F.Z))/sqrt(sum(~isnan(rlfG.Z(F.Z))));
				case 'std'
					std_prop_name=['std_rlf' num2str(rlf{kk,2}) '_f'];
					T.(std_prop_name)(ii)=nanstd(rlfG.Z(F.Z));
				case 'both'
					se_prop_name=['se_rlf' num2str(rlf{kk,2}) '_f'];
					T.(se_prop_name)(ii)=nanstd(rlfG.Z(F.Z))/sqrt(sum(~isnan(rlfG.Z(F.Z))));
					std_prop_name=['std_rlf' num2str(rlf{kk,2})];
					T.(std_prop_name)(ii)=nanstd(rlfG.Z(F.Z));
				end
			end
			% Generate column to record filter
			filt_name=join(cgv);
			filt_name=filt_name{1};
			T.filter{ii}=[ft ' ' filt_name];

		elseif fbc & isempty(AcgInd)
			error('No Categorical Grids were provided to ProcessRiverBasins so filtered values cannot be calculated');
		end

		% Check for the presence of extra fields provided at input
		if ~isempty(efv)
			bnl=cell2mat(efv(:,1));

			ix=find(bnl==RiverMouth(:,3));
			% Check to make sure a single entry exists for each basin number
			if ~isempty(ix) & numel(ix)==1
				efvOI=efv(ix,2:end); % Strip out the basin number column
				num_efv=size(efvOI,2);

				for kk=1:num_efv
					field_name=efn{kk};
					field_value=efvOI{kk};
					% Check to see if field value is a number or string
					if ischar(field_value)
						T.(field_name)(ii)=field_value;
					elseif isnumeric(field_value)
						T.(field_name)(ii)=double(field_value);
					else
						error(['Extra field value provided for ' field_name ' is neither numeric or a character']);
					end
				end
			elseif numel(ix)>1
				error(['More than one entry was provided for extra fields for basin ' num2str(RiverMouth(:,3))]);
			elseif isempty(ix)
				error(['No one entry was provided for extra field values for basin ' num2str(RiverMouth(:,3))]);
			end
		end

		if ~isempty(AcgInd)
			load(FileName,'ACGc','ACGc_stats');
			num_grids=size(ACGc,1);

			for kk=1:num_grids
				mode_prop_name=['mode_' ACGc{kk,3}];
				perc_prop_name=['mode_' ACGc{kk,3} '_percent'];
				ix=find(ACGc{kk,2}.Numbers==ACGc_stats(kk,1),1);
				T.(mode_prop_name){ii}=ACGc{kk,2}.Categories{ix};
				total_nodes=sum(ACGc{kk,2}.Counts);				
				T.(perc_prop_name)(ii)=double((ACGc{kk,2}.Counts(ix)/total_nodes)*100);

				if pc
					ACG_T=ACGc{kk,2};
					total_nodes=sum(ACG_T.Counts);
					for ll=1:numel(ACG_T.Categories)
						cat_name=matlab.lang.makeValidName(ACG_T.Categories{ll});
						cat_name=[ACGc{kk,3} '_perc_' cat_name];
						T.(cat_name)(ii)=double((ACG_T.Counts(ll)/total_nodes)*100);
					end
				end

				if ~isempty(mbc)
					warn_flag=false;
					% Partition input
					cg=mbc(1);
					dg=mbc(2:end);
					num_dg=numel(dg);
					% Find categorical grid of interest
					cix=find(strcmp(ACGc(:,3),cg));
					ACG=ACGc{cix,1}; % GRID
					ACG_T=ACGc{cix,2}; %look up table
					% Iterate through categories
					for ll=1:numel(ACG_T.Categories)
						IDX=GRIDobj(ACG,'logical');
						IDX.Z=ismember(ACG.Z,ACG_T.Numbers(ll));
						cat_name=matlab.lang.makeValidName(ACG_T.Categories{ll});
						for mm=1:num_dg
							dgOI=dg{mm};
							if strcmp(dgOI,'ksn')
								load(FileName,'MSNc');
								KSNG=GRIDobj(CG);
								KSNG.Z(:,:)=NaN;
								for oo=1:numel(MSNc)
									ix=coord2ind(CG,MSNc(oo).X,MSNc(oo).Y);
									KSNG.Z(ix)=MSNc(oo).ksn;
								end
								cat_nameN=['mksn_' cat_name];
								T.(cat_nameN)(ii)=nanmean(KSNG.Z(IDX.Z));
							elseif strcmp(dgOI,'gradient')
								load(FileName,'Goc');
								cat_nameN=['mgrad_' cat_name];
								T.(cat_nameN)(ii)=nanmean(Goc.Z(IDX.Z));
							elseif regexp(dgOI,regexptranslate('wildcard','rlf*'))
								rlfval=str2num(strrep(dgOI,'rlf',''));
								rlfix=find(cell2mat(rlf(:,2))==rlfval);
								if ~isempty(rlfix)
									Rg=rlf{rlfix,1};
									cat_nameN=['mr' num2str(rlfval) '_' cat_name];
									T.(cat_nameN)(ii)=nanmean(Rg.Z(IDX.Z));	
								end								
							else 
								try
									dgix=find(strcmp(AGc(:,2),dgOI));
									AGcOI=AGc{dgix,1};
									cat_nameN=['m' AGc{dgix,2} '_' cat_name];
									T.(cat_nameN)(ii)=nanmean(AGcOI.Z(IDX.Z));
								catch
									warn_flag=true;
								end
							end
						end
					end
				end
			end
		end	


		waitbar(ii/num_files);
	end
	warning on

	if ~isempty(mbc)
		if warn_flag==true
			warning('One or more input for grid names to "means_by_category" was not recognized, table compiled without this entry')
		end
	end

	close(w1);

	cd(current);

end
