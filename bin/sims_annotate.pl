#!/usr/bin/env perl

use strict;
use warnings;

use JSON;
use File::Slurp;
use BerkeleyDB;
use Data::Dumper;
use Getopt::Long;

my $verbose   = 0;
my $format    = '';
my $in_file   = '';
my $in_scg    = '';
my $filt_file = '';
my $exp_file  = '';
my $lca_file  = '';
my $ann_file  = '';
my $get_prot  = 0;
my $frag_num  = 5000;
my $usage     = qq($0
Input:
    1. sim: m8 format blast / blat file - sorted by query | top hit
    2. scg: md5 single copy gene file in json format
Output: top hit for each query per source (protein or rna formats)
    1. filtered sims: same format as m8
    2. expanded sims: see below
    3. lca expanded: see below

m8:       subject|fragment, query|md5, identity, length, mismatch, gaps, q_start, q_end, s_start, s_end, evalue, bit_score
expanded: md5|query, fragment|subject, identity, length, evalue, source
LCA:      md5|query list, fragment|subject, identity list, length list, evalue list, lca string, depth of lca (1-8)

  --format       protein|rna    Required. Type of sequences data in input file.
  --in_sim       file name      Required. Name of input sim file.
  --in_scg       file name      Optional. Name of input md5 single copy gene file.
  --out_filter   file name      Required. Name of filtered sim file.
  --out_expand   file name      Name of output expanded sim file (protein mode only).
  --out_lca      file name      Name of output expanded LCA file (protein and rna mode).
  --ann_file     file name      Name of berkley DB formatted m5nr annotations.
  --frag_num     int            Optional. Number of fragment chunks to load in memory at once before processing. Default is '$frag_num'.
  --verbose                     Optional. Verbose output.

);
if ( (@ARGV > 0) && ($ARGV[0] =~ /-h/) ) { print STDERR $usage; exit 1; }
if ( ! GetOptions( "verbose!"     => \$verbose,
                   "format=s"     => \$format,
		           "in_sim=s"     => \$in_file,
                   "in_scg=s"     => \$in_scg,
		           "out_filter=s" => \$filt_file,
		           "out_expand=s" => \$exp_file,
		           "out_lca=s"    => \$lca_file,
		           "ann_file=s"   => \$ann_file,
		           "frag_num:i"   => \$frag_num
                 ) )
  { print STDERR $usage; exit 1; }

unless ($in_file && (-s $in_file) && $filt_file) {
  print STDERR $usage . "Missing input and/or filter files.\n"; exit 1;
}

if ($format eq 'protein') {
    $get_prot = 1;
    print "Running in protein sim mode.\n" if ($verbose);
} elsif ($format eq 'rna') {
    print "Running in rna sim mode.\n" if ($verbose);
} else {
    print STDERR $usage . "Invalid format value.\n"; exit 1;
}

# get scg hash
my $json = JSON->new->allow_nonref;
my $scgs = {};
eval {
    $scgs = $json->decode(read_file($in_scg));
};

# get m5nr BerkelyDB handle
my %m5nr;
tie %m5nr, "BerkeleyDB::Hash",
        -Filename => $ann_file,
        -Flags    => DB_RDONLY
or die "Cannot open file $ann_file: $! $BerkeleyDB::Error\n";

my $data  = {};
my $count = 0;
my $frags = 0;
my $curr  = '';
my ($filt_fh, $exp_fh, $lca_fh, $filt_t, $exp_t, $lca_t);

print "Loading ach source data for mapping ... " if ($verbose);
my $src_map = $json->decode($m5nr{'source'});
unless ($src_map && ref($src_map)) {
  print STDERR "Error: Unable to get source data from berkeley db\n"; exit 1;
}
print "Done\n" if ($verbose);

print "Parsing file $in_file in $frag_num fragment size chunks ... " if ($verbose);
open(INFILE, "<$in_file") or die "Can't open file $in_file!\n";
open($filt_fh, ">$filt_file") or die "Can't open file $filt_file!\n";
open($exp_fh, ">$exp_file") or die "Can't open file $exp_file!\n";
open($lca_fh, ">$lca_file") or die "Can't open file $lca_file!\n";

while (my $line = <INFILE>) {
  chomp $line;
  my ($frag, $md5, @rest) = split(/\t/, $line);
  my $score = $rest[-1];
  my $eval = $rest[-2] * 1.0;

  unless ($line && $frag && (length($md5) == 32) && (scalar(@rest) == 10) && ($eval <= 0.001)) { next; }
  if ($curr eq '') { $curr = $frag; }
  
  # get top hits for each fragment
  if ($curr ne $frag) {
    if ($frags >= $frag_num) {
      #print STDERR "." if ($verbose);
      ($filt_t, $exp_t, $lca_t) = &get_top_hits($src_map, $data, $get_prot);
      print $filt_fh $filt_t if ($filt_t);
      print $exp_fh $exp_t   if ($exp_t);
      print $lca_fh $lca_t   if ($lca_t);
      $data = {};
      $frags = 0;
    }
    $curr = $frag;
    $count += 1;
    $frags += 1;
  }
  $md5 =~ s/lcl\|//;

  # set of md5s per frag score
  if (! exists $data->{$frag}{$score}{$md5}) {
    $data->{$frag}{$score}{$md5} = \@rest;
  }
}
close(INFILE);

if (scalar(keys %$data) > 0) {
  ($filt_t, $exp_t, $lca_t) = &get_top_hits($src_map, $data, $get_prot);
  print $filt_fh $filt_t if ($filt_t);
  print $exp_fh $exp_t   if ($exp_t);
  print $lca_fh $lca_t   if ($lca_t);
}

close($filt_fh);
close($exp_fh);
close ($lca_fh);

print "Done - $count fragments parsed\n" if ($verbose);
exit 0;

sub get_top_hits {
  my ($src_map, $data, $get_prot) = @_;
  
  my $filter_text   = '';
  my $expand_text   = '';
  my $lca_text      = '';
  my $data_min_md5  = {};
  my $total_min_md5 = {};
  my $total_md5s    = {};
  my $frag_srcs     = {};
  my $frag_md5s     = {};
  my $frag_lca      = {};

  # get total md5s: {md5}
  # get md5 per frag: frag => [ md5, exp, sim ]  # for all exps 0 and less
  foreach my $frag (keys %$data) {
    foreach my $score (keys %{$data->{$frag}}) {
      foreach my $md5 (keys %{$data->{$frag}{$score}}) {
	    $total_md5s->{$md5} = 1;
	    my $exp = &get_exp( $data->{$frag}{$score}{$md5}[8] );
	    if (defined $exp) {
          push @{ $frag_md5s->{$frag} }, [ $md5, $exp, $data->{$frag}{$score}{$md5} ];
        }
      }
    }
  }
  unless (scalar(keys %$total_md5s) > 0) { return; }

  # get data for md5s from memcache
  # source: md5 => { source => 1 }
  # lca: md5 => [lca]
  my ($md5_source, $md5_lca) = &get_md5_data([keys %$total_md5s]);

  # get sources per frag: frag => {source}
  foreach my $frag (keys %$data) {
    foreach my $score (keys %{$data->{$frag}}) {
      foreach my $md5 (grep {exists $md5_source->{$_}} keys %{$data->{$frag}{$score}}) {
	    map { $frag_srcs->{$frag}{$_} = 1 } keys %{$md5_source->{$md5}};
      }
    }
  }

  # get lca per frag: frag => { md5s => [md5], sims => [sim], lca => [lca] }
  foreach my $frag (keys %$frag_md5s) {
    my %md5s_lca  = map { $_->[0], $_->[2] } grep { $_->[1] == 0 } @{$frag_md5s->{$frag}};
    my @sort_md5s = sort { $a->[1] <=> $b->[1] } grep { $_->[1] < 0 } @{$frag_md5s->{$frag}};

    if (@sort_md5s > 0) {   
	  my $cutoff = $sort_md5s[0][1] - int($sort_md5s[0][1] * 0.2);
	  foreach my $set (@sort_md5s) {
        if ($set->[1] <= $cutoff) { $md5s_lca{ $set->[0] } = $set->[2]; }
	  }
    }
    if (scalar(keys %md5s_lca) > 0) {
	  my @lca = &get_lca([keys %md5s_lca], $md5_lca);
	  if (@lca == 9) {
	    $frag_lca->{$frag} = {md5s => [sort keys %md5s_lca], sims => [sort values %md5s_lca], lca => \@lca};
      }
    }
  }

  # get min md5s for max sources, ordered by score: frag => score => md5 => {source}
  foreach my $frag (keys %$data) {
    my $seen_srcs = {};
    my $seen_md5s = {};
    foreach my $score (sort {$b <=> $a} keys %{$data->{$frag}}) {
      if (scalar(keys %$seen_srcs) >= scalar(keys %{$frag_srcs->{$frag}})) { last; }
      my ($min_md5, $srcs) = &get_min_md5s_by_source($md5_source, [keys %{$data->{$frag}{$score}}], $seen_srcs, $seen_md5s);
      $data_min_md5->{$frag}{$score} = $min_md5;
      map { $total_min_md5->{$_} = 1 } keys %$min_md5;
      map { $seen_md5s->{$_} = 1 } keys %$min_md5;
      map { $seen_srcs->{$_} = 1 } @$srcs;
    }
  }

  # output expanded info
  foreach my $frag (sort keys %$data) {
    if (exists($frag_lca->{$frag})) {
      my $level = pop @{$frag_lca->{$frag}{lca}};
      $lca_text .= join("\t", ( join(";", grep {exists $md5_lca->{$_}} @{$frag_lca->{$frag}{md5s}}), # md5s
				                $frag,
				                join(";", map {$_->[0]} @{$frag_lca->{$frag}{sims}}), # identity
				                join(";", map {$_->[1]} @{$frag_lca->{$frag}{sims}}), # length
				                join(";", map {$_->[8]} @{$frag_lca->{$frag}{sims}}), # evalue
				                join(";", @{$frag_lca->{$frag}{lca}}),                # taxa
				                $level
			           )) . "\n";
    }
    next unless (exists $data_min_md5->{$frag});
    foreach my $score ( sort keys %{$data_min_md5->{$frag}} ) {
      foreach my $md5 ( sort keys %{$data_min_md5->{$frag}{$score}} ) {
        next unless (exists $md5_source->{$md5});
        
  	    # sim: [ identity, length, mismatch, gaps, q_start, q_end, s_start, s_end, evalue, bit_score ]
	    my $sim = $data->{$frag}{$score}{$md5};

	    # filter sim output
	    $filter_text .= join("\t", ($frag, $md5, @$sim)) . "\n";

	    # md5_source: md5 => [ source ]
	    # src_map: id => [ name, type ]
        foreach my $src ( sort keys %{$data_min_md5->{$frag}{$score}{$md5}} ) {
	      next unless (exists($md5_source->{$md5}{$src}) && exists($src_map->{$src}));
	      my ($sname, $stype) = @{$src_map->{$src}};
          $expand_text .= join("\t", ($md5, $frag, $sim->[0], $sim->[1], $sim->[8], $sname))."\n";
	    }
      }
    }
  }
  return ($filter_text, $expand_text, $lca_text);
}

sub get_md5_data {
    my ($md5s) = @_;

    my $ann   = {};
    my $lca   = {};
    my %data = ();
    foreach my $md5 (@{$md5s}) {
        if (exists $m5nr{$md5}) {
            $data{$md5} = $json->decode($m5nr{$md5});
        }
    }
    foreach my $m (keys %data) {
        if (exists($data{$m}{lca})) {
            $lca->{$m} = $data{$m}{lca};
        }
        if (exists $data{$m}{ann}) {
            foreach my $src (keys %{$data{$m}{ann}}) {
                $ann->{$m}{$src} = 1;
            }
        }
    }
    return ($ann, $lca);
}

sub get_min_md5s_by_source {
  my ($all_md5_srcs, $md5s, $seen_srcs, $seen_md5s) = @_;

  my %sub_md5s  = ();
  my %avil_srcs = ();
  foreach my $md5 (@$md5s) {
    next if ((exists $seen_md5s->{$md5}) || (! exists $all_md5_srcs->{$md5}));
    foreach my $src (keys %{$all_md5_srcs->{$md5}}) {
      next if (exists $seen_srcs->{$src});
      $sub_md5s{$md5}{$src} = 1;
      $avil_srcs{$src} = 1;
    }
  }
  
  my $max_srcs = scalar(keys %avil_srcs);
  my %cur_md5s = ();
  my %cur_srcs = ();

  foreach my $md5 (sort {scalar(keys %{$sub_md5s{$b}}) <=> scalar(keys %{$sub_md5s{$a}}) || $a cmp $b} keys %sub_md5s) {
    foreach my $src (keys %{$sub_md5s{$md5}}) {
      if (! exists $cur_srcs{$src}) {
	    $cur_md5s{$md5}{$src} = 1;
	    $cur_srcs{$src} = 1;
      }
    }
    last if (scalar(keys %cur_srcs) >= $max_srcs);
  }
  
  return (\%cur_md5s, [keys %cur_srcs]);
}

sub get_exp {
  my ($evalue) =  @_;

  my $value = undef;
  if ($evalue =~ /^(\d\.\d)e([-+])(\d+)$/) {
    my ($int, $pos, $exp) = ($1, $2, $3);
    my $is_zero = (($int eq '0.0') && ($exp eq '00')) ? 1 : 0;
    unless (($pos eq '+') && (! $is_zero)) {
      $value = $is_zero ? 0 : ($pos eq '-') ? -1 * $exp : $exp;
    }
  }

  return $value;
}

sub get_lca {
  my ($md5s, $md5_lca) = @_;

  my @taxa = ();
  my @scg_md5s = grep { exists $scgs->{$_} } @$md5s;
  
  if (scalar(@scg_md5s) > 0) {
      @taxa = map { $md5_lca->{$_} } grep { exists $md5_lca->{$_} } @scg_md5s;
  } else {
      @taxa = map { $md5_lca->{$_} } grep { exists $md5_lca->{$_} } @$md5s;
  }
  
  my $coverage = {};
  foreach my $t (@taxa) {
    for (my $i = 0; $i < scalar(@$t); $i++) {
      $coverage->{$i+1}->{ $t->[$i] }++ if ($t->[$i]);
    }
  }

  if ((scalar(keys %$coverage) < 8) || (scalar(keys %{$coverage->{1}}) > 1)) {
    return ();
  }

  my @lca = ();
  my $pos = 0;
  my $max = 0;
  
  foreach my $key (sort { $a <=> $b } keys %$coverage) {
    my $num = scalar keys %{$coverage->{$key}};
    if (($num <= $max) || ($max == 0)) {
      $max = $num;
      $pos = $key;
    }
  }

  if ( scalar(keys %{$coverage->{$pos}}) == 1 ) {
    @lca = map { keys %{$coverage->{$_}} } (1 .. $pos);
    push @lca, ( map {'-'} ($pos + 1 .. 8) ) if ($pos < 8);
    push @lca, $pos;
  }
  
  return @lca;
}
