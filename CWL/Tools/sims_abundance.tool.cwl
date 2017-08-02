cwlVersion: v1.0
class: CommandLineTool

label: abundance profile
doc: |
    create abundance profile from expanded annotated sims files
    md5:    sims_abundance.py -t md5 -i <input> -o <output> --coverage <coverage> --cluster <cluster> --md5index <md5index>
    lca:    sims_abundance.py -t lca -i <input> -o <output> --coverage <coverage> --cluster <cluster>
    source: sims_abundance.py -t source -i <input> -o <output> --coverage <coverage> --cluster <cluster>

hints:
    DockerRequirement:
        dockerPull: mgrast/pipeline:4.03

requirements:
    InlineJavascriptRequirement: {}

stdout: sims_abundance.log
stderr: sims_abundance.error

inputs:
    input:
        type: File
        doc: Input expanded sims file
        format:
            - Formats:tsv
        inputBinding:
            prefix: -i
    
    coverage:
        type: File?
        doc: Optional input file, assembly coverage
        inputBinding:
            prefix: --coverage
    
    cluster:
        type: File?
        doc: Optional input file, cluster mapping
        inputBinding:
            prefix: --cluster
    
    md5index:
        type: File?
        doc: Optional input file, md5,seek,length
        inputBinding:
            prefix: --md5_index
    
    profileType:
        type: string
        doc: Profile type
        format:
            - Types:md5
            - Types:lca
            - Types:source
        inputBinding:
            prefix: -t
    
    sourceNum:
        type: int?
        doc: Number of sources in m5nr, default 18
        default: 18
        inputBinding:
            prefix: -s
    
    outName:
        type: string
        doc: Output abundance profile
        inputBinding:
            prefix: -o


baseCommand: [sims_abundance.py]

outputs:
    info:
        type: stdout
    error: 
        type: stderr  
    output:
        type: File
        doc: Output abundance profile file
        outputBinding: 
            glob: $(inputs.outName)

$namespaces:
    Types: ProfileTypes.cv.yaml
