clear

% Load un-preprocessed data into gui only
setup_only = true;

% Has to be absolute path. Relative path not working
path_subjects = '/media/dgt00003/dgytl/FUS';

subjects_list = {'sub-212-FUS', 'sub-214-FUS', 'sub-215-FUS', 'sub-216-FUS', 'sub-218-FUS', ...
                 'sub-219-FUS', 'sub-221-FUS', 'sub-222-FUS', 'sub-223-FUS', 'sub-228-FUS', ...
                 'sub-229-FUS', 'sub-231-FUS'};

sessions_list = {'ses-00', 'ses-07', 'ses-30', 'ses-90'};

BATCHFILENAME = [path_subjects '/Lancet_OUD_90Days'];


% MR parameters
TR = 1;
blipdir = -1;

sub_count = 0;
for n = 1 : length(subjects_list)
    sub_name = subjects_list{n};
    if ~isfolder([path_subjects filesep sub_name])
        warning([sub_name ': does not exist!'])
        continue
    end

    ses_count = 0;
    for m = 1 : length(sessions_list)
        ses_name = sessions_list{m};

        if ~isfolder([path_subjects filesep sub_name filesep ses_name])
            fprintf(['**** ' sub_name ' ' ses_name ' **** does not exist!\n\n'])
            continue
        end

        func_path = [path_subjects filesep sub_name filesep ses_name filesep 'func'];
        anat_path = [path_subjects filesep sub_name filesep ses_name filesep 'anat'];
        fmap_path = [path_subjects filesep sub_name filesep ses_name filesep 'fmap'];

        RS_file = find_or_extract([func_path filesep sub_name '_' ses_name '_task-RS_bold.nii']);
        if isempty(RS_file)
            warning([func_path ': functional file not found, skip this session!'])
            continue
        end

        anat_file = find_or_extract([anat_path filesep sub_name '_' ses_name '_T1w.nii']);
        if isempty(anat_file)
            warning([anat_path ': structural file not found, skip this session!'])
            continue
        end

        mag_file = find_or_extract([fmap_path filesep sub_name '_' ses_name '*magnitude1.nii']);
        pd_file = find_or_extract([fmap_path filesep sub_name '_' ses_name '*phasediff.nii']);
        if isempty(mag_file) || isempty(pd_file)
            warning([fmap_path ': magnitude1 + phasediff not found, skip this session!'])
            continue
        end
        fmap_files = {mag_file, pd_file};

        disp(['**** ' sub_name ' ' ses_name ' ****'])
        disp(['Structural: ' anat_file])
        disp(['Functional: ' RS_file])
        disp(['FieldMap: ' mag_file])
        disp(['FieldMap: ' pd_file])
        fprintf('\n')

        if length(fmap_files) ~= 2
            warning([fmap_path ': magnitude1 + phasediff not found, skip this session!'])
            continue
        end

        % This is a valid session now
        ses_count = ses_count + 1;

        batch.Setup.functionals{sub_count+1}{ses_count} = [func_path filesep RS_file];
        batch.Setup.structurals{sub_count+1}{ses_count} = [anat_path filesep anat_file];

        % Default secondary data after preprocess
        batch.Setup.secondarydatasets(1).functionals_type = 2;
        batch.Setup.secondarydatasets(1).functionals_label = 'unsmoothed volumes';
        % Load field map
        batch.Setup.secondarydatasets(2).functionals_label = 'fmap';
        batch.Setup.secondarydatasets(2).functionals_type = 4;
        batch.Setup.secondarydatasets(2).functionals_explicit{sub_count+1}{ses_count} = [repmat([fmap_path filesep], 2, 1) char(fmap_files)];

        for j = 1 : length(sessions_list)
            batch.Setup.conditions.onsets{j}{sub_count+1}{ses_count} = [];
            batch.Setup.conditions.durations{j}{sub_count+1}{ses_count} = [];
        end
        batch.Setup.conditions.onsets{m}{sub_count+1}{ses_count} = 9; % Nathalie discarded first 9 scans
        batch.Setup.conditions.durations{m}{sub_count+1}{ses_count} = inf;
    end

    if ses_count > 0
        sub_count = sub_count + 1;
    end
end

if sub_count == 0
    error(['No subjects found in ' path_subjects])
end

batch.filename = BATCHFILENAME;
batch.Setup.isnew = 1;
batch.Setup.nsubjects = sub_count;
batch.Setup.RT = TR;
batch.Setup.conditions.names = sessions_list;
BATCH.Setup.conditions.missingdata = 1;

[conn_path, ~, ~] = fileparts(which('conn'));
batch.Setup.rois.files{1} = [conn_path '/rois/atlas.nii'];
batch.Setup.rois.files{2} = [conn_path '/rois/networks.nii'];
% batch.Setup.rois.files{1} = 'ROIs/AndyROIs.nii';
% batch.Setup.rois.multiplelabels = 1;

if setup_only
    conn_batch(batch);
    conn
    conn('load', BATCHFILENAME);
    conn gui_setup
    return
end

% Preprocessing using 'VDM' and 'default_mni' steps
batch.Setup.preprocessing.steps = {'functional_label_as_original'; 
                                   'functional_vdm_create'; 
                                   'functional_vdm_apply'; 
                                   'functional_realign&unwarp';
                                   'functional_center';
                                 % 'functional_slicetime';
                                   'functional_art';    
                                   'functional_segment&normalize_direct';
                                   'functional_label_as_mnispace';
                                   'structural_center';
                                   'structural_segment';
                                   'functional_smooth';
                                   'functional_label_as_smoothed'};

batch.Setup.preprocessing.sliceorder = 'interleaved (Siemens)';
batch.Setup.preprocessing.vdm_blip = blipdir;
batch.Setup.done = 1;
batch.Setup.overwrite = 'Yes';
                               
% Default options (uses White Matter+CSF+realignment+scrubbing+conditions as confound regressors)
batch.Denoising.filter = [0.01, 0.1]; % frequency filter (band-pass values, in Hz)
batch.Denoising.done = 1;
batch.Denoising.overwrite = 'Yes';
                                
% Default options (uses all ROIs in conn/rois/ as connectivity sources)
batch.Analysis.done = 1;
batch.Analysis.overwrite = 'Yes';

conn_batch(batch);
conn
conn('load', BATCHFILENAME);
conn gui_analyses

%% Find a file specify by path_name, unzip path_name.gz if necessary
function out_name = find_or_extract(path_name)

FILE = dir(path_name);
if ~isempty(FILE)
    out_name = FILE.name;
else
    FILE = dir([path_name '.gz']);
    if ~isempty(FILE)
        fprintf(['Unzipping ' FILE.name ' ...\n\n'])
        gunzip([FILE.folder filesep FILE.name]);
        out_name = FILE.name(1 : end-3);
    else
        out_name = [];
    end
end

end
