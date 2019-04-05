package fileTest;

use strict;
use utf8;


chdir '../bbs/';
require 'file.pl';
require 'configReader.pl';

my $CONF = configReader::readConfig();
$file::CONF = $CONF;

{
	for my $key (sort keys %ENV){
	  print "$key : $ENV{$key}\n";
	}
}


{
	print "public_name:";
	print file::public_name(1) . "\n";

	print "secret_name:";
	print file::secret_name(2) . "\n";

	print "gzip_public_name:";
	print file::gzip_public_name(3) . "\n";

	print "gzip_secret_name:";
	print file::gzip_secret_name(4) . "\n";

	print "lock_name:";
	print file::lock_name(5) . "\n";

	print "temp_name:";
	print file::temp_name(6) . "\n";

	print "html_name:";
	print file::html_name(7) . "\n";

	print "gunzip_public_name:";
	print file::gunzip_public_name(8) . "\n";

	print "gunzip_secret_name:";
	print file::gunzip_secret_name(9) . "\n";

	print "gzip_public_name_in_temp:";
	print file::gzip_public_name_in_temp(10) . "\n";

	print "gzip_secret_name_in_temp:";
	print file::gzip_secret_name_in_temp(11) . "\n";

	print "pointer_name:";
	print file::pointer_name() . "\n";

	print "blacklist_name:";
	print file::blacklist_name() . "\n";

	print "adminpass_name:";
	print file::adminpass_name() . "\n";
}

chdir '../bbsTest/';
{
	$file::CONF->{'system'}->{'log'}->{'public'} = './testLogPublic/';
	$file::CONF->{'system'}->{'log'}->{'secret'} = './testLogSecret/';
	$file::CONF->{'system'}->{'tmp'} = 'C:/Users/micro/AppData/Local/Temp/';

	my @log0;
	print "read_log:その1:\n";
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

	my @log1;
	print "read_log:その2:\n";
	print file::read_log(0, \@log1, 0, 1, 0) . "\n";
	print @log1 . "\n";
	print $log1[0]{'THREAD_TITLE'} . "\n";
	print $log1[0]{'POST'} . "\n";
	print $log1[0]{'AGE_TIME'} . "\n";
	print $log1[0]{'DAT'} . "\n";
	print $log1[0]{'BUILDER_IP_ADDR'} . "\n";
	print $log1[0]{'BUILDER_IP_HOST'} . "\n";
	print $log1[0]{'TITLE'} . "\n";

}

{
	file::gzip(0);
	my ($gzpub, $gzsec);
	$gzpub = file::gzip_public_name(0);
	$gzsec = file::gzip_secret_name(0);
	my ($exists_gzpub, $exists_gzsec);
	$exists_gzpub = (-f $gzpub);
	$exists_gzsec = (-f $gzsec);
	print "gzip:\n";
	print "exists_gzpub:$exists_gzpub\n";
	print "exists_gzsec:$exists_gzsec\n";

	file::gunzip(0, 0);
	$exists_gzpub = (-f $gzpub);
	$exists_gzsec = (-f $gzsec);
	my ($pub_temp, $sec_temp);
	$pub_temp = file::gunzip_public_name(0);
	$sec_temp = file::gunzip_secret_name(0);
	my ($exists_pub_temp, $exists_sec_temp);
	$exists_pub_temp = (-f $pub_temp);
	$exists_sec_temp = (-f $sec_temp);
	print "gunzip(テンポラリディレクトリに展開):\n";
	print "exists_gzpub:$exists_gzpub\n";
	print "exists_gzsec:$exists_gzsec\n";
	print "exists_pub_temp:$exists_pub_temp\n";
	print "exists_sec_temp:$exists_sec_temp\n";
	file::clear(0);

	file::gunzip(0, 1);
	$exists_gzpub = (-f $gzpub);
	$exists_gzsec = (-f $gzsec);
	my ($pub, $sec);
	$pub = file::public_name(0);
	$sec = file::secret_name(0);
	my ($exists_pub, $exists_sec);
	$exists_pub = (-f $pub);
	$exists_sec = (-f $sec);

	print "gunzip(ログディレクトリに展開):\n";
	print "exists_gzpub:$exists_gzpub\n";
	print "exists_gzsec:$exists_gzsec\n";
	print "exists_pub:$exists_pub\n";
	print "exists_sec:$exists_sec\n";

}

{
	my @thread;
	file::thread_read(\@thread);
	print "thread_read:\n";
	print @thread . "\n";
	print $thread[0]{'THREAD_TITLE'} . "\n";
	print $thread[0]{'POST'} . "\n";
	print $thread[0]{'AGE_TIME'} . "\n";
	print $thread[0]{'DAT'} . "\n";
	print $thread[0]{'BUILDER_IP_ADDR'} . "\n";
	print $thread[0]{'BUILDER_IP_HOST'} . "\n";

}

{
	my @log0;
	file::read_log(0, \@log0, 1, 0, 0);
	$log0[0]{'THREAD_NO'} = 1;
	print "write_log(新規):";
	print file::write_log(\@log0) . "\n";
	my ($pub, $sec);
	$pub = file::public_name(1);
	$sec = file::secret_name(1);
	my ($exists_pub, $exists_sec);
	$exists_pub = (-f $pub);
	$exists_sec = (-f $sec);
	print "write_log(新規ログ作成):\n";
	print "exists_pub:$exists_pub\n";
	print "exists_sec:$exists_sec\n";

	my @log1;
	file::read_log(0, \@log1, 1, 1, 0);
	$log1[0]{'THREAD_TITLE'} .= $$;
	print "write_log(更新):";
	print file::write_log(\@log1) . "\n";

	my @log2;
	print "write_log(ベリファイ):";
	print file::read_log(0, \@log2, 1, 0, 0) . "\n";
	if ($log2[0]{'THREAD_TITLE'} eq $log1[0]{'THREAD_TITLE'}){
		print "OK\n";
	}
	unlink($pub);
	unlink($sec);



}
