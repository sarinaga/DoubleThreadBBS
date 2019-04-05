package fileTest;

use strict;
use utf8;


chdir '../bbs/';
require 'file.pl';
require 'configReader.pl';

my $CONF = configReader::readConfig();
$file::CONF = $CONF;

print file::public_name(1) . "\n";
print file::secret_name(2) . "\n";
print file::gzip_public_name(3) . "\n";
print file::gzip_secret_name(4) . "\n";
print file::lock_name(5) . "\n";
print file::temp_name(6) . "\n";
print file::html_name(7) . "\n";
print file::gunzip_public_name(8) . "\n";
print file::gunzip_secret_name(9) . "\n";
print file::tmp_public_name(10) . "\n";
print file::tmp_secret_name(11) . "\n";
print file::pointer_name() . "\n";
print file::blacklist_name() . "\n";
print file::adminpass_name() . "\n";

chdir '../bbsTest/';
{
	$file::CONF->{'system'}->{'log'}->{'public'} = './testLogPublic/';
	$file::CONF->{'system'}->{'log'}->{'secret'} = './testLogSecret/';
	$file::CONF->{'system'}->{'tmp'} = 'C:/Users/micro/AppData/Local/Temp/';

	my @log0;
	print "-log0-\n";
	print file::read_log(0, \@log0, 1, 0, 0) . "\n";
	print @log0 . "\n";
	print $log0[1]{'TITLE'} . "\n";
	print $log0[1]{'USER_NAME'} . "\n";
	print $log0[1]{'USER_EMAIL'} . "\n";
	print $log0[1]{'USER_WEBPAGE'} . "\n";
	print $log0[1]{'USER_ID'} . "\n";
	print $log0[1]{'TOMATO'} . "\n";
	print $log0[1]{'POST_TIME'} . "\n";
	print $log0[1]{'BODY'} . "\n";

#	my @log1;
#	print "-log1-\n";
#	print file::read_log(0, \@log1, 0, 1, 0) . "\n";
#	print @log1 . "\n";
#	print @log1;
#	print $log1[0]{'THREAD_TITLE'} . "\n";
#	print $log1[0]{'POST'} . "\n";
#	print $log1[0]{'AGE_TIME'} . "\n";
#	print $log1[0]{'DAT'} . "\n";
#	print $log1[0]{'BUILDER_IP_ADDR'} . "\n";
#	print $log1[0]{'BUILDER_IP_HOST'} . "\n";




}
print "-END-";







