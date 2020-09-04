#!/usr/bin/env perl

use strict;
use warnings;
no warnings('once');

use PipelineAWE;

use POSIX qw/strftime/;
use Scalar::Util qw(looks_like_number);
use URI::Escape;
use Getopt::Long;
umask 000;

# options
my $job_id    = "";
my $nr_ver    = "";
my $ann_ver   = "";
my $api_url   = "";
my $upload    = "";
my $qc        = "";
my $preproc   = "";
my $derep     = "";
my $post_qc   = "";
my $source    = "";
my $search    = "";
my $rna_clust = "";
my $rna_map   = "";
my $genecall  = "";
my $aa_clust  = "";
my $aa_map    = "";
my $ontol     = "";
my $filter    = "";
my $help      = 0;
my $options   = GetOptions (
		"job=s"       => \$job_id,
		"nr_ver=s"    => \$nr_ver,
		"ann_ver=s"   => \$ann_ver,
		"api_url=s"   => \$api_url,
		"upload=s"    => \$upload,
		"qc=s"        => \$qc,
		"preproc=s"   => \$preproc,
		"derep=s"     => \$derep,
		"post_qc=s"   => \$post_qc,
		"source=s"    => \$source,
		"search=s"    => \$search,
		"rna_clust=s" => \$rna_clust,
		"rna_map=s"   => \$rna_map,
		"genecall=s"  => \$genecall,
		"aa_clust=s"  => \$aa_clust,
		"aa_map=s"    => \$aa_map,
		"ontol=s"     => \$ontol,
		"filter=s"    => \$filter,
		"help!"       => \$help
);

if ($help){
    print get_usage();
    exit 0;
}elsif (length($job_id)==0){
    PipelineAWE::logger('error', "job ID is required");
    exit 1;
}

# get api variable
my $api_key = $ENV{'MGRAST_WEBKEY'} || undef;

### update attribute stats
my $done_attr = PipelineAWE::get_userattr();
my $mgid = $done_attr->{id};

# get attributes
PipelineAWE::logger('info', "Computing file statistics and updating attributes");
my $pq_attr = PipelineAWE::read_json($post_qc.'.json');
my $sr_attr = PipelineAWE::read_json($search.'.json');
my $gc_attr = PipelineAWE::read_json($genecall.'.json');
my $rc_attr = PipelineAWE::read_json($rna_clust.'.json');
my $ac_attr = PipelineAWE::read_json($aa_clust.'.json');
my $rm_attr = PipelineAWE::read_json($rna_map.'.json');
my $am_attr = PipelineAWE::read_json($aa_map.'.json');
# add statistics
$pq_attr->{statistics} = PipelineAWE::get_seq_stats($post_qc, 'fasta', undef, "$post_qc.stats");
$sr_attr->{statistics} = PipelineAWE::get_seq_stats($search, 'fasta');
$gc_attr->{statistics} = PipelineAWE::get_seq_stats($genecall, 'fasta', 1);
$rc_attr->{statistics} = PipelineAWE::get_seq_stats($rna_clust, 'fasta');
$ac_attr->{statistics} = PipelineAWE::get_seq_stats($aa_clust, 'fasta', 1);
$rm_attr->{statistics} = PipelineAWE::get_cluster_stats($rna_map);
$am_attr->{statistics} = PipelineAWE::get_cluster_stats($aa_map);
# print attributes
PipelineAWE::print_json($post_qc.'.json', $pq_attr);
PipelineAWE::print_json($search.'.json', $sr_attr);
PipelineAWE::print_json($genecall.'.json', $gc_attr);
PipelineAWE::print_json($rna_clust.'.json', $rc_attr);
PipelineAWE::print_json($aa_clust.'.json', $ac_attr);
PipelineAWE::print_json($rna_map.'.json', $rm_attr);
PipelineAWE::print_json($aa_map.'.json', $am_attr);
# cleanup
unlink($post_qc, $search, $genecall, $rna_clust, $aa_clust, $rna_map, $aa_map);

### JobDB update
# get JobDB statistics
PipelineAWE::logger('info', "Retrieving sequence statistics from attributes");
my $job_stats = PipelineAWE::obj_from_url($api_url."/job/statistics/".$mgid, $api_key)->{data};
# get additional attributes
my $up_attr = PipelineAWE::read_json($upload.'.json');
my $qc_attr = PipelineAWE::read_json($qc.'.json');
my $de_attr = PipelineAWE::read_json($derep.'.json');
my $pp_attr = PipelineAWE::read_json($preproc.'.json');
my $fl_attr = PipelineAWE::read_json($filter.'.json');
my $on_attr = PipelineAWE::read_json($ontol.'.json');

# populate job_stats
$job_stats->{sequence_count_dereplication_removed} = $de_attr->{statistics}{sequence_count} || '0';  # derep fail
$job_stats->{read_count_processed_rna} = $sr_attr->{statistics}{sequence_count} || '0';      # pre-cluster / rna search
$job_stats->{read_count_processed_aa}  = $gc_attr->{statistics}{sequence_count} || '0';      # pre-cluster / genecall
$job_stats->{sequence_count_processed_rna} = $rc_attr->{statistics}{sequence_count} || '0';  # post-cluster / rna clust
$job_stats->{sequence_count_processed_aa}  = $ac_attr->{statistics}{sequence_count} || '0';  # post-cluster / aa clust

if ($up_attr->{statistics}) {
    map { $job_stats->{$_.'_raw'} = $up_attr->{statistics}{$_} } keys %{$up_attr->{statistics}}; # raw seq stats
}
if ($qc_attr->{statistics}) {
    map { $job_stats->{$_} = $qc_attr->{statistics}{$_} } keys %{$qc_attr->{statistics}};        # qc stats
}
map { $job_stats->{$_} = $fl_attr->{statistics}{$_} } keys %{$fl_attr->{statistics}};        # sims filter stats
map { $job_stats->{$_} = $on_attr->{statistics}{$_} } keys %{$on_attr->{statistics}};        # annotate ontology stats
map { $job_stats->{$_.'_preprocessed_rna'} = $pp_attr->{statistics}{$_} } keys %{$pp_attr->{statistics}};  # preprocess seq stats
map { $job_stats->{$_.'_preprocessed'}     = $pq_attr->{statistics}{$_} } keys %{$pq_attr->{statistics}};  # screen seq stats
map { $job_stats->{$_.'_processed_rna'}    = $rm_attr->{statistics}{$_} } keys %{$rm_attr->{statistics}};  # rna clust stats
map { $job_stats->{$_.'_processed_aa'}     = $am_attr->{statistics}{$_} } keys %{$am_attr->{statistics}};  # aa clust stats

# diversity computation from API, this is an asynchronous call
PipelineAWE::logger('info', "Starting alpha diversity and species rarefaction");
my $compute_url = $api_url."/compute/rarefaction/".$mgid."?asynchronous=1&alpha=1&level=species&ann_ver=".$ann_ver."&seq_num=".$job_stats->{sequence_count_raw};
my $alpha_rare  = PipelineAWE::async_obj_from_url($compute_url, $api_key, 0)->{data};
PipelineAWE::logger('info', "Completed alpha diversity and species rarefaction");
if ($alpha_rare->{alphadiversity} == 0) {
    PipelineAWE::logger('error', "unable to compute alpha diversity, organism abundance data is missing");
    exit 1;
}
$job_stats->{alpha_diversity_shannon} = $alpha_rare->{alphadiversity};

# read ratios
my ($aa_ratio, $rna_ratio) = read_ratios($job_stats);
$job_stats->{ratio_reads_aa} = $aa_ratio;
$job_stats->{ratio_reads_rna} = $rna_ratio;

# get sequence type
my $job_attrs = PipelineAWE::obj_from_url($api_url."/job/attributes/".$mgid, $api_key)->{data};
my $seq_type  = seq_type($job_attrs, $rna_ratio);

# get versions
my $versions = {
    pipeline_version => $done_attr->{pipeline_version} || '4.0',
    m5rna_sims_version => $nr_ver,
    m5nr_sims_version  => $nr_ver,
    m5rna_annotation_version => $ann_ver,
    m5nr_annotation_version  => $ann_ver
};

# update DB
PipelineAWE::logger('info', "Updating Job DB with new stats / info");
PipelineAWE::post_data($api_url."/job/statistics", $api_key, {metagenome_id => $mgid, statistics => $job_stats});
PipelineAWE::post_data($api_url."/job/attributes", $api_key, {metagenome_id => $mgid, attributes => $versions});
PipelineAWE::obj_from_url($api_url."/metagenome/$mgid/changesequencetype/$seq_type", $api_key);

### create metagenome statistics node
# get stats from inputs
PipelineAWE::logger('info', "Building / computing metagenome statistics file");
my $u_stats = PipelineAWE::read_json($upload);
my $q_stats = PipelineAWE::read_json($qc);
my $s_stats = PipelineAWE::read_json($source);
my %s_map   = map { $_->{source_id}, $_->{source} } @{PipelineAWE::obj_from_url($api_url."/m5nr/sources?version=".$ann_ver)->{data}};
my %s_data  = map { $s_map{$_}, $s_stats->{$_} } keys %$s_stats;

# get abundance stats from API, this is an asynchronous call
PipelineAWE::logger('info', "Starting abundance profiles");
my $abund_url  = $api_url."/job/abundance/".$mgid."?type=all&ann_ver=".$ann_ver;
my $abundances = PipelineAWE::async_obj_from_url($abund_url, $api_key, 0)->{data};
PipelineAWE::logger('info', "Completed abundance profiles");

# minimal test for missing data
if (scalar(@{$abundances->{taxonomy}{domain}}) == 0) {
    PipelineAWE::logger('error', "unable to compute annotation abundances, data is missing from DB.");
    exit 1;
}

# get qc stats - input stats may be from done stage if this is a rerun job
my $up_gc_hist  = undef;
my $up_len_hist = undef;
my $qc_all_stat = undef;
if ($q_stats->{sequence_stats}) {
    $up_gc_hist  = $q_stats->{gc_histogram}{upload};
    $up_len_hist = $q_stats->{length_histogram}{upload};
    $qc_all_stat = $q_stats->{qc};
} else {
    $up_gc_hist  = $u_stats->{gc_histogram};
    $up_len_hist = $u_stats->{length_histogram};
    $qc_all_stat = $q_stats;
}

# build stats obj
my $mgstats = {
    gc_histogram => {
        upload  => $up_gc_hist,
        post_qc => PipelineAWE::file_to_array("$post_qc.stats.gcs")
    },
    length_histogram => {
        upload  => $up_len_hist,
        post_qc => PipelineAWE::file_to_array("$post_qc.stats.lens")
    },
    qc => $qc_all_stat,
    source => \%s_data,
    taxonomy => $abundances->{taxonomy},
    function => $abundances->{function},
    ontology => $abundances->{ontology},
    rarefaction => $alpha_rare->{rarefaction},
    sequence_stats => $job_stats
};

# output stats object
PipelineAWE::logger('info', "Outputing statistics file");
PipelineAWE::print_json($job_id.".statistics.json", $mgstats);
PipelineAWE::create_attr($job_id.".statistics.json.attr", undef, {data_type => "statistics", file_format => "json"});

# upload of solr data
PipelineAWE::logger('info', "POSTing solr data");
my $solrdata = {
    sequence_stats => $mgstats->{sequence_stats},
    function => [ map {$_->[0]} @{$mgstats->{function}} ],
    organism => [ map {$_->[0]} @{$mgstats->{taxonomy}{species}} ]
};
PipelineAWE::post_data($api_url."/job/solr", $api_key, {metagenome_id => $mgid, solr_data => $solrdata});

# done done !!
my $now = strftime("%Y-%m-%d %H:%M:%S", localtime);
PipelineAWE::post_data($api_url."/job/attributes", $api_key, {metagenome_id => $mgid, attributes => {completedtime => $now}});
PipelineAWE::post_data($api_url."/job/viewable", $api_key, {metagenome_id => $mgid, viewable => 1});

exit 0;

sub get_usage {
    return "USAGE: awe_done.pl -job=<job identifier>\n";
}

sub read_ratios {
    # calculate ratio identified reads
    my ($stat_set) = @_;
    my $qc_aa_seqs    = exists($stat_set->{sequence_count_preprocessed}) ? $stat_set->{sequence_count_preprocessed} : 0;
    my $aa_sims       = exists($stat_set->{sequence_count_sims_aa}) ? $stat_set->{sequence_count_sims_aa} : 0;
    my $aa_clusts     = exists($stat_set->{cluster_count_processed_aa}) ? $stat_set->{cluster_count_processed_aa} : 0;
    my $aa_clust_seq  = exists($stat_set->{clustered_sequence_count_processed_aa}) ? $stat_set->{clustered_sequence_count_processed_aa} : 0;
    my $qc_rna_seqs   = exists($stat_set->{sequence_count_preprocessed_rna}) ? $stat_set->{sequence_count_preprocessed_rna} : 0;
    my $rna_sims      = exists($stat_set->{sequence_count_sims_rna}) ? $stat_set->{sequence_count_sims_rna} : 0;
    my $rna_clusts    = exists($stat_set->{cluster_count_processed_rna}) ? $stat_set->{cluster_count_processed_rna} : 0;
    my $rna_clust_seq = exists($stat_set->{clustered_sequence_count_processed_rna}) ? $stat_set->{clustered_sequence_count_processed_rna} : 0;
    my $aa_ratio      = $qc_aa_seqs ? ($aa_sims - $aa_clusts + $aa_clust_seq) / $qc_aa_seqs : 0;
    my $rna_ratio     = $qc_rna_seqs ? ($rna_sims - $rna_clusts + $rna_clust_seq) / $qc_rna_seqs : 0;
    return (sprintf("%.3f", $aa_ratio), sprintf("%.3f", $rna_ratio));
}

sub seq_type {
    my ($data_set, $rna_ratio) = @_;
    # trust amplicon
    my $seq_guess = exists($data_set->{sequence_type_guess}) ? $data_set->{sequence_type_guess} : '';
    if ($seq_guess eq 'Amplicon') {
        return 'Amplicon';
    }
    # use ratio for WGS or MT
    else {
        return ($rna_ratio > 0.25) ? 'MT' : 'WGS';
    }
}
