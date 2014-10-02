#!/bin/bash
# converts alignment to phylip and then makes a tree out of it
# Author: Lee Katz <lkatz@cdc.gov>
# TODO: make an outgroup parameter, probably using eigenvectors (least connected is the best guess for an outgroup)

#$ -S /bin/bash
#$ -pe smp 2
#$ -cwd
#$ -V
#$ -o launch_raxml.sh.out -j y

###############
## Parse options
# defaults
outgroupParam=""
numcpus=${NSLOTS:-2}
# parsing
while getopts ":n:o:" o; do
  case "${o}" in
    n) 
      numcpus=$OPTARG
      ;;
    o) 
      outgroupParam="-o $OPTARG"
      ;;
    *)
      echo "ERROR: I do not understand option $OPTARG"
      ;;
  esac
done
shift $(($OPTIND-1)) # remove the flag arguments from ARGV

#######################
## positional arguments
aln=$1
prefix=$2
if [ "$prefix" == "" ]; then
  echo Usage: `basename $0`" [options] aln.phy outprefix"
  echo -e "Options:\n  -n numcpus\n  -o outgroup"
  exit 1;
fi

############################
## Convert the alignment (?)
# get the extension
b=`basename $aln`;
suffix="${b##*.}";
if [ "$suffix" != "phy" ]; then
  echo "Converting to phylip format because I did not see a phy extension";
  convertAlignment.pl -f phylip -i $aln -o $aln.phy;
  if [ $? -gt 0 ]; then exit 1; fi;
  aln="$aln.phy";
fi;

# Which raxml to use?
which raxmlHPC 1>/dev/null 2>&1 && EXEC=raxmlHPC
which raxmlHPC-PTHREADS 1>/dev/null 2>&1 && EXEC=raxmlHPC-PTHREADS

# what version is raxml?
VERSION=$($EXEC -v | grep -o 'version [0-9]' | grep -o [0-9]);
echo "I detect that you are using version $VERSION of raxml."

if [ $VERSION = 8 ]; then
  MODEL=ASC_GTRGAMMA
else
  MODEL=GTRGAMMA
fi

## time to run the program!
$EXEC -f a -s $aln -n $prefix -T $numcpus -p $RANDOM -x $RANDOM -N 100 -m $MODEL $outgroupParam
if [ $? -gt 0 ]; then exit 1; fi;
