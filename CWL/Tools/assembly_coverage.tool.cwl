cwlVersion: v1.0
class: CommandLineTool

hints:
    DockerRequirement:
        dockerPull: mgrast/pipeline:4.03

requirements:
    InlineJavascriptRequirement: {}

stdout: assembly_coverage.log
stderr: assembly_coverage.error

inputs:
    sequences:
        doc: sequence file in fasta or fastq format
        type: File
        inputBinding:
            prefix: --input
    # format:
    #     doc: fasta or fastq
    #     type: 
    #         type: enum
    #         symbols:
    #             - fasta
    #             - fastq
    #     inputBinding:
    #         prefix: --type        
    #     default: fasta            
    outName:
        type: string
        doc: Output file name
        inputBinding:
            prefix: --output

baseCommand: [assembly_coverage.py]

# arguments: 
#     - prefix: --type
#       valueFrom: |
#           ${
#               return inputs.sequences.format.split("/").slice(-1)[0]
#           } 

outputs:
    info:
        type: stdout
    error: 
        type: stderr  
    output:
        type: File
        outputBinding: 
            glob: $(inputs.outName)
