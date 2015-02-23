#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Bio::Perl;
use File::Basename;

$0=fileparse $0;
sub logmsg{print STDERR "$0: @_\n";}

exit main();
sub main{
  my $settings={ambiguities=>1};
  GetOptions($settings,qw(help ambiguities! tempdir=s allowed=i)) or die $!;
  die usage() if($$settings{help});
  $$settings{tempdir}||="tmp";
  $$settings{allowed}||=0;

  my($in)=@ARGV;

  logmsg "Filtering for clustered SNPs or any other specified filters";
  filterSites($in,$settings);

  return 0;
}

# Filter the BCF query file into a new one, if any filters were given
sub filterSites{
  my($bcfqueryFile,$settings)=@_;

  my $fp;
  if($bcfqueryFile){
    open($fp,"<",$bcfqueryFile) or die "ERROR: could not open bcftools query file $bcfqueryFile for reading: $!";
  } else {
    $fp=*STDIN;
  }

  # Read in the header with genome labels
  my $header=<$fp>;
  print $header;  # Print the header right away so that it can be saved correctly before it's changed
  $header=~s/^\s+|^#|\s+$//g; # trim and remove pound sign
  my @header=split /\t/, $header;

  # Read the actual content with variant calls
  my ($currentPos,$currentChr);
  while(my $bcfMatrixLine=<$fp>){
    # start by assuming that this is a high-quality site
    my $hqSite=1;

    # get the fields from the matrix
    my($CONTIG,$POS,$REF,@GT)=split(/\t/,$bcfMatrixLine);
    
    # get the values of the contig/pos if they aren't set
    if(!defined($currentChr) || $CONTIG ne $currentChr){
      # If the contig's value has switched, then undefine the position and start comparing on the new contig
      undef($currentChr);
      undef($currentPos);

      # start anew with these coordinates
      $currentChr=$CONTIG;
      $currentPos=$POS;
      seek($fp,-length($bcfMatrixLine),1);
      next;
    }

    # High-quality sites are far enough away from each other, as defined by the user
    $hqSite=0 if($POS - $currentPos < $$settings{allowed});

    # The user can specify that high quality sites are those where every site is defined
    # (ie through --noambiguities)
    if(!$$settings{ambiguities}){
      for my $nt(@GT){
        if($nt!~/[ATCG]/i){
          $hqSite=0;
          last;
        }
      }
    }

    print $bcfMatrixLine if($hqSite);

    # update the position
    $currentPos=$POS;
  }
  close $fp;

  return 1;
}

sub usage{
  "Multiple VCF format to alignment
  $0: filters a bcftools query matrix. The first three columns of the matrix are contig/pos/ref, and the next columns are all GT.
  Usage: 
    $0 bcftools.tsv > filtered.tsv
    $0 < bcftools.tsv > filtered.tsv # read stdin
  --noambiguities     remove any site with an ambiguity (i.e., complete deletion)
  --allowed 0         How close SNPs can be from each other before being thrown out
  --tempdir tmp       temporary directory
  "
}