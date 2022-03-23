classdef baseflow_m6 < forcingTransform_abstract
    % Defines the behaviour of baseflow according to the GW head and a scaled weighted rate. 
    
    % Detailed explanation goes here
    % Description:  Quadratic outflow from a reservoir if a storage threshold is exceeded

    properties (GetAccess=public, SetAccess=protected)
        
        % Model Parameters
        %----------------------------------------------------------------
        linear_scaler   % - linear scaling parameter [mm-1 d-1]
        head_threshold % - threshold that must be exceeded for flow to occur [mm]
        % log these parameters? 


        %----------------------------------------------------------------        
    end
    
%%  STATIC METHODS        
% Static methods used to inform the
% user of the available model types. 
    methods(Static)
        function [variable_names, isOptionalInput] = inputForcingData_required(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            variable_names = {'head'};
            isOptionalInput = [true];
        end
        
        function [variable_names] = outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            variable_names = {'baseflow_m6'};
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
           
            options = { };

        
            colNames = {};
            colFormats = {};
            colEdits = logical([0]);

            toolTip = sprintf([ 'there are no user options available for this module']);                               
            
        end
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: baseflow_m6', ...
                               '', ...
                               'Purpose: nonlinear transformation of rainfall and areal potential evaporation to a range of forcing data (eg free-drainage) ', ...
                               'using a highly flexible single layer soil moisture model. Two types of land cover can be simulated using two parrallel soil models.', ...
                               '', ...                               
                               'Number of parameters: 1 to 8', ...
                               '', ...                               
                               'Options: each model parameter (excluding the soil moisture capacity) can be set to a fixed value (ie not calibrated) or calibrated.', ...
                               'Also, the input forcing data field "TreeFraction" is optional and only required if the soil model is to simulate land cover change.', ...
                               '', ...                               
                               'Comments: Below is a summary of the model parameters:' , ...
                                'SMSC          : log10(Soil moisture capacity as water depth).', ...
                                'SMSC_trees    : log10(Tree soil moisture capacity as water depth).', ...
                                'treeArea_frac : Scaler applied to the tree fraction input data.', ...                                
                                'S_initialfrac : Initial soil moisture fraction (0-1).', ...
                                'k_infilt      : log10(Soil infiltration capacity as water depth).', ...
                                'k_sat         : log10(Maximum vertical infiltration rate).', ...
                                'bypass_frac   : Fraction of runoff to bypass drainage.', ...
                                'interflow_frac: Fraction of free drainage going to interflow (0-1).', ...
                                'alpha         : Power term for infiltration rate.', ...
                                'beta          : log10(Power term for dainage rate).', ...
                                'gamma         : log10(Power term for soil evap. rate).', ...
                               '', ...               
                               'References: ', ...
                               '1. Peterson & Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330-8355'};
        end        
           
    end
          
    %% Constructor of the baseflow_m6 class
    
    methods
        function obj = baseflow_m6(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)
            
            % Constructor of the baseflow_m6 class 
            %   Detailed explanation goes here
            
            % Use sub-class constructor to inherit the structure of the object "baseflow"
%             obj = obj@baseflow(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions);
            
            
            % initializing the parameters of the object
            obj.linear_scaler = 1; % initial guess for - linear scaling parameter [mm-1 d-1]
            obj.head_threshold = 200; % initial guess for - threshold that must be exceeded for flow to occur [mm]
            
            
            obj.variables.baseFlow = [];
            obj.variables.head = [];
            obj.variables.t = [];
            obj.variables.isNewParameters = false;
            obj.settings.forcingData_colnames = {""};
            obj.settings.forcingData = [];
            obj.settings.siteCoordinates = siteCoordinates;


            
        end
 
        function [params, param_names] = getParameters(obj)            
           params = [ obj.linear_scaler; obj.head_threshold];
           param_names = {'linear_scaler'; 'head_threshold'};
        end
        
               
        function setParameters(obj, params)
            param_names = {'linear_scaler'; 'head_threshold'};
            for i=1: length(param_names)
                obj.(param_names{i}) = params(i,:);
            end
        end
        
         
        % as per range of parameters for model_25 in MaRRMOT (TCM)
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            params_lowerLimit = [0 ; 0]; 
            params_upperLimit = [1; 1000];
        end
        %0, 1];          % k2, Runoff coefficient [mm-1 d-1]
        %not specified   % threshold that must be exceeded for flow to occur [mm]
                  
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_lowerLimit = [0 ; 0];
            params_upperLimit = [1; 1000];
        end
        
        function isValidParameter = getParameterValidity(obj, params, param_names)
           % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

            % Check parameters are within bounds.
            isValidParameter = params >= params_lowerLimit(:,ones(1,size(params,2))) & ...
    		params <= params_upperLimit(:,ones(1,size(params,2)));  
            
        end
        
        function  isNewParameters = detectParameterChange(obj, params)
            % Get current parameters
            set_params = getParameters(obj);

            % Check if there are any changes to the parameters.
            if isempty(set_params) || max(abs(set_params - params)) ~= 0            
                obj.variables.isNewParameters = true;
            else
                obj.variables.isNewParameters = false;
            end 
        end
        
        
        % Set the input forcing data
        function setForcingData(obj, forcingData, forcingData_colnames)
        
            
             % check if lenght of forcingData_colnames is 1
            if size(forcingData_colnames,1) ~= 1
                error('The number of column name is not 1.');
            end
            
            % check if forcingData_colnames is "head" (simulated head)
            if ~strcmp('head', forcingData_colnames)
                error('forcing data col. name is not "head"')
            end
            
             
            % check if the "head" is daily without gaps
            t = forcingData(:,1);
            delta_t = diff(t);
            %%%%%%% need to change antecedent code so we have a daily time-seires of GW for the period where we have GW obs.data and match it with streamflow time-series
            if any(delta_t ~=1)
                error('forcing data must have no gaps and be a daily time-series') 
            end
                
            
            % place the forcingData into "obj"
            obj.settings.forcingData_colnames = forcingData_colnames;
            obj.settings.forcingData = forcingData;
            
        end
        
        function setTransformedForcing(obj, t, forceRecalculation)        

            % Filter the forcing data to input t.
                filt_time = obj.settings.forcingData(:,1) >= t(1) & obj.settings.forcingData(:,1) <= t(end);
                
                % Get the required forcing data
%                 filt = strcmp(obj.settings.forcingData_cols(:,1),'head');
                filt = strcmp(obj.settings.forcingData_colnames,'head');
%                 head_col = obj.settings.forcingData_cols{filt,2};
%                 head_col = obj.settings.forcingData_colnames(filt,:);
                obj.variables.head = obj.settings.forcingData(filt_time, 2 ); % columns in the input data have no name 
                                
                % Store the time points
                obj.variables.t = obj.settings.forcingData(filt_time,1);
                
                % delta_t in input head to the baseflow obj
                delta_t = diff(obj.variables.t);
                delta_t(end+1,1) = delta_t(end,1); % duplicate last point to match head/delta_t matrixes

                
                r = 0.01;
                e = 5.00;
                % Calculate smoothThreshold_storage_logistic
                if obj.head_threshold == 0
                    smoothThreshold = 1 ./ (1+exp((obj.variables.head - obj.head_threshold + r*e* obj.head_threshold)/(r)));
                else
                    smoothThreshold = 1 ./ (1+exp((obj.variables.head - obj.head_threshold + r*e* obj.head_threshold)/(r*obj.head_threshold)));
                end
                
           % calculate the baseflow 
            obj.variables.baseFlow = min(obj.variables.head./delta_t, obj.linear_scaler.*obj.variables.head.^2).*(1 - smoothThreshold);
            % Description:  Quadratic outflow from a reservoir if a storage threshold is exceeded
            % Constraints:  f <= S/dt
            % @(Inputs):    p1   - linear scaling parameter [mm-1 d-1]
            %               p2   - threshold that must be exceeded for flow to occur [mm]
            %               S    - current storage [mm]
            % func = @(p1,p2,S,dt) min(S/dt,p1.*S.^2).*(1-smoothThreshold_storage_logistic(S,p2));


        end
      
        function [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, t)
            
            forcingData = obj.variables.baseFlow;
            
            isDailyIntegralFlux = true ;
                      
            
        end
        
        
        
         % Return coordinates for forcing variable
        function coordinates = getCoordinates(obj, variableName)

            if ~iscell(variableName)
                variableNameTmp{1}=variableName;
                variableName = variableNameTmp;
                clear variableNameTmp;
            end
                
            % Check each requested variable is within forcingData_cols
            for i=1:length(variableName)
                if ~any(strcmp(variableName{i}, obj.settings.forcingData_cols(:,1)))
                    error(['pumpingRate_SAestiation: Inconsistency between selected downscaled pumps and weighting function input data. See ',variableName{i}])
                end
            end
            
            coordinates = cell(length(variableName),3);
            for i=1:length(variableName)
                % Find row within the list of required containing variabeName
                filt = strcmp(obj.settings.forcingData_cols(:,1), variableName{i});

                % Find input bore for requested output
                sourceBoreColNumber = obj.settings.forcingData_cols{filt,2};
                sourceBoreColName = obj.settings.forcingData_colnames{sourceBoreColNumber};

                % Get coordinates
                filt = strcmp(obj.settings.siteCoordinates(:,1), sourceBoreColName);
                coordinates(i,:) = obj.settings.siteCoordinates(filt,:);
                coordinates{i,1} = variableName{i};
            end
        end
        
  
        
          
        
        
        
    end
end

