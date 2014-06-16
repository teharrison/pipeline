package PipelineAWE;

use strict;
use warnings;
no warnings('once');

use JSON;
use Data::Dumper;

my $global_attr = "userattr.json";
my $json = JSON->new;
$json = $json->utf8();
$json->max_size(0);
$json->allow_nonref;

######### Helper Functions ##########

sub run_cmd {
    my ($cmd, $shell) = @_;
    my $status = undef;
    my @parts  = split(/ /, $cmd);
    print STDOUT $cmd."\n";
    if ($shell) {
        $status = system($cmd);
    } else {
        $status = system(@parts);
    }
    if ($status != 0) {
        print STDERR "ERROR: ".$parts[0]." returns value $status\n";
        exit $status >> 8;
    }
}

sub file_to_array {
    my ($file) = @_;
    my $data = [];
    unless ($file && (-s $file)) {
        return $data;
    }
    open(FILE, "<$file") || return $data;
    while (my $line = <FILE>) {
        chomp $line;
        my @parts = split(/\t/, $line);
        push @$data, [ @parts ];
    }
    close(FILE);
    return $data;
}

######### JSON Functions ##########

sub print_json {
    my ($file, $data) = @_;
    open(OUT, ">$file") or die "Couldn't open file: $!";
    print OUT $json->encode($data);
    close(OUT);
}

sub read_json {
    my ($file) = @_;
    my $data = {};
    if (-s $file) {
        open(IN, "<$file") or die "Couldn't open file: $!";
        $data = $json->decode(join("", <IN>)); 
        close(IN);
    }
    return $data;
}

sub create_attr {
    my ($name, $stats, $other) = @_;
    if (-s $global_attr) {
        my $attr = read_json($global_attr);
        if ($stats && ref($stats) && (scalar(keys %$stats) > 0)) {
            $attr->{statistics} = $stats;
        }
        if ($other && ref($other)&& (scalar(keys %$other) > 0)) {
            foreach my $key (keys %$other) {
                $attr->{$key} = $other->{$key};
            }
        }
        print_json($name, $attr);
    } else {
        print STDERR "missing $global_attr\n";
    }
}

######### Compute Stats ##########

sub get_seq_stats {
    my ($file, $type, $fast, $bins) = @_;
    unless ($file && (-s $file)) {
        return {};
    }
    my $cmd = "seq_length_stats.py -i $file";
    if ($type) {
        $cmd .= " -t $type";
    }
    if ($fast) {
        $cmd .= " -f"
    }
    if ($bins) {
        $cmd .= " -l $bins.lens -g $bins.gcs"
    }
    my @out = `$cmd`;
    chomp @out;
    my $stats = {};
    foreach my $line (@out) {
        if ($line =~ /^\[error\]/) {
            print STDERR $line."\n";
            exit 1;
        }
        my ($k, $v) = split(/\t/, $line);
        $stats->{$k} = $v;
    }
    return $stats;
}

sub get_cluster_stats {
    my ($file) = @_;
    
    my $stats = {
        cluster_count => 0,
        clustered_sequence_count => 0
    };
    unless ($file && (-s $file)) {
        return $stats;
    }
    open(FILE, "<$file") || return $stats;
    while (my $line = <FILE>) {
        chomp $line;
        my @tabs = split(/\t/, $line);
        my @ids  = split(/,/, $tabs[2]);
        $stats->{cluster_count} += 1;
        $stats->{clustered_sequence_count} += scalar(@ids) + 1;
    }
    close(FILE);
    return $stats;
}

# enable hash-resolving in the JSON->encode function
sub TO_JSON { return { %{ shift() } }; }

1;
