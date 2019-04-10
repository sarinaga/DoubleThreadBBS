package configReader;
use strict;
use lib '/home/sarinaga/perl/lib/perl5/site_perl/5.14/mach';
use JSON qw(decode_json);
use utf8;
binmode(STDOUT, ":utf8"); 

require './constants.pl';


##########################################################################
#                 環境設定ファイル(json)を読み込む                       #
##########################################################################
sub readConfig(){
	my $conf = readConfigFromFile();
	$conf = setDefaulyToConfig($conf);
	return $conf;
}

# ファイルから読み込む
sub readConfigFromFile{
	my $fin;
	open($fin, $constants::CONFIG_FILE) || die "Cannot read 'bbs.conf.json'.";
	my $content = do { local $/; <$fin> };
	my $conf = decode_json($content);
	return $conf;
}

# 読み込んだ内容を修正する
sub setDefaulyToConfig{

	my $c = shift;

	my $t;

	$t = \($c->{'general'}->{'idLength'});
	$$t = 5 if ($$t < 5);

	$t = \($c->{'general'}->{'displayLast'});
	$$t = 10 if ($$t < 10);

	$t = \($c->{'general'}->{'passwordLength'});
	$$t = 5 if ($$t < 5);

	$t = \($c->{'resource'}->{'threadMax'});
	$$t = 10 if ($$t < 10);

	$t = \($c->{'resource'}->{'bufferLimit'});
	$$t = 1000 if ($$t < 1000);

	my $f = $c->{'resource'}->{'postLimit'}->{'fileSize'};
	my ($t1, $t2, $t3);
	$t1 = \($f->{'max'});
	$$t1 = 1000000 if ($$t1 < 1000000);
	$t2 = \($f->{'warning'});
	$$t2 = 900000 if ($$t2 < 900000 or $$t1 <= $$t2);
	$t3 = \($f->{'caution'});
	$$t3 = 800000 if ($$t3 < 800000 or $$t2 <= $$t3);

	my $p = $c->{'resource'}->{'postLimit'}->{'post'};
	$t1 = \($p->{'max'});
	$$t1 = 1000 if ($$t1 < 1000);
	$t2 = \($p->{'warning'});
	$$t2 = 950 if ($$t2 < 950 or $$t1 <= $$t2);
	$t3 = \($p->{'caution'});
	$$t3 = 900 if ($$t3 < 900 or $$t2 <= $$t3);

	$t = \($c->{'resource'}->{'chainLimit'}->{'time'});
	$$t = 1 if ($$t < 1);

	$t = \($c->{'system'}->{'log'}->{'public'});
	$$t = $$t . "/" if (substr($$t, -1) ne '/');

	$t = \($c->{'system'}->{'log'}->{'secret'});
	$$t = $$t . "/" if (substr($$t, -1) ne '/');

	$t = \($c->{'system'}->{'log'}->{'html'});
	$$t = $$t . "/" if (substr($$t, -1) ne '/');

	$t = \($c->{'system'}->{'tmp'});
	$$t = $$t . "/" if (substr($$t, -1) ne '/');


	# symlinkファイルロックが利用できないときはロックしない
	$t = \($c->{'system'}->{'fileLock'});
	if ($$t == 1){
		eval {   symlink("","");   };
		$$t = 0 if ($@);
	}

	# バージョン番号 x 100
	$c->{'VERSION'} = $constants::VERSION;

	# OS情報
	$c->{'system'}->{'OS'}->{'name'} = $^O;
	$c->{'system'}->{'OS'}->{'isUnix'} = ($^O=~m/(linux|freebsd)/);

	return $c;


}





