#
#
# �ޥ������åɷǼ��� - ��ɽ���ǡ�������
#
#                                          2002.10.23 ����������
#
package html;
use strict;

require './std.pl';
require './file.pl';
require './write.pl';

use vars qw($PROGRAMMER_WEBPAGE $MANUAL_PAGE $ADMIN_PAGE $JAVA_SCRIPT $STYLESHEET);
$PROGRAMMER_WEBPAGE = 'http://www.sarinaga.com/';  # ������ץȺ�ԤΥڡ���
$MANUAL_PAGE  = 'index.html';                      # ����ǥå����ڡ���
$ADMIN_PAGE   = 'admin.html';                      # �������ѥڡ���
$JAVA_SCRIPT  = 'bbs.js';                          # javascript
$STYLESHEET   = 'bbs.css';                         # �������륷����


use vars qw($TRIP_SEPARETE  $TREE_SPACE  $TREE_BRANCH  $TREE_BRANCH_END  $TREE_NODE);
$TRIP_SEPARETE   = '��';  # ̾��/�ȥ�å׶��ڤ국��
$TREE_SPACE      = '��';  # �ĥ꡼ɽ���ѵ���1
$TREE_BRANCH     = '��';  # �ĥ꡼ɽ���ѵ���2
$TREE_BRANCH_END = '��';  # �ĥ꡼ɽ���ѵ���3
$TREE_NODE       = '��';  # �ĥ꡼ɽ���ѵ���4
#$TREE_SPACE      = '��';  # �ĥ꡼ɽ���ѵ���1
#$TREE_BRANCH     = '��';  # �ĥ꡼ɽ���ѵ���2
#$TREE_BRANCH_END = '��';  # �ĥ꡼ɽ���ѵ���3
#$TREE_NODE       = '��';  # �ĥ꡼ɽ���ѵ���4


#
# ȯ��ɽ���⡼�ɤ�ɽ�魯����
#
use vars qw($COMPLETE $NO_REVISE $ATONE $RES $REV $TOMATO $TITLE $ADMIN
            $MESSAGE $TREE $IGNORE_KILL $HTML $FINAL $CONST);
$COMPLETE    = std::bin2dec('0000000000000001');  #�ֿ�����ơפ��Ǥ��ʤ����֡�ȯ���������С���
$NO_REVISE   = std::bin2dec('0000000000000010');  #��ȯ�������פ��Ǥ��ʤ����֡����̥����С���

$ATONE       = std::bin2dec('0000000000000100');  # ��ȯ��ñ��ɽ���⡼�ɤǤ�ȯ������
$RES         = std::bin2dec('0000000000001000');  # �쥹ȯ����ƥե�������ȯ������
$REV         = std::bin2dec('0000000000010000');  # ȯ�������ե�������ȯ������

$TOMATO      = std::bin2dec('0000000000100000');  # �����ȥޥ�ɽ��

$TITLE       = std::bin2dec('1000000000000000');  # �̾�ɽ���⡼�ɤǥ����ȥ��ɽ������
$MESSAGE     = std::bin2dec('0100000000000000');  # �̾�ɽ���⡼�ɤ�ȯ����ɽ������
$TREE        = std::bin2dec('0010000000000000');  # �����ȥ�󥯥ĥ꡼������ɽ������

$IGNORE_KILL = std::bin2dec('0001000000000000');  # �ʴ����ѡ˶���ɽ���ʥ���ޡ���̵�롢ID��IP���ɥ쥹�����ɽ��������
$ADMIN       = std::bin2dec('0001000000000000');  # �ʴ����ѡ˾��Ʊ��
$HTML        = std::bin2dec('0000100000000000');  # �ʴ����ѡ�HTML�ѽ���

$FINAL       = $COMPLETE | $NO_REVISE;  # ���ڤ��ѹ����Ǥ��ʤ����֤Ǥ���
$CONST       = $FINAL;                  # Ʊ��


use vars qw($PASS_MESSAGE $PASS_REINPUT $TRIP_MES $POST $CREATE $REVISE);
$PASS_MESSAGE = 'ȯ����������������Τ�ɬ��. [0-9A-Za-z]��%dʸ���ʾ�%dʸ������.';
$PASS_REINPUT = 'ȯ����񤭹�����Ȥ��Υѥ���ɤ�����.';
$TRIP_MES = '��ͭID����������. [0-9A-Za-z]��0ʸ���ʾ�%dʸ������.';
$POST   = '��Ƥ���';
$CREATE = '����åɺ���';
$REVISE = 'ȯ������';

###########################################################################
#                          http response header������                     #
###########################################################################
sub http_response_header{

	# content-type������
	my $content_type = 'text/html; charset=EUC-JP';
	if ($main::ENV{'HTTP_ACCEPT'}=~m/application\/xhtml\+xml/){
		$content_type='application/xhtml+xml';
	}elsif($main::ENV{'HTTP_ACCEPT'}=~m/application\/xml/){
		$content_type='application/xml';
	}
	$content_type = 'text/html; charset=EUC-JP';

	# http-response-header�ν���
	print << "RES";
Content-Type: $content_type
Content-Language: ja
Content-Style-Type: text/css
Content-Script-Type: text/javascript
Pragma: no-cache
Cache-Control: no-cache

RES
	return;

}


###########################################################################
#                           �ֹ���ȯ���ǡ��������                      #
###########################################################################
sub multi{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $log      = shift; # [����]��
	my $param    = shift; # [����]�����ѥѥ�᡼��

	my $st       = $$param{'st'};
	my $en       = $$param{'en'};

	print FOUT "<dl class='message'>\n\n";
	for(my $i=$st;$i<=$en;$i++){
		mes_one(*FOUT, $i, $log, $param);
	}
	print FOUT "</dl>\n\n";

}


###########################################################################
#                       �����ȥĥ꡼���ȯ���ǡ��������                #
###########################################################################
sub comment{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $log      = shift; # [����]��
	my $param    = shift; # [����]�����ѥѥ�᡼��

	# ȯ����ĥ꡼����¤٤�
	my @nums = search_thread($log, $$param{'st'}, $$param{'en'});
	foreach my $num(@nums){
		($num, undef, undef) = split(/:/, $num, 3);
	}

	print FOUT "<dl class='message'>\n\n";
	foreach my $num(@nums){
		mes_one(*FOUT, $num, $log, $param);
	}
	print FOUT "</dl>\n\n";

}


#
# ����å�ȯ���ֹ�
#
sub search_thread{
	my $log   = shift; # [����]��
	my $st    = shift; # õ�������ϰϡʻϡ�
	my $en    = shift; # õ�������ϰϡʽ���
	my $max   = @$log-1;

	# �ĥ꡼�����ѥǡ�������Ǽ��
	my $space      = 'S';
	my $branch_end = 'E';
	my $branch     = 'B';
	my $node       = 'N';

	my @t_no;    # ȯ���ֹ�
	my @t_tree;  # �ĥ꡼��¤
	my @t_deep;  # �ĥ꡼����

	# õ������
	for(my $i=$st;$i<=$en;$i++){

		# �쥹ȯ���ΤȤ��Ϥ��Ǥ����򤵤�Ƥ���ȹͤ���
		if (defined($$log[$i]{'RES'})){
			next if ($$log[$i]{'RES'}>=$st);
		}

		# ���򵭲�
		push(@t_no, $i);
		push(@t_deep, 0);
		push(@t_tree, '');

		# �ޤ򵭲�����Τ�ɬ�פʥǡ����ΰ�
		my @stack;
		my $now=$i+1;
		my $point=$i;

		# �ޤ�õ������ť롼�פ���ա�
		for(;;){

			my $j;
			for($j=$now;$j<=$max;$j++){
				next unless(defined($$log[$j]{'RES'}));
				next unless($$log[$j]{'RES'}==$point);

				# ����ȯ���ֹ�򵭲��ʻޡ�
				my $deep=@stack+1;
				push(@t_no, $j);
				push(@t_deep, $deep);
				push(@t_tree, std::spacer(std::math_min($deep-1, 10), $space) . $branch_end);

				# ��˸����ä��������
				for(my $k=@t_tree-2;$k>=0;--$k){
					last if ($t_deep[$k] < $deep);
					if ($t_deep[$k] == $deep){ substr($t_tree[$k], $deep-1, 1) = $node; }
					else { substr($t_tree[$k], $deep-1, 1) = $branch }
				}

				# �ޤ�ʬ���򵭲�
				push(@stack, $point);
				$point=$j;
				$now=$j+1;
				last;
			}

			# �ޤ�õ����ȯ���Ǹ�ޤǹԤ�줿���ϵ��������ޤ�ʬ���ޤ����
			if ($j>$max){
				last if (@stack==0);
				$now=$point+1;
				$point=pop(@stack);
			}
		}
	}

	# �ĥ꡼�ǡ��������Ѳ�
	foreach my $tree(@t_tree){
		$tree =~s/$space/$TREE_SPACE/g;
		$tree =~s/$branch_end/$TREE_BRANCH_END/g;
		$tree =~s/$branch/$TREE_BRANCH/g;
		$tree =~s/$node/$TREE_NODE/g;
	}

	# �ǡ������礷���֤�
	my @thread;
	for(my $i=0;$i<scalar @t_no;++$i){
		push(@thread, join(':' , ($t_no[$i], $t_deep[$i], $t_tree[$i]) ));
	}
	return @thread;

}



#
# ȯ���򣱤Ľ���
#
sub mes_one{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $no       = shift; # ɽ��������ȯ���ֹ�
	my $log      = shift; # [����]���ǡ���
	my $param    = shift; # [����]ȯ��ɽ���ѥ�᡼��

	# �ѥ�᡼�����
	my $st   = $$param{'st'};
	my $mode = $$param{'mode'};

	# ���ǡ�������ɬ�פʾ������Сʥ���åɾ����
	my $post  = $$log[0]{'POST'};
	my $size  = $$log[0]{'SIZE'};
	my $t_no  = $$log[0]{'THREAD_NO'};

	return 0 if($no < 0 or $post <= $no);


	# ���ǡ�������ɬ�פʾ������С�ȯ�������
	my %dat = %{$$log[$no]};

	my @correct_time;
	@correct_time = @{$dat{'CORRECT_TIME'}} if (defined($dat{'CORRECT_TIME'}));

	# ȯ���ֹ�������ȥ���桼��̾��IP���ɥ쥹���桼��ID�����֡��쥹���ɽ��
	print FOUT "<dt id='s$no' class='header'>\n";
	message_header(*FOUT, $no, $log, $param);
	print FOUT "<br />\n";

	# ñ��ɽ�����쥹��Ĥ����ȯ�������γƥ�󥯤�ɽ��
	my $kill = 0;
	if (!($mode & $ADMIN)){
		$kill = defined($dat{'DELETE_TIME'});
	}
	my $ctrl = 0;
	unless($mode & $ADMIN or $mode & $HTML ){
		$ctrl = !defined($dat{'DELETE_TIME'});
	}
	if ($ctrl){
		print FOUT "<span class='ctrl'>";
		unless(($mode & $ATONE) !=0){
			print FOUT "<a href='./$file::READ_SCRIPT?no=$t_no;at=$no'>ñȯ��ɽ��</a>��";
		}
		unless(($mode & $COMPLETE) !=0 or ($mode & $RES) !=0){
			print FOUT "<a href='./$file::READ_SCRIPT?no=$t_no;res=$no'>�쥹��Ĥ���</a>��";
		}
		unless(($mode & $REV) !=0){
			print FOUT "<a href='./$file::READ_SCRIPT?no=$t_no;rev=$no'>ȯ������</a>";
		}
		print FOUT "</span><br />\n";
	}
	print FOUT "</dt>\n\n";

	# �����Τ�ɽ��
	if (!$kill){
		my $body = body($dat{'BODY'});
		print FOUT "<dd class='body'>\n$body\n</dd>\n\n";
	}else{
		print FOUT "\n";
	}

	# IP���ɥ쥹��ɽ��
	if ($$log[$no]{'TOMATO'} or ($mode & $TOMATO) !=0 or ($mode & $ADMIN) !=0 ){
		print FOUT "<dd class='tomato'>\n";
		for(my $i=0;$i<@{$$log[$no]{'IP_HOST'}};++$i){
			print FOUT "$$log[$no]{'IP_HOST'}[$i], $$log[$no]{'IP_ADDR'}[$i], $$log[$no]{'USER_AGENT'}[$i]<br />\n";
		}
		print FOUT "</dd>\n";
	}

	# ȯ��������ȯ�����������ɽ��
	if (@correct_time > 0 or defined($dat{'DELETE_TIME'})){
		print FOUT "<dd class='info'>\n";
		foreach my $c_time(@correct_time){
			print FOUT '����ȯ����' . std::time_format($c_time) . "�˽�������Ƥ��ޤ���<br />\n";
		}
		if (defined($dat{'DELETE_TIME'})){
			print FOUT '����ȯ����' . std::time_format($dat{'DELETE_TIME'}) . '��';
			print FOUT "����͡�$dat{'DELETE_ADMIN'}�פˤ�ä�" if (defined($dat{'DELETE_ADMIN'}));
			print FOUT "�������Ƥ��ޤ���<br />\n";
		}
		print FOUT "</dd>\n\n";
	}

	# ñȯ��ɽ����λ
	print FOUT "\n";
	return;

}

#
# ȯ���Υإå�����Ϥ���
#
# ȯ���ֹ桢ȯ�������ȥ롢̾�����ȥ�åס�ID
# ȯ�����֡��쥹��
#
sub message_header{
	local(*FOUT) = shift;  # ������
	my $target   = shift;  # ȯ��������ɽ���ֹ�
	my $log      = shift;  # ȯ��������
	my $param    = shift;  # ���ϥѥ�᡼��

	my $mode = $$param{'mode'};
	my $res  = $$log[$target]{'RES'};
	my $kill = (defined($$log[$target]{'DELETE_TIME'}) and !($mode & $ADMIN) );

	title(*FOUT, $target, $log, $param);

	print FOUT "<br />\n";
	print FOUT scalar std::time_format($$log[$target]{'POST_TIME'});
	if (defined($res)){
		print FOUT '��[';
		if($mode & $ADMIN){
			print FOUT "$res��";
		}elsif ($$param{'st'} > $res){
			print FOUT "<a href='./$file::READ_SCRIPT?no=$$param{'no'};at=$res'>$res��</a>";
		}else{
			print FOUT "<a href='#s$res'>$res��</a>";
		}
		print FOUT '�ؤΥ�����]';
	}

}


#
# ��ʸ��ʬ�����������Ԥ�<br />�ˡ���Ƭ�������°�����դ���
# Ϣ³�����&nbsp;���Ѵ�
#
sub body{
	my $body=shift;
	$body="\n$body";
	$body=~s/\n(\|.*)/\n<q class="quote-pipe">$1<\/q>/g;
	$body=~s/\n(%.*)/\n<q class="quote-percent">$1<\/q>/g;
	$body=~s/\n(&gt;.*)/\n<q class="quote-gt">$1<\/q>/g;
	$body=~s/\n(\#.*)/\n<q class="quote-sharp">$1<\/q>/g;
	$body=substr($body,1);
	$body=~s/\n/<br \/>\n/g;
	return std::trans_space($body);
}


###########################################################################
#                             �ֹ���ȯ�������ȥ�����                  #
###########################################################################
sub list{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $log      = shift; # [����]��
	my $param    = shift; # [����]�����ѥѥ�᡼��

	my $no = $$log[0]{'THREAD_NO'};

	my $st = $$param{'st'};
	my $en = $$param{'en'};

	my $st_block = int($st/10);
	my $en_block = int($en/10);

	print FOUT "<div class='list'>\n\n";
	for(my $i=$st_block;$i<=$en_block;$i++){

		print FOUT "<table class='list'><tbody>\n\n";

		for(my $j= (std::math_max($st,$i*10));
		       $j<=(std::math_min($en,$i*10+9));
		       $j++){

			print FOUT '<tr>';
			list_header(*FOUT, $j, $log, $param);
			print FOUT "</tr>\n";
		}
		print FOUT "</tbody></table>\n\n";
		print FOUT "<hr />\n\n" if ($i<$en_block);
	}
	print FOUT "</div>\n\n";

}

#
# �ꥹ��ɽ������Ϥ���
#
# ȯ���ֹ桢ȯ�������ȥ롢̾�����ȥ�åס�ID��IP���ɥ쥹���쥹��
#
sub list_header{
	local(*FOUT) = shift;  # ������
	my $target = shift;    # ȯ��������ɽ���ֹ�
	my $log = shift;       # ȯ��������
	my $param = shift;     # ���ϥѥ�᡼��

	my $mode = $$param{'mode'};
	my $res  = $$log[$target]{'RES'};
	my $kill = (defined($$log[$target]{'DELETE_TIME'}) and !($mode & $IGNORE_KILL));

	# ȯ�������ȥ����
	my $title = $$log[$target]{'TITLE'};
	my $short_title = short_string($title, $main::CONF{'TITLE_LENGTH_MAX'});
	print FOUT "<td class='num'><tt>$target.</tt></td>";
	print FOUT ' <td class="title">';
	if ($kill){                                   # ȯ�����������Ƥ�����
		print FOUT '<em class="kill">';
		$short_title = $main::CONF{'KILL_TITLE'};

	}elsif((($mode & $TITLE) != 0 and ($mode & $MESSAGE) == 0) or ($mode & $ATONE) != 0 ){
	                                              # �����ȥ������ɽ����������
	                                              # �嵭������ɽ������Ƥ���ȯ���ʳ��ξ��
		print FOUT "<a href='./$file::READ_SCRIPT?$$log[0]{'THREAD_NO'};at=$target' class='sub' title='$title'>";

	}else{                                        # ����¾�ξ��
		print FOUT "<a href='#s$target' class='sub' title='$title'>";
	}
	print FOUT $short_title;
	if ($kill){  print FOUT "</em>"; }
	else{        print FOUT "</a>";   }
	print FOUT '</td> ';

	# ̾�����ϡ��ȥ�å�
	print FOUT '<td class="name">';
	unless($kill){
		my $name = $$log[$target]{'USER_NAME'};
		my $short_name = short_string($name, $main::CONF{'NAME_LENGTH_MAX'});

		print FOUT "<span title='$name'>$short_name</span>";
		if (defined($$log[$target]{'TRIP'})){
			print FOUT "<span class='trip'>$TRIP_SEPARETE$$log[$target]{'TRIP'}</span>";
		}
	}else{
		print FOUT $main::CONF{'KILL_NAME'};
	}
	print FOUT '</td>';


	# �쥹�ݥ������
	print FOUT ' <td class="response">';
	if (defined($res)){
		if ($$param{'st'} > $res){
			print FOUT "<a href='./$file::READ_SCRIPT?no=$$param{'no'};at=$res'>$res��</a>";
		}else{
			print FOUT "<a href='#d$res'>$res��</a>";
		}
		print FOUT '�ؤΥ�����';
	}
	print FOUT '</td>';

	# ID����
	if ($$log[$target]{'USER_ID'}){
		print FOUT ' <td class="id">';
		print FOUT "ID:$$log[$target]{'USER_ID'}" if (!$kill);
		print FOUT '</td>';
	}

}


###########################################################################
#                     �����ȥĥ꡼���ȯ�������ȥ�����                #
###########################################################################
sub tree{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $log      = shift; # [����]��
	my $param    = shift; # [����]�����ѥѥ�᡼��

	my $max = @$log-1;
	my $st  = $$param{'st'};
	my $en  = $$param{'en'};

	# �ĥ꡼�κ���õ��(ñ��ɽ���ΤȤ�)
	if (($$param{'mode'} & $ATONE) != 0){
		while(defined($$log[$st]{'RES'})){
			$st = $en = $$log[$st]{'RES'};
		}
	}

 	# ȯ����ĥ꡼����¤٤�
	my @nums = search_thread($log, $st, $en);

	# �ĥ꡼ɽ������
	print FOUT "<div class='tree'>\n\n";
	for(my $i=0;$i<@nums;++$i){

		my ($num, $spc, $tree) = split(/:/, $nums[$i], 3);
		print FOUT "<br />\n" if ($spc == 0 and $i > 0);
		print FOUT $tree;
#		print FOUT scalar std::spacer(std::math_min($spc, 10), '��');
		title(*FOUT, $num, $log, $param);
		print FOUT "<br />\n";
	}
	print FOUT "</div>\n\n";
}



#
# �����ȥ롢̾�����ȥ�åס�ID�����򤵤줿���Τߡˤ�ɽ��
#
sub title{
	local(*FOUT) = shift;  # ������ե�����ϥ�ɥ�
	my $num      = shift;  # ɽ������ȯ���ֹ�
	my $log      = shift;  # [����] ��
	my $param    = shift;  # [����] �ѥ�᡼��
	my $id       = shift;  # ID��ɽ�����뤫��

	my $no     = $$log[0]{'THREAD_NO'};
	my $name   = $$log[$num]{'USER_NAME'};
	my $trip   = $$log[$num]{'TRIP'};
	my $title  = $$log[$num]{'TITLE'};
	my $email  = $$log[$num]{'USER_EMAIL'};
	my $web    = $$log[$num]{'USER_WEBPAGE'};

	my $st     = $$param{'st'};
	my $mode   = $$param{'mode'};

	my $kill = 0;
	my $no_link = 0;


	# ����Ĵ��
	if (!($mode & $ADMIN)){
		if (defined($$log[$num]{'DELETE_TIME'}) ){
			$no_link = 1;
			$kill    = 1;
			$name    = $main::CONF{'KILL_NAME'};
			$title   = $main::CONF{'KILL_TITLE'};
			$trip    = undef;
			$email   = undef;
			$web     = undef;
		}
	}
	$no_link = 1 if (($mode & $ATONE) != 0 and $num==$st);
	$no_link = 1 if ($mode & $ADMIN);

	# �إå���ʬ����
	print FOUT "<tt>$num.</tt>";
	if ($kill){   # ȯ�����������Ƥ�����

		print FOUT '<em class="kill">';

	}elsif($no_link){  # ��ʬ���ȤؤΥ�󥯤򤷤ʤ����

		print FOUT "<em class='now' title='$title'>";

	}elsif((($mode & $TITLE) != 0 and ($mode & $MESSAGE) == 0) or ($mode & $ATONE) != 0 ){
	                                            # �����ȥ������ɽ���������
	                                            # �嵭������ɽ������Ƥ���ȯ���ʳ��ξ��
		print FOUT "<a href='./$file::READ_SCRIPT?no=$no;at=$num' class='sub' title='$title'>";

	}else{                                      # ����¾�ξ��
		print FOUT "<a href='#s$num' class='sub' title='$title'>";

	}

	my $short_title = short_string($title, $main::CONF{'TITLE_LENGTH_MAX'});
	$short_title = std::trans_space($short_title);
	print FOUT $short_title;

	if($no_link or $kill){
		print FOUT '</em>';
	}else{
		print FOUT '</a>';
	}

	my $short_name = std::trans_space(short_string($name, $main::CONF{'NAME_LENGTH_MAX'}));
	print FOUT "��<span title='$name'>$short_name";
	print FOUT "<span class='trip'>$TRIP_SEPARETE$trip</span>" if(defined($trip));
	print FOUT '</span>';

	if((!$kill or ($mode & $IGNORE_KILL) !=0) and $$log[$num]{'USER_ID'}){
		print FOUT "��<span class='id'>ID:$$log[$num]{'USER_ID'}</span>��";
	}else{
		print FOUT '��';
	}

	# email��web�ڡ�����ɽ������
	link_email(*FOUT, $email, $name) if ($email and !$kill);
	link_webpage(*FOUT, $web, $name) if ($web   and !$kill);

}


#
# ʸ����ʥ���å�̾�������ȥ�̾����̾�ˤ�û������
#
sub short_string{
	my $string = shift;
	my $length = shift;

	$string = std::html_unescape($string);
	for(my $i=$length;;++$i){
		my $short = std::strnum_limit_euc($string, $i);
		my $euc   = ($short=~tr/\xa1-\xfe/\xa1-\xfe/) / 2;  # EUCʸ���������
		my $ascii = ($short=~tr/\x00-\x7f/\x00-\x7f/);      # ASCIIʸ���������
		return std::html_escape($string) if ($string eq $short);
		return std::html_escape($short) . '...' if ($ascii / 2 + $euc >= $length);
	}
}


###########################################################################
#                           ����åɰ�������Ϥ���                        #
###########################################################################
sub thread_list{
	local(*FOUT) = shift;  # ������ե�����ϥ�ɥ�
	my $thread   = shift;  # ����åɾ���[����]
	my $dat      = shift;  # dat�Ԥ��ξ������Ϥ��뤫�ɤ���/�����⡼��[admin.cgi��]

	# age��ʹ߽�ˤ˥����Ȥ���
	@$thread = sort { $$b{'AGE_TIME'} <=> $$a{'AGE_TIME'} } @$thread;

	# ����åɰ�������Ϥ����ͭ���ʥ���åɤ��ʤ����
	print FOUT "<div class='thread-list'>\n\n";
	unless (@$thread > 0){
		print FOUT "<p>����åɤϤޤ�����Ƥ��ʤ�����ͭ���ʥ���åɤ�����ޤ���</p>\n\n</div>\n\n";
		return;
	}

	# ����åɰ�������Ϥ�����ܥǡ�����
	print FOUT "<table class='thread-list'><tbody>\n\n";
	foreach my $t(@$thread){

		next if ($$t{'DAT'});    # DAT�Ԥ��ǡ����λ��Ͻ������ʤ�

		print FOUT "<tr><td class='no'>$$t{'THREAD_NO'}.</td><td class='thread'>";
		print FOUT "<a href='./$file::READ_SCRIPT?no=$$t{'THREAD_NO'};ls=$main::CONF{'DISPLAY_LAST'};tree=1;sub=1' ";
		print FOUT "class='thread' title='�ǿ�$main::CONF{'DISPLAY_LAST'}�쥹��ɽ��'>";

		my $thread_name = $$t{'THREAD_TITLE'};
		my $thread_short = short_string($thread_name, $main::CONF{'THREAD_LENGTH_MAX'});

		print FOUT "<span title='$thread_name'>$thread_short</span></a>";
		print FOUT "($$t{'POST'})</td><td class='date'>" . std::time_format($$t{'AGE_TIME'}) . "</td>";
		print FOUT "<td class='all'><a href='./$file::READ_SCRIPT?no=$$t{'THREAD_NO'}' ";
		print FOUT "title='����å�$$t{'THREAD_NO'}�֡��ֹ��'>��ȯ��ɽ��</a></td>";
		print FOUT "<td class='titleonly'><a href='./$file::READ_SCRIPT?no=$$t{'THREAD_NO'};sub=1;mes=0;tree=1' ";
		print FOUT "title='����å�$$t{'THREAD_NO'}�֡������Ƚ�'>����̾ɽ��</a></td></tr>\n";
	}
	print FOUT "\n</tbody></table>\n\n";
	print FOUT "</div>\n\n";

}



###########################################################################
#                                 email���                             #
###########################################################################
sub link_email{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $email    = shift; # email���ɥ쥹
	my $name     = shift; # ̾��

	$email = std::shredder("mailto:$email");
	print FOUT "<a href='$email' title='$name'>";
	if ($main::CONF{'ICON_EMAIL'}){
		print FOUT "<img src='$main::CONF{'ICON_EMAIL'}' alt='email' />";
	}else{
		print FOUT '<small>email</small>';
	}
	print FOUT '</a>��';
}



###########################################################################
#                                Web�ڡ������                          #
###########################################################################
sub link_webpage{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $webpage  = shift; # webpage http
	my $name     = shift; # ̾��

	$webpage = std::shredder($webpage);
	print FOUT "<a href='http://$webpage' title='$name'>";
	if ($main::CONF{'ICON_WEBPAGE'}){
		print FOUT "<img src='$main::CONF{'ICON_WEBPAGE'}' alt='webpage' />";
	}else{
		print FOUT '<small>webpage</small>';
	}
	print FOUT '</a>��';

}



###########################################################################
#                          ����åɰ���ɽ���ؤΥ��                     #
###########################################################################
sub link_top{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	print FOUT "<a href='./$file::BBS_TOP_PAGE_FILE'>����åɰ���</a>��";
}



###########################################################################
#                            �Ǽ��Ĥ���ȴ������                       #
###########################################################################
sub link_exit{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	print FOUT "<a href='$main::CONF{'EXIT_TO'}'>�ȥåץڡ���</a>��";
}



###########################################################################
#                             ��ȯ��ɽ���ؤΥ��                        #
###########################################################################
sub link_all{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $no       = shift; # ����å��ֹ�
	print FOUT "<a href='./$file::READ_SCRIPT?no=$no' title='����å�$no�֡��ֹ��'>��ȯ��ɽ��</a>��";
}



###########################################################################
#                              ����̾ɽ���ؤΥ��                       #
###########################################################################
sub link_title{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $no       = shift; # ����å��ֹ�
	print FOUT "<a href='./$file::READ_SCRIPT?no=$no;sub=1;mes=0;tree=1' title='����å�$no�֡������Ƚ�'>����̾ɽ��</a>��";
}



###########################################################################
#                             �ǿ��쥹ɽ���ؤΥ��                      #
###########################################################################
sub link_new{
	link_new100(@_);
}
sub link_new100{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $no       = shift; # ����å��ֹ�
	print FOUT "<a href='./$file::READ_SCRIPT?no=$no;ls=$main::CONF{'DISPLAY_LAST'};sub=1;tree=1'>�ǿ�$main::CONF{'DISPLAY_LAST'}�쥹ɽ��</a>��";
}



###########################################################################
#                             �����ԥ⡼�ɤؤΥ��                      #
###########################################################################
sub link_adminmode{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	print FOUT "<a href='./$ADMIN_PAGE'>�����⡼��</a>��";
}



###########################################################################
#                             �����԰��᡼��ؤΥ��                    #
###########################################################################
sub link_adminmail{
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	print FOUT "<a href='mailto:$main::CONF{'ADMIN_MAIL'}'>�����԰��᡼��</a>��";
}



###########################################################################
#                      ����åɰ���ɽ������ȯ��ɽ����                     #
#                   ����̾ɽ���ǿ�100�쥹ɽ�����Υ��å�                   #
###########################################################################
sub link_set{
	link_3set(@_);
}
sub link_3set{   # �ߴ��Τ���ʴؿ�̿̾���缺�ԡ�
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $no       = shift; # ����å��ֹ�
	print FOUT '<div class="link">';
	link_top(*FOUT);
	link_all(*FOUT, $no);
	link_title(*FOUT, $no);
	link_new100(*FOUT, $no);
}


###########################################################################
#                ����åɰ���ɽ������ȯ��ɽ��������̾ɽ����               #
#              �ǿ�100�쥹ɽ���������԰��᡼��Υ��åȡ��Ĥ���            #
###########################################################################
sub link_set_close{
	link_3set_close(@_);
}
sub link_3set_close{  # �ߴ��Τ���ʴؿ�̿̾���缺�ԡ�
	local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
	my $no       = shift; # ����å��ֹ�
	link_set(*FOUT, $no);
	link_adminmail(*FOUT);
	print "</div>\n\n";
}



###########################################################################
#                        �ѥ��������ʸ��������                         #
###########################################################################
sub pass_message{
	return sprintf($PASS_MESSAGE, $writecgi::PASS_LENGTH_MIN, $main::CONF{'PASSWORD_LENGTH'});
}



###########################################################################
#                          HTML�إå���ʬ�����                           #
###########################################################################
sub header{
	local(*FOUT) = shift;  # ������
	my $title    = shift;  # �ڡ��������ȥ�
	my $base     = shift;  # <base>���Ǥ����Ѥ��뤫�� [���¾�̤����]
	my $cookie   = shift;  # cookie���ơʥϥå���ref��
	my $expires  = shift;  # cookieͭ������
	my $outhtml  = shift;  # html���λ��Υإå����ϡ�

	# XML�����DOCTYPE��������
	print FOUT << "HEADER";
<?xml version="1.0" encoding="EUC-JP" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
                      "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja">

<head>

HEADER

	# �����ȥ롢base���ǡ��������륷���ȡ�����javascript�����
	print FOUT "<base href='$main::CONF{'BASE_HTTP'}' />\n" if ($base);
	print FOUT "<link rel='stylesheet' type='text/css' href='./$STYLESHEET' />\n";
	print FOUT "<script type='text/javascript' src='./$JAVA_SCRIPT'></script>\n" if(!$outhtml);

	# cookie����javascript�����
	if ($cookie){
		print FOUT "<script type='text/javascript'>\n";
		foreach my $key(keys %$cookie){
			print FOUT "    setCookie('$key', '$$cookie{$key}', compute_expires($expires));\n";
		}
		print FOUT "</script>\n";
	}
	print FOUT "<title>$title - $main::CONF{'BBS_NAME'}</title>\n\n";

	# �����ȥ���ʬ����
	print FOUT << "TITLE";
</head>

<!--======================================================================-->

<body>

<h1 id='title'>$main::CONF{'BBS_NAME'}</h1>

TITLE

}



###########################################################################
#                             HTML�եå���ʬ�����                        #
###########################################################################
sub footer{
	local(*FOUT) = shift;  # ������

	# �С�������ֹ��׻�
	my $ver=sprintf("%1.2f",$main::CONF{'VERSION'} / 100);

	# �եå���ʬ����
	print FOUT '<div class="version" xml:lang="en">';
	print FOUT "Double Thread BBS version $ver - programed by ";
	print FOUT "<a href='$PROGRAMMER_WEBPAGE'>";
	print FOUT "SAYURIN-SENSEI</a></div>\n\n</body>\n\n</html>\n";
}



###########################################################################
#                              ��ʿ���Υ�����                           #
###########################################################################
sub hr{
	local(*FOUT) = shift;  # ������
	print FOUT "<!--======================================================================-->\n\n";
}



###########################################################################
#                              �����ե�����Ƽ�                           #
###########################################################################

# ȯ��ɽ���ե�����
sub form_read{
	local(*FOUT) = shift;
	my $no     = shift;  # ����å��ֹ�
	my $last   = shift;  # �Ǹ��ȯ���ֹ�
	my $target = shift;  # ñ��ɽ���ֹ�
	my $kind   = shift;  # ñ��ȯ���򤹤���ͳ

	my $span = $target ? 4 : 3;  # rowspan�ο���Ĵ������
	print FOUT << "FORM";
<h3 id='change-mode'>ɽ�������ڤ��ؤ�</h3>

<form method='get' action='./$file::READ_SCRIPT' class='read' id='read' name='read' onsubmit='return check_read_form(this, $last);'>
<table class="change-mode">

<tbody>

<!-- �ֹ�������ꤷ�ư�ư����ե�������ʬ -->
<tr><td rowspan='$span'>
ȯ���ֹ� <input type='hidden' name='no' value='$no' />
         <input type='text' name='st' size='5' value='0' />����
         <input type='text' name='en' size='5' value='$last' />�ޤ�
<br />

ɽ����� <select name='tree' size='1'>
           <option value='1' selected='selected'>�ĥ꡼</option>
           <option value='0' >ȯ���ֹ�</option>
         </select>��
<br />

ɽ������ <input type='checkbox' name='sub' value='1' />��̾ɽ��
         <input type='checkbox' name='mes' value='1' checked='checked' />ȯ��ɽ��

<br />
<input type='submit' value='����' />
</td>

<!-- �ʰ�Ū��� -->
FORM

	# ��ȯ��ɽ���ؤΥ��
	print FOUT '<td class="or">or</td> <td>';
	link_all(*FOUT, $no);
	print FOUT "</td></tr>\n";

	# ����̾ɽ���ؤΥ��
	print FOUT '<tr><td class="or">or</td> <td>';
	link_title(*FOUT, $no);
	print FOUT "</td></tr>\n";

	# �ǿ�100�쥹ɽ���ؤΥ��
	print FOUT '<tr><td class="or">or</td> <td>';
	link_new100(*FOUT, $no);
	print FOUT "</td></tr>\n";

	# ñ��ȯ��ɽ���ؤΥ��
	if ($target){
		print FOUT "<tr><td class='or'>or</td> <td>";
		print FOUT "<a href='./$file::READ_SCRIPT?no=$no;at=$target'>$kindȯ����ñ��ɽ��</a></td></tr>\n";
	}

	print FOUT "\n</tbody>\n\n</table>\n\n</form>\n\n";

}




# �񤭹��ߥե�������Ƭ��ʬ�ʰʲ����٤ƽ񤭹��ߡ�
sub formparts_head{
	local(*FOUT) = shift;
	print FOUT << "HTML";
<form method='post' action='./$file::WRITE_SCRIPT' class='post' id='post' name='post' onsubmit='return check_write_form(this);'>

<table class="post">
<tbody>

HTML
}


# ������åɺ�������
sub formparts_createthread{
	local(*FOUT) = shift;
	print FOUT << "HTML";
<tr class="thread">
<th>����å�̾</th>
<td>
  <input type='text' name='thread' size='40' value='' />
</td>
</tr>

HTML
}


# ̾���������֥ڡ���
sub formparts_name{
	local(*FOUT) = shift;
	my ($user, $title, $body, $email, $webpage) = @_;
	#$user  = std::html_unescape($user) if (defined($user));
	#$title = std::html_unescape($title);
	#$body  = std::html_unescape($body);

	#
	# ̾����ʬ
	#
	print FOUT "<tr class='name'>\n<th>̾��</th>\n<td>\n";
	print FOUT "  <input type='text' name='name' size='20' ";
	if (defined($user)){
		print FOUT "value='$user' />\n";

	}else{
		print FOUT "/>\n";
		print FOUT << "HTML0";
  <script type='text/javascript'>
    document.post.name.value = getCookie("USER_NAME");
  </script>
HTML0
	}
	print FOUT "</td>\n</tr>\n\n";

	#
	# �����ȥ���ʬ��webpage��ʬ
	#
	print FOUT << "HTML1";
<tr class="title">
<th>�����ȥ�</th>
<td>
  <input type='text' name='title' size='40' value='$title' />
</td>
</tr>

<tr class="body">
<th>��ʸ</th>
HTML1
	print FOUT "<!--===========-->" if ($body);
	print FOUT "<td><textarea cols='60' rows='10' name='body'>";
	if ($body){
		print FOUT "\n$body\n</textarea></td>";
		print FOUT "<!--=========================================-->\n";

	}else{
		print FOUT "</textarea></td>\n";
	}
	print FOUT "</tr>\n\n";

	print FOUT "<tr class='email'>\n<th>email</th>\n<td>\n";
	print FOUT "  mailto:<input type='text' name='email' size='30' ";
	if (defined($email)){
		print FOUT "value='$email' />\n";
	}else{
		print FOUT "/>\n";
		print FOUT << "HTML3";
  <script type='text/javascript'>
     document.post.email.value = getCookie("USER_EMAIL");
  </script>
HTML3
	}
	print FOUT "</td>\n</tr>\n\n";

	print FOUT "<tr class='webpage'>\n<th>webpage</th>\n<td>\n";
	print FOUT "  http://<input type='text' name='web' size='30' ";
	if (defined($webpage)){
		print FOUT "value='$webpage' />\n";

	}else{
		print FOUT "/>\n";
		print FOUT << "HTML5";
  <script type='text/javascript'>
    document.post.web.value = getCookie("USER_WEBPAGE");
  </script>
HTML5
	}
	print FOUT "</td>\n</tr>\n\n";

}



# �ȥ�åס��ѥ����
sub formparts_password{
	local(*FOUT) = shift;
	my $trip     = shift;
	my $form_mes = shift;

	if ($trip){
		my $trip_mes = sprintf($TRIP_MES, $main::CONF{'TRIP_INPUT_LENGTH'});
		print FOUT << "TRIP";
<tr class="trip">
<th>�ȥ�å�</th>
<td>
  <input type='text' name='trip' size='$main::CONF{'TRIP_INPUT_LENGTH'}' maxlength='$main::CONF{'TRIP_INPUT_LENGTH'}' />
  <small>$trip_mes</small>
  <script type='text/javascript'>
    document.post.trip.value = getCookie("TRIP");
  </script>
</td>
</tr>

TRIP
	}

	print FOUT << "PASS";
<tr class="pass">
<th>�ѥ����</th>
<td>
  <input type='password'
         name='pass'
         size='$main::CONF{'PASSWORD_LENGTH'}'
         maxlength='$main::CONF{'PASSWORD_LENGTH'}' />
  <small>$form_mes</small>
  <script type='text/javascript'>
    document.post.pass.value = getCookie("PASSWORD");
  </script>
</td>
</tr>

PASS

}

# cookie, age, tomato
sub formparts_age{
	local(*FOUT) = shift;
	my $agesage  = shift;
	my $tomato   = shift;

	print FOUT << "COOKIE";
<tr class='other'>
<th>����¾</th>
<td>
  <input type='checkbox' name='cookie' value='1' /> cookie����¸����.
  <script type='text/javascript'>
    var cookie = getCookie("COOKIE");
    if (cookie == 1)
        document.post.cookie.checked = true;
    else
        document.post.cookie.checked = false;
  </script>
COOKIE

	if ($agesage){
		print FOUT << "SAGE";

  <input type='checkbox' name='sage' value='1' /> ȯ���򤢤��ʤ�.
  <script type='text/javascript'>
    var sage = getCookie("SAGE");
    if (sage == 1)
        document.post.sage.checked = true;
    else
        document.post.sage.checked = false;
  </script>
SAGE
	}

	if ($tomato){
		print FOUT << "TOMATO";

  <input type='checkbox' name='tomato' value='1' /> IP���ɥ쥹����ɽ��.
  <script type='text/javascript'>
    var tomato = getCookie("TOMATO");
    if (tomato == 1)
        document.post.tomato.checked = true;
    else
        document.post.tomato.checked = false;
  </script>
TOMATO
	}

	print FOUT "</td>\n</tr>\n\n";

}


# ������ʬ�ʥܥ����
sub formparts_foot{
	local(*FOUT) = shift;
	my $post     = shift;  # �����ܥ����ʸ��
	my $mode     = shift;  # ��ƥ⡼�� CREATE | REVISE | POST
	my $t_no     = shift;  # ����å��ֹ�
	my $target   = shift;  # �쥹�衿������

	print FOUT << "HTML0";
<tr class="post">
<th>�ե���������</th>
<td>
  <input type='submit' value='$post' />
  <input type='reset' value='�ꥻ�å�'
         onclick='return reset_form();'
         onkeypress='return reset_form();'  />
  <input type='hidden' name='mode' value='$mode' />
HTML0

	if($mode ne $writecgi::CREATE){
		print FOUT "  <input type='hidden' name='no' value='$t_no' />\n";
		if ($mode eq $writecgi::REVISE){
			print FOUT "  <input type='hidden' name='target' value='$target' />\n";
		}elsif($mode eq $writecgi::POST and defined($target)){
			print FOUT "  <input type='hidden' name='res' value='$target' />\n";
		}
	}
	print FOUT << "HTML1";
</td>
</tr>

</tbody>
</table>

</form>

HTML1
}


# �ǡ�������ե�����
sub formparts_delete{
	my ($no, $target) = @_;
	print << "DEL";
<form method='post' action='./$file::WRITE_SCRIPT' id='d_post' name='d_post' onSubmit='return check_password(document.d_post.pass.value);'>
<p class="delete">
  <input type="hidden"   name="no" value="$no" />
  <input type="hidden"   name="target" value="$target" />
  <input type="hidden"   name="mode" value="$writecgi::DELETE" />
  <input type='password' name='pass' size="$main::CONF{'PASSWORD_LENGTH'}" maxlength="$main::CONF{'PASSWORD_LENGTH'}" />
  <input type='submit'   size='8' value='ȯ�����' />
  <small>$PASS_REINPUT</small>
  <script type='text/javascript'>
    document.d_post.pass.value = getCookie("PASSWORD");
  </script>
</p>
</form>

</div>

DEL
}

###########################################################################
#                              ����ΰ�                                 #
###########################################################################





1;

