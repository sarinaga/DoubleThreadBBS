#!/usr/bin/perl -w
#!C:/Perl/bin/perl -w
#
#
# �ޥ������åɷǼ��� - �񤭹��ߥ�����ץ�
#
#                                          2002.10.23 ����������
#
use strict;
use lib '/home/sarinaga/perllib/';
use CGI;
use Crypt::PasswdMD5;
BEGIN{
	if ($ENV{'HTTP_HOST'}){
		use CGI::Carp qw(carpout);
		open(LOG, ">./error.log") or die "Unable to append to 'error.log': $!\n.";
		carpout(*LOG);
		print LOG "-write.cgi-\n";
	}
}
require './html.pl';
require './file.pl';
require './std.pl';
require './write.pl';


unless($ENV{'HTTP_HOST'}){
	print "���Υץ�����CGI�ѤǤ�. ���ޥ�ɥ饤�󤫤�μ¹ԤϤǤ��ޤ���. \n";
	exit;
}


#--------------------------------------------------------------------------
#                                    �����ѿ�
#--------------------------------------------------------------------------
my $cgi = new CGI;
use vars qw($INIT $INITBAK);
$INIT    = './init.html';
$INITBAK = './init.html.bak';


#--------------------------------------------------------------------------
#                             ư��Ķ����ɤ߹���
#--------------------------------------------------------------------------

# ����ե����ե������ɤ߹���
use vars qw(%CONF);
other() unless(file::config_read(\%CONF));


#--------------------------------------------------------------------------
#                              ɬ�ץǡ�������
#--------------------------------------------------------------------------
#
# �����դ���CGI�ե�����μ�������Ƥϰʲ����̤�
#
# mode       = ��ƥ⡼��(create|revise|delete|post)
# no         = ����å��ֹ��mode=create�λ��Ϥʤ���
# target     = �������������ȯ���ֹ�(mode=revise|delete�ξ��Τ�)
# res        = �쥹���ֹ��mode=post�ξ��Τߡ�
# thread     = ����å�̾ (mode=create�ξ��Τ�)
# title      = ȯ�������ȥ�(mode=delete�λ��Ϥʤ�)
# name       = ��ƼԻ�̾(mode=delete�λ��Ϥʤ�)
# trip       = �ȥ�å�(mode=revise|delete�λ��Ϥʤ�)
# web        = �����֥ڡ������ɥ쥹(mode=delete�λ��Ϥʤ�)
# email      = email���ɥ쥹(mode=delete�λ��Ϥʤ�)
# pass       = ȯ������ѥѥ����
# age        = ����å�age(mode=post�ʳ��λ��Ϥʤ�)
# body       = ��ʸ��ʬ
# cookie     = cookie
# sage       = age/sage
# admin      = �ø��⡼��̾��
# set_cookie = cookie�����Ѥ��뤫�ɤ���
# build      = ���ư�����ǥ��쥯�ȥ�䥹��åɰ�����������
#

# ���̤��礭������Ȥ��ϥ��顼
post_huge() if ($ENV{'CONTENT_LENGTH'} > $CONF{'BUFFER_LIMIT'});

# �ǡ�����ѥ�᡼���������
my $no         = $cgi->param('no');                          # ����å��ֹ�
my $mode       = $cgi->param('mode');                        # ���⡼��
my $target     = $cgi->param('target');                      # ȯ�������ֹ�ޤ���ȯ������ֹ�
my $res        = $cgi->param('res');                         # �쥹���ֹ�
my $web        = std::html_escape($cgi->param('web'));       # http���ɥ쥹
my $trip       = $cgi->param('trip');                        # �桼���ȥ�å�
my $email      = std::html_escape($cgi->param('email'));     # email���ɥ쥹
my $password   = $cgi->param('pass');                        # �ѥ����
my $sage       = $cgi->param('sage');                        # ����åɤ�夲�뤫�夲�ʤ���
my $admin      = $cgi->param('admin');                       # (̤����)
my $set_cookie = $cgi->param('cookie');                      # Cookie����
my $build      = $cgi->param('build');                       # �Ǽ��Ľ����ư���ե饰
my $tomato     = $cgi->param('tomato');                      # IP���ɥ쥹����
my $thread     = std::html_escape($cgi->param('thread'));    # ����å�̾
my $title      = std::html_escape($cgi->param('title'));     # ��̾
my $name       = std::html_escape($cgi->param('name'));      # ��Ƽ�̾
my $body       = std::html_escape($cgi->param('body'));      # ��ʸ


# ���ƷǼ��Ĥ�ư�����Ȥ��ν��������
if (std::trans_bool($build)){
	build() if (-f $INIT);
	bad_request();
}

# ����åɺƹ����ʳ��ξ���POST�ǸƤӽФ��ʤ���Ф����ʤ�
bad_request()  if ($ENV{'REQUEST_METHOD'} ne 'POST');


#--------------------------------------------------------------------------
#                                 �ǡ�������
#--------------------------------------------------------------------------
# �⡼�ɤ����������ɤ���Ĵ�٤�
illigal_form() unless($mode eq $writecgi::CREATE or $mode eq $writecgi::REVISE or   # �⡼�ɰ㤤
                      $mode eq $writecgi::DELETE or $mode eq $writecgi::POST);


# ȯ���������Ǥ��ʤ�����ʤΤ�revise, delete���׵᤬��Ƥ����饨�顼 
no_change() if (($mode eq $writecgi::DELETE or $mode eq $writecgi::REVISE) and !$CONF{'ACCEPT_CHANGE'});


# ��������åɺ����ǡ�������Ƶ������¿���ã�����ͤΤȤ��ϥ��顼
over_thread() if (($mode eq $writecgi::CREATE) and check_builder());


# ��������åɺ����ǡ�����åɺ����ػߤξ��ϥ��顼
cant_create_thread() if (($mode eq $writecgi::CREATE) and $CONF{'THREAD_MAX'} == 0);

# (��ꤿ���ʤ��Τ���)body��http://���ޤޤ���硢̵������reject����
if ($body=~m/http:\/\//){
	std::goto404();
	exit;
}

# (��ꤿ���ʤ��Τ���)title���Ѹ�����ξ�硢̵������reject����
if ($title=~m/^[\w\s]+$/){
	std::goto404();
	exit;
}


# ���ԥ����������ʸ���������Ѵ�
my $trans = join('<>', $thread, $title, $name, $body);
$trans=~s/\x0D\x0A/\n/g;
$trans=~tr/\x0D\x0A/\n\n/;
$trans=~s/\n{4,}/\n\n\n/g;
$trans=~s/\n*$//;

$trans = std::encodeEUC($trans);
cant_encode_guess() unless(defined($trans));   # ʸ�������ɿ�¬�˼��Ԥ������ϥ��顼
($thread, $title, $name, $body) = split(/<>/, $trans);


# ����å�̾����
if ($mode eq $writecgi::CREATE){  lack_thread() if ($thread eq '');  }
else{  illigal_form() if ($thread ne '');  }


# ����å��ֹ�����
if ($mode eq $writecgi::CREATE){
	illigal_form() if ($no ne '');
}else{
	illigal_form() unless($no=~m/^(\d+)$/);
	$no = $1;
}

# ȯ���ֹ�����
if ($mode eq $writecgi::REVISE or $mode eq $writecgi::DELETE){
	illigal_form() unless($target=~m/^\d+$/);
}else{
	illigal_form() if ($target ne '');
}

# �쥹�ֹ�����
if ($mode eq $writecgi::POST){
	illigal_form() unless($res=~m/^\d*$/);
	$res = undef if($res eq '');
}else{
	illigal_form() if ($res ne '');
}


# �����ȥ�, ̾��, URI, email���ɥ쥹����
if ($mode eq $writecgi::DELETE){
	illigal_form() if ($title ne '');
	illigal_form() if ($name ne '');
	illigal_form() if ($web ne '');
	illigal_form() if ($email ne '');

}else{
	lack_body() if ($title eq '' and $body eq '');
	$title = $CONF{'NO_TITLE'} if ($title eq '');
	$name  = $CONF{'NO_NAME'}  if ($name eq '');
	if($web ne ''){
		illigal_http() unless(std::uri_valid($web));
	}
	if($email ne ''){
		illigal_email() unless(std::email_valid($email))
	}
}

# �ȥ�å�����
if ($mode eq $writecgi::DELETE or $mode eq $writecgi::REVISE){
	illigal_form() if($trip ne '');
}else{
	illigal_trip() unless($trip=~m/^[\da-zA-Z]{0,$CONF{'TRIP_INPUT_LENGTH'}}$/);
}


# �ѥ��������
if ($mode eq $writecgi::CREATE or $mode eq $writecgi::POST){
	illigal_password() unless($password=~m/^[\da-zA-Z]{$writecgi::PASS_LENGTH_MIN,$CONF{'PASSWORD_LENGTH'}}$/);
}


# sage����
if ($mode eq $writecgi::POST){
	$sage = std::trans_bool($sage, 0);
	illigal_form() unless(defined($sage));
}else{
	illigal_form() if ($sage ne '');
	$sage = ($mode eq $writecgi::CREATE) ? 0 : 1;
}

# tomato����
if ($mode eq $writecgi::CREATE or $mode eq $writecgi::POST){
	$tomato = std::trans_bool($tomato, 0);
	illigal_form() unless(defined($tomato));
}else{
	illigal_form() if ($tomato ne '');
}


#-------------------------------------------------------------------------
#                             ���ɤ߼��
#-------------------------------------------------------------------------
# �����������λ��ϥ��ե�����򿷵����������إå���ʬ�ǡ������������
my @log;
if($mode eq $writecgi::CREATE){
	$no = file::read_pointer(1);      # ��å��򤫤��äѤʤ��ˤ�������ǥݥ��󥿤��ɤ�
	fail_read() unless(defined($no)); # �ݥ��󥿤��ɤ�ʤ��ä�
	fail_write() unless(create($no)); # �����ե��������

# ��ơ�����������λ��ϥ����ɤ߼��
}else{
	fail_read() unless(file::read_log($no, \@log, 1, 1, 0));   # ��å��򤫤��롢�����ɤࡢgz�����б��򤷤ʤ�
}


# Ϣ³������¤�Ķ����Ȥ��ϥ��顼�ʿ������쥹��Ƥξ���
if ($mode eq $writecgi::POST){
	if (check_chain_post(\@log)){
		clear($no);
		post_chain();
	}
}


# ȯ���ֹ椬���¤�ۤ�����ϥ��顼�ʿ������쥹��Ƥξ���
if ($mode eq $writecgi::POST){
	$target = @log;
	if ($target >= $CONF{'THREAD_LIMIT'}){
		clear($no);
		thread_over();
	}
}

# ����å����̤����¤�ۤ�����ϥ��顼
if ($mode ne $writecgi::DELETE){
	if ($log[0]{'SIZE'} >= $CONF{'FILE_LIMIT'}){
		clear($no);
		file_over();
	}
}

# �������ϥե���������������ǧ����
if ($mode eq $writecgi::DELETE or $mode eq $writecgi::REVISE){

	# ¸�ߤ��ʤ�ȯ������
	if ($target >= @log){
		clear($no);  illigal_form();
	}

	# ���Ǥ�ȯ���������Ƥ��롩
	if (defined($log[$target]{'DELETE_TIME'})){
		clear($no);  already_delete();
	}

    # �ѥ���ɾȹ�
	if ($log[$target]{'PASSWORD'} ne unix_md5_crypt($password, $log[$target]{'PASSWORD'})){
		clear($no);  mismatch_password();
	}
}


# �쥹��ȯ����¸�ߤ��뤫�ɤ�����Ĵ�٤�
if ($mode eq $writecgi::POST and defined($res)){

	# ¸�ߤ��ʤ�ȯ���˥쥹��
	if($res >= @log){
		clear($no);  illigal_form();
	}

	# �쥹��ȯ�����ä��Ƥ���
	if(defined($log[$res]{'DELETE_TIME'})){
		clear($no);  res_lost()
	}
}

# ȯ�����������Ķ�����ѹ����褦�Ȥ����饨�顼
if ($mode eq $writecgi::REVISE and defined($log[$target]{'CORRECT_TIME'})){
	if (@{$log[$target]{'CORRECT_TIME'}} >= $CONF{'CHANGE_LIMIT'}){
		clear($no);
		change_limit();
	}
}


#--------------------------------------------------------------------------
#                                ����������
#--------------------------------------------------------------------------

# ������ƽ���
my $ip = $ENV{'REMOTE_ADDR'};
if ($mode eq $writecgi::POST){

	# ȯ���ֹ�򣱤Ŀʤ��
	++$log[0]{'POST'};


# ��������åɺ�������
}elsif($mode eq $writecgi::CREATE){
	$target = 0;
	$log[0]{'POST'} = 1;
	$log[0]{'THREAD_TITLE'} = $thread;
	$log[0]{'THREAD_NO'} = $no;
	$log[0]{'BUILDER_IP_ADDR'} = $ip;
	$log[0]{'BUILDER_IP_HOST'} = std::gethost($ip);
}

# �Ǹ�ˤ�����줿����
$log[0]{'AGE_TIME'}  = time() if(!$sage or $mode eq $writecgi::CREATE);

# ȯ���ֹ�
$log[$target]{'NO'}           = $target;                                 # ȯ���ֹ�
$log[$target]{'RES'}          = $res if(defined($res));                  # �쥹���ֹ�


# ȯ�������ȥ롢�桼��̾��email�������֥ڡ������ɥ쥹����ʸ�ʿ�������åɺ���������ȯ����ȯ��������
if ($mode ne $writecgi::DELETE){
	$log[$target]{'TITLE'}        = $title;
	$log[$target]{'USER_NAME'}    = $name;
	$log[$target]{'USER_EMAIL'}   = $email;
	$log[$target]{'USER_WEBPAGE'} = $web;
	$log[$target]{'BODY'}         = $body;
	if ($mode ne $writecgi::REVISE and $trip ne ''){
		$log[$target]{'TRIP'} = trip($trip)
	}
	if ($mode eq $writecgi::CREATE or $mode eq $writecgi::POST){
		$log[$target]{'TOMATO'} = $tomato;
	}
}

# ���IP���ɥ쥹(numberic, FQDN)�����ѥ桼�������������
push(@{$log[$target]{'IP_ADDR'}}, $ip);
push(@{$log[$target]{'IP_HOST'}}, std::gethost($ip));
push(@{$log[$target]{'USER_AGENT'}}, $ENV{'HTTP_USER_AGENT'});

# ��ƻ��֡��ѥ���ɡ��桼��ID�ʿ�������åɺ���������ȯ����
if ($mode eq $writecgi::POST or $mode eq $writecgi::CREATE){
	$log[$target]{'POST_TIME'}   = time();
	$log[$target]{'PASSWORD'}    = unix_md5_crypt($password, std::salt());
	$log[$target]{'USER_ID'}     = create_id($ip) if ($CONF{'CREATE_ID'});
}

if ($mode eq $writecgi::DELETE){  $log[$target]{'DELETE_TIME'} = time(); }            # ȯ��������֡�ȯ�������
if ($mode eq $writecgi::REVISE){  push(@{$log[$target]{'CORRECT_TIME'}}, time());  }  # ȯ���������֡�ȯ��������


# �������ӽ�����
if ($mode eq $writecgi::POST){
    if (chack_dupe_post(\@log)){
		clear($no);
		post_dupe();
	}
}

#--------------------------------------------------------------------------
#                               ���񤭽Ф�����
#--------------------------------------------------------------------------

# ��������åɺ����λ��ϥݥ����͹���
if ($mode eq $writecgi::CREATE){
	my $pointer = $no + 1;
	unless(file::write_pointer($pointer)){
		clear($no);
		unlink(file::public_name($no));
		unlink(file::secret_name($no));
		fail_write();
	}
}

# �ܥ��񤭽Ф�
fail_write() unless(file::write_log(\@log));

# ����åɰ����Ǥ��Ф�
age() if(!$sage or $mode eq $writecgi::CREATE);


#--------------------------------------------------------------------------
#                              Cookie�ǡ�������
#--------------------------------------------------------------------------
my %cookie;
if ($mode eq $writecgi::POST or $mode eq $writecgi::CREATE){
	$cookie{'USER_NAME'}    = $name;
	$cookie{'USER_EMAIL'}   = $email;
	$cookie{'USER_WEBPAGE'} = $web;
	$cookie{'TRIP'}         = $trip;
	$cookie{'PASSWORD'}     = $password;
	$cookie{'COOKIE'}       = $set_cookie;
	$cookie{'SAGE'}         = $sage if ($mode eq $writecgi::POST);
	$cookie{'TOMATO'}       = $tomato;
}
my $expires = ($set_cookie) ? $CONF{'COOKIE_EXPIRES'} : -1;


#--------------------------------------------------------------------------
#                             ��λ��å�����ɽ��
#--------------------------------------------------------------------------

# �������֤�Ƚ��
my $process;
$process = '��������åɺ���' if ($mode eq $writecgi::CREATE);
$process = 'ȯ������'         if ($mode eq $writecgi::REVISE);
$process = 'ȯ�����'         if ($mode eq $writecgi::DELETE);
if ($mode eq $writecgi::POST){
	if (defined($res)){  $process = '�쥹ȯ�����';  }
	else{ $process = '�������';  }
}
$process .= '������λ';


# http_response_header ����
html::http_response_header();


# html�إå�����
if ($mode eq $writecgi::POST or $mode eq $writecgi::CREATE){
	html::header(*STDOUT , $process, undef, \%cookie, $expires);
}else{
	html::header(*STDOUT , $process);
}


# ��λ��å������ʲ�ɽ��
print "<h2>$process</h2>\n\n";
print "<p>�񤭹��ߤ���λ���ޤ�����</p>";

# ����ȯ���ɤ߹��ߥե������ɽ��
if ($mode eq $writecgi::DELETE){
	html::form_read(*STDOUT, $no, $#log);

}else{
	html::form_read(*STDOUT, $no, $#log, $target,
	                $mode eq $writecgi::REVISE ? '����' : '���');
}

# ��󥯥С�
print '<div class="link">';
html::link_top(*STDOUT);
html::link_adminmail(*STDOUT);
print "</div>\n\n";

html::footer(*STDOUT);

exit;




###########################################################################
#                    ���Ǽ��ĵ�ư���ν�����ץ���                     #
###########################################################################
sub build{

	# ���Ǥ˥ӥ�ɤ���Ƥ��뤫�ɤ�����Ƚ�ꤹ��
	my $pointer = file::read_pointer();

	# ���Ǥ˷Ǽ��Ĥ�Ư���Ƥ�����Ͻ�����Ԥ�ʤ�
	already_build() if (defined($pointer));

	# �ǥ��쥯�ȥꡢ�ݥ��󥿥ե�����κ����ʽ������
	fail_build() unless(file::init());

	# ����åɤ򤢤�������Ԥ���bbs.html�����������
	fail_build() unless(age());

	# admin.html�ե�����ι�����Ԥ�
	fail_build() unless(file::create_adminpage());

	# ��λ��å�����ɽ��
	html::http_response_header();
	html::header(*STDOUT , '�Ǽ��Ľ����������λ');
	print "<h2 id='complete-init'>�����������λ</h2>\n\n";
	print "<p>�Ǽ��Ĥ��������ޤ������ʸ塢�Ǽ��Ĥ����Ѥ��뤳�Ȥ��Ǥ��ޤ���</p>\n\n";
	print "<div class='link'>";
	html::link_exit(*STDOUT);
	html::link_top(*STDOUT);
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::footer(*STDOUT);

	# ������ե������̾�����Ѥ���
	rename ($INIT, $INITBAK);
	exit;
}


##########################################################################
#      ��������åɺ����λ������������ե�����������Ȥʤ���        #
##########################################################################
sub create{
	my $no = shift;     # ����å��ֹ�

	my $log_public = file::public_name($no);
	my $log_secret = file::secret_name($no);

	# ���ե��������
	open(FOUT, ">$log_public") || return 0;
	close(FOUT);
	unless(open(FOUT, ">$log_secret")){
		unlink($log_public);
		return 0;
	}
	close(FOUT);

	# �ե�����°���ѹ�
	chmod($file::PUBLIC_FILE_PERMISSION, $log_public);
	chmod($file::SECRET_FILE_PERMISSION, $log_secret);

	# ��å��򤫤���
	unless(file::filelock($log_public) and file::filelock($log_secret)){
		clear($no);
		unlink($log_public);  # ��å��˼��Ԥ������Ͽ�������åɤϺ��ʤ��Τ�
		unlink($log_secret);  # ��������ä��ե�����������뤷���ʤ�
		return 0;
	}

	return 1;
}


###########################################################################
#                ���ե�����򽸷פ���bbs.html���������                 #
#                    �Ť��ʤä�����åɤ򰵽̽�������                     #
#                ����åɤ���Ƥ������ͤ򸡺�������������                 #
###########################################################################
sub age{

	# ����åɰ����ɤ߹���
	my @thread;
	my $read = file::thread_read(\@thread);
	#warn "read thread : $read\n";
	return 0 unless (defined($read));

	# ����åɿ����̽���
	file::compress(\@thread);

	# ����å���Ω���¿�Ĵ��
	count_builder(\@thread);

	# bbs.html�򹹿�������[�����ʲ�������]
	return file::create_bbshtml(\@thread);

}



###########################################################################
#         ����å���Ω���¿���ã����IP���ɥ쥹��ȴ���Ф�����Ͽ����        #
###########################################################################
sub count_builder{
	my $thread_list = shift;

	my %builder;
	foreach my $d(@$thread_list){

		next if ($$d{'DAT'});   # DAT�ԥǡ����Ͻ������ʤ�

		my $host = $$d{'BUILDER_IP_HOST'};
		my $addr = $$d{'BUILDER_IP_ADDR'};

		# �ۥ���̾�򽸷פ���
		if(defined($builder{$host})){
			$builder{$host}++;
		}else{
			$builder{$host} = 1;
		}

		# �ۥ���̾��IP���ɥ쥹��Ʊ�����ϼ��ν�����Ԥ�ʤ�
		next if ($host eq $addr);

		# IP���ɥ쥹�򽸷פ���
		if(defined($builder{$addr})){
			$builder{$addr}++;
		}else{
			$builder{$addr} = 1;
		}
	}

	# ������Ƶ����˰��ä����ä���Τ����
	my @over_builder;
	foreach my $addr_host(keys %builder){
		push(@over_builder, $addr_host) if ($builder{$addr_host} >= $CONF{'THREAD_MAX'});
	}

	# ������Ƥ����֥�å��ꥹ�Ƚ���
	return file::write_overbuilder(@over_builder);

}



###########################################################################
#                     ��Ƥ��Ƥ���IP���ɥ쥹�λ����礬                    #
#                 ����åɤ�Ω�Ƥ����Ƥ��ʤ����ɤ�����Ƚ��                #
###########################################################################
sub check_builder{

	# IP���ɥ쥹����
	my $ip_addr = $ENV{'REMOTE_ADDR'};     # ��Ƽ�IP_ADDR
	my $ip_host = std::gethost($ip_addr);  # ��Ƽ�IP_HOST

	# ������Ƥ����֥�å��ꥹ�Ȥ��ɤ߽Ф�
	my @builder;
	file::read_overbuilder(\@builder);

	# ����åɷ��Ƥ����֥�å��ꥹ�Ȥ˺ܤäƤ���Ȥ���
	# �����֤�
	foreach my $black(@builder){
		return 1 if ($black eq $ip_host);
		return 1 if ($black eq $ip_addr);
	}
	# �ܤäƤ��ʤ��Ȥ��ϵ����֤�
	return 0;
}

###########################################################################
#                Ϣ³��Ƥ���Ƥ���Τ��ɤ���������å�����               #
###########################################################################
sub check_chain_post{
	my $log = shift;

	return 0 if ($CONF{'CHAIN_POST'} == 0);  # Ϣ³��Ƥδƻ�򤷤ʤ�����FALSE���֤�

	my $ip_addr = $ENV{'REMOTE_ADDR'};       # ��Ƽ�IP_ADDR
	my $ip_host = std::gethost($ip_addr);    # ��Ƽ�IP_HOST

	my $count = 0;  # ��ʬ��IP���ɥ쥹���ɤΤ��餤�ФƤ������������
	for(my $i=@$log-1;$i>=0 and 
	                  $$log[$i]{'POST_TIME'} >=time() - $CONF{'CHAIN_TIME'} * 60 ;--$i){

		my $last_addr = @{$log[$i]{'IP_ADDR'}} - 1;
		my $last_host = @{$log[$i]{'IP_HOST'}} - 1;

		$count++ if ($ip_addr eq $$log[$i]{'IP_ADDR'}[$last_addr] or
		             $ip_host eq $$log[$i]{'IP_HOST'}[$last_host]
		             );

		return 1 if ($count >= $CONF{'CHAIN_POST'});   # Ķ�����饨�顼

	}

	return 0;
}

###########################################################################
#                     �����Ƥ���Ƥ��ʤ��������å�����                  #
###########################################################################
sub chack_dupe_post{
	my $log = shift;

	# �����������ʬ
	my $last = @$log - 1;
	my $name  = $$log[$last]{'USER_NAME'};
	my $title = $$log[$last]{'TITLE'};
	my $body  = $$log[$last]{'BODY'};
	my $res   = $$log[$last]{'RES'};

	# �����Ƥ��ɤ��������å�����
	for(my $i=std::math_max(0, $last-$CONF{'DUPE_BACK'}) ; $i<$last ; ++$i){

		my $dupe = 1;
		$dupe = 0 if ($name  ne $CONF{'NO_NAME'}  and $name  ne $$log[$i]{'USER_NAME'});
		$dupe = 0 if ($title ne $CONF{'NO_TITLE'} and $title ne $$log[$i]{'TITLE'});
		$dupe = 0 if ($body  ne $$log[$i]{'BODY'});
		$dupe = 0 if ($res   ne $$log[$i]{'RES'});
		return 1 if ($dupe);

	}
	return 0;
}


###########################################################################
#              �ݥ��󥿥ե�����ȥ��ե�����Υ�å���������           #
###########################################################################
sub clear{
	my $no = shift;
	file::unlock(file::pointer_name());
	file::clear($no);
}

###########################################################################
#                              ID�ֹ�����                                 #
###########################################################################
sub create_id{
	my $ip = shift;  # ID�����μ�(IP���ɥ쥹)

	my $id;
	my $seed = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ./';

	# ���դ�������
	my (undef, undef, undef, $day, $mon, $year, undef, undef, undef) = localtime();
	my $salt = substr($seed, $day, 1) . substr($seed, $mon, 1) . substr($seed, ($year % length($seed)) ,1);

	# ����
	return substr(std::scramble($ip, $salt), 0, $CONF{'ID_LENGTH'});
}

###########################################################################
#                              �ȥ�å�����                               #
###########################################################################
sub trip{
	return substr(std::scramble(shift, $CONF{'TRIP_KEY'}), 0, $CONF{'TRIP_OUTPUT_LENGTH'});
}



##########################################################################
#                        write.cgi ���顼��å�����                      #
##########################################################################

#
# ������CGI�ƤӽФ�
#
sub bad_request{
	error_head();
	print "<p>��������ˡ��write.cgi���ƤӽФ���ޤ�����</p>\n\n";
	error_foot();
}

#
# ������CGI������
#
sub illigal_form{
	error_head();
	my $no = shift;
	print "<p>���ͤȹ��פ��ʤ���ˡ�ǥǡ����������Ƥ��ޤ�����$no</p>\n\n";
	error_foot();
}

#
# ����åɺ����ػ�
#
sub cant_create_thread{
	error_head();
	my $no = shift;
	print "<p>���ߡ�����åɤκ����϶ػߤ���Ƥ��ޤ���$no</p>\n\n";
	error_foot();

}

#
# ����å�̾���񤫤�Ƥ��ʤ�
#
sub lack_thread{
	error_head();
	print "<p>����å�̾�����Ҥ���Ƥ��ޤ���</p>\n\n";
	error_foot();
}

#
# ��ʸ���񤫤�Ƥ��ʤ�
#
sub lack_body{
	error_head();
	print "<p>��̾����ʸ�Τɤ��餫�����򵭽Ҥ��ʤ���Фʤ�ޤ���</p>\n\n";
	error_foot();
}


#
# ����email���ɥ쥹������
#
sub illigal_email{
	error_head();
	print "<p>e-mail���ɥ쥹�������Ǥ���</p>\n\n";
	error_foot();
}

#
# ���ϥ��ɥ쥹(http, email)������
#
sub illigal_http{
	error_head();
	print "<p>webpage���ɥ쥹�������Ǥ���</p>\n\n";
	error_foot();
}


#
# ���ϥȥ�åפ�����
#
sub illigal_trip{
	error_head();
	print "<p>�ȥ�åפ�$CONF{'TRIP_INPUT_LENGTH'}ʸ���ޤǤαѿ��������Ѥ��Ƥ���������</p>\n\n";
	error_foot();
}


#
# �ѥ���ɤ�����
#
sub illigal_password{
	error_head();
	print "<p>�ѥ���ɤ�$writecgi::PASS_LENGTH_MINʸ���ʾ�$CONF{'PASSWORD_LENGTH'}ʸ���ʲ��αѿ��������Ѥ��Ƥ���������</p>\n\n";
	error_foot();
}


#
# �ѥ�����԰���
#
sub mismatch_password{
	error_head();
	print "<p>�ѥ���ɤ����פ��ޤ���</p>\n\n";
	error_foot();
}


#
# �����ɤ߽Ф��˼��Ԥ���
#
sub fail_read{
	error_head();
	print "<p>�����ɤ߹��ߤ˼��Ԥ��ޤ�����</p>\n\n";
	error_foot();
}


#
# ���ν񤭽Ф��˼��Ԥ���
#
sub fail_write{
	error_head();
	print "<p>���ι����˼��Ԥ��ޤ�����</p>\n\n";
	error_foot();
}


#
# ����åɤ���Ƥ����Ƥ���
#
sub over_thread{
	error_head();
	print "<p>����ʾ她��åɤ���Ƥ뤳�ȤϤǤ��ޤ���</p>\n\n";
	error_foot();
}


#
# ȯ���������
#
sub post_chain{
	error_head();
	print "<p>û���֤δ֤˽񤭹��ߤ����Ǥ������Ф餯�ԤäƤ�����Ƥ�ľ���Ƥ���������</p>\n\n";
	error_foot();
}


#
# ������
#
sub post_dupe{
	error_head();
	print "<p>�����Ƥ��Ԥ�줿�褦�Ǥ���</p>\n\n";
	error_foot();
}

#
# ȯ������Ķ��
#
sub post_huge{
	error_head();
	print "<p>��Ƥ��줿ȯ�����礭�����ޤ���</p>\n\n";
	error_foot();
}

#
# ����å�����Ķ��ʥХ��ȿ���
#
sub file_over{
	error_head();
	print "<p>���ʤ���ȯ�����Ѱդ��Ƥ���֤˥���åɤ����̸³���$CONF{'FILE_LIMIT'}�Х��ȡˤ�Ķ�����褦�Ǥ���";
	print "���̸³���Ķ�����Τ�ȯ���������򤹤뤳�ȤϤǤ��ޤ���</p>\n\n";
	error_foot();
}


#
# ����å�����Ķ�����ƿ���
#
sub thread_over{
	error_head();
	print "<p>���ʤ���ȯ�����Ѱդ��Ƥ���֤˥���åɤ���ƿ��³���$CONF{'THREAD_LIMIT'}�֤ޤǡˤ�Ķ�����褦�Ǥ���";
	print "��ƿ��³���Ķ�����Τ�ȯ���򤹤뤳�ȤϤǤ��ޤ���</p>\n\n";
	error_foot();
}


#
# ���Ǥ�ȯ�����������Ƥ���ʽ�����ȯ����
#
sub already_deleted{
	error_head();
	print "<p>���ʤ���ȯ�����Ѱդ��Ƥ���֤�ȯ�����������ޤ�����";
	print "���Ǥ˾ä���ȯ���ν���������ϤǤ��ޤ���</p>\n\n";
	error_foot();
}

#
# ���Ǥ�ȯ�����������Ƥ���ʥ쥹��
#
sub res_lost{
	error_head();
	print "<p>���ʤ���ȯ�����Ѱդ��Ƥ���֤˥쥹��ȯ�����������ޤ�����";
	print "���Ǥ˾ä���ȯ���ؤΥ쥹��ƤϤǤ��ޤ���</p>\n\n";
	error_foot();
}


#
# ȯ���������Ǥ��ʤ��Τ˽������褦�Ȥ���
#
sub no_change{
	error_head();
	print "<p>��ƼԤ�ȯ��������������뤳�Ȥϵ��Ĥ���Ƥ��ޤ���</p>\n\n";
	error_foot();
}


#
# ȯ���������¤�ۤ��Ƥ���
#
sub change_limit{
	error_head();
	print "<p>$CONF{'CHANGE_LIMIT'}���Ķ����ȯ���������뤳�ȤϤǤ��ޤ���</p>\n\n";
	error_foot();
}



#
# ���Ǥ˥���åɰ����Ϲ�������Ƥ���
#
sub already_build(){
	error_head();
	print "<p>���Ǥ˽��������Ƥ��ޤ���</p>\n\n";
	error_foot();
	exit;
}

#
# �����������åɰ����ι����˼��Ԥ���
#
sub fail_build{
	error_head();
	print "<p>������˼��Ԥ��ޤ�����</p>\n\n";
	error_foot();
	exit;
}



sub cant_encode_guess{
	error_head();
	print '<p>ʸ�������ɤ��Ѵ��˼��Ԥ��ޤ�����Ⱦ�ѥ��ʤʤ�ʸ�������ɤ�Ƚ�̤�';
	print '���𤵤���褦��ʸ�������Ϥ��ʤ��Ǥ����������ޤ�����ʸ���ä�Ĺ��';
	print "���Ϥ��ƤߤƤ���������</p>\n\n";
	error_foot();
	exit;
}


#
# ����¾�Υ��顼
#
sub other{
	error_head();
	print "<p>�Х���ޤ��������ߤޤ���</p>\n\n";
	error_foot();
}



#
# ���顼ɽ�����̽���
#
sub error_head{
	my $err_mes = 'write.cgi���顼ȯ��';
	html::http_response_header();
	html::header(*STDOUT, $err_mes);
	print "<div class='error'>\n\n";
	print "<h2>$err_mes</h2>\n\n";
}

sub error_foot{
	print "</div>\n\n";
	print "<div class='link'>";
	html::link_exit(*STDOUT);
	html::link_top(*STDOUT);
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::footer(*STDOUT);
	exit;
}





##########################################################################
#                              �ƥ������ΰ�                              #
##########################################################################

