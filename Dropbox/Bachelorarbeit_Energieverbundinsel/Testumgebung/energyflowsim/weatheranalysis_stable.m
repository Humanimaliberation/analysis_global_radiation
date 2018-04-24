
% README FIRST

% step by step INSTRUCTION:
% 1) Download global radiation data with 1h-timebase and 24h-timebase from link 
%     below into the subdirectory 'data' of the current working directory 
%     DWD weather data in the climate data center (cdc) accessable through ftp
%     ftp://ftp-cdc.dwd.de/pub/CDC/observations_germany/climate/
% 2) Configure parameters
%     2)a) filenames 'filename_1h' and 'filename_24h' in Initalisation-Part of this script
%     2)b) times 'time_start' and 'time_end' for the timeinterval which should be used
%     2)c) pv_peak
%     2)d) pv_angle [NOT YET IMPLEMENTED!]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% NOTES FORMAT DATA SOURCE DWD CDC GLOBAL RADIATION
  % 1h Dataset: 
  % STATIONS_ID;MESS_DATUM;   QN_592; ATMO_LBERG; FD_LBERG;FG_LBERG;SD_LBERG;ZENIT;   MESS_DATUM_WOZ;eor
  % 5906;       1979010100:28;    1;   -999;      0.0;      0.0;      0;      152.90; 1979010101:00;eor
  % global radiation (FG_LBERG) in J/cm²
  %
  % 24h Dataset: 
  % STATIONS_ID;MESS_DATUM;QN_592;ATMO_STRAHL;FD_STRAHL;FG_STRAHL;SD_STRAHL;eor
  % 5906;       19790101;    1;     -999;     -999;     373.00;    2.7;eor
  % global radiation (FG_STRAHL) in J/cm²
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % PROGRAMMSTART
  
clear;
t0 = clock(); % to estimate the calculation time
printf("Programstart: Let us begin! \n");

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% FUNCTIONS
% function description
% In/Out: argument/output name: datatype and if applicable physical unit
% e.g. In: time: datestring in format 'yyyymmdd'
% e.g. Out: matrixOut: (4x2) [datenum, scalar value in Wh; ...] 

function [pathdir] = change_savedir
% [pathdir] = change_savedir   changes save directory through user response, probably buggy when loading data afterwards
% Out: pathdir: string
  disp('The current path to write datafiles is: ');
  disp(pwd);
  usrprmpt = input('Would you like to change the directory? Y/N [N]: ','s');
  if (isempty(usrprmpt))
      usrprmpt = 'N';
  end
  if (usrprmpt == 'Y')
    pathdir = input('Please give a new absolute path: ','s');
  else
    pathdir = pwd;  
  endif  
endfunction

function [dataOut] = pv_power(dataIn,pv_peak,pv_angle,geo_b,geo_l) 
% [dataOut] = pv_power(dataIn,pv_peak,pv_angle,geo_b,geo_l) 
% converts global radiation vertical on ground surface in J/m^2 to kWh PV energy according to PV plant peak power, module angle, geographical location and time dependand global radiation vertical on modulesurface
% In: dataIn: (?x2) [datenum vertical global radiation in joule]
% In: pv peak: scalar in Wp
% In: pv_angle: scalar in degree
% In: geo_b and geo_l: scalar in degree
% Out: dataOut: (?x2) [datenum, vertical global radiation in Wh]
  if pv_angle == 0        
  dataOut = dataIn*(100*100)*pv_peak/3600; % Js/cm^2 global radiation -> Wh pv power       
  dataOut(:,1) = dataIn(:,1); % restore original datenum
  else
  dataOut = dataIn;           % NOTE: NOT YET IMPLEMENTED: Include angle and location
  endif
endfunction

function [idx_min,idx_max,idx_avg] = dayfinder(dataset, datestr_start, datestr_end, frmt_datestr)
  % [idx_min,idx_max,idx_avg] = dayfinder(dataset, datestr_start, datestr_end, frmt_datestr) outputs indices to row in dataset(:,1:2) with minimum, next to average and maximum value dataset(:,2) ignoring negative values as plausibility test
  % In: dataset: (?x2) [datenum (24h-steps), scalar]
  % In: datestr_start and datestr_end: datestring in format frmt_datestr
  % In: frmt_datestr: string with time format e.g. 'yyyymmdd'
  % Out: [idx_in,idx_max,idx_avg]:(3x1) [scalar, scalar]
  idx_start = 1 + datenum(datestr_start,frmt_datestr) - dataset(1,1);  % set index to skip first part in dataset
  a = datenum(datestr_start,frmt_datestr);
  o = datenum(datestr_end,frmt_datestr);  % to be checked ... (o-a)==dt   ???
  idx_end = idx_start + (o-a);            % index for dataset to datestr_end
  dt = idx_end - idx_start + 1;           % delta t in days
  
  % plausibility test
  idx_miss = dataset(:,2) < 0;            % indices of missing measurement values
  corr = sum(dataset(idx_miss,2));        % sum of inplausible data 
  avg = (sum(dataset(:,2))-corr)/(dt-length(find(idx_miss))); % average per day excluding inplausible negative values
  
  input('FYI: Press Enter to show Info:','s'); % user info
  printf('inplausible negative data values: %d out of %d days \n ',length(find(idx_miss)),length(dataset));
  disp('[Octave users only] Ignore warnings for short-circuit operation [...] for operator &');
  input('EOM: Press Enter to continue!','s');

  idx_min = idx_max = idx_avg = idx_start;          % set all indices to start
  for i = idx_start+1:idx_end
    if dataset(i,2) < dataset(idx_min,2) & dataset(i,2) > 0 % minimum?
      idx_min = i;                        % adjust index to minimum
    endif  
    if dataset(i,2) > dataset(idx_max,2)  % maximum?
      idx_max = i;                        % adjust index to max
    endif  
    if abs((dataset(i,2) - avg)) < abs((dataset(idx_avg,2) - avg)) % average?
      idx_avg = i;                            % adjust index to average 
    endif  
  endfor
endfunction
  
function idx1h = idx24hto1h(idx24h,dtnum_24hstrt,dtnum_1hstrt,frmt_time)
  % idx1h = idx24hto1h(idx24h,dtnum_24hstrt,dtnum_1hstrt,frmt_24htime) converts an index to a day in a 24h dataset to an index to the first hour of the same day in a 1h dataset
  % In: idx24h:        scalar index in 24h dataset
  % In: dtnum_24hstrt: datenum of start date in 24h dataset
  % In: dtnum_1hstrt:  datenum of start date in 1h dataset
  % In: frmt_time:     string with time format of dataset with lower resolution
  % Out: idx1h:        scalar index in 1h dataset
  dtnum_1hstrt = datenum(datestr(dtnum_1hstrt,frmt_time),frmt_time); % cut out hours
  dtnum_24hstrt = datenum(datestr(dtnum_24hstrt,frmt_time),frmt_time); % cut out hours
  idx1h = (dtnum_24hstrt + idx24h - dtnum_1hstrt)*24-23; % dtnum_1hstrt + idx1h = dtnum_24hstrt + (idx24h / 24)
endfunction

function caltime(t)
% caltime(t) displays measured timeintervals during compilation process
% In: t: {6x1}(1x6) struct with 6 6-element datevectors [year month day hour minute seconds]
  printf('Total loading time: %f s \n',etime(t{end},t{1}));
  printf('Initalisation time: %f s \n',etime(t{2},t{1}));
  printf('Read 1h data: %f s \n',etime(t{3},t{2}));
  printf('Read 24h data: %f s \n',etime(t{4},t{3}));
  printf('Analysing time data 24h: %f \n',etime(t{5},t{4}));
  printf('Writing time data 1h: %f \n\n',etime(t{6},t{5}));
endfunction

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% INITIALISATION (manual configuration of parameters)
filename_1h = 'produkt_st_stunde_19790101_20180330_05906.txt';  % 1h-timebase data 
filename_24h = 'produkt_st_tag_19790101_20180330_05906.txt';    % 24h-timebase data

frmt_1h = ['%d %s %d %d %f %f %f %f %s']; % Datatypes: Integer(%d), String)(%s), Float(%f) NOTE: Theoretisch reichen Int16 (%d16)
frmt_24h = ['%d %s %d %d %f %f %f'];      % Datatypes: Integer(%d), String)(%s), Float(%f) NOTE: Theoretisch reichen Int16 (%d16)
frmt_1htime = 'yyyymmddHH:MM';             % Timestamp format after conversion
frmt_24htime = 'yyyymmdd';                % Timestamp format

% filepaths
pwd = change_savedir; % prompt to change directory to save data

% timeinterval for observations_germany 
time_start = '19910101';  % start of timeinterval with string format 'yyyymmdd'
time_end =  '20111231';   % end of timeinterval with string format 'yyyymmdd'
time_diff = datenum(time_end,frmt_24htime) - datenum(time_start,frmt_24htime); % length of observed timeinterval

% PV-Anlagendaten
pv_peak = 20145;    % peak power in watt-peak (Wp)
pv_angle = 0;       % NOT INTEGRATED YET, module angle to horizontal line in degree 

% Geodata (necessary if the module angle is not zero)
% geo_b = 49.4875;    % geographical width in degree, Mannheim
% geo_l = 8.4661;     % geographical length in degree, Mannheim

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Debug Mode? (Partial reinitalisation)
usrprmpt = input('Start in debug mode with shorter loading time? Y/N [Y]: ','s');
if (isempty(usrprmpt))
  usrprmpt = 'Y';
end
if (usrprmpt == 'Y')
  time_start = '19790101';  % start of timeinterval with string format 'yyyymmdd'
  time_end =  '19791231';   % end of timeinterval with string format 'yyyymmdd'
  filename_1h = 'Testdaten_1h.txt';  % 1h-timebase data 
  filename_24h = 'Testdaten_24h.txt';    % 24h-timebase data

  printf('1h database: %s \n 24h database: %s \n time start: %s \n time end: %s \n',filename_1h,filename_24h,time_start, time_end);
elseif
  printf('1h database: %s \n 24h database: %s \n time start: %s \n time end: %s \n',filename_1h,filename_24h,time_start, time_end);  
endif  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% READING AND RE-FORMATTING DATA WITH 1H-TIMEBASE
t00 = clock(); % timestamp for caltime(t) function
disp('1h-database is loading... this could take some minutes. Ignore fclose-warning.'); % user info
% read original weather data 1h-timebase:
fid_1h = fopen(fullfile('data',filename_1h),'rt'); % file identifier
raw1h = textscan(fid_1h, frmt_1h, 'Delimiter',';', 'CollectOutput',true, 'HeaderLines',1, 'CommentStyle','eor'); % cell-array with all data from file
fclose(fid_1h);

dt_woz = datenum(raw1h{5}, frmt_1htime); % convert datestring to datenum
dt_utc = datenum(raw1h{2}, frmt_1htime); % convert datestring to datenum

% filter raw data:
data_1h_cell = [num2cell([dt_woz raw1h{4}(:,2)])] % Timestamp and global radiation in kWh instead of joule
data_1h = cell2mat (data_1h_cell); % (?x2) matrix with all data from file except unused columns

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% READING AND RE-FORMATTING DATA WITH 24H-TIMEBASE
t01 = clock(); % timestamp for caltime(t) function
disp('24h-database is loading... this could take some minutes. Ignore fclose-warning.'); % user info
% read original weather data 24h-timebase:
fid_24h = fopen(fullfile('data',filename_24h),'rt'); % File Identifier
raw24h = textscan(fid_24h, frmt_24h, 'Delimiter',';', 'CollectOutput',true, 'HeaderLines',1, 'CommentStyle','eor'); % cell-array with all data from file
fclose(fid_24h);

dt_24h = datenum(raw24h{2}, frmt_24htime); % convert datestring to datenum

% filter raw data:
data_24h_cell = [num2cell([dt_24h raw24h{4}(:,2)])] % cell-array with all data from file except unused columns
data_24h = cell2mat (data_24h_cell);          % (?x2) matrix with all data from file except unused columns [datenum, vertical global radiation in joule]
data_24h = pv_power(data_24h,pv_peak,0);      % Calculate PV energyoutput [kWh] out of vertical global radiation [J]




% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% ANALYSING DATA WITH 24H-TIMEBASE AND SAVE DATA WITH 1H-TIMEBASE TO .CSV
t02 = clock(); % timestamp for caltime(t) function
% find indices 24h-timebase, convert to 1h-timebase
[idx_min,idx_max,idx_avg] = dayfinder(data_24h,time_start,time_end,frmt_24htime); % index for day with min/max/avg global radiation
idx_min1h = idx24hto1h(idx_min,data_24h(1,1),data_1h(1,1),frmt_24htime); % Convert Index 24h dataset to 1h dataset
idx_avg1h = idx24hto1h(idx_avg,data_24h(1,1),data_1h(1,1),frmt_24htime); % Convert Index 24h dataset to 1h dataset
idx_max1h = idx24hto1h(idx_max,data_24h(1,1),data_1h(1,1),frmt_24htime); % Convert Index 24h dataset to 1h dataset

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% SAVING DATA WITH 1H-TIMEBASE TO .CSV
% path and filename = case_date_datestart_to_dateend.csv 
filename_wd = strcat('wd_',datestr(data_24h(idx_min,1),'yyyymmdd'),'_',time_start(1:4),'_to_',time_end(1:4),'.csv'); % filename for worst day global radiation data
filename_ad = strcat('ad_',datestr(data_24h(idx_avg,1),'yyyymmdd'),'_',time_start(1:4),'_to_',time_end(1:4),'.csv'); % filename for average day global radiation data
filename_bd = strcat('bd_',datestr(data_24h(idx_max,1),'yyyymmdd'),'_',time_start(1:4),'_to_',time_end(1:4),'.csv'); % filename for best day global radiation data

% write data of certain days to new .csv
t03 = clock(); % timestamp for caltime(t) function
dlmwrite(fullfile(pwd, filename_wd),data_1h(idx_min1h:idx_min1h+23,:),'delimiter',';','newline','pc'); % write 24h .csv worst day
dlmwrite(fullfile(pwd, filename_ad),data_1h(idx_avg1h:idx_avg1h+23,:),'delimiter',';','newline','pc'); % write 24h .csv average day
dlmwrite(fullfile(pwd, filename_bd),data_1h(idx_max1h:idx_max1h+23,:),'delimiter',';','newline','pc'); % write 24h .csv best day

printf('%s is written to directory %s \n',filename_wd,pwd); % user info
printf('%s is written to directory %s \n',filename_ad,pwd); % user info
printf('%s is written to directory %s \n',filename_bd,pwd); % user info

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% DISPLAY RESULTS FOR USER
t1 = clock();
t = {t0,t00,t01,t02,t03,t1};
usrprmpt = input('Zeiten und Ergebnisse anzeigen? Y/N [Y] \n','s');
if (isempty(usrprmpt))
  usrprmpt = 'Y';
end
if usrprmpt == 'Y'
  caltime(t);
  printf('Timeinterval total: %s to %s \n',datestr(data_24h(1,1),'dd.mm.yyyy'), datestr(data_24h(end,1),'dd.mm.yyyy'));
  printf('Timeinterval analysed: %s to %s \n\n',datestr(datenum(time_start,'yyyymmdd'),'dd.mm.yyyy'), datestr(datenum(time_end,'yyyymmdd'),'dd.mm.yyyy'));
  disp(sprintf('Min. radiation on %s: \n %.2f J/(d*cm^2) = %.2f Wh/(d*m^2)',datestr(data_24h(idx_min,1),'dd.mm.yyyy'), raw24h{4}(idx_min,2),raw24h{4}(idx_min,2)*(100/60)^2)); 
  disp(sprintf('PV-Power on %s: \n %.2f Wh/d with %.2f Wp \n',datestr(data_24h(idx_min,1),'dd.mm.yyyy'),data_24h(idx_min,2),pv_peak));
  disp(sprintf('Avg. radiation on %s: \n %.2f J/(d*cm^2) = %.2f Wh/(d*m^2)',datestr(data_24h(idx_avg,1),'dd.mm.yyyy'), raw24h{4}(idx_avg,2),raw24h{4}(idx_avg,2)*(100/60)^2)); 
  disp(sprintf('PV-Power on %s: \n %.2f Wh/d with %.2f Wp \n',datestr(data_24h(idx_avg,1),'dd.mm.yyyy'),data_24h(idx_avg,2),pv_peak));
  disp(sprintf('Max. radiation on %s: \n %.2f J/(d*cm^2) = %.2f Wh/(d*m^2)',datestr(data_24h(idx_max,1),'dd.mm.yyyy'), raw24h{4}(idx_max,2),raw24h{4}(idx_max,2)*(100/60)^2)); 
  disp(sprintf('PV-Power on %s: \n %.2f Wh/d with %.2f Wp \n',datestr(data_24h(idx_max,1),'dd.mm.yyyy'),data_24h(idx_max,2),pv_peak));
endif  
