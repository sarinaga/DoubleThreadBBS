#
#
# マルチスレッド掲示板 - ファイル入出力関係処理
#
#                                          2002.10.23 さゆりん先生
#
#
package file;
use strict;

use lib '/home/sarinaga/lib/i386-freebsd';

use File::Copy;
use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);

require './html.pl';    # create_bbshtml用
require './write.pl';   # create_bbshtml用

BEGIN{
	use vars qw($TIME_HIRES_OK);
	$TIME_HIRES_OK = 1;
	eval "use Time::HiRes qw(sleep);";
	$TIME_HIRES_OK = 0 if ($@);
}


use vars qw($CONFIG_FILE $CONFIG_DIR $POINTER_FILE $BLACKLIST_FILE $BBS_TOP_PAGE_FILE $PASSWORD_FILE);
$CONFIG_FILE         = 'bbs.conf';   # コンフィグファイル
$CONFIG_DIR          = './';         # コンフィグファイルが置かれているディレクトリ
$POINTER_FILE        = 'pointer';    # ポインタファイル
$BLACKLIST_FILE      = 'blacklist';  # スレ建て制限に引っかかっているIPアドレス、IPホストを格納
$BBS_TOP_PAGE_FILE   = 'bbs.html';   # トップページファイル/スレッド一覧表示
$PASSWORD_FILE       = 'passwd';     # パスワードファイル


use vars qw($READ_SCRIPT $WRITE_SCRIPT $ADMIN_SCRIPT);
$READ_SCRIPT  = 'read.cgi';
$WRITE_SCRIPT = 'write.cgi';
$ADMIN_SCRIPT = 'admin.cgi';

use vars qw($PUBLIC_DIR_PERMISSION $SECRET_DIR_PERMISSION 
            $PUBLIC_FILE_PERMISSION $SECRET_FILE_PERMISSION);
$PUBLIC_DIR_PERMISSION  = 0755;
$SECRET_DIR_PERMISSION  = 0700;
$PUBLIC_FILE_PERMISSION = 0644;
$SECRET_FILE_PERMISSION = 0600;


use vars qw($EXT_LOG $EXT_PUBLIC $EXT_SECRET $EXT_GZIP $EXT_TEMP $EXT_LOCK);

$EXT_LOG      = 'log';     # 発言ログであることをあらわす拡張子
$EXT_PUBLIC   = 'pub';     # 公開されていることをあらわす拡張子
$EXT_SECRET   = 'sec';     # 非公開であることをあらわす拡張子
$EXT_GZIP     = 'gz';      # gzip圧縮の拡張子
$EXT_TEMP     = $$;        # 一時ファイル拡張子
$EXT_LOCK     = 'lock';    # ロックファイル拡張子


#
# ・プログラム設計上の重大注意
#
#  ファイルをロック／アンロックするとき、以下のように順番を守ること
#
#  1. ポインタファイル
#  2. ログファイル公開部
#  3. ログファイル非公開部
#
#  この順番を守らない場合、処理時間が長くなったり
#  デッドロックを起こす可能性があります.
#



##########################################################################
#                       環境設定ファイルを読み込む                       #
##########################################################################
sub config_read{
	my $conf = shift;   # （参照）環境設定保存用ハッシュ

	# デフォルト値をセットする
	%$conf = config_default();

	# 環境設定ファイルをオープンする
	my $config_file = config_name();
	open(FIN, $config_file) || return 0;

	# １行ずつ環境設定ファイルを読み取り、解析していく
	until(eof(FIN)){
		my $read = <FIN>;
		chomp($read);

		$read=~s/\s+\#.*$//;     # 先行空白〜'#'〜コメント文を削除
		$read=~s/\s*$//;         # 行末空白文字削除
		next if ($read eq '');   # 空白行だけの場合は処理しない
		next if ($read=~m/^\#/); # コメント行は処理しない

		my ($elements, $contents) = split(/\s*=\s*/, $read ,2);  # 分離
		$elements =~tr/a-z/A-Z/;                                 # 環境設定名を大文字変換
		$$conf{$elements} = $contents;                           # 格納

	}
	close(FIN);

	return 0 unless(config_check($conf));  # 環境設定が不正ならエラーを返す
	return 1;
}


##########################################################################
#                      環境のデフォルト値を設定する                      #
##########################################################################
sub config_default{

	# デフォルト値を設定：一般的な設定
	my %conf;
	#$conf{'BASE_HTTP'}         = (なし)                   # 掲示板起点となるURI
	#$conf{'ADMIN_MAIL'}        = (なし)                   # 管理者メールアドレス
	$conf{'BBS_NAME'}           = 'ダブルスレッド掲示板';  # 掲示板の名前
	$conf{'NO_NAME'}            = '無名';                  # 投稿時に名前が入力されなかったときに入れられる名前
	$conf{'NO_TITLE'}           = '無題';                  # 投稿時に題名が入力されなかったときに入れられる題名
	$conf{"THREAD_LENGTH_MAX"}  = 30;                      # スレッド名が長すぎるときにどこでちょん切るか？
	$conf{'TITLE_LENGTH_MAX'}   = 20;                      # タイトルが長すぎるときにどこでちょん切るか？
	$conf{'NAME_LENGTH_MAX'}    = 10;                      # 名前が長すぎるときにどこでちょん切るか？
	$conf{'KILL_TITLE'}         = '削除されました';        # 削除された発言を表わす表示（タイトル）
	$conf{'KILL_NAME'}          = '削除されました';        # 削除された発言を表わす表示（名前）
	$conf{'EXIT_TO'}            = '/';                     # 掲示板から抜けるとき、その先のリンク
	$conf{'FORCE_TOMATO'}       = 0;                       # 投稿者のIPアドレスを強制表示
	$conf{'CREATE_ID'}          = 1;                       # 投稿者固有IDを生成する

	$conf{'ACCEPT_CHANGE'}      = 1;                       # 発言の変更、削除、復活を認めるか
	$conf{'COOKIE_EXPIRES'}     = 7;                       # cookie有効日数
	$conf{'ID_LENGTH'}          = 5;                       # IDの長さ
	$conf{'DISPLAY_LAST'}       = 100;                     # 最新レス表示をいくつまで表示するか
	$conf{'TRIP_INPUT_LENGTH'}  = 10;                      # トリップの長さ（入力）
	$conf{'TRIP_OUTPUT_LENGTH'} = 10;                      # トリップの長さ（出力）
	$conf{'TRIP_KEY'}           = 'aa';                    # トリップ鍵
	$conf{'PASSWORD_LENGTH'}    = 20;                      # 入力パスワードの最大長さ（最小は8）

	# デフォルト値を設定：リソース設定
	$conf{'THREAD_SAVE'}    = 20;      # スレッドをいくつまで保存するか
	$conf{'THREAD_MAX'}     = 5;       # １人あたりスレッドをいくつ作成できるか 
	$conf{'BUFFER_LIMIT'}   = 5000;    # １発言の大きさ制限（バイト数）

	                                    # スレッドへの書き込み制限（バイト数）
	$conf{'FILE_LIMIT'}     = 1000000;  # 書込み禁止
	$conf{'FILE_WARNING'}   = 900000;   # 警告表示
	$conf{'FILE_CAUTION'}   = 800000;   # 注意勧告

	                                    # スレッドへの書き込み制限（発言数）
	$conf{'THREAD_LIMIT'}   = 1000;     # 書込み禁止
	$conf{'THREAD_WARNING'} = 950;      # 警告表示
	$conf{'THREAD_CAUTION'} = 900;      # 注意勧告

	$conf{'CHANGE_LIMIT'}   = 5;        # 発言修正ができる回数
	$conf{'DUPE_BACK'}      = 5;        # 二重投稿の判断を何発言まで遡って見るか
	$conf{'CHAIN_POST'}     = 1;        # 連続投稿荒らし防止機構／数制限
	$conf{'CHAIN_TIME'}     = 30;       # 連続投稿荒らし防止機構／監視時間

	# デフォルト値を設定：システム設定
	$conf{'LOG_DIR_PUBLIC'} = './public_log/';       # 掲示板のログのうち、公開されるものを保存するディレクトリ
	$conf{'LOG_DIR_SECRET'} = './secret_log/';       # 掲示板のログのうち、公開されないものを保存するディレクトリ
	$conf{'LOG_DIR_HTML'}   = './';                  # 掲示板のログのうち、HTML化したものを保存するディレクトリ
	$conf{'TEMP_DIR'}       = '/tmp/';               # テンポラリ(一時）ファイルを作るディレクトリ
	$conf{'FILE_LOCK'}      = 0;                     # ファイルロックの方法(0:なし／1:symlink／2:mkdir)

	# その他の環境値
	$conf{'VERSION'} = 70;      # バージョン番号 x 100

	return %conf;
}


##########################################################################
#                環境が正しく設定されているかチェックする                #
##########################################################################
sub config_check{
	my $conf = shift;   # （参照）環境設定保存用ハッシュ

	# 必須入力確認
	return 0 unless(defined($$conf{'BASE_HTTP'}));
	return 0 unless(defined($$conf{'ADMIN_MAIL'}));

	# 必須入力正当性確認
	return 0 unless (std::uri_valid($$conf{'BASE_HTTP'}));
	return 0 unless (std::email_valid($$conf{'ADMIN_MAIL'}));

	# 数値を入れるものに文字列を入れた場合は不正
	my @number_only = (
	                    'THREAD_LENGTH_MAX',
	                    'TITLE_LENGTH_MAX',
	                    'NAME_LENGTH_MAX',
	                    'FORCE_TOMATO',
	                    'CREATE_ID',
	                    'ACCEPT_CHANGE',
	                    'COOKIE_EXPIRES',
	                    'ID_LENGTH',
	                    'DISPLAY_LAST',
	                    'TRIP_INPUT_LENGTH',
	                    'TRIP_OUTPUT_LENGTH',
	                    'PASSWORD_LENGTH',
	                    'THREAD_SAVE',
	                    'THREAD_MAX',
	                    'BUFFER_LIMIT',
	                    'FILE_LIMIT',
	                    'FILE_WARNING',
	                    'FILE_CAUTION',
	                    'THREAD_LIMIT',
	                    'THREAD_WARNING',
	                    'THREAD_CAUTION',
	                    'CHANGE_LIMIT',
	                    'DUPE_BACK',
	                    'CHAIN_POST',
	                    'CHAIN_TIME',
	                    'FILE_LOCK',
	                   );

	foreach my $item(@number_only){
		return 0 unless($$conf{$item}=~m/^\d+$/);
	}

	# 代入系チェック
	return 0 if ($$conf{'BBS_NAME'}   eq '');
	return 0 if ($$conf{'NO_NAME'}    eq '');
	return 0 if ($$conf{'NO_TITLE'}   eq '');
	return 0 if ($$conf{'KILL_NAME'}  eq '');
	return 0 if ($$conf{'KILL_TITLE'} eq '');
	return 0 if ($$conf{'TRIP_KEY'}   eq '');

	# 飽和系チェック
	$$conf{'THREAD_LENGTH_MAX'}  = 5   if ($$conf{'THREAD_LENGTH_MAX'}  <   5);
	$$conf{'TITLE_LENGTH_MAX'}   = 5   if ($$conf{'TITLE_LENGTH_MAX'}   <   5);
	$$conf{'NAME_LENGTH_MAX'}    = 5   if ($$conf{'NAME_LENGTH_MAX'}    <   5);
	$$conf{'DISPLAY_LAST'}       = 10  if ($$conf{'DISPLAY_LAST'}       <  10);
	$$conf{'TRIP_INPUT_LENGTH'}  = 5   if ($$conf{'TRIP_INPUT_LENGTH'}  <   5);
	$$conf{'TRIP_OUTPUT_LENGTH'} = 5   if ($$conf{'TRIP_OUTPUT_LENGTH'} <   5);
	$$conf{'THREAD_SAVE'}        = 5   if ($$conf{'THREAD_SAVE'}        <   5);
	$$conf{'BUFFER_LIMIT'}       = 500 if ($$conf{'BUFFER_LIMIT'}       < 500);

	# 整合性チェック
	return 0 if ($$conf{'FILE_LIMIT'}   <= $$conf{'FILE_WARNING'} or
	             $$conf{'FILE_WARNING'} <= $$conf{'FILE_CAUTION'}  );

	return 0 if ($$conf{'THREAD_LIMIT'}   <= $$conf{'THREAD_WARNING'} or
	             $$conf{'THREAD_WARNING'} <= $$conf{'THREAD_CAUTION'}  );


	# symlinkファイルロックが利用できないときはロックしない
	if ($$conf{'FILE_LOCK'} == 1){
		eval {   symlink("","");   };
		$$conf{'FILE_LOCK'} = 0 if ($@);
	}

	return 1;
}



##########################################################################
#                   ファイル、ディレクトリの初期化                       #
##########################################################################
sub init{

	# ディレクトリを作る
	my @directorys = ($main::CONF{'LOG_DIR_PUBLIC'},
	                  $main::CONF{'LOG_DIR_SECRET'},
	                  $main::CONF{'LOG_DIR_HTML'}  ,
	                  $main::CONF{'TEMP_DIR'}      , 
	                 );

	# 公開用ログと非公開ログを同じディレクトリに保存する場合は
	# 公開用ログディレクトリを作らない
	shift(@directorys) if($main::CONF{'LOG_DIR_PUBLIC'} eq $main::CONF{'LOG_DIR_SECRET'});

	# ディレクトリを生成する
	foreach my $directory(@directorys){
		my $permission;
		if ($directory eq $main::CONF{'LOG_DIR_SECRET'}){  $permission = $SECRET_DIR_PERMISSION;  }
		else {  $permission = $PUBLIC_DIR_PERMISSION;  }
		chop($directory);
		unless(mkdir($directory, $permission)){
			return 0 unless (-d $directory);
		}
	}


	# ポインタファイルを作る
	my $pointer_file = pointer_name();
	unless(-e $pointer_file){
		return 0 unless(open(FOUT, ">$pointer_file"));
		print FOUT "0\n";
		close(FIN);
	}
	return 0 unless(chmod($SECRET_FILE_PERMISSION, $pointer_file));

	# スレッド建てすぎブラックリストファイルを作る
	my $blacklist_file = blacklist_name();
	#system("touch $blacklist_file");
	unless(-e $blacklist_file){
		return 0 unless(open(FOUT, ">$blacklist_file"));
		close(FOUT);
	}
	return 0 unless(chmod($SECRET_FILE_PERMISSION, $blacklist_file));

	# 管理者用パスワードファイルを作る
	my $password_file = adminpass_name();
	unless(-e $password_file){
		return 0 unless(open(FOUT, ">$password_file"));
		print FOUT "admin:\$1\$fdah\$eEx833FHr9nM6dMvboVou1\n";  # admin/admin
		close(FOUT);
	}
	return 0 unless(chmod($SECRET_FILE_PERMISSION, $password_file));

	# すべて正常終了
	return 1;

}




##########################################################################
#                        ログファイルを読み取る                          #
##########################################################################
sub read_log{
	my $no     = shift(@_); # スレッド番号（純粋に番号のみ）
	my $log    = shift(@_); # [参照]ログ内容を返す
	my $all    = shift(@_); # この値が偽の時、スレッド情報だけを読み取る[$lockの値は常に偽とする]
	my $lock   = shift(@_); # この値が真の時、読み込んだあとファイルロックをかけっぱなしにする。
	my $gzip   = shift(@_); # この値が真の時、gzip圧縮がかかっているログファイルも読む。

	# ログファイルが保存されているディレクトリを取得
	my ($log_public, $log_secret, $lock_public, $lock_secret);
	$log_public = $lock_public = public_name($no);    # ログ[公開部]
	$log_secret = $lock_secret = secret_name($no);    # ログ[非公開部]


	# ログファイルを探索する
	# ログファイルがないときはgzip圧縮されたログファイル名を取得
	unless(-f $log_public and -f $log_secret){
		return 0 unless($gzip);                # gzip処理をしない場合は終了
		$lock_public .= ".$EXT_GZIP";
		$lock_secret .= ".$EXT_GZIP";
		return 0 unless(-f $lock_public and -f $lock_secret);
	}else{
		$gzip = 0;	# 通常のファイルが見つかった時はgzip処理はしなくていい
	}

	# ログ[公開部／非公開部]をロックする
	return 0 unless(filelock($lock_public));
	unless(filelock($lock_secret)){
		clear($no);   return 0;
	}


	# gzip展開をし展開されたログファイル名を取得
	if ($gzip){
		gunzip($no);                                # gzip展開
		$log_public = gz_public_name($no);          # gzip展開した時のログ[公開部]
		$log_secret = gz_secret_name($no);          # gzip展開した時のログ[非公開部]
		unless(-f $log_public and -f $log_secret){  # gzip展開されていない時は終了
			return 0;
			clear($no);  return 0;
		}
	}


	# ファイル情報を入手
	my @stat_public = stat($log_public);
	my @stat_secret = stat($log_secret);
	$$log[0]{'THREAD_NO'}     = $no;                                    # スレッド番号
	$$log[0]{'SIZE'}          = $stat_public[7] + $stat_secret[7];      # ファイルサイズ
	$$log[0]{'LAST_MODIFIED'} = $stat_public[9];                        # 最終更新時間
	$$log[0]{'DAT'}           = ($log_public eq $lock_public) ? 0 : 1;  # gzipのログかどうか


	# ログ[公開部／非公開部]を開く
	unless(open(FIN_P, $log_public)){
		clear($no);  return 0;
	}
	unless(open(FIN_S, $log_secret)){
		close(FIN_P); clear($no);  return 0;
	}


	# ログ[公開部／非公開部]からスレッド情報を読み出す
	my $result = read_header(*FIN_P, $log);      # [公開部]
	if(!defined($result) or $result ne '&&'){    # ログが破損している場合は終了
		close(FIN_S);  close(FIN_P);  clear($no);  return 0;
	}
	$result = read_header(*FIN_S, $log);         # [非公開部]
	if(!defined($result) or $result ne '&&'){    # ログが破損している場合は終了
		close(FIN_S);  close(FIN_P);  clear($no);  return 0;
	}


	# スレッド情報だけを読む場合は終了
	unless($all){
		close(FIN_S);
		close(FIN_P);
		clear($no, 0);  # スレッド情報だけを読む場合は必ずロックを
		return 1;       # 解除することに注意[上書きをしないため]
	}


	# ログ[公開部]の発言データを読み込む
	my $error_flag = 0;
	my $count_public = 0;
	until(eof(FIN_P)){

		# ログ[公開部]の処理・ヘッダ
		my $read = read_header(*FIN_P, $log, $count_public);
		unless(defined($read)){ $error_flag = 1; last; }
		if ($read eq '&&'){ ++$count_public; next; }

		# ログ[公開部]の処理・本文
		$read = read_body(*FIN_P, $log, $count_public);
		unless(defined($read)){ $error_flag = 1; last; }
		$$log[$count_public]{'BODY'} = $read;
		++$count_public;
	}
	close(FIN_P);


	# ログが不正の場合は終了
	if ($error_flag){
		clear($no);  return 0;
	}

	my $count_secret = 0;
	until(eof(FIN_S)){

		# 非公開部ログの処理・ヘッダ
		my $read = read_header(*FIN_S, $log, $count_secret);
		unless(defined($read)){ $error_flag = 1; last; }
		if ($read eq '&&'){ ++$count_secret; next; }

		# 非公開部ログの処理・本文
		$read = read_body(*FIN_S, $log, $count_secret);
		unless(defined($read)){ $error_flag = 1; last; }
		$$log[$count_secret]{'BODY'} = $read;
		++$count_secret;
	}
	close(FIN_S);

	# ログファイル整合性チェック
	$error_flag = 1 unless($count_public == $count_secret and $count_secret == $$log[0]{'POST'});
	if($error_flag){
		clear($no); return 0;
	}

	# ログが正常に読み取れた場合の処理
	clear($no, $lock);
	return 1;


	#
	#   ストッパー'&','&&'が出るまでログヘッダ部分を解読する
	#
	sub read_header{
		local(*FIN) = shift;  # ファイルハンドル
		my $log     = shift;  # [参照]データ格納用
		my $count   = shift;  # 現在作業している発言番号

		loop: for(;;){

			# 区切文字より先にEOFが来たときは未定義値を返す
			return undef if (eof(FIN));

			# １行読む／区切り文字を見つけたらそれを返す
			my $read = <FIN>;
			chomp($read);
			return $read if ($read eq '&' or $read eq '&&');

			# キーと内容を分離
			my ($key, $value) = split(/<>/, $read, 2);

			# キーを大文字化
			$key=~tr/a-z/A-Z/;

			# スレッド情報 [公開部冒頭部分] 処理
			my @thread_data = ('THREAD_TITLE', 'POST', 'AGE_TIME',
						'BUILDER_IP_ADDR', 'BUILDER_IP_HOST');  # 特殊処理5パラメータ
			foreach my $element(@thread_data){
				if ($key eq $element){
					$$log[0]{$key} = $value;
					next loop;
				}
			}

			# ログ本体 [公開部] ログ変更時刻 特殊処理
			if ($key eq 'CORRECT_TIME'){
				push(@{$$log[$count]{'CORRECT_TIME'}}, $value);
				next loop;
			}

			# ログ本体 [公開部／非公開部] 発言番号 特殊処理
			if ($key eq 'NO'){

				# 記録されている発言番号と読み出している発言の数が
				# あっているかチェックする
				return undef unless ($count == $value);                    # 不正
				if (defined($$log[$count]{'NO'})){
					return undef unless ($$log[$count]{'NO'} == $value);   # 不正
					$$log[$count]{'NO'} = $value;                          # or $count ; あまり意味がない
				}
				next loop;
			}

			# ログ本体 [非公開部] IPアドレス IPホスト ユーザエージェント 特殊処理
			if ($key eq 'IP_HOST' or $key eq 'IP_ADDR' or $key eq 'USER_AGENT'){
				push(@{$$log[$count]{$key}}, $value);
				next loop;
			}

			# ログ本体[公開部／非公開部] 共通処理
			$$log[$count]{$key} = $value;
			next loop;
		}
	}

	#
	#   ストッパー'&&'が出るまでログ本文部分を読み取る
	#
	sub read_body{
		local(*FIN) = shift;  # ファイルハンドル

		my $body = '';
		for(;;){
			return undef if(eof(FIN));        # ゴルア！
			my $read = <FIN>;
			chomp($read);
			if ($read eq '&&'){               # 区切り記号まで読んだ
				chomp($body);
				return $body;
			}
			return undef if ($read eq '&');   # ゴルア！
			$body .= "$read\n";
		}
	}



}


#
#   gzip圧縮されているログファイルをテンポラリ用
#   ディレクトリに展開する
#
sub gunzip{
	my $no   = shift;
	my $lock = shift;  # 真の時、ロックをかける

	# コピー元フルパス
	my $gzip_log_public_from = public_name($no) . ".$EXT_GZIP";
	my $gzip_log_secret_from = secret_name($no) . ".$EXT_GZIP";

	# ファイルロック
	if ($lock){
		return 0 unless(filelock($gzip_log_public_from) and
		                filelock($gzip_log_secret_from)      );
	}

	# コピー先ディレクトリ
	my $gzip_log_public_to = gz_public_name($no) . ".$EXT_GZIP";
	my $gzip_log_secret_to = gz_secret_name($no) . ".$EXT_GZIP";

	# テンポラリ用ディレクトリにコピー
	copy($gzip_log_public_from, $gzip_log_public_to);
	copy($gzip_log_secret_from, $gzip_log_secret_to);
####	system("cp $gzip_log_public_from $gzip_log_public_to");
####	system("cp $gzip_log_secret_from $gzip_log_secret_to");

	# ファイルロック解除
	unlock($gzip_log_public_from);
	unlock($gzip_log_secret_from);

	# gzip展開
####	system("gunzip $gzip_log_public_to");
####	system("gunzip $gzip_log_secret_to");
	rename($gzip_log_public_to, gz_public_name($no));
	rename($gzip_log_secret_to, gz_secret_name($no));

}


#
#   gzip圧縮されているログファイルを展開する
#
sub gunzip_only{
	my $no = shift;

	# 展開するログファイル
	my $gzip_log_public = public_name($no) . ".$EXT_GZIP";
	my $gzip_log_secret = secret_name($no) . ".$EXT_GZIP";

	# ファイルロック
	return 0 unless(filelock($gzip_log_public) and filelock($gzip_log_secret));

	# gzip展開
####	system("gunzip $gzip_log_public");
####	system("gunzip $gzip_log_secret");
	rename($gzip_log_public, public_name($no));
	rename($gzip_log_secret, secret_name($no));

	# ファイルロック解除
	unlock($gzip_log_public);
	unlock($gzip_log_secret);

	return 1;
}


#
# ログファイルをgzip圧縮する
#
sub gzip{
	my $no = shift;
	my $log_public = public_name($no);
	my $log_secret = secret_name($no);

	return 0 unless(filelock($log_public) and filelock($log_secret));

####	system('gzip $log_public');
####	system('gzip $log_secret');
	rename($log_public, "$log_public.$EXT_GZIP") or return 0;
	rename($log_secret, "$log_secret.$EXT_GZIP") or return 0;
	unlock($log_public) or return 0;
	unlock($log_secret) or return 0;
	return 1;
}




#
#   ログを読み取るに当たって作成した一時ファイルや
#   ロックファイルを削除する
#
sub clear{
	my $no   = shift;  # 発言番号
	my $lock = shift;  # ロックを解除するかどうか？
	                   #（偽なら解除；デフォルト動作をロック解除とするため）

	# ロックを解除する
	unless($lock){
		unlock(public_name($no));
		unlock(secret_name($no));
		unlock(public_name($no) . ".$EXT_GZIP");
		unlock(secret_name($no) . ".$EXT_GZIP");
	}

	# gzip展開したログファイルを削除する
	unlink(gz_public_name($no));
	unlink(gz_secret_name($no));

}



###########################################################################
#                    スレッド情報一覧を読み込む                           #
###########################################################################
sub thread_read{
	my $thread = shift;   # スレッド情報(参照)
	my $gzip   = shift;   # この値が真のとき、dat化されたスレッドの情報も読み取る
	my $lock   = shift;   # 未使用

	# （公開）ログディレクトリからログファイル名一覧を読み込む
	return undef unless(opendir (DIR, $main::CONF{'LOG_DIR_PUBLIC'}));
	my @filenames = readdir(DIR);
	closedir(DIR);
	my @logfiles = grep(/^\d+\.$EXT_PUBLIC\.$EXT_LOG$/, @filenames);
	if ($gzip){
		push(@logfiles, grep(/^\d+\.$EXT_PUBLIC\.$EXT_LOG\.$EXT_GZIP$/, @filenames));
	}

	# それをスレッド番号に変換する
	my @thread_no = map { $_=~s/^(\d+).*/$1/; $_=$1; } @logfiles;


	# データを全部読み込む
	my $c = 0;    # $c is counter.
	foreach my $no(@thread_no){
		my @log;
		next unless(file::read_log($no, \@log, 0, 0, 1));
		        # ロックをかけない、ヘッダ部分だけを読む、gz圧縮対応をする
		push(@$thread, $log[0]);
		$c++;
	}
	return $c;
}



##########################################################################
#                        ログファイルを更新する                          #
##########################################################################
sub write_log{
	my $log = shift(@_);  # 保存したいログデータ

	# 各種ファイル名データ作成
	my $no          = $$log[0]{'THREAD_NO'};

	my $log_public  = public_name($no);
	my $log_secret  = secret_name($no);
	my $temp_public = temp_name($log_public);
	my $temp_secret = temp_name($log_secret);

	# ログテンポラリファイル[公開部]を開く
	unless(open(TEMP, ">$temp_public")){
		unlock($log_public);
		unlock($log_secret);
		return 0;
	}

	# 公開部スレッド情報を書き込む
	print TEMP "THREAD_TITLE<>$$log[0]{'THREAD_TITLE'}\n";       # スレッド名
	print TEMP "POST<>$$log[0]{'POST'}\n";                       # 投稿されている数
	print TEMP "AGE_TIME<>$$log[0]{'AGE_TIME'}\n";               # スレッドが上がった時間
	print TEMP "&&\n";

	# 公開部発言情報を書き込む
	for(my $i=0;$i<$$log[0]{'POST'};++$i){

		print TEMP "NO<>$i\n";                                               # 発言番号
		print TEMP "RES<>$$log[$i]{'RES'}\n" if (defined($$log[$i]{'RES'})); # レス先番号

		# 発言が削除されていない場合
		common_write(*TEMP, $$log[$i]) unless(defined($$log[$i]{'DELETE_TIME'}));
		sub common_write{
			local(*FOUT) = shift; # 出力先ファイルハンドル
			my $log = shift;
			print FOUT "TITLE<>$$log{'TITLE'}\n";                                     # 発言タイトル
			print FOUT "USER_NAME<>$$log{'USER_NAME'}\n";                             # 投稿者氏名
			print FOUT "USER_EMAIL<>$$log{'USER_EMAIL'}\n";                           # 投稿者e-mail
			print FOUT "USER_WEBPAGE<>$$log{'USER_WEBPAGE'}\n";                       # 投稿者webpage
			print FOUT "USER_ID<>$$log{'USER_ID'}\n" if (defined($$log{'USER_ID'})); # 投稿者固有ID
			print FOUT "TRIP<>$$log{'TRIP'}\n" if (defined($$log{'TRIP'}));           # トリップ
		}

		# アクセス方法
		print TEMP "TOMATO<>$$log[$i]{'TOMATO'}\n";                                 # IPアドレス表示
		tomato_write(*TEMP, $$log[$i]) if ($$log[$i]{'TOMATO'});
		sub tomato_write{
			local(*FOUT) = shift; # 出力先ファイルハンドル
			my $log = shift;
			foreach my $ip_host(@{$$log{'IP_HOST'}}){                           # IPアドレス（ドメイン）
				print TEMP "IP_HOST<>$ip_host\n";
			}
			foreach my $ip_addr(@{$$log{'IP_ADDR'}}){                           # IPアドレス
				print TEMP "IP_ADDR<>$ip_addr\n";
			}
			foreach my $user_agent(@{$$log{'USER_AGENT'}}){                     # 利用ユーザエージェント
				print TEMP "USER_AGENT<>$user_agent\n";
			}
		}

		# 投稿修正時間
		print TEMP "POST_TIME<>$$log[$i]{'POST_TIME'}\n";                           # 投稿時間
		foreach my $correct_time(@{$$log[$i]{'CORRECT_TIME'}}){
			print TEMP "CORRECT_TIME<>$correct_time\n";                         # 修正時間
		}

		# 発言が削除されている場合
		if (defined($$log[$i]{'DELETE_TIME'})){
			print TEMP "DELETE_TIME<>$$log[$i]{'DELETE_TIME'}\n";               # 発言削除時間
			if (defined($$log[$i]{'DELETE_ADMIN'})){
				print TEMP "DELETE_ADMIN<>$$log[$i]{'DELETE_ADMIN'}\n";     # 発言を消した管理者
			}
		}else{
			print TEMP "&\n$$log[$i]{'BODY'}\n";                         # 発言本文
		}

		print TEMP "&&\n";                                               # 区切記号

	}
	close(TEMP);


	# ログファイル[非公開部]を開く
	unless(open(TEMP,">$temp_secret")){
		unlock($log_public);
		unlock($log_secret);
		return 0;
	}

	# 非公開部スレッド情報を書き込む
	print TEMP "BUILDER_IP_ADDR<>$$log[0]{'BUILDER_IP_ADDR'}\n"; # スレッド作成者 IPアドレス
	print TEMP "BUILDER_IP_HOST<>$$log[0]{'BUILDER_IP_HOST'}\n"; # スレッド作成者 IPホスト
	print TEMP "&&\n";

	# 非公開部発言情報を書き込む
	for(my $i=0;$i<$$log[0]{'POST'};++$i){

		print TEMP "NO<>$i\n";                                           # 発言番号

		# 発言削除の場合
		common_write(*TEMP, $$log[$i]) if(defined($$log[$i]{'DELETE_TIME'}));
		tomato_write(*TEMP, $$log[$i]) unless($$log[$i]{'TOMATO'});

		print TEMP "PASSWORD<>$$log[$i]{'PASSWORD'}\n";                  # 発言変更用パスワード

		if(defined($$log[$i]{'DELETE_TIME'})){
			print TEMP "&\n$$log[$i]{'BODY'}\n";                         # 発言本文
		}
		print TEMP "&&\n";                                               # 区切記号
	}
	close(TEMP);

	# ログファイル更新
	chmod($PUBLIC_FILE_PERMISSION, $temp_public);
	chmod($SECRET_FILE_PERMISSION, $temp_secret);
	return 1 if (renew($log_public) and renew($log_secret));

	# 更新失敗
	unlock($log_public);
	unlock($log_secret);
	return 0;

}



###########################################################################
#                    スレッド情報からbbs.htmlを作成する                   #
###########################################################################
#
#  このサブルーチンは本来ならwrite.cgiに置かれるべき物ですが、
#  admin.cgiとの共通利用となるため、file.plに置かれることになります。
#
sub create_bbshtml{
	my $thread      = shift;   # スレッド情報[参照]

	# bbs.html をロックする
	my $bbs_html = "./$BBS_TOP_PAGE_FILE";
	return 0 unless (filelock($bbs_html));

	# bbs.htmlヘッダ作成
	my $tempfile = temp_name($bbs_html);
	return 0 unless(open(FOUT, ">$tempfile"));
	html::header(*FOUT, 'スレッド一覧表示');

	# bbs.html冒頭説明文出力
	my $info = '';
	open(FIN, $writecgi::THREADLIST_INFO);
	until(eof(FIN)){
		$info .= <FIN>;
	}
	$info = std::encodeEUC($info);
	print FOUT "<div class='info'>\n\n";
	print FOUT "$info\n";
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# リンクバー出力
	print FOUT "<div class='link'>";
	print FOUT '<a href="#create-thread">新規スレッド作成</a>　';
	html::link_exit(*FOUT);
	html::link_adminmode(*FOUT);
	html::link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# スレッド一覧部分出力
	print FOUT "<div class='thread'>\n\n";
	print FOUT "<h3 id='thread'>スレッド一覧</h3>\n\n";
	html::thread_list(*FOUT, $thread);
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# リンクバー
	print FOUT "<div class='link'>";
	html::link_exit(*FOUT);
	html::link_adminmode(*FOUT);
	html::link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# 新規スレッド作成フォーム作成
	print FOUT "<div class='create-thread'>\n\n";
	print FOUT "<h3 id='create-thread'>新規スレッド作成</h3>\n\n";
	html::formparts_head(*FOUT);
	html::formparts_createthread(*FOUT);
	html::formparts_name(*FOUT, undef, '', '', undef, undef);
	html::formparts_password(*FOUT, 1, html::pass_message() );
	html::formparts_age(*FOUT, 0, 1);
	html::formparts_foot(*FOUT, $html::CREATE, $writecgi::CREATE);
	print FOUT "</div>\n\n";

	# リンクバー
	print FOUT "<div class='link'>";
	html::link_exit(*FOUT);
	html::link_adminmode(*FOUT);
	html::link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# 末尾部分
	html::footer(*FOUT);
	close(FOUT);

	# テンポラリファイルから正式ファイルに変換
	return renew($bbs_html);
}




###########################################################################
#                     古くなったスレッドを圧縮処理する                    #
###########################################################################
sub compress{
	my $thread = shift;    # スレッド情報[参照]
	my $force  = shift;    # 強制的圧縮をする場合

	# DATでないスレッドの数を数える
	my $live = 0;
	for(my $i=0;$i<scalar @$thread;++$i){
		++$live unless($$thread[$i]{'DAT'});
	}

	# スレッド圧縮上限目安
	my $limit = $main::CONF{'THREAD_SAVE'} + std::math_max(10, $main::CONF{'THREAD_SAVE'} / 2);
	unless($force){
		return 0 unless($live > $limit);    # 許容量を超えていない場合は処理を行わない
	}else{
		return 0 unless($live > $main::CONF{'THREAD_SAVE'});  # 1つでも超えたら圧縮する場合の判定
	}

	# 圧縮優先順位でソート
	@$thread = sort {  $$b{'LAST_MODIFIED'} + $$b{'AGE_TIME'} / 2 <=> $$a{'LAST_MODIFIED'} + $$a{'AGE_TIME'} / 2  } @$thread;

	# 超過したスレッドの処理を行う
	my ($c, $j) = (0, 0);
	for(my $i=0;$i<scalar @$thread;++$i){
		next if ($$thread[$i]{'DAT'});
		next if ($j++ < $main::CONF{'THREAD_SAVE'});
		if (file::gzip($$thread[$i]{'THREAD_NO'})){
			$$thread[$i] = undef;
			++$c;
		}
	}

	# 処理したスレッドを削除
	@$thread = grep{ defined($_); } @$thread;
	return $c;

}


###########################################################################
#                      admin.html 管理ページを更新する                    #
###########################################################################
#
#  このサブルーチンは本来ならwrite.cgiに置かれるべき物ですが、
#  admin.cgiとの共通利用となるため、file.plに置かれることになります。
#
sub create_adminpage{

	# 情報整理
	my $version      = sprintf("%1.2f",$main::CONF{'VERSION'} / 100);
	my $bbs_top      = "./$file::BBS_TOP_PAGE_FILE";
	my $stylesheet   = "./$html::STYLESHEET";
	my $admin_mail   = $main::CONF{'ADMIN_MAIL'};
	my $admin_script = "./$file::ADMIN_SCRIPT";
	my $programmer   = $html::PROGRAMMER_WEBPAGE;

	# admin.infoの読み込み
	return 0 unless(open(FIN, $writecgi::ADMIN_INFO));
	my $info = '';
	until(eof(FIN)){
		$info .= <FIN>;
	}
	$info = std::encodeEUC($info);
	$info =~ s/(\$\w+)/$1/gee;

	# admin.htmlの書き出し
	my $admin_html = "./$html::ADMIN_PAGE";
	return 0 unless (filelock($admin_html));
	my $tempfile = temp_name($admin_html);
	return 0 unless(open(FOUT, ">$tempfile"));
	print FOUT $info;
	close(FOUT);

	# テンポラリファイルから正式ファイルに変換
	return renew($admin_html);


}


##########################################################################
#                      ポインタファイルを読み込む                        #
##########################################################################
sub read_pointer{
	my $lock = shift;    # この値が真の時、読み込んだあとファイルロックをかけっぱなしにする

	# ロック→ファイルから読み込み
	my $pointer_file = pointer_name();
	return undef unless (filelock($pointer_file) and open(FIN, $pointer_file));
	my $read=<FIN>;
	close(FIN);
	unlock($pointer_file) unless($lock);

	# 洗浄
	chomp($read);
	return undef unless ($read=~m/^(\d+)$/);
	return $1;
}


##########################################################################
#                         ポインタファイルを更新する                     #
##########################################################################
sub write_pointer{

	#
	# この処理を実行する前にポインタファイルを
	# ロックしておくことが必要
	#
	my $pointer = shift;                  # 新しいポインタ値

	my $pointer_file = pointer_name();
	my $pointer_temp = temp_name($pointer_file);
	unless(open(TEMP,">$pointer_temp")){
		unlock($pointer_file);
		return 0;
	}
	print TEMP "$pointer\n";
	close(TEMP);
	chmod($SECRET_FILE_PERMISSION, $pointer_temp);
	return renew($pointer_file);
}


##########################################################################
#               スレッド建てすぎブラックリストを読み込む                 #
##########################################################################
sub read_overbuilder{
	my $list = shift;

	open(FIN, blacklist_name()) || return 0;
	my @dat = <FIN>;
	close(FIN);

	foreach my $line(@dat){
		chomp($line);
		push(@$list, $line);
	}
	return 1;
}

##########################################################################
#               スレッド建てすぎブラックリストを更新する                 #
##########################################################################
sub write_overbuilder{
	#
	# 前もってファイルをロックしておくこと
	#

	# ファイルオープン
	my $filename = blacklist_name();
	my $tempfile = temp_name($filename);
	unless(open(TEMP, ">$tempfile")){
		unlock($filename);
		return 0;
	}

	# ブラックリスト書き込み〜更新
	foreach my $line(@_){
		print TEMP "$line\n";
	}
	close(TEMP);
	chmod($SECRET_FILE_PERMISSION, $tempfile);
	return renew($filename);
}


###########################################################################
#                         管理者パスワードを読み込む                      #
###########################################################################
sub read_adminpass{
	my $passwords = shift;       # (参照)パスワードデータ授受用
	my $lock      = shift;       # 未使用
	my $pass_file = adminpass_name();
	return 0 unless (open(FIN, $pass_file));
	foreach my $line(<FIN>){
		chomp($line);
		my ($user, $pass) = split(/:/, $line, 2);
		$$passwords{$user} = $pass;
	}
	close(FIN);
	return 1;
}


###########################################################################
#                         管理者パスワードを書き込む                      #
###########################################################################
sub write_adminpass{
	#
	# この処理を実行する前にパスワード一覧ファイルを
	# ロックしておくことが必要
	#
	my $passwords = shift;                  # (参照)パスワードデータ授受用
	my $pass_file = adminpass_name();
	my $pass_temp = temp_name($pass_file);

	unless(open(TEMP,">$pass_temp")){
		unlock($pass_file);
		return 0;
	}
	my ($user, $pass);
	while ( ($user, $pass) = each(%$passwords) ){
		print TEMP "$user:$pass\n";
	}
	close(TEMP);
	chmod($file::SECRET_FILE_PERMISSION, $pass_temp);
	return renew($pass_file);

}


##########################################################################
#                 ファイルをロックする/ロック開放待ち                    #
##########################################################################
sub filelock{
	my $filename = shift;                  # ロックするファイル名

	return 0 unless(-f $filename);
	return 1 if ($main::CONF{'FILE_LOCK'} == 0);            # ファイルロックなし

	my $lockfile = lock_name($filename);
	foreach (1..10){

		unless(lock_check($filename)){

			if ($main::CONF{'FILE_LOCK'} == 1){     # symlinkロック
				my $lock_ok;
				eval "$lock_ok = symlink($filename, $lockfile)";
				return 0 if ($@);
				return 1 if ($lock_ok);

			}else{                                  # mkdirロック
				return 1 if (mkdir($lockfile, 0755));

			}
		}
		if ($TIME_HIRES_OK){
			sleep(0.1);	# 0.1秒待つ(Time::Hires利用)
		}else{
			sleep(1);	# 1秒待つ(通常)
		}
	}
	return 0;
}


##########################################################################
#          ファイルがロックされているかどうかチェックする                #
##########################################################################
sub lock_check{

	if ($main::CONF{'FILE_LOCK'} == 0){      # ファイルロックなし
		return 1;

	}elsif ($main::CONF{'FILE_LOCK'} == 1){  # symlinkロック
		return (-l lock_name(shift));

	}else{                                   # mkdirロック
		return (-d lock_name(shift));

	}
}


##########################################################################
#                       ファイルのロックを解除する                       #
##########################################################################
sub unlock{
	if ($main::CONF{'FILE_LOCK'} == 0){      # ファイルロックなし
		return 1;

	}elsif ($main::CONF{'FILE_LOCK'} == 1){  # symlinkロック
		return unlink(lock_name(shift));

	}else{                                   # rmdirロック
		return rmdir(lock_name(shift));

	}
}


##########################################################################
#           テンポラリファイルを変換してファイルを更新する               #
##########################################################################
sub renew{
	my $filename = shift;                  # 更新したいファイル

	my $lockfile = lock_name($filename);   # ロックファイル
	my $tempfile = temp_name($filename);   # テンポラリファイル

	# 更新に必要なファイルがそろっているかチェックする
	return 0 unless (-e $filename);
	return 0 unless (-e $tempfile);
#	return 0 unless (lock_check($filename));

	# 変換
	move($tempfile, $filename);    # 更新
#	rename($tempfile, $filename);  

	if ($main::CONF{'FILE_LOCK'} == 2){   # ロック解除（rmdir利用の場合）
		rmdir($lockfile);
	}else{                                # ロック解除（その他）
		unlink($lockfile);
	}

	# テンポラリファイルが残っているときは正常に書き換わっていない
	# そうでないときは成功
	return 0 if (unlink($tempfile) > 0);
	return 1;
}



##########################################################################
#                         各種ファイル名ジェネレーター                   #
##########################################################################

#
# 公開ログファイル名を生成する
#
sub public_name{
	my $no = shift;
	return "$main::CONF{'LOG_DIR_PUBLIC'}$no.$EXT_PUBLIC.$EXT_LOG";
}


#
# 非公開ログファイル名を生成する
#
sub secret_name{
	my $no = shift;
	return "$main::CONF{'LOG_DIR_SECRET'}$no.$EXT_SECRET.$EXT_LOG";
}


#
# gzip圧縮を解除した公開ログファイル名を生成する
#
sub gz_public_name{
	my $no = shift;
	return "$main::CONF{'TEMP_DIR'}$no.$EXT_PUBLIC.$EXT_LOG";
}


#
# gzip圧縮を解除した非公開ログファイル名を生成する
#
sub gz_secret_name{
	my $no = shift;
	return "$main::CONF{'TEMP_DIR'}$no.$EXT_SECRET.$EXT_LOG";
}


#
# ロックファイル名を生成する
#
sub lock_name{
	my $filename = shift;
	return $main::CONF{'TEMP_DIR'} . sha1_hex($filename) . ".$EXT_LOCK";
}


#
# テンポラリファイル名を生成する
#
sub temp_name{
	my $filename = shift;
	return $main::CONF{'TEMP_DIR'} . sha1_hex($filename) .  ".$EXT_TEMP";
}


#
# ポインタファイル名を生成する
#
sub pointer_name{
	return $main::CONF{'LOG_DIR_SECRET'} . $POINTER_FILE;
}


#
# スレッド建てすぎブラックリストファイル名を生成する
#
sub blacklist_name{
	return $main::CONF{'LOG_DIR_SECRET'} . $BLACKLIST_FILE;
}


#
# コンフィグファイル名を生成する
#
sub config_name{
	return $CONFIG_DIR . $CONFIG_FILE;
}


#
# HTML化済みのログファイル名を作成する
#
sub html_name{
	return $main::CONF{'LOG_DIR_HTML'} . shift() . '.html';
}


#
# 管理者パスワードファイル名を生成する
#
sub adminpass_name{
	return "$main::CONF{'LOG_DIR_SECRET'}$PASSWORD_FILE";
}

##########################################################################
#                               試験用領域                               #
##########################################################################



1;


