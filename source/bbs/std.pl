#
# マルチスレッド掲示板 - 汎用サブルーチンなど
#
#                                          2002.10.23 さゆりん先生
#
use strict;
use Digest::SHA1 qw(sha1_base64);
use utf8;

package std;



########################################################################
#                         リモートホストを入手                         #
#                                                                      #
#  このプログラムは http://www.futomi.com/subroutine/ の               #
#  サブ・ルーチン集のソースを改良したものを利用しています              #
########################################################################
use vars qw($REMOTE_HOST);
$REMOTE_HOST = undef;
sub getHostname{

	# 一度取得したら二度と問い合わせをしない(処理コストが高いため)
	return $REMOTE_HOST if (defined($REMOTE_HOST));

	if (defined($ENV{'REMOTE_HOST'})  or
	    $ENV{'REMOTE_HOST'} eq '' or
	    $ENV{'REMOTE_HOST'} eq $ENV{'REMOTE_ADDR'} ){

		my $ip_address = $ENV{'REMOTE_ADDR'};
		my @addr = split(/\./, $ip_address);
		my $packed_addr = pack("C4", $addr[0], $addr[1], $addr[2], $addr[3]);
		my ($name, $aliases, $addrtype, $length, @addrs) = gethostbyaddr($packed_addr, 2);

		if ($name eq '' or !defined($name)){
			$REMOTE_HOST = $ENV{'REMOTE_ADDR'};
		}else{
			$REMOTE_HOST = $name;
		}

	}else{
		$REMOTE_HOST = $ENV{'REMOTE_HOST'};

	}
	return $REMOTE_HOST;

}



########################################################################
#           HTMLで利用される文字を実態文字参照でエスケープ             #
########################################################################
sub html_escape{
	my $data = shift;           # 変換したい文字列
	$data =~s/&/&amp;/g;
	$data =~s/</&lt;/g;
	$data =~s/>/&gt;/g;
	$data =~s/"/&quot;/g;
	$data =~s/'/&apos;/g;
	return $data;
}


########################################################################
#                       HTML所定文字のエスケープ解除                   #
########################################################################
sub html_unescape{
	my $data = shift;           # 変換したい文字列
	$data =~s/&lt;/</g;
	$data =~s/&gt;/>/g;
	$data =~s/&amp;/&/g;
	$data =~s/&quot;/"/g;
	$data =~s/&apos;/'/g;
	return $data;
}


########################################################################
#                               シュレッダー                           #
#                                                                      #
# ・文字列の一部を数値文字参照にします.                                #
# ・html_escape 後との併用できないので注意.                            #
########################################################################
	sub shredder{
	my $data = shift;           # 変換したい文字列

	my $len = length($data);
	return $data unless ($len > 0);

	# 変換させる数を決める
	my $trans = int(rand($len)) / 2 + 1;

	# 変換する文字を乱数で決める
	my @place = ();
	for(my $i=0;$i<$trans;++$i){
		my $p = int(rand($len));
		my $repeat = grep{$_ == $p} @place;
		redo if($repeat > 0);
		push(@place, $p);
	}
	@place = sort{$b <=> $a} @place;

	# 変換する
	foreach my $p(@place){
		my $code = substr($data, $p, 1);
		$code = ord($code);
		substr($data, $p, 1) = "&#$code;";
	}

	return $data;
}


########################################################################
#                             URIエスケープ                            #
########################################################################
sub uri_escape{
	my $arg = shift;	# エスケープをしたい文字列
	$arg =~s/([^a-zA-Z0-9_.!~*'()-])/sprintf("%%%02X", ord($1))/eg;
	$arg =~tr/ /+/;
	return $arg;
}


########################################################################
#                           URIエスケープ解除                          #
########################################################################
sub uri_unescape{
	my $arg = shift;	# エスケープを解除したい文字列
	$arg =~s/%([0-9A-Fa-f][0-9A-Fa-f])/pack("C", hex($1))/eg;
	return $arg;
}


########################################################################
#                          暗号種を生成する                            #
#                                                                      #
# ・unix_md5_cryptで利用する乱数種を作成する                           #
########################################################################
sub salt{
	my $salt;
	my $salt_length = int(rand(7))+2;  # ２～８の乱数を発生
	my @seed = ('0' .. '9', 'a' .. 'z', 'A' .. 'Z' , '.', '/');
	$salt = '';
	for(my $i=0;$i<$salt_length;++$i){
		$salt .= $seed[rand(scalar @seed)];
	}
	return $salt;
}



########################################################################
#                      所定書式をbool値に変換する                      #
########################################################################
sub trans_bool{
	my $check   = lc(shift);
	my $default = shift;
	$check = 1 if ($check eq 'yes' or $check eq 'true');
	$check = 0 if ($check eq 'no' or $check eq 'false');
	return $default unless($check=~m/^\d+$/);
	return ($check==0) ? 0 : 1;
}




##########################################################################
#                        正当なURIかどうか調べる                         #
#                                                                        #
#  このプログラムは「Perlメモ」                                          #
#  http://www.din.or.jp/%7Eohzaki/perl.htm#URI のソースを改良したものを  #
#  利用しています                                                        #
##########################################################################
sub uri_valid{
	my $uri = shift;  # この正規表現は簡易版なのだそうな
	return $uri =~m/^[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+$/;
}


########################################################################
#                正当なe-mailアドレスかどうか調べる                    #
#                                                                      #
#  このプログラムは「Perlメモ」                                        #
#  http://www.din.or.jp/%7Eohzaki/perl.htm#Mail のソースを             #
#  そのまま利用しています。                                            #
########################################################################
sub email_valid{
	my $email = shift;

	my $mail_regex = q{(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\\} .
	                 q{\[\]\000-\037\x80-\xff])|"[^\\\\\x80-\xff\n\015"]*(?:\\\\[^\x80-\xff][} .
	                 q{^\\\\\x80-\xff\n\015"]*)*")(?:\.(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x} .
	                 q{80-\xff]+(?![^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff])|"[^\\\\\x80-}  .
	                 q{\xff\n\015"]*(?:\\\\[^\x80-\xff][^\\\\\x80-\xff\n\015"]*)*"))*@(?:[^(}  .
	                 q{\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\\\[\]\0} .
	                 q{00-\037\x80-\xff])|\[(?:[^\\\\\x80-\xff\n\015\[\]]|\\\\[^\x80-\xff])*}  .
	                 q{\])(?:\.(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,} .
	                 q{;:".\\\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\\\x80-\xff\n\015\[\]]|\\\\[} .
	                 q{^\x80-\xff])*\]))*};

	return ($email=~m/^$mail_regex$/o);

}



##########################################################################
#                                  大小比較                              #
##########################################################################
sub math_max{
	my $first=shift(@_);
	my $second=shift(@_);
	return ($second<$first) ? $first : $second;
}

sub math_min{
	my $first=shift(@_);
	my $second=shift(@_);
	return ($first>$second) ? $second : $first;
}

sub str_max{
	my $first=shift(@_);
	my $second=shift(@_);

	return ($second lt $first) ? $first : $second;
}

sub str_min{
	my $first=shift(@_);
	my $second=shift(@_);

	return ($first gt $second) ? $second : $first;
}


##########################################################################
#                          スペーサ文字列を返す                          #
##########################################################################
sub spacer{
	my $number   = shift; # スペーサの数
	my $letter   = shift; # スペーサに使う文字
	$letter='&nbsp;' unless(defined($letter));
	return $letter x $number;
}

##########################################################################
#                     連続する空白文字を&nbsp;に変換                     #
##########################################################################
sub trans_space{
	my $body = shift;
	$body  =~s/(\ {2,})/"&nbsp;"x(length $1)/eg;
	return $body;
}


##########################################################################
#                        時間を日本語形式(JST)にする                     #
##########################################################################
sub time_format{
	my (undef,$min,$hr,$day,$mon,$year,$wdy,undef,undef) = localtime(shift); # 時刻
	$year+=1900;	$mon++;
	my @week=('日','月','火','水','木','金','土');
	return sprintf("%4d年%02d月%02d日(%s)%02d時%02d分", $year, $mon, $day, $week[$wdy], $hr, $min);
}

##########################################################################
#                         時間を標準(GMT)形式にする                      #
##########################################################################
sub gtime_format{
	my ($sec, $min, $hour, $day, $mon, $year, $wdy, $yday, $isdst) = gmtime(shift);

	my @week=('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	my @month=('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

	return sprintf("%s, %02d-%s-%4d %02d:%02d:%02d GMT",
                    $week[$wdy], $day, $month[$mon],
	                $year+1900, $hour, $min, $sec);
}


##########################################################################
#                    トリップキー作成(write.cgiに移動？)                 #
##########################################################################
sub createTrip{
	my $str  = shift;   # ハッシュ化したい文字列
	my $salt = shift;   # ハッシュ化キー
	my $crypted = Digest::SHA1::sha1_base64("$salt\$str");
	return $crypted;
}





##########################################################################
#                                  強制404                               #
##########################################################################
sub goto404{
#Status: 404 Not Found
	print << "EOF";
Content-Type: text/html;

<!DOCTYPE HTML">
<HTML>
<HEAD>
<TITLE>404 Not Found</TITLE>
</HEAD>
<BODY>
<H1>Not Found</H1>
The requested URL $ENV{'REQUEST_URI'} was not found on this server.<P>
<HR>
<ADDRESS>$ENV{'SERVER_SOFTWARE'} Server at www.sarinaga.com Port 80</ADDRESS>
</BODY>
</HTML>
EOF
}


# テスト用領域

1;


