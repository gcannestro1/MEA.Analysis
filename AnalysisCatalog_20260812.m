%% Catalog for files and analysis to run
% This function makes tree-like structure for the GUI to allow for cascades
% of analysis, graphs, and visualizations. 
% Is used in combination with SelectOptionalScripts 

% catalog - name for overall variable
% makeNode - creates node from which you can add children if needed
    % inputs -> [('Label', 'FileName', [empty if no children otherwise add child
    % node in here]), ('OtherNode', 'FileName', [])]

% Template
%  MakeNode('label','script', [ ...
%         MakeNode('childlabel','childscript',[]), ...   
%         MakeNode('childlabel','childscript',[]) ...
%     ]), ...
% 


function Catalog = AnalysisCatalog_20260812()
Catalog = [
    MakeNode('Waveforms','Waveforms', []), ...
    MakeNode('Raster','RasterPlot', []), ...
    MakeNode('STTC','STTC_NullDistribution_20260120', [ ...
    MakeNode('STTC Visualization','STTCVisualization',[]) ...
    MakeNode('Clustering Coefficient','ClusteringCoefficient_20260812', []) ...
    ]), ...
    
    ];
end

function node = MakeNode(label, script, children)
if nargin < 3, children = []; end
node = struct('label',string(label),'script',string(script),'children',children);
end
