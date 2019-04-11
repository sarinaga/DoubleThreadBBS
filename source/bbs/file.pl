#
#
# マルチスレッド掲示板 - ファイル入出力関係処理
#
#                                          2002.10.23 さゆりん先生
#
#
package file;
use strict;

use lib '/home/sarinaga/perl/lib/perl5/site_perl/5.14';
use File::Copy;
use File::Basename;
use Time::HiRes qw(sleep);
use Crypt::PasswdMD5;
use Digest::SHA 'sha1_hex';
use utf8;
binmode(STDOUT, ":utf8"); 
binmode(STDERR, ":utf8"); 

require './constants.pl';

# bbs.conf.json設定値(外部からこのグローバル変数に値をセットすること)
use vars qw($CONF);


#
# ・プログラム設計上の重大注意
#
#  ファイルをロックするとき、以下のように順番を守ること
#  (アンロックの場合は順番逆).
#
#  1. ポインタファイル
#  2. ログファイル公開部
#  3. ログファイル非公開部
#
#  この順番を守らない場合, デッドロックを起こす可能性がある.
#

#
# ログ@logの構造
#   @log =
#     [
#       {
#         // 以下は配列添字[0]にのみ存在する.
#         // * 公開ログに出力. ファイル名やファイル情報の値を利用. 添字[0]にしか存在しない
#         // + 公開ログに出力
#         // - 非公開ログに出力
#         // # 通常は公開, 削除されると非公開に出力
#         // $ 通常は非公開, TOMATOされると公開に出力
#
#         THREAD_NO       : * スレッド番号,
#         SIZE            : * ファイルサイズ(公開ログファイル+秘密ログファイルのバイト数),
#         LAST_MODIFIED   : * 最終更新時間(epoc),
#         DAT             : * gzip圧縮されたものかどうか,
#         THREAD_TITLE    : + スレッド名,
#         POST            : + 投稿数,
#         AGE_TIME        : + スレッドがageられた時間(epoc),
#
#         BUILDER_IP_ADDR : - スレッドを建てた人のIPアドレス,
#         BUILDER_IP_HOST : - スレッドを建てた人のホスト名,
#
#         DELETE_TIME     : + 削除された時間(epoc),
#         DELETE_ADMIN    : + 発言を削除した管理者,
#         RES             : + レス先,
#         TITLE           : # 発言タイトル,
#         USER_NAME       : # 投稿者氏名,
#         USER_EMAIL      : # 投稿者e-mail,
#         USER_WEBPAGE    : # 投稿者webpage,
#         USER_ID         : # 投稿者固有ID,
#         TRIP            : # トリップ,
#         POST_TIME       : # 投稿時間(epoc),
#         CORRECT_TIME    : # 修正時間(epoc),
#         BODY            : # 発言本文,
#
#         TOMATO          : + IPアドレス表示可否,
#         IP_ADDR         : $ 投稿者IPアドレス,
#         IP_HOST         : $ 投稿者ホスト名,
#         USER_AGENT      : $ 投稿者ユーザエージェント,
#       },
#     ]

##########################################################################
#                        ログファイルを読み取る                          #
##########################################################################
sub read_log{
	my $no     = shift; # スレッド番号
	my $log    = shift; # [参照]ログ内容(これに読み取った内容が反映される)
	my $all    = shift; # この値が偽の時、スレッド情報だけを読み取る[このとき$lockの値は無視される]
	my $lock   = shift; # この値が真の時、読み込んだあとファイルロックをかけっぱなしにする
	my $gzip   = shift; # この値が真の時、gzip圧縮がかかっているログファイルも読む

	# ログファイルを作成.
	my ($log_public, $log_secret);
	$log_public = public_name($no);    # ログ[公開部]
	$log_secret = secret_name($no);    # ログ[非公開部]

	# ログファイルが見つかった時は, gunzip処理はしなくてよい.
	# ログファイルが見つからず, gunzip処理をしないときは終了.
	if(-f $log_public and -f $log_secret){
		$gzip = 0;
	}else{
		return 0 unless($gzip);
	}

	# gzip展開をし, その展開されたログファイルを処理するようにする
	if ($gzip){

		# 過去ログをgzip展開
		gunzip($no);

		# gzipに失敗したときは終了
		$log_public = gunzip_public_name($no);
		$log_secret = gunzip_secret_name($no);
		return 0 unless(-f $log_public and -f $log_secret);

	}


	# ログ[公開部／非公開部]をロックする
	#   ・gzip展開したときはロックなし
	unless ($gzip){
		return 0 unless(filelock($log_public));
		unless(filelock($log_secret)){
			clear($no);
			return 0;
		}
	}

	# ファイル情報を入手
	my @stat_public = stat($log_public);
	my @stat_secret = stat($log_secret);
	$$log[0]{'THREAD_NO'}     = $no;                                    # スレッド番号
	$$log[0]{'SIZE'}          = $stat_public[7] + $stat_secret[7];      # ファイルサイズ
	$$log[0]{'LAST_MODIFIED'} = $stat_public[9];                        # 最終更新時間
	$$log[0]{'DAT'}           = $gzip;                                  # gzipのログかどうか




	# ログ[公開部／非公開部]を開く
	unless(open(FIN_P, $log_public)){
		clear($no);  return 0;
	}

	unless(open(FIN_S, $log_secret)){
		close(FIN_P); clear($no);  return 0;
	}
	binmode(FIN_S, ":utf8");	
	binmode(FIN_P, ":utf8");	

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
		clear($no, 0);  # ロック解除
		return 1;
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
		print "AA\n";
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
			utf8::decode($read);
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
				return undef unless ($count == $value);                    # ログが正常なら未到達
				if (defined($$log[$count]{'NO'})){
					return undef unless ($$log[$count]{'NO'} == $value);   # ログが正常なら未到達
					$$log[$count]{'NO'} = $value;
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
			return undef if(eof(FIN));        # ログが正常なら未到達
			my $read = <FIN>;
			utf8::decode($read);
			chomp($read);
			if ($read eq '&&'){               # 区切り記号まで読んだ
				chomp($body);
				return $body;
			}
			return undef if ($read eq '&');   # ログが正常なら未到達
			$body .= "$read\n";
		}
	}



}


#
#   gzip圧縮されているログファイルを展開する
#
sub gunzip{
	my $no   = shift;  # スレッド番号
	my $where= shift;  # 展開先 0:テンポラリディレクトリ, 1:ログディレクトリ

	# コピー元
	my ($g_pub_from, $g_sec_from);
	$g_pub_from = gzip_public_name($no);
	$g_sec_from = gzip_secret_name($no);

	# コピー元ファイルがない場合は処理しない
	return 0 unless (-f $g_pub_from or -f $g_sec_from);

	# (テンポラリディレクトリへの)コピー先
	my ($t_pub, $t_sec);
	unless ($where){
		$t_pub = gzip_public_name_in_temp($no);
		$t_sec = gzip_secret_name_in_temp($no) ;
	}

	# gunzipしたログファイル
	my ($g_pub_to, $g_sec_to);
	unless ($where){
		$g_pub_to = gunzip_public_name($no);
		$g_sec_to = gunzip_secret_name($no);
	}else{
		$g_pub_to = public_name($no);
		$g_sec_to = secret_name($no);
	}


	# テンポラリ用ディレクトリにコピー
	unless ($where){
		copy($g_pub_from, $t_pub);
		copy($g_sec_from, $t_sec);
	}

	# gzip展開
	#   Unixの場合のみ, Windowsの場合はファイル名を変えるだけ
	my $isUnix = $ENV{'SERVER_SOFTWARE'} =~m/Unix/;
	unless ($where){
		if ($isUnix){
			system("gunzip $t_pub");
			system("gunzip $t_sec");
		}else{
			rename($t_pub, $g_pub_to);
			rename($t_sec, $g_sec_to);
		}
	}else{
		if ($isUnix){
			system("gunzip $g_pub_from");
			system("gunzip $g_sec_from");
		}else{
			rename($g_pub_from, $g_pub_to);
			rename($g_sec_from, $g_sec_to);
		}

	}



	if ($ENV{'SERVER_SOFTWARE'} =~m/Unix/){
	}else{
	}


}




#
# ログファイルをgzip圧縮する
#
sub gzip{
	my $no = shift;

	# gzipするファイル
	my $log_public = public_name($no);
	my $log_secret = secret_name($no);

	# gzipされたあとのファイル名
	my $gz_public = gzip_public_name($no);
	my $gz_secret = gzip_secret_name($no);

	# ファイルロックする
	return 0 unless(filelock($log_public) and filelock($log_secret));

	# gzip圧縮
	#   Unixの場合のみ, Windowsの場合はファイル名を変えるだけ
	if ($ENV{'SERVER_SOFTWARE'} =~m/Unix/){
		system("gzip $log_public");
		system("gzip $log_secret");
	}else{
		rename($log_public, $gz_public);
		rename($log_secret, $gz_secret);
	}

	return 0 unless(-f $gz_public and -f $gz_secret);

	# ロック解除
	clear($no);

	return 1;
}




#
#   ログを読み取るに当たって作成した一時ファイルや
#   ロックファイルを削除する
#
sub clear{
	my $no   = shift;      # スレッド番号
	my $contLock = shift;  # ロックは削除しない

	unless ($contLock){
		unlock(public_name($no));
		unlock(secret_name($no));
	}
	unlink(gzip_public_name_in_temp($no));
	unlink(gzip_secret_name_in_temp($no));
	unlink(gunzip_public_name($no));
	unlink(gunzip_secret_name($no));

}



###########################################################################
#                    スレッド情報一覧を読み込む                           #
###########################################################################
sub thread_read{
	my $thread = shift;   # スレッド情報(参照)
	my $gzip   = shift;   # この値が真のとき、dat化されたスレッドの情報も読み取る

	# （公開）ログディレクトリからログファイル名一覧を読み込む
	return undef unless(opendir (DIR, $CONF->{'system'}->{'log'}->{'public'}));
	my @filenames = readdir(DIR);
	closedir(DIR);

	my @logfiles = grep(/^\d+\.${constants::EXT_PUBLIC}\.${constants::EXT_LOG}$/, @filenames);
	if ($gzip){
		push(@logfiles, grep(/^\d+\.${constants::EXT_PUBLIC}\.${constants::EXT_LOG}\.${constants::EXT_GZIP}$/, @filenames));
	}

	# それをスレッド番号に変換する
	my @thread_no = map { $_=~s/^(\d+).*/$1/; $_=$1; } @logfiles;

	# データを全部読み込む
	my $c = 0;    # $c is counter.
	foreach my $no(@thread_no){
		my @log;
		next unless(read_log($no, \@log, 0, 0, 1));
		        # ロックをかけつづけない、ヘッダ部分だけを読む、gz圧縮も読む
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

	warn $log_public;
	warn $log_secret;
	warn $temp_public;
	warn $temp_secret;

	# ログテンポラリファイル[公開部]を開く
	unless(open(TEMP, ">$temp_public")){
		unlock($log_public);
		unlock($log_secret);
		return 0;
	}
	binmode(TEMP, ":utf8");	

	warn "499 line ok";


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
		common_write(*TEMP, $$log[$i]) unless($$log[$i]{'DELETE_TIME'});
		sub common_write{
			local(*FOUT) = shift; # 出力先ファイルハンドル
			my $log = shift;
			print FOUT "TITLE<>$$log{'TITLE'}\n";                                     # 発言タイトル
			print FOUT "USER_NAME<>$$log{'USER_NAME'}\n";                             # 投稿者氏名
			print FOUT "USER_EMAIL<>$$log{'USER_EMAIL'}\n";                           # 投稿者e-mail
			print FOUT "USER_WEBPAGE<>$$log{'USER_WEBPAGE'}\n";                       # 投稿者webpage
			print FOUT "USER_ID<>$$log{'USER_ID'}\n" if (defined($$log{'USER_ID'}));  # 投稿者固有ID
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
	}
	binmode(TEMP, ":utf8");	

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
	warn "595 line bad";
	chmod($constants::PUBLIC_FILE_PERMISSION, $temp_public);
	chmod($constants::SECRET_FILE_PERMISSION, $temp_secret);
	return 1 if (renew($log_public) and renew($log_secret));


	warn "601 line bad";

	# 更新失敗
	unlock($log_public);
	unlock($log_secret);
	return 0;

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
	utf8::decode($read);
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
	binmode(TEMP, ":utf8");	
	print TEMP "$pointer\n";
	close(TEMP);
	chmod($constants::SECRET_FILE_PERMISSION, $pointer_temp);
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
		utf8::decode($line);
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
	binmode(TEMP, ":utf8");	

	# ブラックリスト書き込み～更新
	foreach my $line(@_){
		print TEMP "$line\n";
	}
	close(TEMP);
	chmod($constants::SECRET_FILE_PERMISSION, $tempfile);
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
		utf8::decode($line);
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
	binmode(TEMP, ":utf8");	

	my ($user, $pass);
	while ( ($user, $pass) = each(%$passwords) ){
		print TEMP "$user:$pass\n";
	}
	close(TEMP);
	chmod($constants::SECRET_FILE_PERMISSION, $pass_temp);
	return renew($pass_file);

}


##########################################################################
#                 ファイルをロックする/ロック開放待ち                    #
##########################################################################
sub filelock{
	my $filename = shift;                  # ロックするファイル名

	return 0 unless(-f $filename);
	return 1 if ($CONF->{'system'}->{'fileLock'} == 0);            # ファイルロックなし

	my $lockfile = lock_name($filename);
	foreach (1..10){

		unless(lock_check($filename)){

			if ($CONF->{'system'}->{'fileLock'} == 1){     # symlinkロック
				my $lock_ok;
				eval "$lock_ok = symlink($filename, $lockfile)";
				return 0 if ($@);
				return 1 if ($lock_ok);

			}else{                                  # mkdirロック
				return 1 if (mkdir($lockfile, 0755));

			}
		}

		# 0.1秒待つ(Time::Hires利用)
		sleep(0.1);
	}
	return 0;
}


##########################################################################
#          ファイルがロックされているかどうかチェックする                #
##########################################################################
sub lock_check{

	if ($CONF->{'system'}->{'fileLock'} == 0){      # ファイルロックなし
		return 1;

	}elsif ($CONF->{'system'}->{'fileLock'} == 1){  # symlinkロック
		return (-l lock_name(shift));

	}else{                                   # mkdirロック
		return (-d lock_name(shift));

	}
}


##########################################################################
#                       ファイルのロックを解除する                       #
##########################################################################
sub unlock{
	if ($CONF->{'system'}->{'fileLock'} == 0){      # ファイルロックなし
		return 1;

	}elsif ($CONF->{'system'}->{'fileLock'} == 1){  # symlinkロック
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

	# 更新元テンポラリファイルが存在しない場合は処理を行わない
	return 0 unless (-e $tempfile);

	# テンポラリファイル→実ファイル変換
	File::Copy::move($tempfile, $filename) or warn "Cannot renew File from $tempfile to $filename: $!";
	rename($tempfile, $filename);

	# ロック解除
	if ($CONF->{'system'}->{'fileLock'} == 2){
		rmdir($lockfile);
	}else{
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
	return sprintf("%s%d.%s.%s",
		$CONF->{'system'}->{'log'}->{'public'}, $no,
		$constants::EXT_PUBLIC, $constants::EXT_LOG
	);
}


#
# 非公開ログファイル名を生成する
#
sub secret_name{
	my $no = shift;
	return sprintf("%s%d.%s.%s",
		$CONF->{'system'}->{'log'}->{'secret'}, $no,
		$constants::EXT_SECRET, $constants::EXT_LOG
	);
}

#
# gzip圧縮した公開ログファイル名を生成する
#
sub gzip_public_name{
	return public_name(shift) . '.' . $constants::EXT_GZIP;
}
#
# gzip圧縮した非公開ログファイル名を生成する
#
sub gzip_secret_name{
	return secret_name(shift) . '.' . $constants::EXT_GZIP;
}

#
# gzip圧縮を解除して*テンポラリに展開した*公開ログファイル名を生成する
#
sub gunzip_public_name{
	my $no = shift;
	return sprintf("%s%d.%s.%d.%s",
		$CONF->{'system'}->{'tmp'}, $no,
		$constants::EXT_PUBLIC, $$, $constants::EXT_LOG
	);
}


#
# gzip圧縮を解除して*テンポラリに展開した*非公開ログファイル名を生成する
#
sub gunzip_secret_name{
	my $no = shift;
	return sprintf("%s%d.%s.%d.%s",
		$CONF->{'system'}->{'tmp'}, $no,
		$constants::EXT_SECRET, $$, $constants::EXT_LOG
	);
}


#
# *テンポラリにコピーされた*gzip圧縮の公開ログファイル名を生成する
#
sub gzip_public_name_in_temp{
	return gunzip_public_name(shift) . '.' . $constants::EXT_GZIP;
}
#
# *テンポラリにコピーされた*gzip圧縮の非公開ログファイル名を生成する
#
sub gzip_secret_name_in_temp{
	return gunzip_secret_name(shift) . '.' . $constants::EXT_GZIP;
}




#
# ロックファイル名を生成する
#
sub lock_name{
	my $filename = shift;
	return sprintf("%s%s.%s",
		$CONF->{'system'}->{'tmp'},
		sha1_hex($filename),
		$constants::EXT_LOCK
	);
}


#
# テンポラリファイル名を生成する
#
sub temp_name{
	my $filename = shift;
	return sprintf("%s%s.%s",
		$CONF->{'system'}->{'tmp'},
		sha1_hex($filename),
		$constants::EXT_TEMP
	);
}


#
# ポインタファイル名を生成する
#
sub pointer_name{
	return $CONF->{'system'}->{'log'}->{'secret'} . $constants::POINTER_FILE;
}


#
# スレッド建てすぎブラックリストファイル名を生成する
#
sub blacklist_name{
	return $CONF->{'system'}->{'log'}->{'secret'} . $constants::BLACKLIST_FILE;
}


#
# HTML化済みのログファイル名を作成する
#
sub html_name{
	return sprintf("%s%d.%s",
		$CONF->{'system'}->{'log'}->{'html'} ,
		shift , $constants::EXT_HTML
	);
}


#
# 管理者パスワードファイル名を生成する
#
sub adminpass_name{
	return $CONF->{'system'}->{'log'}->{'secret'} . $constants::ADMIN_PASSWORD_FILE;
}


1;


