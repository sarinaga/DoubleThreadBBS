#
# �ޥ������åɷǼ��� - ���ѥ��֥롼����ʤ�
#
#                                          2002.10.23 ����������
#
use strict;
package std;


use lib '/home/sarinaga/lib/i386-freebsd';
use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);
BEGIN{
	use vars qw($ENCODE_OK);
	eval "use Encode qw(from_to);";
	eval "use Encode::Guess qw(euc-jp shiftjis 7bit-jis);" if (!$@);
	if (!$@){
		$ENCODE_OK = 1;

	}else{
		$ENCODE_OK = 0;
		require './jcode.pl';
	}
}
use vars qw($REMOTE_HOST);
$REMOTE_HOST = undef;



########################################################################
#                         ��⡼�ȥۥ��Ȥ�����                         #
#                                                                      #
#  ���Υץ����� http://www.futomi.com/subroutine/ ��               #
#  ���֡��롼���󽸤Υ���������ɤ�����Τ����Ѥ��Ƥ��ޤ�              #
########################################################################
sub gethost{

	return $REMOTE_HOST if (defined($REMOTE_HOST));

	if ($ENV{'REMOTE_HOST'} eq '' or
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
#           HTML�����Ѥ����ʸ�������ʸ�����Ȥǥ���������             #
########################################################################
sub html_escape{
	my $data = shift;           # �Ѵ�������ʸ����
	$data =~s/&/&amp;/g;
	$data =~s/</&lt;/g;
	$data =~s/>/&gt;/g;
	$data =~s/'/&#39;/g;
	return $data;
}


########################################################################
#                       HTML����ʸ���Υ��������ײ��                   #
########################################################################
sub html_unescape{
	my $data = shift;           # �Ѵ�������ʸ����
	$data =~s/&lt;/</g;
	$data =~s/&gt;/>/g;
	$data =~s/&amp;/&/g;
	return $data;
}


########################################################################
#                               �����å���                           #
#                         ¿�Х��ȥ����Ȥˤ�̤�б�                     #
#                        html_escape �Ȥ�ʻ���Բ�ǽ                    #
########################################################################
sub shredder{
	my $data = shift;           # �Ѵ�������ʸ����

	my $len = length($data);
	return $data unless ($len > 0);

	# �Ѵ�������������
	my $trans = int(rand($len)) / 2 + 1;

	# �Ѵ�����ʸ��������Ƿ���
	my @place = ();
	for(my $i=0;$i<$trans;++$i){
		my $p = int(rand($len));
		my $repeat = grep{$_ == $p} @place;
		redo if($repeat > 0);
		push(@place, $p);
	}
	@place = sort{$b <=> $a} @place;

	# �Ѵ�����
	foreach my $p(@place){
		my $code = substr($data, $p, 1);
		$code = ord($code);
		substr($data, $p, 1) = "&#$code;";
	}

	return $data;
}


########################################################################
#                             URI����������                            #
########################################################################
sub uri_escape{
	my $arg = shift;	# ���������פ򤷤���ʸ����
	$arg =~s/([^a-zA-Z0-9_.!~*'()-])/sprintf("%%%02X", ord($1))/eg;
	$arg =~tr/ /+/;
	return $arg;
}


########################################################################
#                           URI���������ײ��                          #
########################################################################
sub uri_unescape{
	return un_uri_escape(shift);
}
sub un_uri_escape{
	my $arg = shift;	# ���������פ���������ʸ����
	$arg =~s/%([0-9A-Fa-f][0-9A-Fa-f])/pack("C", hex($1))/eg;
	return $arg;
}


#########################################################################
#                            ʸ���������Ѵ�                             #
#########################################################################
sub encodeEUC{
	my $trans = shift;
	if ($ENCODE_OK){
		my $encode_type	= guess_encoding($trans);
		return undef unless(ref($encode_type));
		my $from = $encode_type->name;
		my $to = "euc-jp";
		from_to($trans, $from, $to);
	}else{
		jcode::convert(\$trans, "euc");
	}
	return $trans;
}


########################################################################
#                          �Ź�����������                            #
########################################################################
sub salt{
	my $salt;
	my $salt_length = int(rand(7))+2;  # �������������ȯ��
	my @seed = ('0' .. '9', 'a' .. 'z', 'A' .. 'Z' , '.', '/');
	$salt = '';
	for(my $i=0;$i<$salt_length;++$i){
		$salt .= $seed[rand(scalar @seed)];
	}
	return "\$1\$$salt\$";
}


########################################################################
#                      ����񼰤�bool�ͤ��Ѵ�����                      #
########################################################################
sub trans_bool{
	my $check   = lc(shift);
	my $default = shift;
	$check = 1 if ($check eq 'yes' or $check eq 'true');
	$check = 0 if ($check eq 'no' or $check eq 'false');
	return $default unless($check=~m/^\d+$/);
	return ($check==0) ? 0 : 1;
}




########################################################################
#                      ʸ���������(HTML-EUC��)                        #
########################################################################
sub strnum_limit_html{
	my $data   = shift;
	my $limit = shift;
	$data = html_unescape($data);
	$data = strnum_limit_euc($data, $limit);
	$data = html_escape($data);
	return $data;
}


########################################################################
#                          ʸ���������(EUC��)                         #
#                                                                      #
# ���Υץ����� http://www2u.biglobe.ne.jp/%7EMAS/index.html ��     #
# ��Perl�ǽ񤯡פΥ������򤽤Τޤ����Ѥ��Ƥ��ޤ���                     #
########################################################################
sub strnum_limit_euc{
	my $str = shift;	# ʸ����
	my $limit = shift;	# �����
	
	my $limited_str = '';
	my $cnt = 0;
	
	while( $str =~ m/(
		[\x00-\x7F]|
		[\x8E\xA1-\xFE][\xA1-\xFE]|
		\x8F[\xA1-\xFE][\xA1-\xFE]
		)/gx
	) {
		$cnt++;
		$limited_str .= $1;
		if ($limit <= $cnt) {
			last;
		}
	}
	return $limited_str;
}

##########################################################################
#                        ������URI���ɤ���Ĵ�٤�                         #
#                                                                        #
#  ���Υץ����ϡ�Perl����                                          #
#  http://www.din.or.jp/%7Eohzaki/perl.htm#URI �Υ���������ɤ�����Τ�  #
#  ���Ѥ��Ƥ��ޤ�                                                        #
##########################################################################
sub uri_valid{
	my $uri = shift;  # ��������ɽ���ϴʰ��ǤʤΤ�������
	return $uri =~m/^[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+$/;
}


########################################################################
#                ������e-mail���ɥ쥹���ɤ���Ĵ�٤�                    #
#                                                                      #
#  ���Υץ����ϡ�Perl����                                        #
#  http://www.din.or.jp/%7Eohzaki/perl.htm#Mail �Υ�������             #
#  ���Τޤ����Ѥ��Ƥ��ޤ���                                            #
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
#                                  �羮���                              #
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
#                          ���ڡ���ʸ������֤�                          #
##########################################################################
sub spacer{
	my $number   = shift; # ���ڡ����ο�
	my $letter   = shift; # ���ڡ����˻Ȥ�ʸ��
	$letter='&nbsp;' unless(defined($letter));
	return $letter x $number;
}

##########################################################################
#                     Ϣ³�������ʸ����&nbsp;���Ѵ�                     #
##########################################################################
sub trans_space{
	my $body = shift;
	$body  =~s/(\ {2,})/"&nbsp;"x(length $1)/eg;
	return $body;
}


##########################################################################
#                        ���֤����ܸ����(JST)�ˤ���                     #
##########################################################################
sub time_format{
	my (undef,$min,$hr,$day,$mon,$year,$wdy,undef,undef) = localtime(shift); # ����
	$year+=1900;	$mon++;
	my @week=('��','��','��','��','��','��','��');
	return sprintf("%4dǯ%02d��%02d��(%s)%02d��%02dʬ", $year, $mon, $day, $week[$wdy], $hr, $min);
}

##########################################################################
#                         ���֤�ɸ��(GMT)�����ˤ���                      #
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
#                             �Ե�§ʸ����κ���                         #
##########################################################################
sub scramble{
	my $str  = shift;   # �ϥå��岽������ʸ����
	my $salt = shift;   # �ϥå��岽����

	# SALT�����ꤵ��ʤ��ä���������Ƿ���
	$salt = salt() unless(defined($salt));

	# SHA1�ϥå���base64��
	my $crypted = sha1_base64("$salt$str");

	# �ѿ�ʸ�������ˤ���
	$crypted=~s/\W//g;
	return $crypted;
}



##########################################################################
#                           ���ʿ��������ʿ��Ѵ�                         #
#                          (Perl5.6.1�������б���)                       #
#                                                                        #
#  ���Υץ����ϡ�Perl�ǽ񤯡�                                        #
#  http://www2u.biglobe.ne.jp/~MAS/perl/waza/210.html �Υ�������         #
#  ���Τޤ����Ѥ��Ƥ��ޤ���                                              #
##########################################################################
sub bin2dec{
	my $val = shift;
	my $ret = 0;
	my $i = 1;
	foreach my $num (reverse split //, $val) {
		if ($num == 1) {
			$ret = $ret + $i;
		}
		$i = $i * 2;
	}
	return $ret;
}


##########################################################################
#                                  ����404                               #
##########################################################################
sub goto404{
#Status: 404 Not Found
	print << "EOF";
Content-Type: text/html;

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML><HEAD>
<TITLE>404 Not Found</TITLE>
</HEAD><BODY>
<H1>Not Found</H1>
The requested URL /bbs/write.cgi was not found on this server.<P>
<HR>
<ADDRESS>Apache/1.3.37 Server at www.sarinaga.com Port 80</ADDRESS>
</BODY></HTML>
EOF
}


# �ƥ������ΰ�

1;


