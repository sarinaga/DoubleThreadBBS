#!/usr/bin/perl -w
#!C:/Perl/bin/perl -w
#
#
# マルチスレッド掲示板 - 書き込みスクリプト
#
#                                          2002.10.23 さゆりん先生
#
use strict;
use utf8;
use CGI;
use Crypt::PasswdMD5;
use Digest::SHA 'sha1';
use Time::localtime;
use POSIX qw(strftime);

# ログ出力のヘッダとフッタ
BEGIN{
	if ($ENV{'HTTP_HOST'}){
	    my $tm = localtime;
		use CGI::Carp qw(carpout);
		open(LOG, strftime(">../log/error%Y%m.log", $tm));
		carpout(*LOG);
	}
	print LOG "write.cgi log start.\n";
}
END{
	print LOG "write.cgi log end.\n";
	close(LOG);
}

require './html.pl';
require './file.pl';
require './std.pl';
require './write.pl';


# CGI以外の場合は動作させない(簡易的なもの)
unless($ENV{'HTTP_HOST'}){
	print "このプログラムはCGI用です. コマンドラインからの実行はできません. \n";
	exit;
}


#--------------------------------------------------------------------------
#                                    共通変数
#--------------------------------------------------------------------------
my $cgi = new CGI;
use vars qw($INIT $INITBAK);
$INIT    = './init.html';
$INITBAK = './init.html.bak';


#--------------------------------------------------------------------------
#                             動作環境を読み込み
#--------------------------------------------------------------------------

# コンフィグファイル読み込み
use vars qw(%CONF);
other() unless(file::config_read(\%CONF));


#--------------------------------------------------------------------------
#                              必要データ取得
#--------------------------------------------------------------------------
#
# 受け付けるCGIフォームの種類と内容は以下の通り
#
# mode       = 投稿モード(create|revise|delete|post)
# no         = スレッド番号（mode=createの時はなし）
# target     = 修正、削除する発言番号(mode=revise|deleteの場合のみ)
# res        = レス先番号（mode=postの場合のみ）
# thread     = スレッド名 (mode=createの場合のみ)
# title      = 発言タイトル(mode=deleteの時はなし)
# name       = 投稿者氏名(mode=deleteの時はなし)
# trip       = トリップ(mode=revise|deleteの時はなし)
# web        = ウェブページアドレス(mode=deleteの時はなし)
# email      = emailアドレス(mode=deleteの時はなし)
# pass       = 発言削除用パスワード
# age        = スレッドage(mode=post以外の時はなし)
# body       = 本文部分
# cookie     = cookie
# sage       = age/sage
# admin      = 特権モード名前
# set_cookie = cookieを利用するかどうか
# build      = 初回起動時、ディレクトリやスレッド一覧を構成する
#

# 容量が大きすぎるときはエラー
post_huge() if ($ENV{'CONTENT_LENGTH'} > $CONF{'BUFFER_LIMIT'});

# データをパラメータから取得
my $no         = $cgi->param('no');                          # スレッド番号
my $mode       = $cgi->param('mode');                        # 操作モード
my $target     = $cgi->param('target');                      # 発言修正番号または発言削除番号
my $res        = $cgi->param('res');                         # レス先番号
my $web        = std::html_escape($cgi->param('web'));       # httpアドレス
my $trip       = $cgi->param('trip');                        # ユーザトリップ
my $email      = std::html_escape($cgi->param('email'));     # emailアドレス
my $password   = $cgi->param('pass');                        # パスワード
my $sage       = $cgi->param('sage');                        # スレッドを上げるか上げないか
my $admin      = $cgi->param('admin');                       # (未使用)
my $set_cookie = $cgi->param('cookie');                      # Cookie利用
my $build      = $cgi->param('build');                       # 掲示板初期起動時フラグ
my $tomato     = $cgi->param('tomato');                      # IPアドレス晒し
my $thread     = std::html_escape($cgi->param('thread'));    # スレッド名
my $title      = std::html_escape($cgi->param('title'));     # 題名
my $name       = std::html_escape($cgi->param('name'));      # 投稿者名
my $body       = std::html_escape($cgi->param('body'));      # 本文


# 初めて掲示板を動作させるときの初期化処理
if (std::trans_bool($build)){
	build() if (-f $INIT);
	bad_request();
}

# スレッド再構成以外の場合はPOSTで呼び出さなければいけない
bad_request()  if ($ENV{'REQUEST_METHOD'} ne 'POST');


#--------------------------------------------------------------------------
#                                 データ洗浄
#--------------------------------------------------------------------------
# モードが正しいかどうか調べる
illigal_form() unless($mode eq $writecgi::CREATE or $mode eq $writecgi::REVISE or   # モード違い
                      $mode eq $writecgi::DELETE or $mode eq $writecgi::POST);


# 発言修正ができない設定なのにrevise, deleteの要求が来ていたらエラー
no_change() if (($mode eq $writecgi::DELETE or $mode eq $writecgi::REVISE) and !$CONF{'ACCEPT_CHANGE'});


# 新規スレッド作成で、スレ建て規制制限数に達した人のときはエラー
over_thread() if (($mode eq $writecgi::CREATE) and check_builder());


# 新規スレッド作成で、スレッド作成禁止の場合はエラー
cant_create_thread() if (($mode eq $writecgi::CREATE) and $CONF{'THREAD_MAX'} == 0);

# (やりたくないのだが)bodyにhttp://が含まれる場合、無理矢理rejectする
if ($body=~m/http:\/\//){
	std::goto404();
	exit;
}

# (やりたくないのだが)titleが英語だけの場合、無理矢理rejectする
if ($title=~m/^[\w\s]+$/){
	std::goto404();
	exit;
}


# 改行文字修正
my $trans = join('<>', $thread, $title, $name, $body);
$trans=~s/\x0D\x0A/\n/g;
$trans=~tr/\x0D\x0A/\n\n/;
$trans=~s/\n{4,}/\n\n\n/g;
$trans=~s/\n*$//;
($thread, $title, $name, $body) = split(/<>/, $trans);


# スレッド名洗浄
if ($mode eq $writecgi::CREATE){  lack_thread() if ($thread eq '');  }
else{  illigal_form() if ($thread ne '');  }


# スレッド番号洗浄
if ($mode eq $writecgi::CREATE){
	illigal_form() if ($no ne '');
}else{
	illigal_form() unless($no=~m/^(\d+)$/);
	$no = $1;
}

# 発言番号洗浄
if ($mode eq $writecgi::REVISE or $mode eq $writecgi::DELETE){
	illigal_form() unless($target=~m/^\d+$/);
}else{
	illigal_form() if ($target ne '');
}

# レス番号洗浄
if ($mode eq $writecgi::POST){
	illigal_form() unless($res=~m/^\d*$/);
	$res = undef if($res eq '');
}else{
	illigal_form() if ($res ne '');
}


# タイトル, 名前, URI, emailアドレス洗浄
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

# トリップ洗浄
if ($mode eq $writecgi::DELETE or $mode eq $writecgi::REVISE){
	illigal_form() if($trip ne '');
}else{
	illigal_trip() unless($trip=~m/^[\da-zA-Z]{0,$CONF{'TRIP_INPUT_LENGTH'}}$/);
}


# パスワード洗浄
if ($mode eq $writecgi::CREATE or $mode eq $writecgi::POST){
	illigal_password() unless($password=~m/^[\da-zA-Z]{$writecgi::PASS_LENGTH_MIN,$CONF{'PASSWORD_LENGTH'}}$/);
}


# sage洗浄
if ($mode eq $writecgi::POST){
	$sage = std::trans_bool($sage, 0);
	illigal_form() unless(defined($sage));
}else{
	illigal_form() if ($sage ne '');
	$sage = ($mode eq $writecgi::CREATE) ? 0 : 1;
}

# tomato洗浄
if ($mode eq $writecgi::CREATE or $mode eq $writecgi::POST){
	$tomato = std::trans_bool($tomato, 0);
	illigal_form() unless(defined($tomato));
}else{
	illigal_form() if ($tomato ne '');
}


#-------------------------------------------------------------------------
#                             ログ読み取り
#-------------------------------------------------------------------------
# 新規ログ作成の時はログファイルを新規作成し、ヘッダ部分データを作成する
my @log;
if($mode eq $writecgi::CREATE){
	$no = file::read_pointer(1);      # ロックをかけっぱなしにする設定でポインタを読む
	fail_read() unless(defined($no)); # ポインタが読めなかった
	fail_write() unless(create($no)); # ログ仮ファイルを作る

# 投稿、修正、削除の時はログを読み取る
}else{
	fail_read() unless(file::read_log($no, \@log, 1, 1, 0));   # ロックをかける、全部読む、gz圧縮対応をしない
}


# 連続投稿制限を超えるときはエラー（新規・レス投稿の場合）
if ($mode eq $writecgi::POST){
	if (check_chain_post(\@log)){
		clear($no);
		post_chain();
	}
}


# 発言番号が制限を越える時はエラー（新規・レス投稿の場合）
if ($mode eq $writecgi::POST){
	$target = @log;
	if ($target >= $CONF{'THREAD_LIMIT'}){
		clear($no);
		thread_over();
	}
}

# スレッド容量が制限を越える場合はエラー
if ($mode ne $writecgi::DELETE){
	if ($log[0]{'SIZE'} >= $CONF{'FILE_LIMIT'}){
		clear($no);
		file_over();
	}
}

# ログと入力フォームの整合性を確認する
if ($mode eq $writecgi::DELETE or $mode eq $writecgi::REVISE){

	# 存在しない発言を操作？
	if ($target >= @log){
		clear($no);  illigal_form();
	}

	# すでに発言削除されている？
	if (defined($log[$target]{'DELETE_TIME'})){
		clear($no);  already_delete();
	}

    # パスワード照合
	if ($log[$target]{'PASSWORD'} ne unix_md5_crypt($password, $log[$target]{'PASSWORD'})){
		clear($no);  mismatch_password();
	}
}


# レス先発言が存在するかどうかを調べる
if ($mode eq $writecgi::POST and defined($res)){

	# 存在しない発言にレス？
	if($res >= @log){
		clear($no);  illigal_form();
	}

	# レス先発言が消えている
	if(defined($log[$res]{'DELETE_TIME'})){
		clear($no);  res_lost()
	}
}

# 発言修正回数を超えて変更しようとしたらエラー
if ($mode eq $writecgi::REVISE and defined($log[$target]{'CORRECT_TIME'})){
	if (@{$log[$target]{'CORRECT_TIME'}} >= $CONF{'CHANGE_LIMIT'}){
		clear($no);
		change_limit();
	}
}


#--------------------------------------------------------------------------
#                                ログ修正処理
#--------------------------------------------------------------------------

# 新規投稿処理
my $ip = $ENV{'REMOTE_ADDR'};
if ($mode eq $writecgi::POST){

	# 発言番号を１つ進める
	++$log[0]{'POST'};


# 新規スレッド作成処理
}elsif($mode eq $writecgi::CREATE){
	$target = 0;
	$log[0]{'POST'} = 1;
	$log[0]{'THREAD_TITLE'} = $thread;
	$log[0]{'THREAD_NO'} = $no;
	$log[0]{'BUILDER_IP_ADDR'} = $ip;
	$log[0]{'BUILDER_IP_HOST'} = std::gethost($ip);
}

# 最後にあげられた時間
$log[0]{'AGE_TIME'}  = time() if(!$sage or $mode eq $writecgi::CREATE);

# 発言番号
$log[$target]{'NO'}           = $target;                                 # 発言番号
$log[$target]{'RES'}          = $res if(defined($res));                  # レス先番号


# 発言タイトル、ユーザ名、email、ウェブページアドレス、本文（新規スレッド作成、新規発言、発言修正）
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

# 投稿IPアドレス(numberic, FQDN)、利用ユーザエージェント
push(@{$log[$target]{'IP_ADDR'}}, $ip);
push(@{$log[$target]{'IP_HOST'}}, std::gethost($ip));
push(@{$log[$target]{'USER_AGENT'}}, $ENV{'HTTP_USER_AGENT'});

# 投稿時間、パスワード、ユーザID（新規スレッド作成、新規発言）
if ($mode eq $writecgi::POST or $mode eq $writecgi::CREATE){
	$log[$target]{'POST_TIME'}   = time();
	$log[$target]{'PASSWORD'}    = unix_md5_crypt($password, std::salt());
	$log[$target]{'USER_ID'}     = create_id($ip) if ($CONF{'CREATE_ID'});
}

if ($mode eq $writecgi::DELETE){  $log[$target]{'DELETE_TIME'} = time(); }            # 発言削除時間（発言削除）
if ($mode eq $writecgi::REVISE){  push(@{$log[$target]{'CORRECT_TIME'}}, time());  }  # 発言修正時間（発言修正）


# 二重投稿排除処理
if ($mode eq $writecgi::POST){
    if (chack_dupe_post(\@log)){
		clear($no);
		post_dupe();
	}
}

#--------------------------------------------------------------------------
#                               ログ書き出し処理
#--------------------------------------------------------------------------

# 新規スレッド作成の時はポインタ値更新
if ($mode eq $writecgi::CREATE){
	my $pointer = $no + 1;
	unless(file::write_pointer($pointer)){
		clear($no);
		unlink(file::public_name($no));
		unlink(file::secret_name($no));
		fail_write();
	}
}

# 本ログ書き出し
fail_write() unless(file::write_log(\@log));

# スレッド一覧吐き出し
age() if(!$sage or $mode eq $writecgi::CREATE);


#--------------------------------------------------------------------------
#                              Cookieデータ作成
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
#                             終了メッセージ表示
#--------------------------------------------------------------------------

# 処理形態を判別
my $process;
$process = '新規スレッド作成' if ($mode eq $writecgi::CREATE);
$process = '発言修正'         if ($mode eq $writecgi::REVISE);
$process = '発言削除'         if ($mode eq $writecgi::DELETE);
if ($mode eq $writecgi::POST){
	if (defined($res)){  $process = 'レス発言投稿';  }
	else{ $process = '新規投稿';  }
}
$process .= '処理終了';


# http_response_header 出力
html::http_response_header();


# htmlヘッダ出力
if ($mode eq $writecgi::POST or $mode eq $writecgi::CREATE){
	html::header(*STDOUT , $process, undef, \%cookie, $expires);
}else{
	html::header(*STDOUT , $process);
}


# 終了メッセージ以下表示
print "<h2>$process</h2>\n\n";
print "<p>書き込みが終了しました。</p>";

# 次の発言読み込みフォームを表示
if ($mode eq $writecgi::DELETE){
	html::form_read(*STDOUT, $no, $#log);

}else{
	html::form_read(*STDOUT, $no, $#log, $target,
	                $mode eq $writecgi::REVISE ? '修正' : '投稿');
}

# リンクバー
print '<div class="link">';
html::link_top(*STDOUT);
html::link_adminmail(*STDOUT);
print "</div>\n\n";

html::footer(*STDOUT);

exit;




###########################################################################
#                    初回掲示板起動時の初期化プロセス                     #
###########################################################################
sub build{

	# すでにビルドされているかどうかを判定する
	my $pointer = file::read_pointer();

	# すでに掲示板が働いている場合は処理を行わない
	already_build() if (defined($pointer));

	# ディレクトリ、ポインタファイルの作成（初期化）
	fail_build() unless(file::init());

	# スレッドをあげる操作を行うとbbs.htmlが生成される
	fail_build() unless(age());

	# admin.htmlファイルの更新を行う
	fail_build() unless(file::create_adminpage());

	# 終了メッセージ表示
	html::http_response_header();
	html::header(*STDOUT , '掲示板初期化処理終了');
	print "<h2 id='complete-init'>初期化処理終了</h2>\n\n";
	print "<p>掲示板を初期化しました。以後、掲示板を利用することができます。</p>\n\n";
	print "<div class='link'>";
	html::link_exit(*STDOUT);
	html::link_top(*STDOUT);
	html::link_adminmail(*STDOUT);
	print "</div>\n\n";
	html::footer(*STDOUT);

	# 初期化ファイルの名前を変える
	rename ($INIT, $INITBAK);
	exit;
}


##########################################################################
#      新規スレッド作成の時、新しいログファイルを作る（中身なし）        #
##########################################################################
sub create{
	my $no = shift;     # スレッド番号

	my $log_public = file::public_name($no);
	my $log_secret = file::secret_name($no);

	# 仮ファイルを作る
	open(FOUT, ">$log_public") || return 0;
	close(FOUT);
	unless(open(FOUT, ">$log_secret")){
		unlink($log_public);
		return 0;
	}
	close(FOUT);

	# ファイル属性変更
	chmod($file::PUBLIC_FILE_PERMISSION, $log_public);
	chmod($file::SECRET_FILE_PERMISSION, $log_secret);

	# ロックをかける
	unless(file::filelock($log_public) and file::filelock($log_secret)){
		clear($no);
		unlink($log_public);  # ロックに失敗した時は新規スレッドは作れないので
		unlink($log_secret);  # 新しく作ったファイルを削除するしかない
		return 0;
	}

	return 1;
}


###########################################################################
#                ログファイルを集計してbbs.htmlを作成する                 #
#                    古くなったスレッドを圧縮処理する                     #
#                スレッドを建てすぎた人を検索し、記憶する                 #
###########################################################################
sub age{

	# スレッド一覧読み込み
	my @thread;
	my $read = file::thread_read(\@thread);
	#warn "read thread : $read\n";
	return 0 unless (defined($read));

	# スレッド数圧縮処理
	file::compress(\@thread);

	# スレッド設立制限数調査
	count_builder(\@thread);

	# bbs.htmlを更新させる[ここ以下の内容]
	return file::create_bbshtml(\@thread);

}



###########################################################################
#         スレッド設立制限数に達したIPアドレスを抜き出し、記録する        #
###########################################################################
sub count_builder{
	my $thread_list = shift;

	my %builder;
	foreach my $d(@$thread_list){

		next if ($$d{'DAT'});   # DAT行データは処理しない

		my $host = $$d{'BUILDER_IP_HOST'};
		my $addr = $$d{'BUILDER_IP_ADDR'};

		# ホスト名を集計する
		if(defined($builder{$host})){
			$builder{$host}++;
		}else{
			$builder{$host} = 1;
		}

		# ホスト名とIPアドレスが同じ時は次の処理を行わない
		next if ($host eq $addr);

		# IPアドレスを集計する
		if(defined($builder{$addr})){
			$builder{$addr}++;
		}else{
			$builder{$addr} = 1;
		}
	}

	# スレ建て規制に引っかかったものを抽出
	my @over_builder;
	foreach my $addr_host(keys %builder){
		push(@over_builder, $addr_host) if ($builder{$addr_host} >= $CONF{'THREAD_MAX'});
	}

	# スレ建てすぎブラックリスト出力
	return file::write_overbuilder(@over_builder);

}



###########################################################################
#                     投稿してきたIPアドレスの持ち主が                    #
#                 スレッドを立てすぎていないかどうかを判別                #
###########################################################################
sub check_builder{

	# IPアドレス取得
	my $ip_addr = $ENV{'REMOTE_ADDR'};     # 投稿者IP_ADDR
	my $ip_host = std::gethost($ip_addr);  # 投稿者IP_HOST

	# スレ建てすぎブラックリストを読み出す
	my @builder;
	file::read_overbuilder(\@builder);

	# スレッド建てすぎブラックリストに載っているときは
	# 真を返す
	foreach my $black(@builder){
		return 1 if ($black eq $ip_host);
		return 1 if ($black eq $ip_addr);
	}
	# 載っていないときは偽を返す
	return 0;
}

###########################################################################
#                連続投稿されているのかどうかをチェックする               #
###########################################################################
sub check_chain_post{
	my $log = shift;

	return 0 if ($CONF{'CHAIN_POST'} == 0);  # 連続投稿の監視をしない場合はFALSEを返す

	my $ip_addr = $ENV{'REMOTE_ADDR'};       # 投稿者IP_ADDR
	my $ip_host = std::gethost($ip_addr);    # 投稿者IP_HOST

	my $count = 0;  # 自分のIPアドレスがどのくらい出てきたかを数える
	for(my $i=@$log-1;$i>=0 and
	                  $$log[$i]{'POST_TIME'} >=time() - $CONF{'CHAIN_TIME'} * 60 ;--$i){

		my $last_addr = @{$log[$i]{'IP_ADDR'}} - 1;
		my $last_host = @{$log[$i]{'IP_HOST'}} - 1;

		$count++ if ($ip_addr eq $$log[$i]{'IP_ADDR'}[$last_addr] or
		             $ip_host eq $$log[$i]{'IP_HOST'}[$last_host]
		             );

		return 1 if ($count >= $CONF{'CHAIN_POST'});   # 超えたらエラー

	}

	return 0;
}

###########################################################################
#                     二重投稿されていないかチェックする                  #
###########################################################################
sub chack_dupe_post{
	my $log = shift;

	# 二重投稿比較部分
	my $last = @$log - 1;
	my $name  = $$log[$last]{'USER_NAME'};
	my $title = $$log[$last]{'TITLE'};
	my $body  = $$log[$last]{'BODY'};
	my $res   = $$log[$last]{'RES'};

	# 二重投稿かどうかチェックする
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
#              ポインタファイルとログファイルのロックを解除する           #
###########################################################################
sub clear{
	my $no = shift;
	file::unlock(file::pointer_name());
	file::clear($no);
}

###########################################################################
#                              ID番号製作                                 #
###########################################################################
sub create_id{
	my $ip = shift;  # ID作成の種(IPアドレス)

	my $id;
	my $seed = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ./';

	# 日付から種を作る
	my (undef, undef, undef, $day, $mon, $year, undef, undef, undef) = localtime();
	my $salt = substr($seed, $day, 1) . substr($seed, $mon, 1) . substr($seed, ($year % length($seed)) ,1);

	# 生成
	return substr(std::scramble($ip, $salt), 0, $CONF{'ID_LENGTH'});
}

###########################################################################
#                              トリップ製作                               #
###########################################################################
sub trip{
	return substr(std::scramble(shift, $CONF{'TRIP_KEY'}), 0, $CONF{'TRIP_OUTPUT_LENGTH'});
}



##########################################################################
#                        write.cgi エラーメッセージ                      #
##########################################################################

#
# 不正なCGI呼び出し
#
sub bad_request{
	error_head();
	print "<p>不正な方法でwrite.cgiが呼び出されました。</p>\n\n";
	error_foot();
}

#
# 不正なCGI入力値
#
sub illigal_form{
	error_head();
	my $no = shift;
	print "<p>仕様と合致しない方法でデータが送られてきました。$no</p>\n\n";
	error_foot();
}

#
# スレッド作成禁止
#
sub cant_create_thread{
	error_head();
	my $no = shift;
	print "<p>現在、スレッドの作成は禁止されています。$no</p>\n\n";
	error_foot();

}

#
# スレッド名が書かれていない
#
sub lack_thread{
	error_head();
	print "<p>スレッド名が記述されていません。</p>\n\n";
	error_foot();
}

#
# 本文が書かれていない
#
sub lack_body{
	error_head();
	print "<p>題名か本文のどちらか片方を記述しなければなりません。</p>\n\n";
	error_foot();
}


#
# 入力emailアドレスが不正
#
sub illigal_email{
	error_head();
	print "<p>e-mailアドレスが不正です。</p>\n\n";
	error_foot();
}

#
# 入力アドレス(http, email)が不正
#
sub illigal_http{
	error_head();
	print "<p>webpageアドレスが不正です。</p>\n\n";
	error_foot();
}


#
# 入力トリップが不正
#
sub illigal_trip{
	error_head();
	print "<p>トリップは$CONF{'TRIP_INPUT_LENGTH'}文字までの英数字を利用してください。</p>\n\n";
	error_foot();
}


#
# パスワードが不正
#
sub illigal_password{
	error_head();
	print "<p>パスワードは$writecgi::PASS_LENGTH_MIN文字以上$CONF{'PASSWORD_LENGTH'}文字以下の英数字を利用してください。</p>\n\n";
	error_foot();
}


#
# パスワード不一致
#
sub mismatch_password{
	error_head();
	print "<p>パスワードが一致しません。</p>\n\n";
	error_foot();
}


#
# ログの読み出しに失敗した
#
sub fail_read{
	error_head();
	print "<p>ログの読み込みに失敗しました。</p>\n\n";
	error_foot();
}


#
# ログの書き出しに失敗した
#
sub fail_write{
	error_head();
	print "<p>ログの更新に失敗しました。</p>\n\n";
	error_foot();
}


#
# スレッドを建てすぎている
#
sub over_thread{
	error_head();
	print "<p>これ以上スレッドを建てることはできません。</p>\n\n";
	error_foot();
}


#
# 発言投稿制限
#
sub post_chain{
	error_head();
	print "<p>短時間の間に書き込みすぎです。しばらく待ってから投稿し直してください。</p>\n\n";
	error_foot();
}


#
# 二重投稿
#
sub post_dupe{
	error_head();
	print "<p>二重投稿が行われたようです。</p>\n\n";
	error_foot();
}

#
# 発言容量超過
#
sub post_huge{
	error_head();
	print "<p>投稿された発言が大きすぎます。</p>\n\n";
	error_foot();
}

#
# スレッド容量超過（バイト数）
#
sub file_over{
	error_head();
	print "<p>あなたが発言を用意している間にスレッドの容量限界（$CONF{'FILE_LIMIT'}バイト）を超えたようです。";
	print "容量限界を超えたので発言、修正をすることはできません。</p>\n\n";
	error_foot();
}


#
# スレッド容量超過（投稿数）
#
sub thread_over{
	error_head();
	print "<p>あなたが発言を用意している間にスレッドの投稿数限界（$CONF{'THREAD_LIMIT'}番まで）を超えたようです。";
	print "投稿数限界を超えたので発言をすることはできません。</p>\n\n";
	error_foot();
}


#
# すでに発言が削除されている（修正、発言）
#
sub already_deleted{
	error_head();
	print "<p>あなたが発言を用意している間に発言が削除されました。";
	print "すでに消えた発言の修正、削除はできません。</p>\n\n";
	error_foot();
}

#
# すでに発言が削除されている（レス）
#
sub res_lost{
	error_head();
	print "<p>あなたが発言を用意している間にレス先発言が削除されました。";
	print "すでに消えた発言へのレス投稿はできません。</p>\n\n";
	error_foot();
}


#
# 発言修正ができないのに修正しようとした
#
sub no_change{
	error_head();
	print "<p>投稿者が発言を修正、削除することは許可されていません。</p>\n\n";
	error_foot();
}


#
# 発言修正制限を越えている
#
sub change_limit{
	error_head();
	print "<p>$CONF{'CHANGE_LIMIT'}回を超えて発言を修正することはできません。</p>\n\n";
	error_foot();
}



#
# すでにスレッド一覧は構成されている
#
sub already_build(){
	error_head();
	print "<p>すでに初期化されています。</p>\n\n";
	error_foot();
	exit;
}

#
# 初期化、スレッド一覧の構成に失敗した
#
sub fail_build{
	error_head();
	print "<p>初期化に失敗しました。</p>\n\n";
	error_foot();
	exit;
}



sub cant_encode_guess{
	error_head();
	print '<p>文字コードの変換に失敗しました。半角カナなど文字コードの判別を';
	print '混乱させるような文字を入力しないでください。また、本文をもっと長く';
	print "入力してみてください。</p>\n\n";
	error_foot();
	exit;
}


#
# その他のエラー
#
sub other{
	error_head();
	print "<p>バグりました。すみません。</p>\n\n";
	error_foot();
}



#
# エラー表示共通処理
#
sub error_head{
	my $err_mes = 'write.cgiエラー発生';
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
#                              テスト用領域                              #
##########################################################################

