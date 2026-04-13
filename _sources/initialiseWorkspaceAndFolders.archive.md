# initialiseWorkspaceAndFolders change archive

Date: 2026-04-03
Target file: initialiseWorkspaceAndFolders.m

This archive stores the 3 change groups that were temporarily reverted.
When asked to "modify initialiseWorkspaceAndFolders.m", re-apply all groups below.

## Group 1: Project root detection
Insert before directory loop:

projectRoot = fileparts(mfilename('fullpath'));

## Group 2: Directory resolution with project-root fallback
Replace the inner directory handling block with this logic:

- Build projectRelativeDir = fullfile(projectRoot, directoryToCheck)
- If projectRelativeDir exists, use it
- Else if directoryToCheck exists, use it
- Else throw error: directory not found in project root or current MATLAB path
- Use pathToAdd = genpath(directoryToAdd)

Reference implementation:

        projectRelativeDir = fullfile(projectRoot, directoryToCheck);

        if exist(projectRelativeDir, 'dir') == 7
            directoryToAdd = projectRelativeDir;
        elseif exist(directoryToCheck, 'dir') == 7
            directoryToAdd = directoryToCheck;
        else
            error(['Directory "', directoryToCheck, '" could not be found in the project root or current MATLAB path.']);
        end

        if exist(directoryToAdd, 'dir') == 7
            pathToAdd = genpath(directoryToAdd);
            % if ~contains(currentPath, pathToAdd) % not working properly in certain cases
                addpath(pathToAdd);
                disp(['Directory "', directoryToCheck, '" has been added to the MATLAB search path.']);
            % end
        else
            error(['Directory "', directoryToCheck, '" could not be found on the current search path.']);
        end

## Group 3: yaml package parent-path fallback
Insert before final disp line:

% Ensure the parent folder of the +yaml package is explicitly available.
yamlParentFolder = fullfile(projectRoot, 'Lib', 'yamlmatlab');
if exist(fullfile(yamlParentFolder, '+yaml'), 'dir') == 7
    addpath(yamlParentFolder);
    rehash;
end
