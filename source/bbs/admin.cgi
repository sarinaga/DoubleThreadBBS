#!/usr/bin/perl -w
#
#
# マルチスレッド掲示板 - 書き込みスクリプト
#
#                                          2003.01.14 さゆりん先生
#
use strict;
use CGI;
use Digest::SHA 'sha512';
use utf8;
binmode(STDOUT, ":utf8"); 
binmode(STDERR, ":utf8"); 

BEGIN{
	if ($ENV{'HTTP_HOST'}){
		use CGI::Carp qw(carpout);
		use POSIX qw(strftime);
	    my @tm = localtime;
		open(LOG, strftime(">>error%Y%m%d%H%M%d.log", @tm));
		binmode(LOG, ":utf8"); 
		carpout(*LOG);
		warn "admin.cgi log start.\n";
	}
}
END{
	warn "admin.cgi log end.\n";
}

unless($ENV{'HTTP_HOST'}){
	print "このプログラムはCGI用です. コマンドラインからの実行はできません. \n";
	exit;
}

require './html.pl';
require './std.pl';
require './file.pl';
require './configReader.pl';


#
# コマンドの文法
#
# n - 単一数値
# N - 複数数字
# s - 英数字
# S - 英数字[パスワード]
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
# コマンド処理結果
#
use vars qw(%RESULT);
$RESULT{'OK'}      = '○';  # 正常終了
$RESULT{'PART'}    = '△';  # 部分終了
$RESULT{'BAD'}     = '×';  # 異常終了
$RESULT{'INVALID'} = '＝';  # 処理不能
$RESULT{'IGNORE'}  = '－';  # コマンド無効

#
# 管理者用パスワード最小長さ
#
use vars qw($PASSWORD_LENGTH);
$PASSWORD_LENGTH = 8;




#--------------------------------------------------------------------------
#                              動作環境を読み込み
#--------------------------------------------------------------------------
use vars qw($CONF);
error_fail_conf() unless($CONF = configReader::readConfig());
$html::CONF = $CONF;
$file::CONF = $CONF;

#--------------------------------------------------------------------------
#                                 フォーム取得
#--------------------------------------------------------------------------
#
# 受け付けるCGIフォームの種類と内容は以下の通り
#
# user    = 管理者ID
# pass    = パスワード
# command = 入力コマンド
#

# 容量が大きすぎるときはエラー
post_huge() if ($ENV{'CONTENT_LENGTH'} > $CONF->{'resource'}->{'bufferLimit'});

# フォームデータ取得
my $cgi = new CGI;
my $userid   = $cgi->param('user');
my $password = $cgi->param('password');
my $command  = $cgi->param('command');
$command=~s/\x0D\x0A/\n/g;
$command=~tr/\x0D\x0A/\n\n/;

#--------------------------------------------------------------------------
#                              パスワード確認
#--------------------------------------------------------------------------
# パスワードファイル読み込み
use vars qw(%PASS);
my $password_command_flag = 0;    # パスワードコマンドがある？
if ($command=~m/password/i){      # パスワードコマンドがあるときだけファイルをロック
	no_password_file() unless(file::filelock(file::adminpass_name()));
	$password_command_flag = 1;
}
no_password_file() unless(file::read_adminpass(\%PASS));           # 読み込み
invalid_call() unless($userid);
if ( !exists($PASS{$userid}) or $PASS{$userid} ne unix_md5_crypt($password, $PASS{$userid}) ){
	file::unlock(file::adminpass_name());
	unmatch_password();
}


#--------------------------------------------------------------------------
#                 コマンド読み取り、ログファイル読み込み、処理
#--------------------------------------------------------------------------
my @command_lines = split(/\n/, $command);  # コマンド行ごとに分割
my @errors;                                 # 結果集計格納用
my $change_password_flag = 0;               # パスワード変更？

foreach my $c_line(@command_lines){

	# コマンドを解読
	my ($c, @p) = read_command($c_line);   # $c is command, @p is parameters.

	# コマンド隠蔽
	my ($sub_phased_command, undef, undef) = split(/:/, $c_line, 3);
	$c_line = "$sub_phased_command:?????:?????" if (uc($sub_phased_command) eq 'PASSWORD');

	# 1コマンド結果格納用
	my $error = $RESULT{'OK'};

	# コマンドによる処理の分岐
	# 該当コマンドがないか、不正なコマンドの使い方をした
	if(!defined($c)){
		$error = $RESULT{'IGNORE'};

	# 発言を読む@
	}elsif($c eq 'READ' or $c eq 'TREEREAD'){
		$error = display_command($c_line, $c, @p);

	# 発言の削除変更等@
	}elsif($c eq 'DEL' or $c eq 'TREEDEL' or $c eq 'UNDEL' or  $c eq 'TOMATO' or $c eq 'UNTOMATO' ) {
		$error = write_command($c, @p, $userid);

	# スレッドをageる@
	}elsif($c eq 'AGE'){
		$error = age($p[0]);

	# 発言保管等@
	}elsif($c eq 'DAT' or  $c eq 'UNDAT'){
		$error = dat($c, $p[0]);

	# 倉庫発言のHTML化
	}elsif($c eq 'HTML'){
		$error = html($p[0]);

	# スレッド一覧表示@
	}elsif($c eq 'THREADLIST'){
		$error = thread_list($c_line);

	# スレッド系処理 @refresh  xcompress
	}elsif($c eq 'REFRESH' or $c eq 'COMPRESS'){
		$error = thread_command($c);

	# パスワード変更@
	# これは直接処理
	}elsif($c eq 'PASSWORD'){
		if ($p[0] ne $p[1]){
			$error = $RESULT{'INVALID'};
		}else{
			$change_password_flag = 1;
			$PASS{$userid} = unix_md5_crypt($p[0], std::salt());
			$error = $RESULT{'OK'};
		}
	}

	# 結果を格納
	push(@errors, "$error - $c_line");

}



#--------------------------------------------------------------------------
#                                    締め
#--------------------------------------------------------------------------

# http-responce-headerとHTMLヘッダ出力
html::http_response_header();
html::header(*STDOUT , '管理コマンド実行');

# パスワードファイル処理
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

# 結果出力（成否の表示）
print "<h2>コマンド処理結果</h2>\n";
print "<div class='command'>\n";
foreach my $line(@errors){
	print "$line<br />\n";
}
print "</div>\n\n";
print "<p>コマンド処理が終了しました。</p>\n";


# 結果出力（表示系コマンドがある場合）
my $tempfile = temp_filename();
if (open(FIN, $tempfile)) {
	print "<p>以下はデータ表示系コマンドの結果です。</p>\n\n";
	print "<div class='result'>\n";
	until(eof(FIN)){
		my $line = <FIN>;
		utf8::decode($line);
		print "$line";
	}
	print "</div>\n\n";
	close(FIN);
	unlink($tempfile);

}


# リンクバー表示とHTMLの終了
print "<div class='link'>";
html::link_top(*STDOUT);
html::link_adminmode(*STDOUT);
html::link_adminmail(*STDOUT);
print "</div>\n\n";
html::footer(*STDOUT);
exit;


###########################################################################
#                            読み取り表示系コマンド                       #
###########################################################################
sub display_command{

	# 引数受け取り(解析前コマンドライン、コマンド種類、スレッド番号、発言番号)
	my ($purecommand, $command, $no, $num) = @_;

	# ログ読み取り / 一時ロックで読む
	my @log;
	return $RESULT{'BAD'} unless(file::read_log($no, \@log, 1, 0, 1));

	# 読み込む発言の一覧作成
	my @nums;
	if ($command eq 'READ'){
		@nums = read_number($num, @log-1);
	}elsif ($command eq 'TREEREAD'){
		@nums = html::search_thread(\@log, $num, $num);
		foreach my $num(@nums){
			($num, undef) = split(/:/, $num, 2);
		}
	}

	# パラメーター設定
	my %param;
	$param{'st'} = 0;
	$param{'en'} = @log - 1;
	$param{'no'} = $no;
	$param{'mode'} = $html::ADMIN;

	# テンポラリファイルを開いて、そこにログを書き込む
	my $filename = temp_filename();
	unless (open(FOUT, ">>$filename")) {
		open(FOUT, ">$filename") or return $RESULT{'BAD'};
	}
	binmode(FOUT, ":utf8");	
	print FOUT "<div class='commandline'>$purecommand</div>\n";
	print FOUT "<dl class='message'>\n\n";
	foreach my $i(@nums){
		html::mes_one(*FOUT, $i, \@log, \%param);
	}
	print FOUT "</dl>\n\n";
	close(FOUT);

	# 正常終了
	return $RESULT{'OK'};
}


###########################################################################
#                              書き込み系コマンド                         #
###########################################################################
sub write_command{
	my ($c, $no, $num, $admin) = @_;   # $c is command, $no is therad number, $num is post number.

	# ログを読み取る
	my @log;
	return $RESULT{'BAD'} unless(file::read_log($no, \@log, 1, 1, 0));  # ロック継続で読む

	# 処理を行う発言をピックアウト
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

	# データ削除/復活処理
	foreach my $n(@nums){   # $n is processing post number.

		next if ($n>= @log);      # ログ範囲外の場合は処理しない

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

	# 発言更新
	return file::write_log(\@log) ? $RESULT{'OK'} : $RESULT{'BAD'};

}


###########################################################################
#                              スレッドをageる                            #
###########################################################################
sub age{
	# 情報取得
	my $thread = shift;                              # パラメータ値読み込み
	my $pointer = file::read_pointer(0);             # ポインタ値読み込み
	return $RESULT{'BAD'} if (!defined($pointer));   # ポインタ値異常
	my @threads = read_number($thread, $pointer-1);  # 数値解析（注:$pointerを-1するのは
	                                                 # 次のポインタを指しているから）
	# age処理
	my $c=0; # $cは処理できたスレッドの数
	foreach my $no(@threads){
		my @log;
		next unless(file::read_log($no, \@log, 1, 1, 0));  # ロック継続で読む
		$log[0]{'AGE_TIME'} = time();
		unless (file::write_log(\@log)){  clear($no) ;  }
		else { ++$c;  }
	}

	# 結果返却
	if (!$c){
		return $RESULT{'BAD'};
	}elsif ($c == scalar @threads){
		return $RESULT{'OK'};
	}
	return $RESULT{'PART'};
}


##########################################################################
#                            スレッド保存操作                             #
##########################################################################
sub dat{
	my ($c, $p) = @_;
	my $pointer = file::read_pointer(0);
	return $RESULT{'BAD'} if (!defined($pointer));
	my @thread = read_number($p, $pointer-1);

	my $i = 0; # $iは処理できたスレッドの数
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
#                              HTML化保存操作                             #
##########################################################################
sub html{
	my $no = shift;

	my $pointer = file::read_pointer(0);
	return $RESULT{'BAD'} if (!defined($pointer));
	my @thread = read_number($no, $pointer-1);

	my $c = 0;  # $c is count.
	foreach $no(@thread){

		my $filename = file::public_name($no) . ".$file::EXT_GZIP";
		next unless (-f $filename);     # datログがない時は次のスレッドへ

		my @log;
		next unless(file::read_log($no, \@log, 1, 1, 1));
		                                # ログが読めない時は次のスレッドへ

		my $htmlfile = file::html_name($no);

		open(FOUT, ">$htmlfile") or next;  # ログ出力ファイル
		binmode(FOUT, ":utf8");	

		html::header(*FOUT, "$log[0]{'THREAD_TITLE'} - 過去ログ表示", 0, undef, undef, 1);

		# リンクバー1
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

		# リンクバー2
		print FOUT '<div class="link">';
		html::link_top(*FOUT);
		html::link_exit(*FOUT);
		html::link_adminmail(*FOUT);
		print FOUT "</div>\n\n";

		html::footer(*FOUT);

		close(FOUT);
		#unlink($filename);	# html化したログファイルは削除する
		file::clear($no);
		++$c;
	}

	# 結果を返す
	if (!$c){
		return $RESULT{'BAD'};
	}elsif($c < scalar @thread){
		return $RESULT{'PART'};
	}else{
		return $RESULT{'OK'};
	}

}



###########################################################################
#                              スレッド一覧表示                           #
###########################################################################
sub thread_list{
	my $c_line = shift;

	# スレッド一覧読み込み
	my @thread;
	return $RESULT{'BAD'} unless (file::thread_read(\@thread, 1) );

	# スレッド一覧出力
	my $filename = temp_filename();
	unless (open(FOUT, ">>$filename")) {
		open(FOUT, ">$filename") or return $RESULT{'BAD'};
	}
	binmode(FOUT, ":utf8");	
	print FOUT "<div class='commandline'>$c_line</div>\n";

	# スレッド一覧表示
	for(;;){

		# スレッドがない場合
		unless (scalar @thread > 0){
			print FOUT "<p>スレッドは存在しません。</p>\n\n";
			last;
		}

		# スレッドがある場合
		print FOUT "<table class='thread-list'><tbody>\n\n";
		foreach my $t(@thread){
			print FOUT '<tr><td class="no">';
			print FOUT "$$t{'THREAD_NO'}.";
			print FOUT '</td><td class="thread-admin">';
			print FOUT "$$t{'THREAD_TITLE'}($$t{'POST'})";
			print FOUT " [DAT状態]" if ($$t{'DAT'});
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

	# 正常終了
	return $RESULT{'OK'};
}


##########################################################################
#                          スレッド操作系コマンド                        #
##########################################################################
sub thread_command{
	my $command = shift;

	# スレッド一覧読み込み
	my @thread;
	return 0 unless (file::thread_read(\@thread));

	# 各種処理
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
#                          テンポラリファイル名作成                       #
###########################################################################
sub temp_filename{
	return file::temp_name('admin');
}


###########################################################################
#                              入力コマンド解析                           #
###########################################################################
sub read_command{
	my $str = shift;
	my @parameters = split(/:/, $str);
	foreach my $parameter(@parameters){
		$parameter =~s/^\s*//;
		$parameter =~s/\s*$//;
	}

	my $command;
	($command, @parameters) = @parameters;               # 一番最初はコマンド
	$command = uc($command);                             # コマンドの大文字小文字統一

	return () unless(exists($COMMAND_SYNTAX{$command})); # 実在しないコマンドが書かれた
	my $syntax = $COMMAND_SYNTAX{$command};
	return () if (length($syntax) != @parameters);       # 文法が合っていない

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
#                            複数指定番号を読み込む                       #
###########################################################################
sub read_number{
	my $str = shift;
	my $last = shift;

	$str =~s/[^0-9,\-\s]//g;             # 不正な文字は読み飛ばしてしまう
	my @parts = split(/,/ , $str);

	my @nums = ();
	foreach my $part(@parts){

		my ($st, $en) = split(/-/, $part, 2);

		next unless(defined($st));  # nullの場合

		$st = 0 if ($st eq '');

		unless(defined($en)){       # 数を1つだけ指定した場合
			$en = $st;
		}else{
			if ($en eq ''){     # ハイフン指定された場合
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

	my %seen;                            # 重複するデータを削除
	@nums = grep { !$seen{$_} ++} @nums;
	@nums = sort {$a <=> $b} @nums;      # 整列
	return @nums;
}



###########################################################################
#                           エラー表示共通処理                            #
###########################################################################
sub error_head{
	my $err_mes = 'admin.cgiエラー発生';
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
#                               エラー表示                                #
###########################################################################

#
# 投稿が大きすぎる
#
sub post_huge{
	error_head();
	print "<p>コマンドを実行させすぎです。</p>\n\n";
	error_foot();
	exit;

}

#
# 不正なCGI呼び出し
#
sub invalid_call{
	error_head();
	print "<p>不正な呼び出しです。</p>\n\n";
	error_foot();
	exit;

}



#
# パスワード不一致
#
sub unmatch_password{
	error_head();
	print "<p>パスワードが一致しません。もう一度やり直してください。</p>\n\n";
	error_foot();
	exit;

}


#
# コンフィグファイルがが読み取れない
#
sub no_conf{
	error_head();
	print "<p>コンフィグファイルが読み取れないか、または不正です。</p>\n\n";
	error_foot();
	exit;
}


#
# パスワードファイルが読み取れない
#
sub no_password_file{
	error_head();
	print "<p>パスワードファイルが読み取れないか、または不正です。</p>\n\n";
	error_foot();
	exit;
}














