#!/usr/bin/perl -w
#!C:/Perl/bin/perl -w
#
#
# �ޥ������åɷǼ��� - ȯ��ɽ��������ץ� read.cgi
#
#                                          2002.10.23 ����������
#
use strict;
use lib '/home/sarinaga/perllib/';
use CGI;
require './html.pl';
require './file.pl';
require './std.pl';
require './write.pl';

BEGIN{
	if ($ENV{'HTTP_HOST'}){
		use CGI::Carp qw(carpout);
		open(LOG, ">./error.log") or die "Unable to append to 'error.log': $!\n.";
		carpout(*LOG);
		print LOG "-read.cgi-\n";
	}
}
unless($ENV{'HTTP_HOST'}){
	print "���Υץ�����CGI�ѤǤ�. ���ޥ�ɥ饤�󤫤�μ¹ԤϤǤ��ޤ���. \n";
	exit;
}

# ư��Ķ��ɤ߼��
use vars qw(%CONF);
error_fail_conf() unless(file::config_read(\%CONF));

# CGI���饹����
my $cgi = new CGI;

# �ꥯ�����Ȥ�GET�Ǥʤ���Фʤ�ʤ�
bad_request()  if ($ENV{'REQUEST_METHOD'} ne 'GET');

# �ѥ�᡼���������Ǥʤ����Ͻ�������Location�����Ф�
my $reg_query = regularization($ENV{'QUERY_STRING'}, \$cgi);
location($reg_query) if ($ENV{'QUERY_STRING'} ne $reg_query);


#
# �ѥ�᡼�����ɤ߼�ꡢ�ǡ��������������������
#
#
# �����դ���CGI�ե�����μ�������Ƥϰʲ����̤�
#
# no       = ����å��ֹ�
#
# st       = �ɤ߼�곫�ϡʾ�ά����0��
# en       = �ɤ߼�꽪λ�ʾ�ά���ϺǸ�ޤǡ�
# at       = ñ��ȯ��ɽ��
# ls       = �ǿ���ȯ��*��ɽ��
#
# mes      = ȯ����ʸ��ɽ�����뤫���ʤ����ʾ�ά����1��
# sub      = ȯ�������ȥ������ɽ�����뤫���ʤ����ʾ�ά����0��
#
# tree     = �ĥ꡼������å�ɽ��������ȯ��ɽ��
#
# res      = ȯ���쥹��ƥե�����ɽ��
# del      = ȯ�������ǧ�ե�����ɽ��
# rev      = ȯ��������ǧ�ե�����ɽ��
#
my $no  = $cgi->param('no');
error_illigal_call() unless($no =~m/^(\d+)$/);  # ����
$no = $1;


# ư��Ķ��ɤ߼�����Ⱦ�������ɤ߼��ʤ��Ƥ�Ƚ�ǤǤ�����ʬ��
my %param;
$param{'no'}   = $no;
$param{'mode'} = 0;

# �ǡ�����̷�⤷�Ƥ��ʤ��������å�����(at, res, rev)
my $double_flag = 0;   # ��ʣ���Ϥ���Ƥ��ʤ����ɤ������ǧ����ե饰�ʷ빽���ȤޤǻȤ��Τ���ա�
foreach my $key('at', 'res', 'rev'){
	my $num = $cgi->param($key);
	if (defined($num)){

		error_illigal_call() unless($num=~m/^\d+$/); # ���������äƤ��ʤ������������
		error_illigal_call() if($double_flag);       # ��ʣ���Ƥ����������

		$double_flag    = 1;
		$param{'st'}    = $num;
		$param{'en'}    = $num;

		if($key eq 'at'){
			$param{'mode'} |= $html::ATONE;  # ñ��ȯ��ɽ��

		}elsif($key eq 'res'){
			$param{'mode'} |= $html::RES;    # �쥹�դ�ɽ��

		}elsif($key eq 'rev'){
			$param{'mode'} |= $html::REV;    # ȯ������ɽ��
		}
	}
}

# �ѥ�᡼��������ʣ���Ƥ���������(st, en, at, res, rev)
my $st = $cgi->param('st');
my $en = $cgi->param('en');
my $ls = $cgi->param('ls');
error_illigal_call() if((defined($st) or defined($en) or defined($ls)) and $double_flag);

# �ͤ����ͤǤʤ���Х��顼(st, en, at)
error_illigal_call() if (defined($st) and $st!~m/^\d+$/);
error_illigal_call() if (defined($en) and $en!~m/^\d+$/);
error_illigal_call() if (defined($ls) and $ls!~m/^\d+$/);

# �������Ѵ�(tree, mes, sub)
$param{'mode'} |= $html::TREE    if (std::trans_bool($cgi->param('tree'), 0));
$param{'mode'} |= $html::MESSAGE if (std::trans_bool($cgi->param('mes'), 1));
$param{'mode'} |= $html::TITLE   if (std::trans_bool($cgi->param('sub'), 0));

# ȯ���ȥ����ȥ��ξ��ɽ�����ʤ��Ȥ������ȤϤʤ�
error_complex() if ( $param{'mode'} & $html::TREE & $html::MESSAGE == 0);

# �ѥ�᡼����̷�⤷�Ƥ���������(at, res, rev, tree, mes, sub)
if ($param{'mode'} & $html::ATONE or 
    $param{'mode'} & $html::RES   or 
    $param{'mode'} & $html::REV      ){
	error_complex() if (defined($cgi->param('tree'))  or 
	                    defined($cgi->param('mes'))   or 
	                    defined($cgi->param('sub'))      );
}



# �����ɤ߼��
my @log;
error_fail_read($no) unless(file::read_log($no, \@log, 1, 0, 0));  # ���٤Ƥξ���򡢥�å��򤫤��ʤ��ǡ�gz���̤���Ƥ��������ɤޤʤ�

# ư��Ķ��ɤ߼��ʸ�Ⱦ�������ɤ߼��ʤ��ȵ��ҤǤ��ʤ�����
unless($double_flag){

	if(defined($st)){  $param{'st'} = $st;  }
	else{  $param{'st'} = 0;  }

	if (defined($en)){  $param{'en'} = $en;  }
	else{  $param{'en'} = @log - 1;  }

	if(defined($ls)){
		$param{'en'} = @log - 1;
		$param{'st'} = @log - $ls;
	}

}

($param{'st'}, $param{'en'})=($param{'en'}, $param{'st'}) if($param{'st'} > $param{'en'});
$param{'st'} = 0     if($param{'st'} < 0);
$param{'en'} = $#log if($#log < $param{'en'});

$param{'mode'} |= $html::NO_REVISE if ($log[0]{'SIZE'} >= $CONF{'FILE_LIMIT'});   # ����Ķ��
$param{'mode'} |= $html::COMPLETE  if ($log[0]{'POST'} >= $CONF{'THREAD_LIMIT'}); # ȯ����Ķ��


#
# HTMLɽ��
#
html::http_response_header();
if($cgi->param('at') ne ''){
	at(\@log, \%param);

}elsif($cgi->param('res') ne ''){
	res(\@log, \%param);

}elsif($cgi->param('rev') ne ''){
	rev(\@log, \%param);

}else{
	mes(\@log, \%param);
}

#
# ��󥯥С�ɽ��
#
html::link_3set_close(*STDOUT, $no);
html::hr(*STDOUT);

# �եå�ɽ��
html::footer(*STDOUT);

exit;




##########################################################################
#                               ñ��ȯ��ɽ��                             #
##########################################################################
sub at{
	my $log   = shift;  # �ʻ��ȡ˥�
	my $param = shift;  # �ʻ��ȡ�ȯ��ɽ����

	my $no    = $$log[0]{'THREAD_NO'};
	my $title = $$log[0]{'THREAD_TITLE'};
	my $at    = $$param{'st'};

	# �إå�
	html::header(*STDOUT, "$$log[0]{'THREAD_TITLE'} - ñȯ��ɽ��");

	# ��Ƭ����ʸ
	print "<h2 id='subtitle'>$$log[0]{'THREAD_TITLE'}</h2>\n\n";
	notice($$log[0]{'SIZE'}, $log[0]{'POST'});
	html::hr(*STDOUT);

	# ȯ����ʬ
	print "<div class='message'>";
	print "<h3 id='message'>ȯ��ɽ��</h3>\n\n";
	html::multi(*STDOUT, $log, $param);
	print "</div>\n\n";

	# ��󥯥С�
	html::link_3set_close(*STDOUT, $no);
	html::hr(*STDOUT);

	# ��Ϣ�ĥ꡼
	print "<div class='subject'>\n\n";
	print "<h3 id='tree'>��Ϣ�ĥ꡼ɽ��</h3>\n\n";

	my $flag_have_response=0;  # ��Ϣ�ĥ꡼�����ä����Ϥ����ͤϿ�
	for(my $i=$at+1;$i<@$log;$i++){
		$flag_have_response=1 if (defined($$log[$i]{'RES'}) and $$log[$i]{'RES'}==$at);
	}
	$flag_have_response=1 if (defined($$log[$at]{'RES'}));

	if ($flag_have_response){
		html::tree(*STDOUT, $log, $param);
	}else{
		print "<p>����ȯ���˴�Ϣ����ȯ���Ϥ���ޤ���</p>\n\n";
	}
	print "</div>\n\n";

}

##########################################################################
#                           �쥹ȯ���ե�����ɽ��                         #
##########################################################################
sub res{
	my $log   = shift;  # �ʻ��ȡ˥�
	my $param = shift;  # �ʻ��ȡ�ȯ��ɽ����

	my $target = $$param{'st'};
	my $thread = $$log[0]{'THREAD_TITLE'};

	html::header(*STDOUT, "$thread - �쥹ȯ���ե�����");
	print "<h2 id='subtitle'>$thread</h2>\n\n";
	html::hr(*STDOUT);

	# ����
	print << "HTML";
<div class='howto'>

<h3 id='howto'>�쥹���</h3>

<p>����å�̾��$thread��(����å��ֹ�$no)��ȯ��$target�֤ؤΥ쥹��ƥե������ɽ�����Ƥ��ޤ�(��<a href='./bbs.html'>�ܤ�������</a>)��</p>

</div>

HTML


	# ��󥯥С�
	html::link_3set(*STDOUT, $no);
	print "<a href='#post'>�쥹���</a>��";
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# ȯ��ɽ��
	print "<div class='message'>\n\n";
	print "<h3 id='message'>ȯ��ɽ��</h3>\n\n";
	html::multi(*STDOUT, $log, $param);
	print "</div>\n\n";

	# ��󥯥С�
	html::link_3set_close(*STDOUT, $no);
	html::hr(*STDOUT);

	# �쥹ȯ���ե�����
	form_new($log, $target);

}



##########################################################################
#                           ȯ�������ե�����ɽ��                         #
##########################################################################
sub rev{
	my $log   = shift;  # �ʻ��ȡ˥�
	my $param = shift;  # �ʻ��ȡ�ȯ��ɽ����

	my $no     = $$log[0]{'THREAD_NO'};
	my $thread = $$log[0]{'THREAD_TITLE'};
	my $target = $$param{'st'};

	# �إå�������ʸ
	html::header(*STDOUT, "$thread - ����������ѥե�����");

	print "<h2 id='subtitle'>$thread</h2>\n\n";
	html::hr(*STDOUT);
	print << "HTML";
<div class='howto'>

<h3 id='howto'>ȯ���κ��������</h3>

<p>���Υե����फ��<em class="thread">����å�̾��$thread��(����å��ֹ�$no��)��$target��ȯ��</em>�ν�����������Ǥ��ޤ���ȯ�������������Ԥ��ˤ���ƻ��˻��ꤷ���ѥ���ɤ�ɬ�פǤ���</p>

<p>�ѥ���ɤ�˺��Ƥ��ޤä�ȯ���κ�������ȯ���κ�����ä��Ƥ��ޤä�ȯ�������褵���������ʤɤ�<a href="mailto:$CONF{'ADMIN_MAIL'}">������</a>�ˤ�Ϣ����������</p>

<p>�����ԤϿͤ�ȯ���򾡼�˽������뤳�ȤϤǤ��ޤ��󡣤������äƥѥ���ɤ�˺���Ȥ�����Ƥ�ï�ˤ⽤���Ǥ��ʤ��ʤ�ޤ�(�����Ԥ��ä����ȤϤǤ��ޤ�)��</p>

</div>

HTML

	html::hr(*STDOUT);

	# ��󥯥С�
	html::link_3set(*STDOUT, $no);
	print '<a href="#revise">ȯ������</a>��';
	print '<a href="#delete">ȯ�����</a>��';
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# ȯ��ɽ��
	print "<div class='message'>\n\n";
	print "<h3 id='message'>ȯ��ɽ��</h3>\n\n";
	html::multi(*STDOUT, $log, $param);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# ��󥯥С�
	html::link_3set(*STDOUT, $no);
	print "<a href='#delete'>ȯ�����</a>��";
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# ȯ�������ե�����
	form_rev($log, $target);
	html::hr(*STDOUT);

	# ��󥯥С�
	html::link_3set_close(*STDOUT, $no);
	html::hr(*STDOUT);

	# ����ѥե�����
	form_del($log, $target);
	html::hr(*STDOUT);

}

##########################################################################
#                                 ȯ��ɽ��                               #
##########################################################################
sub mes{
	my $log   = shift;  # �ʻ��ȡ˥�
	my $param = shift;  # �ʻ��ȡ�ȯ��ɽ����

	my $no     = $$log[0]{'THREAD_NO'};
	my $thread = $$log[0]{'THREAD_TITLE'};
	my $mode   = $$param{'mode'};

	# ��Ƭ��ʬ
	my $head;
	if (($mode & $html::TITLE) != 0){
		if (($mode & $html::MESSAGE) != 0){
			$head = '��̾ȯ��ɽ��';
		}else{
			$head = '��̾ɽ��';
		}
	}else{
		$head = 'ȯ��ɽ��';
	}
	html::header(*STDOUT, "$thread - $head");

	# ����å�̾ɽ��
	print "<h2 id='subtitle'>$$log[0]{'THREAD_TITLE'}</h2>\n\n";

	# ȯ���ɤ߹��ߥե�����ɽ��
	html::form_read(*STDOUT, $no, $#log);

	# ȯ�����̷ٹ�ɽ��
	notice($$log[0]{'SIZE'}, $$log[0]{'POST'});

	# 0��ȯ��ɽ��
	if ($$param{'st'} > 0 and ($$param{'mode'} & $html::TITLE) != 0){
		my %sub_param;
		$sub_param{'st'} = 0;
		$sub_param{'en'} = 0;
		$sub_param{'no'} = $param{'no'};
		$sub_param{'mode'} = 0;
		html::multi(*STDOUT, $log, \%sub_param);
	}

	# ��󥯥С�
	print '<div class="link">';
	html::link_top(*STDOUT);
	print '<a href="#message">ȯ��ɽ��</a>��' if(($mode & $html::TITLE) != 0 and ($mode & $html::MESSAGE) != 0);
	print '<a href="#newpost">�������</a>��';
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# ��̾ɽ��
	if (($mode & $html::TITLE) != 0){
		print "<div class='subject'>\n\n";
		print "<h3 id='subject'>��̾ɽ��</h3>\n\n";
		if (($mode & $html::TREE) != 0){
			html::tree(*STDOUT, $log, $param)
		}else{
			html::list(*STDOUT, $log, $param) 
		}
		print "</div>\n\n";
	}

	# ��󥯥С�
	if(($mode & $html::MESSAGE) != 0 and ($mode & $html::TITLE) != 0){
		html::link_3set(*STDOUT, $no);
		print "<a href='#newpost'>�������</a>��";
		html::link_adminmail(*STDOUT);
		print "</div>\n\n";
		html::hr(*STDOUT);
	}

	# ȯ��ɽ��
	if (($mode & $html::MESSAGE) != 0){
		print "<div class='message'>\n\n";
		print "<h3 id='message'>ȯ��ɽ��</h3>\n\n";
		if (($mode & $html::TREE) != 0){
			html::comment(*STDOUT, $log, $param);
		}else{
			html::multi(*STDOUT, $log, $param);
		}
		print "</div>\n\n";
	}

	# ��󥯥С�
	html::link_3set_close(*STDOUT, $no);
	html::hr(*STDOUT);

	# �������
	form_new($log);
	html::hr(*STDOUT);

}

#
# ȯ����Ķ��ٹ�ɽ��
#
sub notice{
	my $amount = shift;  # ����åɤ��礭��
	my $post = shift;    # ��ƿ�

	# ����å����¤˰��ä�����ʤ����ϲ���ɽ�����ʤ�
	return if ($amount < $CONF{'FILE_CAUTION'} and $post < $CONF{'THREAD_CAUTION'});

	# ����åɤ��礭����KBñ�̤ˤ���
	my $kb    = int($amount / 1000);
	my $limit = int($CONF{'FILE_LIMIT'} / 1000);

	# �ٹ����ɽ���򤹤�
	print "<div class='notice'>\n\n";

	# ��¤�ã�������Υ�å�����
	my $already_display = 0;
	if($amount >= $CONF{'FILE_LIMIT'}){
		print "<p class='warning'>����åɤ����̤����($limit" . "KB)��ã���ޤ���������ʾ���ơ������ϤǤ��ޤ���</p>\n\n";
		$already_display = 1;
	}
	if($post >= $CONF{'THREAD_LIMIT'}){
		print "<p class='warning'>����åɤؤ���ƿ������($CONF{'THREAD_LIMIT'}ȯ��)��ã���ޤ���������ʾ���ƤǤ��ޤ���</p>\n\n";
		$already_display = 1;
	}
	if($already_display){
		print "</div>\n\n";
		return;
	}

	# �ٹ�ɽ���ʥե������������¡�
	if($amount >= $CONF{'FILE_WARNING'}){
		print '<p class="warning">';
	}elsif($amount >= $CONF{'FILE_CAUTION'}){
		print '<p class="caution">';
	}
	if ($amount >= $CONF{'FILE_CAUTION'}){
		print "����åɤ����̤�$kb" . "KB��Ķ���Ƥ��ޤ���$limit" . "KB��Ķ�������ơ�����������ʤ��ʤ�ޤ���</p>\n\n";
	}

	# �ٹ�ɽ������������¡�
	if($post >= $CONF{'THREAD_WARNING'}){
		print "<p class='warning'>����åɤؤ���ƿ���$CONF{'THREAD_WARNING'}";
	}elsif($post >= $CONF{'THREAD_CAUTION'}){
		print "<p class='caution'>����åɤؤ���ƿ���$CONF{'THREAD_CAUTION'}";
	}
	if($post >= $CONF{'THREAD_CAUTION'}){
		print "ȯ����Ķ���Ƥ��ޤ���$CONF{'THREAD_LIMIT'}ȯ����Ķ�������Ƥ�����ʤ��ʤ�ޤ���</p>\n\n";
	}
	print "</div>\n\n";

}



##########################################################################
#                           ������ƥե�����ɽ��                         #
##########################################################################
sub form_new{
	my $log = shift;  # [����]���ǡ���
	my $res = shift;  #�ʥ쥹ȯ���λ��˥쥹�ֹ�

	my $no = $$log[0]{'THREAD_NO'};

	my $message;
	my $title = '';
	my $body  = '';

	if(defined($res)){
		$message = '�쥹ȯ�����';
		$title = response($$log[$res]{'TITLE'});
		$body  = quote($$log[$res]{'BODY'});
	}else{
		$message = '����ȯ�����';
	}

	print "<div class='post'>\n\n";
	print "<h3 id='newpost'>$message</h3>\n\n";

	if($$log[0]{'SIZE'} >= $CONF{'FILE_LIMIT'} or $$log[0]{'POST'} >= $CONF{'THREAD_LIMIT'}){
		print '<p>����åɤ����̤�Ķ���Ƥ���Τ�';
		if (defined($res)){  print '�쥹ȯ�����';  }
		else{  print '�������';  }
		print "�Ͻ���ޤ���</p>\n\n";

	}elsif(!defined($res) or !defined($$log[$res]{'DELETE_TIME'})){

		unless(defined($res)){
			print "<p>�������顢������ȯ������Ƥ��뤳�Ȥ�����ޤ����⤷������ȯ���˥쥹��Ĥ�����Ϥ���ȯ����ɽ�������Ƥ���֥쥹��Ĥ���פΥ����˰�ư���ޤ���</p>\n\n";
		}

		html::formparts_head(*STDOUT);
		html::formparts_name(*STDOUT, undef, $title, $body, undef, undef);
		html::formparts_password(*STDOUT, 1, html::pass_message() );
		html::formparts_age(*STDOUT, 1, 1);
		html::formparts_foot(*STDOUT, $html::POST, $writecgi::POST, $no, $res);

	}else{
		print "<p>���Ǥ�ȯ�����������Ƥ���Τǥ쥹��Ĥ��뤳�ȤϤǤ��ޤ���</p>\n\n";
	}
	print "</div>\n\n";

}

# �������Ĥ���
sub quote{
	my $body = shift;
	$body = "\n" . $body;
	$body=~s/\n/\n&gt; /g;
	return substr($body, 1);
}

# ȯ����RE:��Ĥ���
sub response{
	my $title = shift;
	$title = 'Re:' . $title;
	$title =~s/^(Re:)+/Re:/i;
	return $title;
}



##########################################################################
#                           ȯ�������ե�����ɽ��                         #
##########################################################################
sub form_rev{
	my $log    = shift;  #�ʻ��ȡ˥��ǡ���
	my $target = shift;  # ������Ԥʤ�ȯ���ֹ�

	print "<div class='revise'>\n\n";
	print "<h3 id='revise'>ȯ������</h3>\n\n";

	if($$log[0]{'SIZE'} >= $CONF{'FILE_LIMIT'}){
		print "<p>����åɤ����̤�Ķ���Ƥ���Τǽ����Ǥ��ޤ���</p>\n\n";

	}elsif(defined($$log[$target]{'DELETE_TIME'})){
		print "<p>����ȯ���Ϥ��Ǥ˺������Ƥ���Τǽ����Ǥ��ޤ���</p>\n\n";

	}elsif(defined($$log[$target]{'CORRECT_TIME'}) && @{$$log[$target]{'CORRECT_TIME'}} >= $CONF{'CHANGE_LIMIT'}){
		print "<p>$CONF{'CHANGE_LIMIT'}���Ķ����ȯ���������뤳�ȤϤǤ��ޤ���</p>";

	}else{

		if (defined($$log[$target]{'CORRECT_TIME'})){
			my $limit = $CONF{'CHANGE_LIMIT'} - @{$$log[$target]{'CORRECT_TIME'}};
			print "<p>����$limit��ȯ�������Ǥ��ޤ���</p>\n\n";
		}
		my $body = $$log[$target]{'BODY'};
		html::formparts_head(*STDOUT);
		html::formparts_name(*STDOUT, $$log[$target]{'USER_NAME'}, $$log[$target]{'TITLE'}, $body, $$log[$target]{'USER_EMAIL'}, $$log[$target]{'USER_WEBPAGE'});
		html::formparts_password(*STDOUT, 0, $html::PASS_REINPUT);
		html::formparts_foot(*STDOUT, $html::REVISE, $writecgi::REVISE, $$log[0]{'THREAD_NO'}, $target);
	}
	print "</div>\n\n";
}



##########################################################################
#                           ȯ������ե�����ɽ��                         #
##########################################################################
sub form_del{
	my $log    = shift;  #�ʻ��ȡ�ȯ����
	my $target = shift;  # �ä�ȯ�����ֹ�

	print "<div class='delete'>\n\n";
	print "<h3 id='delete'>ȯ�����</h3>\n\n";
	if(defined($$log[$target]{'DELETE_TIME'})){
		print "<p>����ȯ���Ϥ��Ǥ˺������Ƥ��ޤ���</p>\n\n";
		print "</div>\n\n";
		return;
	}

	html::formparts_delete($$log[0]{'THREAD_NO'}, $target);

}



##########################################################################
#                     URI�ѥ�᡼�����¤��ؤ������å�                    #
##########################################################################
sub regularization{
	my $query = shift;
	my $cgi = shift;
	my @reg = (
	           'no', 'st', 'en', 'ls', 'at',
	           'res', 'rev', 'sub', 'mes', 'tree',
	          );

	# �����꡼�¤��ؤ�
	my $new_query = '';
	for(my $i=0;$i<scalar @reg;++$i){
		my $data = $$cgi->param($reg[$i]);
		next unless(defined($data));
		$new_query .= "$reg[$i]=" . std::uri_escape($$cgi->param($reg[$i])) . ';' ;
	}
	chop($new_query);
	return $new_query;
}


##########################################################################
#                             URIž�����ƽ�λ                            #
##########################################################################
sub location{
	my $query = shift;
	print "Status: 302 Found\n";
	print "Location: $CONF{'BASE_HTTP'}$file::READ_SCRIPT?$query\n\n";
	exit;
}


##########################################################################
#                         read.cgi ���顼��å�����                      #
##########################################################################

#
# �Ķ��ե����뤬�ɤ߼��ʤ�
#
sub error_fail_conf{
	error_head();
	print "<p>'bbs.conf'�Ķ��ե����뤬�ɤ߼��ʤ������ޤ��������Ǥ���</p>\n\n";
	error_foot();
	exit;
}
#
# �����ɤ߼��ʤ�
#
sub error_fail_read{
	my $no = shift;

	my $gz_log = file::public_name($no) . ".$file::EXT_GZIP";
	my $html   = file::html_name($no);

	error_head();
	print '<p>';
	if(-f $html){
		print "����å��ֹ�$no�Ǥε����Ͻ�λ���ޤ�����";
		print "<a href='$html'>����</a>�򻲾Ȥ��Ƥ���������";

	}elsif(-f $gz_log){
		print "����å��ֹ�$no�Ǥε����Ͻ�λ���ޤ�����";
		print "����HTML�������ޤǤ��Ф餯���Ԥ�����������";

	}else{
		print "����å��ֹ�$no��¸�ߤ��ޤ���";

	}
	print "</p>\n\n";
	error_foot();
	exit;
}


#
# ���ϥե���������
#
sub error_illigal_call{
	error_head();
	print "<p>���ϥե����ब�����ʤ��ᡢȯ����ɽ�������뤳�Ȥ��Ǥ��ޤ���</p>\n\n";
	error_foot();
	exit;
}


#
# ���Ͽ��ͤ��ϰϳ�
#
sub error_over_value{
	error_head();
	print "<p>Ϳ����줿�ͤ��ǡ������ϰϳ��Τ��ᡢȯ����ɽ�������뤳�Ȥ��Ǥ��ޤ���</p>\n\n";
	error_foot();
	exit;
}

#
# ���Ͽ��ͤ�̷��
#
sub error_complex{
	error_head();
	print "<p>Ϳ����줿�ͤ�̷�⤬���뤿�ᡢȯ����ɽ�������뤳�Ȥ��Ǥ��ޤ���</p>\n\n";
	error_foot();
	exit;
}






#
# ����¾
#
sub error_other{
	my $hint = shift;
	error_head();
	print "<p>�Х���ޤ��������ߤޤ���hint:$hint</p>\n\n";
	error_foot();
	exit;
}


#
# ���顼���̽���
#
sub error_head{
	my $err_mes = 'read.cgi���顼ȯ��';
	html::http_response_header();
	html::header(*STDOUT, $err_mes);
	print "<div class='error'>\n\n";
	print "<h2 id='error'>$err_mes</h2>\n\n";
}


sub error_foot{
	print "</div>\n\n";
	print "<div class='link'>";
	html::link_top(*STDOUT);
	html::link_exit(*STDOUT);
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::footer(*STDOUT);
	exit;
}



##########################################################################
#                              �ƥ������ΰ�                              #
##########################################################################



