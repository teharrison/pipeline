package PipelineAWE_Conf;

use strict;
use warnings;
no warnings('once');


# awe url for submission
our $awe_url = "";

# OAuth token for shock permissions
our $shock_pipeline_token = "";

# template to use
our $template_file = "";

# jobcache db
our $job_dbhost => "";
our $job_dbname => "";
our $job_dbuser => "";

# keywords and values for workflow template
our $template_keywords = {
    
    # versions
    'pipeline_version'   => "",
    'ach_seq_ver'        => "",
    'ach_annotation_ver' => "",
    
    # awe clients
    'clientgroups' => "",
    
    # service urls
    'shock_url' => "",
    'mem_host'  => "",
    'mem_key'   => "",
    
    # default options
    'prefix_length' => '50',
    'fgs_type'      => '454',
    'aa_pid'        => '90',
    'rna_pid'       => '97',
    'md5rna_clust'  => "md5nr.clust",
    
    # shock data urls
    'index_download_urls' => "",
    'md5nr1_download_url' => "",
    'md5nr2_download_url' => "",
    'md5rna_clust_download_url' => "",
    
    # jobcache db
    'job_dbhost' => $job_dbhost,
    'job_dbname' => $job_dbname,
    'job_dbuser' => $job_dbuser,
    
    # analysis db
    'analysis_dbhost' => "",
    'analysis_dbname' => "",
    'analysis_dbuser' => ""

};

# shock nodes for bowtie indexes
our $bowtie_shock_indexes = {
    'a_thaliana'     => {
                            'a_thaliana.1.bt2' => '',  
                            'a_thaliana.2.bt2' => '',  
                            'a_thaliana.3.bt2' => '',  
                            'a_thaliana.4.bt2' => '',  
                            'a_thaliana.rev.1.bt2' => '',  
                            'a_thaliana.rev.2.bt2' => ''
                        },
    'b_taurus'       => {
                            'b_taurus.1.bt2' => '',  
                            'b_taurus.2.bt2' => '',  
                            'b_taurus.3.bt2' => '',  
                            'b_taurus.4.bt2' => '',  
                            'b_taurus.rev.1.bt2' => '',  
                            'b_taurus.rev.2.bt2' => ''
                        },
    'd_melanogaster' => {
                            'd_melanogaster.1.bt2' => '',  
                            'd_melanogaster.2.bt2' => '',  
                            'd_melanogaster.3.bt2' => '',  
                            'd_melanogaster.4.bt2' => '',  
                            'd_melanogaster.rev.1.bt2' => '',  
                            'd_melanogaster.rev.2.bt2' => ''
                        },
    'e_coli'         => {
                            'e_coli.1.bt2' => '',  
                            'e_coli.2.bt2' => '',  
                            'e_coli.3.bt2' => '',  
                            'e_coli.4.bt2' => '',  
                            'e_coli.rev.1.bt2' => '',  
                            'e_coli.rev.2.bt2' => ''
                        },
    'h_sapiens'      => {
                            'h_sapiens.1.bt2' => '',  
                            'h_sapiens.2.bt2' => '',  
                            'h_sapiens.3.bt2' => '',  
                            'h_sapiens.4.bt2' => '',  
                            'h_sapiens.rev.1.bt2' => '',  
                            'h_sapiens.rev.2.bt2' => ''
                        },
    'm_musculus'     => {
                            'm_musculus.1.bt2' => '',  
                            'm_musculus.2.bt2' => '',  
                            'm_musculus.3.bt2' => '',  
                            'm_musculus.4.bt2' => '',  
                            'm_musculus.rev.1.bt2' => '',  
                            'm_musculus.rev.2.bt2' => ''
                        },
    's_scrofa'       => {
                            's_scrofa.1.bt2' => '',  
                            's_scrofa.2.bt2' => '',  
                            's_scrofa.3.bt2' => '',  
                            's_scrofa.4.bt2' => '',  
                            's_scrofa.rev.1.bt2' => '',  
                            's_scrofa.rev.2.bt2' => ''
                        }
}