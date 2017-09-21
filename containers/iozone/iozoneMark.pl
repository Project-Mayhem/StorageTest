#!/usr/bin/perl
#
# Computer geometric mean of the IOzone metrics
#

use POSIX;

# input arguments, where the test should run
chomp(my $testDir = $ARGV[0] || `pwd`);
#my $testDir = '/data';

#--------------------------------------------------------------------
# IOPS test
my $origDir = $ENV{PWD} || `pwd`;
my $procPerThread = 2;
my $stat = 0;
my $iops = 1;
my $iopsCnt = 0;
my $randomIops = 1;
my $randomIopsCount = 0;
my $sequentialIops = 1;
my $sequentialIopsCount = 0;

# We need to run this in a unique sub-directory because of the temp files the benchmark creates
chomp(my $hostname = `hostname`);
my $tmpDir = $testDir . "/work_" . $hostname;
$stat = mkdir($tmpDir);
if ($stat == 0) {
	perror('mkdir ' . $tmpDir);
	exit(1);
}
$stat = chdir($tmpDir);
if ($stat == 0) {
	perror('chdir ' . $tmpDir);
	exit(1);
}

chomp($FS=`stat --file-system --format=%T $tmpDir`);
#print $FS . "\n";

# record the start time
chomp(my $testStartTime = `date "+%Y-%m-%d'T'%H:%M:%S"`);
chomp(my $startTimestamp = `date "+%Y%m%d-%H%M%S"`);

my $cmd = "$origDir/iozone3_469/src/current/iozone -o -O -rlk -s10m -l$procPerThread |";
print("[RUN] $cmd\n");
open(F, $cmd);
while ($_ = <F> ) {
	chomp($_);
	m#Parent.* \d+ readers\s*=\s*([\d\.]+)\s+ops/sec# and do {
		$sequentialIops *= $1;
		$sequentialIopsCount += 1;
	};
	m#Parent.* random readers\s*=\s*([\d\.]+)\s+ops/sec# and do {
		$randomIops *= $1;
		$randomIopsCount += 1;
	};
	m#Avg throughput per process\s*=\s*([\d\.]+)\s+ops/sec# and do {
		$iops *= $1;
		$iopsCnt += 1;
	};	
}
close(F);
$stat = chdir("$origDir");
if ($stat == 0) {
	perror('chdir ' . $origDir);
}
system("rm -rf $tmpDir");

#--------------------------------------------------------------------
# Bandwidth test
my $procPerThread = 1;
my $stat = undef;
my $kps = 1;
my $bwCnt = 0;
my $r_kbps = 1;
my $randomBwCount = 0;
my $s_kbps = 1;
my $sequentialBwCount = 0;

# We need to run this in a unique sub-directory because of the temp files the benchmark creates
$stat = mkdir($tmpDir);
if ($stat == 0) {
	perror('mkdir ' . $tmpDir);
	exit(1);
}
$stat = chdir($tmpDir);
if ($stat == 0) {
	perror('chdir ' . $tmpDir);
	exit(1);
}

my $cmd = "$origDir/iozone3_469/src/current/iozone -o -c -rlm -s30m -l$procPerThread |";
print("[RUN] $cmd\n");
open(F, $cmd);
while ($_ = <F> ) {
	chomp($_);
	m#Parent.* \d+ readers\s*=\s*([\d\.]+)\s+kB/sec# and do {
		$s_kbps *= $1;
		$sequentialBwCount += 1;
		next;
	};
	m#Parent.*random readers\s*=\s*([\d\.]+)\s+kB/sec# and do {
		$r_kbps *= $1;
		$randomBwCount += 1;
		next;
	};
	m#Avg throughput per process\s*=\s*([\d\.]+)\s+kB/sec# and do {
		$kbps *= $1;
		$bwCnt += 1;
		next;
	};
}
close(F);
$stat = chdir("$origDir");
if ($stat == 0) {
	perror('chdir ' . $origDir);
}
system("rm -rf $tmpDir");

# record the end time
chomp(my $testEndTime = `date "+%Y-%m-%d'T'%H:%M:%S"`);

#--------------------------------------------------------------------
# Calculate averages

my $iopsAvg = "";
$iopsAvg = sprintf("%.4g", POSIX::pow($iops, 1.0 / $iopsCnt))  if ($iopsCnt > 0);

my $sequentialIopsAvg = "";
$sequentialIopsAvg = sprintf("%.4g", POSIX::pow($sequentialIops, 1.0 / $sequentialIopsCount))  if ($sequentialIopsCount > 0);

my $randomIopsAvg = "";
$randomIopsAvg = sprintf("%.4g", POSIX::pow($randomIops, 1.0 / $randomIopsCount))  if ($randomIopsCount > 0);

my $iopsUnits = "IOPS";


my $diskBwAvg = "";
$diskBwAvg = sprintf("%.4g", POSIX::pow($kbps, 1.0 / $bwCnt))  if ($bwCnt > 0);

my $sequentialBwAvg = "";
$sequentialBwAvg = sprintf("%.4g", POSIX::pow($s_kbps, 1.0 / $sequentialBwCount))  if ($sequentialBwCount > 0);

my $randomBwAvg = "";
$randomBwAvg = sprintf("%.4g", POSIX::pow($r_kbps, 1.0 / $randomBwCount))  if ($randomBwCount > 0);

my $bwUnits = "GB/s";

#--------------------------------------------------------------------
# Output results

my $outputString = '{';
$outputString .= '"metric": "iozone",';
$outputString .= '"hostname": "' . $hostname . '",';
$outputString .= '"startTime": "' . $testStartTime . '",';
$outputString .= '"endTime": "' . $testEndTime . '",';
$outputString .= '"testDirectory": "' . $testDir . '",';
$outputString .= '"fileSystemType": "' . $FS . '",';
$outputString .= '"iops": ' . $iopsAvg . ',';
$outputString .= '"sequentialIOPS": ' . $sequentialIopsAvg . ',';
$outputString .= '"randomIOPS": ' . $randomIopsAvg . ',';
$outputString .= '"iopsUnits": "' . $iopsUnits . '",';
$outputString .= '"diskBW": ' . $diskBwAvg . ',';
$outputString .= '"sequentialBW": ' . $sequentialBwAvg . ',';
$outputString .= '"randomBW": ' . $randomBwAvg . ',';
$outputString .= '"bwUnits": "' . $bwUnits . '"';
$outputString .= '}';
print $outputString, "\n";

# write the output file that will be processed by Logstash
#my $filename = "output.txt";
my $filename = "$testDir/output.txt";
open FILE, ">> $filename" or die "Could not open $filename";
print FILE $outputString, "\n";
close FILE;

# write an individual file for each run using the hostname and timestamp
#my $individualOutputFile = "./results/" . $hostname . "-" . $startTimestamp . ".txt";
my $individualOutputFile = "$testDir/" . $hostname . "-" . $startTimestamp . ".txt";
open RESULTFILE, "> $individualOutputFile" or die "Could not open $individualOutputFile";
print RESULTFILE $outputString, "\n";
close RESULTFILE;