% Locate the main project folder.
bms_project_root = fileparts(mfilename('fullpath'));

% Configure folders for automatically generated files.
Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(bms_project_root, 'generated', 'cache'), ...
    'CodeGenFolder', fullfile(bms_project_root, 'generated', 'code'), ...
    'createDir', true);

% Tell MATLAB where to find our project files.
addpath(bms_project_root);
addpath(fullfile(bms_project_root, 'models'));
addpath(fullfile(bms_project_root, 'parameters'));
addpath(fullfile(bms_project_root, 'tests'));

disp('BMS project paths and generated folders configured.');