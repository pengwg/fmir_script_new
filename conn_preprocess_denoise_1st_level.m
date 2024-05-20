clear

% Has to be absolute path. Relative path not working
path_subjects = '/home/pw0032/Work/fusOUD/fmri';

% Use 'sub-*' for all subjects
subjects_matching = 'sub-221-FUS'; 

BATCHFILENAME = [path_subjects '/fusOUD_90Days'];
conditions = {'RS_Baseline', 'RS_7Days', 'RS_30Days', 'RS_90Days'}; 
% conditions = {'RS_Baseline', 'RS_7Days'};
% batch.parallel.N = 2;   

if isfolder ([path_subjects filesep subjects_matching])
    sub_names = {subjects_matching};
else
    subjects = dir([path_subjects filesep subjects_matching]);
    sub_names = {subjects.name};
end

if isempty(sub_names)
    error('No subjects found!')
end

% MR parameters
TR = 1;

batch.filename = BATCHFILENAME;
batch.Setup.isnew = 1;
batch.Setup.nsubjects = length(sub_names);
batch.Setup.RT = TR;
batch.Setup.conditions.names = conditions;

for n = 1 : length(sub_names)
    sessions = dir([path_subjects, filesep, sub_names{n}, filesep, 'ses*']);

    for m = 1 : length(sessions)
        ses_name = sessions(m).name;
        func_path = [path_subjects filesep sub_names{n} filesep ses_name filesep 'func'];
        anat_path = [path_subjects filesep sub_names{n} filesep ses_name filesep 'anat'];

        RS_file = dir([func_path filesep sub_names{n} '_' ses_name '_task-RS_bold.nii']);
        anat_file = dir([anat_path filesep sub_names{n} '_' ses_name '_T1w.nii']);

        if isempty(RS_file)
            warning([func_path ': functional file not found!'])
            continue
        end

        if isempty(anat_file)
            warning([anat_path ': structural file not found!'])
            continue
        end

        batch.Setup.functionals{n}{m} = [func_path filesep RS_file(1).name];
        batch.Setup.structurals{n}{m} = [anat_path filesep anat_file(1).name];

        for j = 1 : length(conditions)
            if m == j
                batch.Setup.conditions.onsets{j}{n}{m} = 9; % Nathalie discarded first 9 scans
                batch.Setup.conditions.durations{j}{n}{m} = inf;
            else
                batch.Setup.conditions.onsets{j}{n}{m} = [];
                batch.Setup.conditions.durations{j}{n}{m} = [];
            end
        end

    end
    
end

% Default options (uses all ROIs in conn/rois/ directory); see conn_batch for additional options
% (realignment/coregistration/segmentation/normalization/smoothing)

batch.Setup.preprocessing.steps = 'default_mni';
batch.Setup.preprocessing.sliceorder = 'interleaved (Siemens)';
batch.Setup.done = 1;
batch.Setup.overwrite = 'Yes';

[conn_path, ~, ~] = fileparts(which('conn'));

batch.Setup.rois.files{1} = [conn_path '/rois/atlas.nii'];
batch.Setup.rois.files{2} = [conn_path '/rois/networks.nii'];
% batch.Setup.rois.files{1} = 'ROIs/AndyROIs.nii';
% batch.Setup.rois.multiplelabels = 1;

% CONN Denoising                                    % Default options (uses White Matter+CSF+realignment+scrubbing+conditions as confound regressors); see conn_batch for additional options
batch.Denoising.filter = [0.01, 0.1];                 % frequency filter (band-pass values, in Hz)
batch.Denoising.done = 1;
batch.Denoising.overwrite = 'Yes';

% CONN Analysis                                     % Default options (uses all ROIs in conn/rois/ as connectivity sources); see conn_batch for additional options
batch.Analysis.done = 1;
batch.Analysis.overwrite = 'Yes';

conn_batch(batch);

conn
conn('load', BATCHFILENAME);
conn gui_analyses

