/**************************************************************************
                                   環境設定値

  この部分は、各コメントをよく読んだ上でbbs.confの値に合わせてください。
 **************************************************************************/
var password_min = 5;   // この値は変更してはいけません（パスワードの最小長さ）
var password_max = 20;  // パスワードの最大長さ
var trip_max     = 10;  // トリップの最大長さ
var base_http    = "http://www.sarinaga.com/bbs/";
//var base_http    = "http://localhost/bbs/";

/**************************************************************************
                             cookieの設定・取得

  http://www.din.or.jp/~hagi3/JavaScript/JSTips/CookieCounter.htm
  のソースを利用しています。
 **************************************************************************/

//----- Cookie設定関数 -----
function setCookie(name, value, expires){
	document.cookie = name + '=' + escape(value) + 
	                  ((expires==null) ? '' : '; expires=' + expires.toGMTString());

}


//----- Cookie 取得関数 -----
function getCookie(name){

	// cookie文字列が0の時はnullを返す
	if (document.cookie.length == 0) return '';

	// cookieのキーを検索する（キーがない場合はnullを返す）
	var search = name + '=';
	offset = document.cookie.indexOf(search);
	if (offset == -1) return '';

	// cookieの内容を切り出す
	offset += search.length;
	end = document.cookie.indexOf(';', offset);
	if(end == -1) end = document.cookie.length;

	return unescape(document.cookie.substring(offset, end));
}



//----- Cookie 有効期限計算 -----
function compute_expires(day){
	var today = new Date();
	var expires = today;
	expires.setTime(today.getTime() + (1000 * 60 * 60 * 24 * day) );
	return expires;
}


/**************************************************************************
                           入力フォームチェック

  http://www.scollabo.com/banban/magazine/review_063.html
  http://www.tagindex.com/javascript/form/check3.html
  のソースを利用しています。
 **************************************************************************/

//----- 読み込みフォーム整合性 -----
function check_read_form(form, last){ 

	// 発言番号に数字が入っているか？
	if (!form.st.value.match(/^\d+$/) ||
	    !form.en.value.match(/^\d+$/)    )  {
		alert("発言番号には数値を入力してください。");
		form.st.focus();
		return false;
	}

	// 発言番号がねじれている
//	if (form.st.value > form.en.value){   // うまく比較ができていません
//		alert("読み終わりの発言番号を読み始めの発言番号より大きくしてください。");
//		form.st.focus();
//		return false;
//	}

	// 最大値間違い
	if (form.en.value > last){
		alert("読み終わりの発言番号がスレッドの最終発言番号より大きいです。");
		form.en.focus();
		return false;
	}

	// タイトルが発言のどちらかを表示させること
	if (form.sub.checked == false && form.mes.checked == false){
		alert("題名表示か発言表示のどちらかにチェックを入れてください。");
		form.sub.focus();
		return false;
	}

	// 最後までクリア
	return true;

}



//----- 書き込みフォーム整合性 -----
function check_write_form(form){

	// パスワード制限に引っかかっていたらエラー
	if (!check_password(form.pass.value)){
		form.pass.focus();
		return false;
	}

	// トリップ制限に引っかかっていたらエラー
	if (form.trip != null){
		var trip = form.trip.value;
		len = trip.length;	// 文字数チェック
		if (len > trip_max){
			alert("トリップの文字数は" + trip_max + "文字以内で入力します。");
			form.trip.focus();
			return false;
		}
		if (trip.match(/[^0-9A-Za-z]/)){	// 入力文字チェック
			alert("トリップの入力が不正です。");
			form.trip.focus();
			return false;
		}
	}

	// email入力が不正だったらエラー[簡易チェック]
	if (form.email.value != ""  && !form.email.value.match(/.+@.+\..+/)){ 
		alert("emailの入力が不正です。");
		form.email.focus();
		return false;
	}


	// webpage入力が不正だったらエラー
	if (form.web.value != "" && !form.web.value.match(/^[-_.!~*'()a-zA-Z0-9;\/?:@&=+$,%#]+$/)){
		alert("webpageの入力が不正です。");
		form.web.focus();
		return false;
	}


	// スレッド名が入力されていなかったらエラー
	if (form.mode.value == "create"){
		if (form.thread.value == ""){
			alert("スレッド名が入力されていません。");
			form.thread.focus();
			return false;
		}
	}

	// タイトル、本文のうちどちらかが入力されていなかったらエラー
	if (form.title.value == "" && form.body.value == ""){
		alert("題名か本文のどちらか一方を入力してください。");
		form.title.focus();
		return false;
	}

	// 最後までクリア
	return true;

}

//----- パスワード不正入力チェック -----
function check_password(password){

	var len = password.length;  // 文字数チェック
	if (len < password_min || len > password_max){
		alert("パスワードの文字数は" + password_min + "文字以上 " + password_max + "文字以内で入力します。");
		return false;
	}
	if (password.match(/[^0-9A-Za-z]/)){  // 入力文字チェック
		alert("パスワードの入力が不正です。");
		return false;
	}
	return true;
}


//----- フォームのリセット前にチェックする -----
function reset_form(){
	return window.confirm("入力フォームを初期化します。よろしいですか？");
}

