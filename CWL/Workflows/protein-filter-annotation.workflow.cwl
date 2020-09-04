cwlVersion: v1.0
class: Workflow

label: protein annotation
doc: Proteins - predict, filter, cluster, identify, annotate

requirements:
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement

inputs:
    jobid: string
    sequences: File
    rnaSims: File
    rnaClustMap: File
    protIdentity:
        type: float?
        default: 0.9
    # static DBs
    m5nrBDB: File
    m5nrFull: File[]
    m5nrSCG: File

outputs:
    protFeatureOut:
        type: File
        outputSource: protFeature/outProt
    protFilterFeatureOut:
        type: File
        outputSource: protFilter/output
    protClustSeqOut:
        type: File
        outputSource: protCluster/outSeq
    protClustMapOut:
        type: File
        outputSource: formatCluster/output
    protSimsOut:
        type: File
        outputSource: bleachSims/output
    protFilterOut:
        type: File
        outputSource: annotateSims/outFilter
    protExpandOut:
        type: File
        outputSource: annotateSims/outExpand
    protLCAOut:
        type: File
        outputSource: annotateSims/outLca

steps:
    protFeature:
        run: ../Tools/fraggenescan.tool.cwl
        in:
            input: sequences
            outName:
                source: jobid
                valueFrom: $(self).350.genecalling.coding
        out: [outProt]
    sortProt:
        run: ../Tools/seqUtil.tool.cwl
        in:
            sequences: protFeature/outProt
            sortbyid2tab:
                default: true
            output:
                source: protFeature/outProt
                valueFrom: $(self.basename).sort.tab
        out: [file]
    protFilter:
        run: ../Tools/filter_feature.tool.cwl
        in:
            sequences: sortProt/file
            similarity: rnaSims
            cluster: rnaClustMap
            outName:
                source: jobid
                valueFrom: $(self).375.filtering.faa
        out: [output]
    protCluster:
        run: ../Tools/cdhit.tool.cwl
        in:
            input: protFilter/output
            identity: protIdentity
            outName:
                source: jobid
                valueFrom: $(self).550.cluster.aa90.faa
        out: [outSeq, outClstr]
    formatCluster:
        run: ../Tools/format_cluster.tool.cwl
        in:
            input: protCluster/outClstr
            outName:
                source: jobid
                valueFrom: $(self).550.cluster.aa90.mapping
        out: [output]
    superblat:
        run: ../Tools/superblat.tool.cwl
        scatter: ["#superblat/database", "#superblat/outName"]
        scatterMethod: dotproduct
        in:
            query: protCluster/outSeq
            database: m5nrFull
            fastMap:
                default: true
            outName:
                source: m5nrFull
                valueFrom: $(self.basename).superblat.sims
        out: [output]
    catSims:
        run: ../Tools/cat.tool.cwl
        in:
            files: superblat/output
            outName:
                source: jobid
                valueFrom: $(self).superblat.sims.raw
        out: [output]
    sortSims:
        run: ../Tools/sort.tool.cwl
        in:
            input:
              source: catSims/output
              valueFrom: $([self])
            key: 
                valueFrom: $(["1,1"])
            outName:
                source: jobid
                valueFrom: $(self).superblat.sims.sort
        out: [output]
    bleachSims:
        run: ../Tools/bleachsims.tool.cwl
        in:
            input: sortSims/output
            outName:
                source: jobid
                valueFrom: $(self).650.superblat.sims
        out: [output]
    annotateSims:
        run: ../Tools/sims_annotate.tool.cwl
        in:
            input: bleachSims/output
            scgs: m5nrSCG
            database: m5nrBDB
            seqFormat:
                valueFrom: protein
            outFilterName:
                source: jobid
                valueFrom: $(self).650.aa.sims.filter
            outExpandName:
                source: jobid
                valueFrom: $(self).650.aa.expand.protein
            outLcaName:
                source: jobid
                valueFrom: $(self).650.aa.expand.lca
        out: [outFilter, outExpand, outLca]

