#!/usr/bin/perl -w
#!c:/Perl/bin/Perl.exe
#
#
# �ޥ������åɷǼ��� - �񤭹��ߥ�����ץ�
#
#                                          2003.01.14 ����������
#
use strict;
use lib '/home/sarinaga/perllib/';
use CGI;
use Crypt::PasswdMD5;
BEGIN{
	use CGI::Carp qw(carpout);
	open(LOG, ">./error.log") or die "Unable to append to 'error.log': $!\n.";
	carpout(*LOG);
	print LOG "-admin.cgi-\n";
}
unless($ENV{'HTTP_HOST'}){
	print "���Υץ�����CGI�ѤǤ�. ���ޥ�ɥ饤�󤫤�μ¹ԤϤǤ��ޤ���. \n";
	exit;
}

require './html.pl';
require './std.pl';
require './file.pl';
require './write.pl';


#
# ���ޥ�ɤ�ʸˡ
#
# n - ñ�����
# N - ʣ������
# s - �ѿ���
# S - �ѿ���[�ѥ����]
#
use vars qw(%COMMAND_SYNTAX);
%COMMAND_SYNTAX =  (
                     'READ'       => 'nN' ,
                     'TREEREAD'   => 'nn' ,
                     'DEL'        => 'nN' ,
                     'TREEDEL'    => 'nn' ,
                     'UNDEL'      => 'nN' ,
                     'TOMATO'     => 'nN' ,
                     'UNTOMATO'   => 'nN' ,
                     'AGE'        => 'N'  ,
                     'DAT'        => 'N'  ,
                     'UNDAT'      => 'N'  ,
                     'HTML'       => 'N'  ,
                     'THREADLIST' => ''   ,
                     'REFRESH'    => ''   ,
                     'COMPRESS'   => ''   ,
                     'PASSWORD'   => 'SS' ,
                   );

#
# ���ޥ�ɽ������
#
use vars qw(%RESULT);
$RESULT{'OK'}      = '��';  # ���ｪλ
$RESULT{'PART'}    = '��';  # ��ʬ��λ
$RESULT{'BAD'}     = '��';  # �۾ｪλ
$RESULT{'INVALID'} = '��';  # ������ǽ
$RESULT{'IGNORE'}  = '��';  # ���ޥ��̵��

#
# �������ѥѥ���ɺǾ�Ĺ��
#
use vars qw($PASSWORD_LENGTH);
$PASSWORD_LENGTH = 8;




#--------------------------------------------------------------------------
#                              ư��Ķ����ɤ߹���
#--------------------------------------------------------------------------
# ����ե����ե������ɤ߹���
use vars qw(%CONF);
no_conf() unless(file::config_read(\%CONF));

#--------------------------------------------------------------------------
#                                 �ե��������
#--------------------------------------------------------------------------
#
# �����դ���CGI�ե�����μ�������Ƥϰʲ����̤�
#
# user    = ������ID
# pass    = �ѥ����
# command = ���ϥ��ޥ��
#

# ���̤��礭������Ȥ��ϥ��顼
post_huge() if ($ENV{'CONTENT_LENGTH'} > $CONF{'BUFFER_LIMIT'});

# �ե�����ǡ�������
my $cgi = new CGI;
my $userid   = $cgi->param('user');
my $password = $cgi->param('password');
my $command  = $cgi->param('command');
$command=~s/\x0D\x0A/\n/g;
$command=~tr/\x0D\x0A/\n\n/;

#--------------------------------------------------------------------------
#                              �ѥ���ɳ�ǧ
#--------------------------------------------------------------------------
# �ѥ���ɥե������ɤ߹���
use vars qw(%PASS);
my $password_command_flag = 0;    # �ѥ���ɥ��ޥ�ɤ����롩
if ($command=~m/password/i){      # �ѥ���ɥ��ޥ�ɤ�����Ȥ������ե�������å�
	no_password_file() unless(file::filelock(file::adminpass_name()));
	$password_command_flag = 1;
}
no_password_file() unless(file::read_adminpass(\%PASS));           # �ɤ߹���
invalid_call() unless($userid);
if ( !exists($PASS{$userid}) or $PASS{$userid} ne unix_md5_crypt($password, $PASS{$userid}) ){
	file::unlock(file::adminpass_name());
	unmatch_password();
}


#--------------------------------------------------------------------------
#                 ���ޥ���ɤ߼�ꡢ���ե������ɤ߹��ߡ�����
#--------------------------------------------------------------------------
my @command_lines = split(/\n/, $command);  # ���ޥ�ɹԤ��Ȥ�ʬ��
my @errors;                                 # ��̽��׳�Ǽ��
my $change_password_flag = 0;               # �ѥ�����ѹ���

foreach my $c_line(@command_lines){

	# ���ޥ�ɤ����
	my ($c, @p) = read_command($c_line);   # $c is command, @p is parameters.

	# ���ޥ�ɱ���
	my ($sub_phased_command, undef, undef) = split(/:/, $c_line, 3);
	$c_line = "$sub_phased_command:?????:?????" if (uc($sub_phased_command) eq 'PASSWORD');

	# 1���ޥ�ɷ�̳�Ǽ��
	my $error = $RESULT{'OK'};

	# ���ޥ�ɤˤ�������ʬ��
	# �������ޥ�ɤ��ʤ����������ʥ��ޥ�ɤλȤ����򤷤�
	if(!defined($c)){
		$error = $RESULT{'IGNORE'};

	# ȯ�����ɤ�@
	}elsif($c eq 'READ' or $c eq 'TREEREAD'){
		$error = display_command($c_line, $c, @p);

	# ȯ���κ���ѹ���@
	}elsif($c eq 'DEL' or $c eq 'TREEDEL' or $c eq 'UNDEL' or  $c eq 'TOMATO' or $c eq 'UNTOMATO' ) {
		$error = write_command($c, @p, $userid);

	# ����åɤ�age��@
	}elsif($c eq 'AGE'){
		$error = age($p[0]);

	# ȯ���ݴ���@
	}elsif($c eq 'DAT' or  $c eq 'UNDAT'){
		$error = dat($c, $p[0]);

	# �Ҹ�ȯ����HTML��
	}elsif($c eq 'HTML'){
		$error = html($p[0]);

	# ����åɰ���ɽ��@
	}elsif($c eq 'THREADLIST'){
		$error = thread_list($c_line);

	# ����åɷϽ��� @refresh  xcompress
	}elsif($c eq 'REFRESH' or $c eq 'COMPRESS'){
		$error = thread_command($c);

	# �ѥ�����ѹ�@
	# �����ľ�ܽ���
	}elsif($c eq 'PASSWORD'){
		if ($p[0] ne $p[1]){
			$error = $RESULT{'INVALID'};
		}else{
			$change_password_flag = 1;
			$PASS{$userid} = unix_md5_crypt($p[0], std::salt());
			$error = $RESULT{'OK'};
		}
	}

	# ��̤��Ǽ
	push(@errors, "$error - $c_line");

}



#--------------------------------------------------------------------------
#                                    ����
#--------------------------------------------------------------------------

# http-responce-header��HTML�إå�����
html::http_response_header();
html::header(*STDOUT , '�������ޥ�ɼ¹�');

# �ѥ���ɥե��������
if ($change_password_flag){
	unless(file::write_adminpass(\%PASS)){
		foreach my $error(@errors){
			my ($result, $cline) = split(/ - /, $error, 2);
			$error = "$RESULT{'BAD'} - $cline" if ($cline=~m/^password/i);
		}
	}

}else{
	file::unlock(file::adminpass_name()) if ($password_command_flag);
}

# ��̽��ϡ����ݤ�ɽ����
print "<h2>���ޥ�ɽ������</h2>\n";
print "<div class='command'>\n";
foreach my $line(@errors){
	print "$line<br />\n";
}
print "</div>\n\n";
print "<p>���ޥ�ɽ�������λ���ޤ�����</p>\n";


# ��̽��ϡ�ɽ���ϥ��ޥ�ɤ��������
my $tempfile = temp_filename();
if (open(FIN, $tempfile)) {
	print "<p>�ʲ��ϥǡ���ɽ���ϥ��ޥ�ɤη�̤Ǥ���</p>\n\n";
	print "<div class='result'>\n";
	until(eof(FIN)){
		my $line = <FIN>;
		print "$line";
	}
	print "</div>\n\n";
	close(FIN);
	unlink($tempfile);

}


# ��󥯥С�ɽ����HTML�ν�λ
print "<div class='link'>";
html::link_top(*STDOUT);
html::link_adminmode(*STDOUT);
html::link_adminmail(*STDOUT);
print "</div>\n\n";
html::footer(*STDOUT);
exit;


###########################################################################
#                            �ɤ߼��ɽ���ϥ��ޥ��                       #
###########################################################################
sub display_command{

	# �����������(���������ޥ�ɥ饤�󡢥��ޥ�ɼ��ࡢ����å��ֹ桢ȯ���ֹ�)
	my ($purecommand, $command, $no, $num) = @_;

	# ���ɤ߼�� / �����å����ɤ�
	my @log;
	return $RESULT{'BAD'} unless(file::read_log($no, \@log, 1, 0, 1));

	# �ɤ߹���ȯ���ΰ�������
	my @nums;
	if ($command eq 'READ'){
		@nums = read_number($num, @log-1);
	}elsif ($command eq 'TREEREAD'){
		@nums = html::search_thread(\@log, $num, $num);
		foreach my $num(@nums){
			($num, undef) = split(/:/, $num, 2);
		}
	}

	# �ѥ�᡼��������
	my %param;
	$param{'st'} = 0;
	$param{'en'} = @log - 1;
	$param{'no'} = $no;
	$param{'mode'} = $html::ADMIN;

	# �ƥ�ݥ��ե�����򳫤��ơ������˥���񤭹���
	my $filename = temp_filename();
	unless (open(FOUT, ">>$filename")) {
		open(FOUT, ">$filename") or return $RESULT{'BAD'};
	}
	print FOUT "<div class='commandline'>$purecommand</div>\n";
	print FOUT "<dl class='message'>\n\n";
	foreach my $i(@nums){
		html::mes_one(*FOUT, $i, \@log, \%param);
	}
	print FOUT "</dl>\n\n";
	close(FOUT);

	# ���ｪλ
	return $RESULT{'OK'};
}


###########################################################################
#                              �񤭹��߷ϥ��ޥ��                         #
###########################################################################
sub write_command{
	my ($c, $no, $num, $admin) = @_;   # $c is command, $no is therad number, $num is post number.

	# �����ɤ߼��
	my @log;
	return $RESULT{'BAD'} unless(file::read_log($no, \@log, 1, 1, 0));  # ��å���³���ɤ�

	# ������Ԥ�ȯ����ԥå�������
	my @nums;
	if ($c eq 'DEL' or $c eq 'UNDEL' or 
		$c eq 'TOMATO' or $c eq 'UNTOMATO'){
		@nums = read_number($num, @log-1);

	}elsif ($c eq 'TREEDEL'){
		@nums = html::search_thread(\@log, $num, $num);
		foreach my $part(@nums){
			($part, undef) = split(/:/, $part, 2);
		}
	}

	# �ǡ������/�������
	foreach my $n(@nums){   # $n is processing post number.

		next if ($n>= @log);      # ���ϰϳ��ξ��Ͻ������ʤ�

		if ($c eq 'DEL' or $c eq 'TREEDEL'){
			$log[$n]{'DELETE_TIME'}  = time();
			$log[$n]{'DELETE_ADMIN'} = $admin;

		}elsif ($c eq 'UNDEL'){
			$log[$n]{'DELETE_TIME'}  = undef;
			$log[$n]{'DELETE_ADMIN'} = undef;

		}elsif($c eq 'TOMATO'){
			$log[$n]{'TOMATO'}  = 1;

		}elsif($c eq 'UNTOMATO'){
			$log[$n]{'TOMATO'}  = 0;

		}
	}

	# ȯ������
	return file::write_log(\@log) ? $RESULT{'OK'} : $RESULT{'BAD'};

}


###########################################################################
#                              ����åɤ�age��                            #
###########################################################################
sub age{
	# �������
	my $thread = shift;                              # �ѥ�᡼�����ɤ߹���
	my $pointer = file::read_pointer(0);             # �ݥ������ɤ߹���
	return $RESULT{'BAD'} if (!defined($pointer));   # �ݥ����Ͱ۾�
	my @threads = read_number($thread, $pointer-1);  # ���Ͳ��ϡ���:$pointer��-1����Τ�
	                                                 # ���Υݥ��󥿤�ؤ��Ƥ��뤫���
	# age����
	my $c=0; # $c�Ͻ����Ǥ�������åɤο�
	foreach my $no(@threads){
		my @log;
		next unless(file::read_log($no, \@log, 1, 1, 0));  # ��å���³���ɤ�
		$log[0]{'AGE_TIME'} = time();
		unless (file::write_log(\@log)){  clear($no) ;  }
		else { ++$c;  }
	}

	# ����ֵ�
	if (!$c){
		return $RESULT{'BAD'};
	}elsif ($c == scalar @threads){
		return $RESULT{'OK'};
	}
	return $RESULT{'PART'};
}


##########################################################################
#                            ����å���¸���                             #
##########################################################################
sub dat{
	my ($c, $p) = @_;
	my $pointer = file::read_pointer(0);
	return $RESULT{'BAD'} if (!defined($pointer));
	my @thread = read_number($p, $pointer-1);

	my $i = 0; # $i�Ͻ����Ǥ�������åɤο�
	foreach my $no(@thread){
		if ($c eq 'DAT')      {  ++$i if (file::gzip($no));  }
		elsif ($c eq 'UNDAT') {  ++$i if (file::gunzip_only($no));  }
		else{  next;  }
	}

	if (!$i){
		return $RESULT{'BAD'};
	}elsif($i == scalar @thread){
		return $RESULT{'OK'};
	}
	return $RESULT{'PART'};

}


##########################################################################
#                              HTML����¸���                             #
##########################################################################
sub html{
	my $no = shift;

	my $pointer = file::read_pointer(0);
	return $RESULT{'BAD'} if (!defined($pointer));
	my @thread = read_number($no, $pointer-1);

	my $c = 0;  # $c is count.
	foreach $no(@thread){

		my $filename = file::public_name($no) . ".$file::EXT_GZIP";
		next unless (-f $filename);     # dat�����ʤ����ϼ��Υ���åɤ�

		my @log;
		next unless(file::read_log($no, \@log, 1, 1, 1));
		                                # �����ɤ�ʤ����ϼ��Υ���åɤ�

		my $htmlfile = file::html_name($no);
		#next if (-f $htmlfile);
		open(FOUT, ">$htmlfile") or next;  # �����ϥե�����

		html::header(*FOUT, "$log[0]{'THREAD_TITLE'} - ����ɽ��", 0, undef, undef, 1);

		# ��󥯥С�1
		print FOUT '<div class="link">';
		html::link_top(*FOUT);
		html::link_exit(*FOUT);
		html::link_adminmail(*FOUT);
		print FOUT "</div>\n\n";

		print FOUT "<h2 id='subtitle'>$log[0]{'THREAD_TITLE'}</h2>\n\n";

		my %param;
		$param{'st'}   = 0;
		$param{'en'}   = scalar @log - 1;
		$param{'no'}   = $no;
		$param{'mode'} = $html::HTML;
		html::multi(*FOUT, \@log, \%param);

		# ��󥯥С�2
		print FOUT '<div class="link">';
		html::link_top(*FOUT);
		html::link_exit(*FOUT);
		html::link_adminmail(*FOUT);
		print FOUT "</div>\n\n";

		html::footer(*FOUT);

		close(FOUT);
		#unlink($filename);	# html���������ե�����Ϻ������
		file::clear($no);
		++$c;
	}

	# ��̤��֤�
	if (!$c){
		return $RESULT{'BAD'};
	}elsif($c < scalar @thread){
		return $RESULT{'PART'};
	}else{
		return $RESULT{'OK'};
	}

}



###########################################################################
#                              ����åɰ���ɽ��                           #
###########################################################################
sub thread_list{
	my $c_line = shift;

	# ����åɰ����ɤ߹���
	my @thread;
	return $RESULT{'BAD'} unless (file::thread_read(\@thread, 1) );

	# ����åɰ�������
	my $filename = temp_filename();
	unless (open(FOUT, ">>$filename")) {
		open(FOUT, ">$filename") or return $RESULT{'BAD'};
	}
	print FOUT "<div class='commandline'>$c_line</div>\n";

	# ����åɰ���ɽ��
	for(;;){

		# ����åɤ��ʤ����
		unless (scalar @thread > 0){
			print FOUT "<p>����åɤ�¸�ߤ��ޤ���</p>\n\n";
			last;
		}

		# ����åɤ�������
		print FOUT "<table class='thread-list'><tbody>\n\n";
		foreach my $t(@thread){
			print FOUT '<tr><td class="no">';
			print FOUT "$$t{'THREAD_NO'}.";
			print FOUT '</td><td class="thread-admin">';
			print FOUT "$$t{'THREAD_TITLE'}($$t{'POST'})";
			print FOUT " [DAT����]" if ($$t{'DAT'});
			print FOUT '</td><td class="date">';
			print FOUT std::time_format($$t{'AGE_TIME'});
			print FOUT '</td><td class="ip_addr">';
			print FOUT "$$t{'BUILDER_IP_HOST'}, $$t{'BUILDER_IP_ADDR'}</td>";
			print FOUT "</tr>\n";
		}
		print FOUT "</tbody></table>\n\n";
		last;
	}
	close(FOUT);

	# ���ｪλ
	return $RESULT{'OK'};
}


##########################################################################
#                          ����å����ϥ��ޥ��                        #
##########################################################################
sub thread_command{
	my $command = shift;

	# ����åɰ����ɤ߹���
	my @thread;
	return 0 unless (file::thread_read(\@thread));

	# �Ƽ����
	my $flag;
	if ($command eq 'REFRESH'){
		$flag  = file::create_bbshtml(\@thread);
		$flag |= file::create_adminpage();
	}elsif($command eq 'COMPRESS'){
		$flag = file::compress(\@thread, 1);
	}
	return $flag ? $RESULT{'OK'} : $RESULT{'BAD'};

}






###########################################################################
#                          �ƥ�ݥ��ե�����̾����                       #
###########################################################################
sub temp_filename{
	return "$CONF{'TEMP_DIR'}temp.$$";
}


###########################################################################
#                              ���ϥ��ޥ�ɲ���                           #
###########################################################################
sub read_command{
	my $str = shift;
	my @parameters = split(/:/, $str);
	foreach my $parameter(@parameters){
		$parameter =~s/^\s*//;
		$parameter =~s/\s*$//;
	}

	my $command;
	($command, @parameters) = @parameters;               # ���ֺǽ�ϥ��ޥ��
	$command = uc($command);                             # ���ޥ�ɤ���ʸ����ʸ������

	return () unless(exists($COMMAND_SYNTAX{$command})); # �ºߤ��ʤ����ޥ�ɤ��񤫤줿
	my $syntax = $COMMAND_SYNTAX{$command};
	return () if (length($syntax) != @parameters);       # ʸˡ����äƤ��ʤ�

	for(my $i=0;$i<@parameters;++$i){

		my $s = substr($syntax, $i, 1);   # s is 'Syntax letter'
		if ($s eq 'n'){
			return () unless($parameters[$i] =~m/^\d+$/);

		}elsif ($s eq 'N'){
			return () unless($parameters[$i]=~m/[\d,-]+/);

		}elsif ($s eq 's'){
			return () unless($parameters[$i]=~m/^[A-Za-z\d]+$/);

		}elsif ($s eq 'S'){
			return () unless($parameters[$i]=~m/^[A-Za-z\d]+$/);
			return () if (length($parameters[$i]) < $PASSWORD_LENGTH);
		}
	}

	return ($command, @parameters);

}




###########################################################################
#                            ʣ�������ֹ���ɤ߹���                       #
###########################################################################
sub read_number{
	my $str = shift;
	my $last = shift;

	$str =~s/[^0-9,\-\s]//g;             # ������ʸ�����ɤ����Ф��Ƥ��ޤ�
	my @parts = split(/,/ , $str);

	my @nums = ();
	foreach my $part(@parts){

		my ($st, $en) = split(/-/, $part, 2);

		next unless(defined($st));  # null�ξ��

		$st = 0 if ($st eq '');

		unless(defined($en)){       # ����1�Ĥ������ꤷ�����
			$en = $st;
		}else{
			if ($en eq ''){     # �ϥ��ե���ꤵ�줿���
				if (defined($last)){
					$en = $last;
				}else{
					next;
				}
			}
		}
		($st, $en) = ($en, $st) if ($st > $en);
		push (@nums, $st..$en);

	}

	my %seen;                            # ��ʣ����ǡ�������
	@nums = grep { !$seen{$_} ++} @nums;
	@nums = sort {$a <=> $b} @nums;      # ����
	return @nums;
}



###########################################################################
#                           ���顼ɽ�����̽���                            #
###########################################################################
sub error_head{
	my $err_mes = 'admin.cgi���顼ȯ��';
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


###########################################################################
#                               ���顼ɽ��                                #
###########################################################################

#
# ��Ƥ��礭������
#
sub post_huge{
	error_head();
	print "<p>���ޥ�ɤ�¹Ԥ��������Ǥ���</p>\n\n";
	error_foot();
	exit;

}

#
# ������CGI�ƤӽФ�
#
sub invalid_call{
	error_head();
	print "<p>�����ʸƤӽФ��Ǥ���</p>\n\n";
	error_foot();
	exit;

}



#
# �ѥ�����԰���
#
sub unmatch_password{
	error_head();
	print "<p>�ѥ���ɤ����פ��ޤ��󡣤⤦���٤��ľ���Ƥ���������</p>\n\n";
	error_foot();
	exit;

}


#
# ����ե����ե����뤬���ɤ߼��ʤ�
#
sub no_conf{
	error_head();
	print "<p>����ե����ե����뤬�ɤ߼��ʤ������ޤ��������Ǥ���</p>\n\n";
	error_foot();
	exit;
}


#
# �ѥ���ɥե����뤬�ɤ߼��ʤ�
#
sub no_password_file{
	error_head();
	print "<p>�ѥ���ɥե����뤬�ɤ߼��ʤ������ޤ��������Ǥ���</p>\n\n";
	error_foot();
	exit;
}














