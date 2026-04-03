function data = readYamlSafe(fileName, nosuchfileaction, makeords, treatasdata, dictionary)
% Read YAML files robustly across different working directories.
%
% Args:
%     fileName (char|string): YAML filename or path.
%     nosuchfileaction (optional): Passed to yaml.ReadYaml.
%     makeords (optional): Passed to yaml.ReadYaml.
%     treatasdata (optional): Passed to yaml.ReadYaml.
%     dictionary (optional): Passed to yaml.ReadYaml.
%
% Returns:
%     data: Parsed YAML content.

    if nargin < 2
        nosuchfileaction = false;
    end
    if nargin < 3
        makeords = true;
    end

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    yamlParentFolder = fullfile(projectRoot, 'Lib', 'yamlmatlab');

    if exist(yamlParentFolder, 'dir') ~= 7
        error(['Directory not found: ', yamlParentFolder]);
    end

    % For package calls (yaml.ReadYaml), the parent folder must be on path.
    addpath(yamlParentFolder);
    rehash;

    readYamlName = '';
    if ~isempty(which('yaml.ReadYaml'))
        readYamlName = 'yaml.ReadYaml';
    elseif ~isempty(which('ReadYaml'))
        readYamlName = 'ReadYaml';
    end

    if isempty(readYamlName)
        error(['Could not resolve yaml.ReadYaml. Ensure ', fullfile('Lib', 'yamlmatlab'), ' is available.']);
    end

    readYamlFn = str2func(readYamlName);

    if isstring(fileName)
        fileName = char(fileName);
    end

    yamlPath = fileName;
    if exist(yamlPath, 'file') ~= 2
        yamlPath = fullfile(projectRoot, 'Lib', fileName);
    end

    if exist(yamlPath, 'file') ~= 2
        error(['YAML file not found: ', fileName]);
    end

    try
        if nargin >= 5
            data = readYamlFn(yamlPath, nosuchfileaction, makeords, treatasdata, dictionary);
        elseif nargin == 4
            data = readYamlFn(yamlPath, nosuchfileaction, makeords, treatasdata);
        else
            data = readYamlFn(yamlPath, nosuchfileaction, makeords);
        end
    catch ME
        if ~contains(ME.message, 'Invalid character code sequence detected')
            rethrow(ME);
        end

        % Fallback: decode file bytes as UTF-8 and parse as YAML data string.
        yamlData = readUtf8Text(yamlPath);
        if nargin >= 5
            data = readYamlFn(yamlData, nosuchfileaction, makeords, true, dictionary);
        else
            data = readYamlFn(yamlData, nosuchfileaction, makeords, true);
        end
    end
end

function txt = readUtf8Text(filePath)
    fid = fopen(filePath, 'r');
    if fid < 0
        error(['Could not open file: ', filePath]);
    end

    cleaner = onCleanup(@() fclose(fid));
    bytes = fread(fid, '*uint8');
    %#ok<NASGU>
    txt = native2unicode(bytes', 'UTF-8');
end
