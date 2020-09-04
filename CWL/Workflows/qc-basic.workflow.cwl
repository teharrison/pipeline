cwlVersion: v1.0
class: Workflow

requirements:
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement

inputs:
    jobid: string
    sequences: File
    kmerLength:
        type: int[]?
        default: [6]

outputs:
    seqStatFile:
        type: File
        outputSource: formatSequenceStats/stats
    seqBinFile:
        type: File
        outputSource: formatSequenceStats/bins
    qcStatFile:
        type: File
        outputSource: formatQcStats/stats
    qcSummaryFile:
        type: File
        outputSource: formatQcStats/summary

steps:
    sequenceStats:
        run: ../Tools/seq_length_stats.tool.cwl
        in:
            sequences: sequences
            outName:
                source: jobid
                valueFrom: $(self).075.seq.stats
            lenBin:
                source: jobid
                valueFrom: $(self).075.length.bin
            gcBin:
                source: jobid
                valueFrom: $(self).075.gc.bin
        out: [statOut, lenBinOut, gcBinOut]
    drisee:
        run: ../Tools/drisee.tool.cwl
        in:
            sequences: sequences
        out: [info, stats]
    kmer:
        run: ../Tools/kmer-tool.tool.cwl
        scatter: "#kmer/length"  
        scatterMethod: dotproduct
        in:
            sequences: sequences
            length: kmerLength
            format:
                valueFrom: histo
            prefix:
                source: jobid
                valueFrom: $(self).075
        out: [stats]
    consensus:
        run: ../Tools/consensus.tool.cwl
        label: Nucleotide Histogram 
        doc: Compute nucleotide histogram for all reads
        in:
            sequences: sequences
            stats: sequenceStats/statOut
            output:
                source: jobid
                valueFrom: $(self).075.consensus.stats
        out: [summary, consensus]
    formatSequenceStats:
        run: ../Tools/format_seq_stats.tool.cwl
        in:
            output_prefix:
                source: jobid
                valueFrom: $(self).075.qc
            sequence_stats: sequenceStats/statOut
            sequence_lengths: sequenceStats/lenBinOut
            sequence_gc: sequenceStats/gcBinOut
        out: [stats, bins]
    formatQcStats:
        run: ../Tools/format_qc_stats.tool.cwl
        in:
            outPrefix:
                source: jobid
                valueFrom: $(self).075.qc
            driseeStat: drisee/stats
            driseeInfo: drisee/info
            consensus: consensus/consensus
            kmer: kmer/stats
        out: [stats, summary]
