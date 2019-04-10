#!/usr/bin/perl
use strict;
use File::Path;
use lib '/home/sarinaga/perl/lib/perl5/site_perl/5.14';
use Crypt::PasswdMD5;
use utf8;

require './configReader.pl';
require './constants.pl';
require './std.pl';
require './file.pl';
require './html.pl';

use vars qw($CONF);
$CONF = configReader::readConfig();
$file::CONF = $CONF;
$html::CONF = $CONF;

binmode(STDOUT, ":utf8");

##########################################################################
#                   ファイル、ディレクトリの初期化                       #
##########################################################################
sub createDirectory{

	# ディレクトリを作る
	my %dirs = (
	  "$CONF->{'system'}->{'log'}->{'public'}" => $constants::PUBLIC_DIR_PERMISSION,
	  "$CONF->{'system'}->{'log'}->{'secret'}" => $constants::SECRET_DIR_PERMISSION,
 	  "$CONF->{'system'}->{'log'}->{'html'}"   => $constants::PUBLIC_DIR_PERMISSION,
	);

	foreach my $dir(keys %dirs){
		my $permission = $dirs{$dir};
		chop($dir);
		if (-e $dir){
			if (-d $dir){
				rmtree($dir);
				print "ディレクトリ'${dir}'があったので削除します.\n";
			}else{
				unlink($dir);
				print "ファイル'${dir}'があったので削除します.\n";
			}
		}

		if (-e $dir){
			die "ディレクトリまたはファイル'${dir}'を削除できませんでした. ";
		}

		unless (mkdir($dir, $permission)){
			die "ディレクトリ'${dir}'を作成できませんでした. ";
		}

		print "ディレクトリ'${dir}'を作成しました.\n";
	}

}

##########################################################################
#                       ポインタファイルの作成                           #
##########################################################################
sub createPointer(){
	my $pointer_file = file::pointer_name();
	unless(open(FOUT, ">${pointer_file}")){
		die "ポインタファイル'${pointer_file}'を初期化できませんでした.";
	}
	print FOUT "0\n";
	close(FOUT);

	unless(chmod($constants::SECRET_FILE_PERMISSION, $pointer_file)){
		die "ポインタファイル'${pointer_file}'にパーミッションが設定できませんでした.";
	}
	print "ポインタファイル'${pointer_file}'を作成しました.\n";
}

##########################################################################
#                     ブラックリストファイルの作成                       #
##########################################################################
sub createBlacklist(){

	my $blacklist_file = file::blacklist_name();
	unless(open(FOUT, ">${blacklist_file}")){
		die "ブラックリストファイル'${blacklist_file}'を初期化できませんでした.";
	}
	close(FOUT);
	unless(chmod($constants::SECRET_FILE_PERMISSION, $blacklist_file)){
		die "ブラックリストファイル'${blacklist_file}'にパーミッションが設定できませんでした.";
	}
	print "ブラックリストファイル'${blacklist_file}'を作成しました.\n";

}

##########################################################################
#                   管理者パスワードファイルの作成                       #
##########################################################################
sub createAdminPassword(){
	my $password_file = file::adminpass_name();
	unless(open(FOUT, ">$password_file")){
		die "管理者パスワードファイル'${password_file}'を初期化できませんでした.";
	}
	my $cpassword = apache_md5_crypt('admin', std::salt());
	print FOUT "admin:$cpassword\n";
	close(FOUT);
	unless(chmod($constants::SECRET_FILE_PERMISSION, $password_file)){
		die "管理者パスワードファイル'${password_file}'にパーミッションが設定できませんでした.";
	}
	print "管理者パスワードファイル'${password_file}'を作成しました.\n";

}

###########################################################################
#                       bbs.htmlとadmin.htmlの作成                        #
###########################################################################
sub createPage{


	# bbs.htmlの作成
	my @thread;
	unless (html::create_bbshtml(\@thread)){
		die "トップページ'bbs.html'が作成できませんでした.";
	}
	print "トップページ'bbs.html'を作成しました.\n";

	# admin.htmlの作成
	unless (html::create_adminpage()){
		die "管理者ページ'admin.html'が作成できませんでした.";
	}
	print "管理者ページ'admin.html'を作成しました.\n";
}

###########################################################################
#                        cgiに実行権限を付与                           #
###########################################################################
sub setPermission{
	chmod 0700, "./$constants::READ_CGI";
	print "'${constants::READ_CGI}'に実行権限をつけました.\n";
	chmod 0700, "./$constants::WRITE_CGI";
	print "'${constants::WRITE_CGI}'に実行権限をつけました.\n";
	chmod 0700, "./$constants::ADMIN_CGI";
	print "'${constants::ADMIN_CGI}'に実行権限をつけました.\n";
}


createDirectory();
createPointer();
createBlacklist();
createAdminPassword();
createPage();
setPermission();

print "インストールが正しく終了しました. 'bbs.html'からアクセスできます.\n";
