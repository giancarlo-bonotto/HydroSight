classdef model_TFN_SW_GW < model_TFN & model_abstract
% Class definition for Transfer Function Noise (TFN) model for use with
% HydroSight to simulate SW-GW interactions 

    %   Model uses the weighting function of the GW head interpolation to
    %   inform the behavior of baseflow, whether it is discharge to or recharging from the river.
    
    properties
        
        
    end
    
    
    %%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model types. Any new models must be listed here
% in order to be accessable within the GUI.
    methods(Static)
        % Provides a simple description of the function for the user
        % interface.
        function str = description()
           
            str = {['"model_TFN_SW_GW" is a highly flexible nonlinear transfer function noise time-series model. '], ...
                   'The model has the following additional features:', ...
                   '   - joint simulation of groundwater head and streamflow time-series', ...
                   '', ...
                   'For further details of the algorithms use the help menu or see:', ...
                   '', ...
                   '   - Future publication', ...
                   '', ...
                   '   - Peterson, T. J., and A. W. Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355, doi:10.1002/2013WR014800.', ...
                   '', ...
                   '   - Shapoori V., Peterson T. J., Western A. W. and Costelloe J. F., (2015), Top-down groundwater hydrograph time series modeling for climate-pumping decomposition. Hydrogeology Journal'};                     
               
        end        
    end        
    
    
    
    %%  PUBLIC METHODS              

    methods
        
        
        %% Model constructor
        %function obj = model_TFN_SW_GW(bore_ID, stream_ID, obsHead, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)           
        function obj = model_TFN_SW_GW(bore_ID, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)           
% model_TFN constructs for linear and nonlinear Transfer Function Noise model
%
% Syntax:
%   model = model_TFN(bore_ID, obsData, forcingData_data, ...
%           forcingData_colnames, siteCoordinates, modelOptions)
%       

            % Get model option for which ID is stream gauge
            
            % identify what is bore and what is river, so define what is bore in bore_ID and what is streamflow... 
            % impose to the user to put streamflow data as the "first
            % bore"in the observed data file, so in this function we pick
            % the first "bore_id" as the river... 
            
            %bore_ID = 124705
            
            % streamID = "first bore_id in the observed data file..." 
            
            % tranforms streamflow to mm to compare with the 
            
            % estimate the baseflow using GW data so it can be used to calculate the objective function based on the
            % simulated time series of GW head and quick-flow from the
            % soil-moisture model, like  total_sim_flow = BaseFlow(GW) +
            % quickFlow (soil_moisture), then we compare the total_sim_flow
            % com observed_flow from the BOM database.. 
            
            
            % Use sub-class constructor.
            obj = obj@model_TFN(bore_ID, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin{1});

            %% Read in file with obs flow.
            % Note, eventually site_IDs needs to be chnaged from a single
            % string with the bore ID to a vector of stream and bore IDs.
            % Maybe the first could be the stream ID.
%             obsDataFlow = csvread('obsFlow_Brucknell.csv');
            obsDataFlow = readtable('obsFlow_Brucknell_up to 2009.csv');
            obsDataFlow = obsDataFlow(:,2:end);

            obsDataFlow = table2array(obsDataFlow);
            
            % Derive columns of year, month, day etc to matlab date value
            switch size(obsDataFlow,2)-1
                case 3
                    obsDates = datenum(obsDataFlow(:,1), obsDataFlow(:,2), obsDataFlow(:,3));
                case 4
                    obsDates = datenum(obsDataFlow(:,1), obsDataFlow(:,2), obsDataFlow(:,3),obsDataFlow(:,4), zeros(size(obsDataFlow,1),1), zeros(size(obsDataFlow,1),1));
                case 5
                    obsDates = datenum(obsDataFlow(:,1), obsDataFlow(:,2), obsDataFlow(:,3),obsDataFlow(:,4),obsDataFlow(:,5), zeros(size(obsDataFlow,1),1));
                case 6
                    obsDates = datenum(obsDataFlow(:,1), obsDataFlow(:,2), obsDataFlow(:,3),obsDataFlow(:,4),obsDataFlow(:,5),obsDataFlow(:,6));
                otherwise
                    error('The input observed head must be 4 to 7 columns with right hand column being the head and the left columns: year; month; day; hour (optional), minute (optionl), second (optional).');
            end
            
            
            % Use all input data
            obsDataFlow = [obsDates, obsDataFlow(:,end)];
            
            % including the flow data into the input data object
            obj.inputData.flow = obsDataFlow;

            
            %% check the SW and GW and how to separate them... 
            
            
            
            %% logical part of how to store the data in the object... 
            
            %% Set Obj parameters for the baseflow calculation
            %obj.parameters.streamflow.head_threshold = mean(obsData(:,end));
            %obj.parameters.streamflow.head_to_baseflow = 1;
%             obj.parameters.baseflow = baseflow(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, []);
 
            obj.parameters.baseflow = baseflow(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, [], []);

            
        end
    
        
        function  [params_initial, time_points_head, time_points_streamflow ] = calibration_initialise(obj, t_start, t_end);
            
            
            % Set a flag to indicate that calibration is being undertaken.
            obj.variables.doingCalibration = true;
            
            % Get parameter names and initial values
            [params_initial, obj.variables.param_names] = getParameters(obj);
            
            calibration_initialise@model_TFN(obj, t_start, t_end);
            
            
            % Derive time points for groundwater head objective
            % function calc.
            obsHead = getObservedHead(obj);
            t_filt = find( obsHead(:,1) >=t_start  ...
                & obsHead(:,1) <= t_end );
            time_points_head = obsHead(t_filt,1);
            obj.variables.time_points_head = time_points_head;
            
            
            % Derive time steps for streamflow data
            t_filt = find( obj.inputData.flow(:,1) >=t_start  ...
                & obj.inputData.flow(:,1) <= t_end );   
            time_points_streamflow = obj.inputData.flow(t_filt,1);
            obj.variables.time_points_streamflow = time_points_streamflow;
            
            
            
        end
        
        
        
    function [objFn_joint, objFn_head, objFn_flow, totalFlow_sim, colnames, drainage_elevation] = objectiveFunction_joint(params, time_points_head, time_points_streamflow, obj, varargin)
       
%         obj.variables.theta_est_indexes_min = ones(1,length(time_points) ); % to pass the condition in line 2679 in model_TFN - "tor_end = tor( obj.variables.theta_est_indexes_min(1,:) )';
%         obj.variables.theta_est_indexes_max = ones(1,length(time_points) );
%         obj.variables.doingCalibration = true ; % to see if the model calibrates 
        
%         t_start = 0;
%         t_end  = inf;
%         %%%%% dont i need to first do this to then get the objective function? 
%         [params_initial, time_points] = calibration_initialise(obj, t_start, t_end);
          
%         calibration_finalise(obj, params, useLikelihood)
%             
%         [objFn, h_star] = objectiveFunction(params, time_points, obj)        
        %%%%
      
        % Call objectiveFunction in model_TFN to get head objFn
%         [objFn, h_star, colnames, drainage_elevation] = objectiveFunction@model_TFN(params, time_points, obj, varargin);  % "false" to pass the condition in "islogical(varargin{1})" in line 1826 in model_TFN of "objectiveFunction@model_TFN"
        [objFn_head, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points_head, obj, false);  % "false" to pass the condition in "islogical(varargin{1})" in line 1826 in model_TFN of "objectiveFunction@model_TFN"
        % line 132 above seems not to be working 
        objFn_head
        
        % Add the drainage elevation to the object. This
        % is just done because the model needs to be solved for the
        % streamflow time steps, and to do so model_TFN assumes the
        % calibration has assigned obj.variables.d.
        obj.variables.d = drainage_elevation;
        obj.variables.doingCalibration = false; % false as used in Hydromod, but should it be "true"?
        
        % Store some variables that are cleared when the model_TFN
        % solve() is called. These will be added back.
        theta_est_indexes_min = obj.variables.theta_est_indexes_min;
        theta_est_indexes_max = obj.variables.theta_est_indexes_max;
        delta_time = obj.variables.delta_time;
        
        % missing the forcingMean in obj.variables."precip or
        % ET".forcingMean, which function "solves" requires
                 
         companants = fieldnames(obj.inputData.componentData);
         nCompanants = size(companants,1);  
               
         
        for j=1:nCompanants  
        obj.variables.(companants{j}).forcingMean(:,1) = mean(obj.variables.(companants{j}).forcingData);
        end 
        
        
        
        % Call some method in model_TFN_SW_GW to return simulated flow
        % (using the simulated head - so call 
        [totalFlow_sim, baseFlow, quickFlow] = getStreamFlow(time_points_streamflow, obj, varargin);
        
        
        
        % Call some method in model_TFN_SW_GW to return obs flow
        
        obsFlow = getObservedFlow(obj);


                
        % Calc. flow objFn using NSE
        objFn_flow = 1 - ( sum((totalFlow_sim - obsFlow(:,2)).^2)./ ...
            sum((obsFlow(:,2) - mean(obsFlow(:,2))).^2));
        objFn_flow
        
        % Calc. flow objFn using normalized NSE
        objFn_flow_NNSE = 1 / (2- objFn_flow); 
        objFn_flow_NNSE
        
        
        % Have some way of merging objFn from head and objFn from flow
        objFn_joint = objFn_head + objFn_flow; % TO DO: we want to maximize both, rigth?
        
        
        
        % Rten combined objFun and other terms 
        
        
        
        
        
        
    end
    
    % get quickFlow and baseFlow using simulated head and streamflow 
    function [totalFlow, baseFlow, quickFlow] = getStreamFlow(time_points_streamflow, obj, varargin)
     
        % solve is calling back objectiveFunction that calls
        % calibration_initialise, maybe take calibration_initialise ouside
        % of objectiveFunction???      
     % get simulated head to use to estimate baseflow AT A DAILY TIMESTEP        
     [head, colnames, noise] = solve(obj, time_points_streamflow); % just the deterministic . is it at the same time step (daily)? 
      obj.parameters.variables.doingCalibration = true;
      
     
      % Add model_TFN variables back
%       obj.parameters.variables.theta_est_indexes_min = theta_est_indexes_min;
%       obj.parameters.variables.theta_est_indexes_max = theta_est_indexes_max;
%       obj.parameters.variables.delta_time = delta_time;
%       clear theta_est_indexes_min theta_est_indexes_max delta_time
     
     
     % set head in baseflow (using setForcingData)
     
     setForcingData(obj.parameters.baseflow, head, 'head')
     
     % calc. baseflow using setTransformedForcing in baseflow
     setTransformedForcing(obj.parameters.baseflow, time_points_streamflow, true)
     
     % get calcuated baseflow in baseflow
     baseFlow = getTransformedForcing(obj.parameters.baseflow, time_points_streamflow);
     
     
     % calc. runoff using setTransformedForcing in model_TFN - this is
     % needed to get the derived runoff from the
     % "climateTransform_soilMoistureModels" only for the dates with
     % streamflow observations 
     setTransformedForcing(obj.parameters.climateTransform_soilMoistureModels, time_points_streamflow, true) 
     
     
     % getting the derived forcing data, which includes the quick flow
     % (runoff and interflow)
     [allDerivedForcingData, derivedForcingData_colnames] = getDerivedForcingData(obj, time_points_streamflow);
     
     % getting the forcing data (precip, ET) with the date column
     [allForcingData, forcingData_colnames] = getForcingData(obj);
     
        
     % Initialise function eval counter
     obj.variables.nobjectiveFunction_calls=0;
     
     % Initialise total flow 
     obj.variables.totalFlow = [];
     
     
     quickFlow = allDerivedForcingData(:,6); % runoff in [mm/day], to get ML/day, mutiply by the catchmentArea - (quickflow from the runoff of the lumped 1-d soil moisture model)
     
     totalFlow = quickFlow + baseFlow; % baseFlow + quickFlow;  BASEFLOW IS DAILY TIME-SERIES MATCHING THE TIME STEPS OF QUICKFLOW, DOUBLE CHECH THIS MATCHING....
     
     % limit the total flow to above zero
     if totalFlow < 0 
        totalFlow = 0; 
     end
     
     % Storing total flow
     obj.variables.totalFlow = totalFlow;
     
    end
     
    % Get the observed streamflow
    function obsFlow = getObservedFlow(obj)
        obsFlow = obj.inputData.flow;
    end
    
   

    
    end
end
