package configReaderTest;
use strict;
use utf8;
use Data::Dumper;

chdir '../bbs/';
require './configReader.pl';

sub testReadConfig{
	my $conf = configReader::readConfig();
	print "-----testReadConfig-----\n";
	print Dumper $conf;

}

testReadConfig;

