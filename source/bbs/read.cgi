#!/usr/bin/perl -w
#!C:/Perl/bin/perl -w
#
#
# マルチスレッド掲示板 - 発言表示スクリプト read.cgi
#
#                                          2002.10.23 さゆりん先生
#
use strict;
use CGI;
use utf8;

BEGIN{
	if ($ENV{'HTTP_HOST'}){
		use CGI::Carp qw(carpout);
		open(LOG, ">../log/error.log");
		carpout(*LOG);
	    my $tm = localtime;
		print LOG strftime("[%Y/%m/%d %H:%M:%S] read.cgi log start.\n", $tm);
	}
}
END{
    my $tm = localtime;
	print LOG strftime("[%Y/%m/%d %H:%M:%S] read.cgi log end.\n", $tm);
}

require './html.pl';
require './file.pl';
require './std.pl';
require './write.pl';

unless($ENV{'HTTP_HOST'}){
	print "このプログラムはCGI用です. コマンドラインからの実行はできません. \n";
	exit;
}

# 動作環境読み取り
use vars qw(%CONF);
error_fail_conf() unless(file::config_read(\%CONF));

# CGIクラス利用
my $cgi = new CGI;

# リクエストはGETでなければならない
bad_request()  if ($ENV{'REQUEST_METHOD'} ne 'GET');

# パラメータが正規でない場合は修正してLocationで飛ばす
my $reg_query = regularization($ENV{'QUERY_STRING'}, \$cgi);
location($reg_query) if ($ENV{'QUERY_STRING'} ne $reg_query);


#
# パラメータを読み取り、データ洗浄する（前処理）
#
#
# 受け付けるCGIフォームの種類と内容は以下の通り
#
# no       = スレッド番号
#
# st       = 読み取り開始（省略時は0）
# en       = 読み取り終了（省略時は最後まで）
# at       = 単体発言表示
# ls       = 最新の発言*個表示
#
# mes      = 発言本文を表示するかしないか（省略時は1）
# sub      = 発言タイトル一覧を表示するかしないか（省略時は0）
#
# tree     = ツリー・スレッド表示方式の発言表示
#
# res      = 発言レス投稿フォーム表示
# del      = 発言削除確認フォーム表示
# rev      = 発言修正確認フォーム表示
#
my $no  = $cgi->param('no');
error_illigal_call() unless($no =~m/^(\d+)$/);  # 洗浄
$no = $1;


# 動作環境読み取り（前半：ログを読み取らなくても判断できる部分）
my %param;
$param{'no'}   = $no;
$param{'mode'} = 0;

# データが矛盾していないかチェックする(at, res, rev)
my $double_flag = 0;   # 重複入力されていないかどうかを確認するフラグ（結構あとまで使うので注意）
foreach my $key('at', 'res', 'rev'){
	my $num = $cgi->param($key);
	if (defined($num)){

		error_illigal_call() unless($num=~m/^\d+$/); # 数字が入っていなければ不正入力
		error_illigal_call() if($double_flag);       # 重複していた場合不正

		$double_flag    = 1;
		$param{'st'}    = $num;
		$param{'en'}    = $num;

		if($key eq 'at'){
			$param{'mode'} |= $html::ATONE;  # 単体発言表示

		}elsif($key eq 'res'){
			$param{'mode'} |= $html::RES;    # レス付け表示

		}elsif($key eq 'rev'){
			$param{'mode'} |= $html::REV;    # 発言修正表示
		}
	}
}

# パラメーターが重複していたら不正(st, en, at, res, rev)
my $st = $cgi->param('st');
my $en = $cgi->param('en');
my $ls = $cgi->param('ls');
error_illigal_call() if((defined($st) or defined($en) or defined($ls)) and $double_flag);

# 値が数値でなければエラー(st, en, at)
error_illigal_call() if (defined($st) and $st!~m/^\d+$/);
error_illigal_call() if (defined($en) and $en!~m/^\d+$/);
error_illigal_call() if (defined($ls) and $ls!~m/^\d+$/);

# 真偽値変換(tree, mes, sub)
$param{'mode'} |= $html::TREE    if (std::trans_bool($cgi->param('tree'), 0));
$param{'mode'} |= $html::MESSAGE if (std::trans_bool($cgi->param('mes'), 1));
$param{'mode'} |= $html::TITLE   if (std::trans_bool($cgi->param('sub'), 0));

# 発言とタイトルを両方表示しないということはない
error_complex() if ( $param{'mode'} & $html::TREE & $html::MESSAGE == 0);

# パラメーター矛盾していたら不正(at, res, rev, tree, mes, sub)
if ($param{'mode'} & $html::ATONE or
    $param{'mode'} & $html::RES   or
    $param{'mode'} & $html::REV      ){
	error_complex() if (defined($cgi->param('tree'))  or
	                    defined($cgi->param('mes'))   or
	                    defined($cgi->param('sub'))      );
}



# ログを読み取る
my @log;
error_fail_read($no) unless(file::read_log($no, \@log, 1, 0, 0));  # すべての情報を、ロックをかけないで、gz圧縮されていた場合は読まない

# 動作環境読み取り（後半：ログを読み取らないと記述できない場合）
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

$param{'mode'} |= $html::NO_REVISE if ($log[0]{'SIZE'} >= $CONF{'FILE_LIMIT'});   # 容量超過
$param{'mode'} |= $html::COMPLETE  if ($log[0]{'POST'} >= $CONF{'THREAD_LIMIT'}); # 発言数超過


#
# HTML表示
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
# リンクバー表示
#
html::link_3set_close(*STDOUT, $no);
html::hr(*STDOUT);

# フッタ表示
html::footer(*STDOUT);

exit;




##########################################################################
#                               単体発言表示                             #
##########################################################################
sub at{
	my $log   = shift;  # （参照）ログ
	my $param = shift;  # （参照）発言表示用

	my $no    = $$log[0]{'THREAD_NO'};
	my $title = $$log[0]{'THREAD_TITLE'};
	my $at    = $$param{'st'};

	# ヘッダ
	html::header(*STDOUT, "$$log[0]{'THREAD_TITLE'} - 単発言表示");

	# 冒頭説明文
	print "<h2 id='subtitle'>$$log[0]{'THREAD_TITLE'}</h2>\n\n";
	notice($$log[0]{'SIZE'}, $log[0]{'POST'});
	html::hr(*STDOUT);

	# 発言部分
	print "<div class='message'>";
	print "<h3 id='message'>発言表示</h3>\n\n";
	html::multi(*STDOUT, $log, $param);
	print "</div>\n\n";

	# リンクバー
	html::link_3set_close(*STDOUT, $no);
	html::hr(*STDOUT);

	# 関連ツリー
	print "<div class='subject'>\n\n";
	print "<h3 id='tree'>関連ツリー表示</h3>\n\n";

	my $flag_have_response=0;  # 関連ツリーがあった場合はこの値は真
	for(my $i=$at+1;$i<@$log;$i++){
		$flag_have_response=1 if (defined($$log[$i]{'RES'}) and $$log[$i]{'RES'}==$at);
	}
	$flag_have_response=1 if (defined($$log[$at]{'RES'}));

	if ($flag_have_response){
		html::tree(*STDOUT, $log, $param);
	}else{
		print "<p>この発言に関連する発言はありません。</p>\n\n";
	}
	print "</div>\n\n";

}

##########################################################################
#                           レス発言フォーム表示                         #
##########################################################################
sub res{
	my $log   = shift;  # （参照）ログ
	my $param = shift;  # （参照）発言表示用

	my $target = $$param{'st'};
	my $thread = $$log[0]{'THREAD_TITLE'};

	html::header(*STDOUT, "$thread - レス発言フォーム");
	print "<h2 id='subtitle'>$thread</h2>\n\n";
	html::hr(*STDOUT);

	# 説明
	print << "HTML";
<div class='howto'>

<h3 id='howto'>レス投稿</h3>

<p>スレッド名「${thread}」(スレッド番号${no})の発言${target}番へのレス投稿フォームを表示しています(→<a href='./bbs.html'>詳しい説明</a>)。</p>

</div>

HTML


	# リンクバー
	html::link_3set(*STDOUT, $no);
	print "<a href='#post'>レス投稿</a>　";
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# 発言表示
	print "<div class='message'>\n\n";
	print "<h3 id='message'>発言表示</h3>\n\n";
	html::multi(*STDOUT, $log, $param);
	print "</div>\n\n";

	# リンクバー
	html::link_3set_close(*STDOUT, $no);
	html::hr(*STDOUT);

	# レス発言フォーム
	form_new($log, $target);

}



##########################################################################
#                           発言修正フォーム表示                         #
##########################################################################
sub rev{
	my $log   = shift;  # （参照）ログ
	my $param = shift;  # （参照）発言表示用

	my $no     = $$log[0]{'THREAD_NO'};
	my $thread = $$log[0]{'THREAD_TITLE'};
	my $target = $$param{'st'};

	# ヘッダ～説明文
	html::header(*STDOUT, "$thread - 修正、削除用フォーム");

	print "<h2 id='subtitle'>$thread</h2>\n\n";
	html::hr(*STDOUT);
	print << "HTML";
<div class='howto'>

<h3 id='howto'>発言の削除、修正</h3>

<p>このフォームから<em class="thread">スレッド名「$thread」(スレッド番号${no}番)の${target}番発言</em>の修正、削除ができます。発言修正、削除を行うには投稿時に指定したパスワードが必要です。</p>

<p>パスワードを忘れてしまった発言の削除、中傷発言の削除、消してしまった発言を復活させたい場合などは<a href="mailto:$CONF{'ADMIN_MAIL'}">管理者</a>にご連絡ください。</p>

<p>管理者は人の発言を勝手に修正することはできません。したがってパスワードを忘れるとその投稿は誰にも修正できなくなります(管理者が消すことはできます)。</p>

</div>

HTML

	html::hr(*STDOUT);

	# リンクバー
	html::link_3set(*STDOUT, $no);
	print '<a href="#revise">発言修正</a>　';
	print '<a href="#delete">発言削除</a>　';
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# 発言表示
	print "<div class='message'>\n\n";
	print "<h3 id='message'>発言表示</h3>\n\n";
	html::multi(*STDOUT, $log, $param);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# リンクバー
	html::link_3set(*STDOUT, $no);
	print "<a href='#delete'>発言削除</a>　";
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# 発言修正フォーム
	form_rev($log, $target);
	html::hr(*STDOUT);

	# リンクバー
	html::link_3set_close(*STDOUT, $no);
	html::hr(*STDOUT);

	# 削除用フォーム
	form_del($log, $target);
	html::hr(*STDOUT);

}

##########################################################################
#                                 発言表示                               #
##########################################################################
sub mes{
	my $log   = shift;  # （参照）ログ
	my $param = shift;  # （参照）発言表示用

	my $no     = $$log[0]{'THREAD_NO'};
	my $thread = $$log[0]{'THREAD_TITLE'};
	my $mode   = $$param{'mode'};

	# 冒頭部分
	my $head;
	if (($mode & $html::TITLE) != 0){
		if (($mode & $html::MESSAGE) != 0){
			$head = '題名発言表示';
		}else{
			$head = '題名表示';
		}
	}else{
		$head = '発言表示';
	}
	html::header(*STDOUT, "$thread - $head");

	# スレッド名表示
	print "<h2 id='subtitle'>$$log[0]{'THREAD_TITLE'}</h2>\n\n";

	# 発言読み込みフォーム表示
	html::form_read(*STDOUT, $no, $#log);

	# 発言容量警告表示
	notice($$log[0]{'SIZE'}, $$log[0]{'POST'});

	# 0番発言表示
	if ($$param{'st'} > 0 and ($$param{'mode'} & $html::TITLE) != 0){
		my %sub_param;
		$sub_param{'st'} = 0;
		$sub_param{'en'} = 0;
		$sub_param{'no'} = $param{'no'};
		$sub_param{'mode'} = 0;
		html::multi(*STDOUT, $log, \%sub_param);
	}

	# リンクバー
	print '<div class="link">';
	html::link_top(*STDOUT);
	print '<a href="#message">発言表示</a>　' if(($mode & $html::TITLE) != 0 and ($mode & $html::MESSAGE) != 0);
	print '<a href="#newpost">新規投稿</a>　';
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::hr(*STDOUT);

	# 題名表示
	if (($mode & $html::TITLE) != 0){
		print "<div class='subject'>\n\n";
		print "<h3 id='subject'>題名表示</h3>\n\n";
		if (($mode & $html::TREE) != 0){
			html::tree(*STDOUT, $log, $param)
		}else{
			html::list(*STDOUT, $log, $param)
		}
		print "</div>\n\n";
	}

	# リンクバー
	if(($mode & $html::MESSAGE) != 0 and ($mode & $html::TITLE) != 0){
		html::link_3set(*STDOUT, $no);
		print "<a href='#newpost'>新規投稿</a>　";
		html::link_adminmail(*STDOUT);
		print "</div>\n\n";
		html::hr(*STDOUT);
	}

	# 発言表示
	if (($mode & $html::MESSAGE) != 0){
		print "<div class='message'>\n\n";
		print "<h3 id='message'>発言表示</h3>\n\n";
		if (($mode & $html::TREE) != 0){
			html::comment(*STDOUT, $log, $param);
		}else{
			html::multi(*STDOUT, $log, $param);
		}
		print "</div>\n\n";
	}

	# リンクバー
	html::link_3set_close(*STDOUT, $no);
	html::hr(*STDOUT);

	# 新規投稿
	form_new($log);
	html::hr(*STDOUT);

}

#
# 発言数超過警告表示
#
sub notice{
	my $amount = shift;  # スレッドの大きさ
	my $post = shift;    # 投稿数

	# スレッド制限に引っかからない場合は何も表示しない
	return if ($amount < $CONF{'FILE_CAUTION'} and $post < $CONF{'THREAD_CAUTION'});

	# スレッドの大きさをKB単位にする
	my $kb    = int($amount / 1000);
	my $limit = int($CONF{'FILE_LIMIT'} / 1000);

	# 警告・注意表示をする
	print "<div class='notice'>\n\n";

	# 上限に達した場合のメッセージ
	my $already_display = 0;
	if($amount >= $CONF{'FILE_LIMIT'}){
		print "<p class='warning'>スレッドの容量が上限($limit" . "KB)に達しました。これ以上投稿、修正はできません。</p>\n\n";
		$already_display = 1;
	}
	if($post >= $CONF{'THREAD_LIMIT'}){
		print "<p class='warning'>スレッドへの投稿数が上限($CONF{'THREAD_LIMIT'}発言)に達しました。これ以上投稿できません。</p>\n\n";
		$already_display = 1;
	}
	if($already_display){
		print "</div>\n\n";
		return;
	}

	# 警告表示（ファイル容量制限）
	if($amount >= $CONF{'FILE_WARNING'}){
		print '<p class="warning">';
	}elsif($amount >= $CONF{'FILE_CAUTION'}){
		print '<p class="caution">';
	}
	if ($amount >= $CONF{'FILE_CAUTION'}){
		print "スレッドの容量が$kb" . "KBを超えています。$limit" . "KBを超えると投稿、修正が出来なくなります。</p>\n\n";
	}

	# 警告表示（投稿量制限）
	if($post >= $CONF{'THREAD_WARNING'}){
		print "<p class='warning'>スレッドへの投稿数が$CONF{'THREAD_WARNING'}";
	}elsif($post >= $CONF{'THREAD_CAUTION'}){
		print "<p class='caution'>スレッドへの投稿数が$CONF{'THREAD_CAUTION'}";
	}
	if($post >= $CONF{'THREAD_CAUTION'}){
		print "発言を超えています。$CONF{'THREAD_LIMIT'}発言を超えると投稿が出来なくなります。</p>\n\n";
	}
	print "</div>\n\n";

}



##########################################################################
#                           新規投稿フォーム表示                         #
##########################################################################
sub form_new{
	my $log = shift;  # [参照]ログデータ
	my $res = shift;  #（レス発言の時）レス番号

	my $no = $$log[0]{'THREAD_NO'};

	my $message;
	my $title = '';
	my $body  = '';

	if(defined($res)){
		$message = 'レス発言投稿';
		$title = response($$log[$res]{'TITLE'});
		$body  = quote($$log[$res]{'BODY'});
	}else{
		$message = '新規発言投稿';
	}

	print "<div class='post'>\n\n";
	print "<h3 id='newpost'>$message</h3>\n\n";

	if($$log[0]{'SIZE'} >= $CONF{'FILE_LIMIT'} or $$log[0]{'POST'} >= $CONF{'THREAD_LIMIT'}){
		print '<p>スレッドの容量を超えているので';
		if (defined($res)){  print 'レス発言投稿';  }
		else{  print '新規投稿';  }
		print "は出来ません。</p>\n\n";

	}elsif(!defined($res) or !defined($$log[$res]{'DELETE_TIME'})){

		unless(defined($res)){
			print "<p>ここから、新規に発言を投稿することが出来ます。もし、ある発言にレスをつける場合はその発言を表示させてから「レスをつける」のリンク先に移動します。</p>\n\n";
		}

		html::formparts_head(*STDOUT);
		html::formparts_name(*STDOUT, undef, $title, $body, undef, undef);
		html::formparts_password(*STDOUT, 1, html::pass_message() );
		html::formparts_age(*STDOUT, 1, 1);
		html::formparts_foot(*STDOUT, $html::POST, $writecgi::POST, $no, $res);

	}else{
		print "<p>すでに発言が削除されているのでレスをつけることはできません。</p>\n\n";
	}
	print "</div>\n\n";

}

# 引用符をつける
sub quote{
	my $body = shift;
	$body = "\n" . $body;
	$body=~s/\n/\n&gt; /g;
	return substr($body, 1);
}

# 発言にRE:をつける
sub response{
	my $title = shift;
	$title = 'Re:' . $title;
	$title =~s/^(Re:)+/Re:/i;
	return $title;
}



##########################################################################
#                           発言修正フォーム表示                         #
##########################################################################
sub form_rev{
	my $log    = shift;  #（参照）ログデータ
	my $target = shift;  # 修正を行なう発言番号

	print "<div class='revise'>\n\n";
	print "<h3 id='revise'>発言修正</h3>\n\n";

	if($$log[0]{'SIZE'} >= $CONF{'FILE_LIMIT'}){
		print "<p>スレッドの容量を超えているので修正できません。</p>\n\n";

	}elsif(defined($$log[$target]{'DELETE_TIME'})){
		print "<p>この発言はすでに削除されているので修正できません。</p>\n\n";

	}elsif(defined($$log[$target]{'CORRECT_TIME'}) && @{$$log[$target]{'CORRECT_TIME'}} >= $CONF{'CHANGE_LIMIT'}){
		print "<p>$CONF{'CHANGE_LIMIT'}回を超えて発言を修正することはできません。</p>";

	}else{

		if (defined($$log[$target]{'CORRECT_TIME'})){
			my $limit = $CONF{'CHANGE_LIMIT'} - @{$$log[$target]{'CORRECT_TIME'}};
			print "<p>あと${limit}回発言を修正できます。</p>\n\n";
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
#                           発言削除フォーム表示                         #
##########################################################################
sub form_del{
	my $log    = shift;  #（参照）発言ログ
	my $target = shift;  # 消す発言の番号

	print "<div class='delete'>\n\n";
	print "<h3 id='delete'>発言削除</h3>\n\n";
	if(defined($$log[$target]{'DELETE_TIME'})){
		print "<p>この発言はすでに削除されています。</p>\n\n";
		print "</div>\n\n";
		return;
	}

	html::formparts_delete($$log[0]{'THREAD_NO'}, $target);

}



##########################################################################
#                     URIパラメーター並べ替えチェック                    #
##########################################################################
sub regularization{
	my $query = shift;
	my $cgi = shift;
	my @reg = (
	           'no', 'st', 'en', 'ls', 'at',
	           'res', 'rev', 'sub', 'mes', 'tree',
	          );

	# クエリー並べ替え
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
#                             URI転送して終了                            #
##########################################################################
sub location{
	my $query = shift;
	print "Status: 302 Found\n";
	print "Location: $CONF{'BASE_HTTP'}$file::READ_SCRIPT?$query\n\n";
	exit;
}


##########################################################################
#                         read.cgi エラーメッセージ                      #
##########################################################################

#
# 環境ファイルが読み取れない
#
sub error_fail_conf{
	error_head();
	print "<p>'bbs.conf'環境ファイルが読み取れないか、または不正です。</p>\n\n";
	error_foot();
	exit;
}
#
# ログが読み取れない
#
sub error_fail_read{
	my $no = shift;

	my $gz_log = file::public_name($no) . ".$file::EXT_GZIP";
	my $html   = file::html_name($no);

	error_head();
	print '<p>';
	if(-f $html){
		print "スレッド番号${no}での議論は終了しました。";
		print "<a href='$html'>過去ログ</a>を参照してください。";

	}elsif(-f $gz_log){
		print "スレッド番号${no}での議論は終了しました。";
		print "ログがHTML化されるまでしばらくお待ちください。";

	}else{
		print "スレッド番号${no}は存在しません。";

	}
	print "</p>\n\n";
	error_foot();
	exit;
}


#
# 入力フォーム不正
#
sub error_illigal_call{
	error_head();
	print "<p>入力フォームが不正なため、発言を表示させることができません。</p>\n\n";
	error_foot();
	exit;
}


#
# 入力数値が範囲外
#
sub error_over_value{
	error_head();
	print "<p>与えられた値がデータの範囲外のため、発言を表示させることができません。</p>\n\n";
	error_foot();
	exit;
}

#
# 入力数値が矛盾
#
sub error_complex{
	error_head();
	print "<p>与えられた値に矛盾があるため、発言を表示させることができません。</p>\n\n";
	error_foot();
	exit;
}






#
# その他
#
sub error_other{
	my $hint = shift;
	error_head();
	print "<p>バグりました。すみません。hint:$hint</p>\n\n";
	error_foot();
	exit;
}


#
# エラー共通処理
#
sub error_head{
	my $err_mes = 'read.cgiエラー発生';
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
#                              テスト用領域                              #
##########################################################################



