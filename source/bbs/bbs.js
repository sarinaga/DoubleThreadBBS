/**************************************************************************
                                   �Ķ�������

  ������ʬ�ϡ��ƥ����Ȥ�褯�ɤ�����bbs.conf���ͤ˹�碌�Ƥ���������
 **************************************************************************/
var password_min = 5;   // �����ͤ��ѹ����ƤϤ����ޤ���ʥѥ���ɤκǾ�Ĺ����
var password_max = 20;  // �ѥ���ɤκ���Ĺ��
var trip_max     = 10;  // �ȥ�åפκ���Ĺ��
var base_http    = "http://www.sarinaga.com/bbs/";
//var base_http    = "http://localhost/bbs/";

/**************************************************************************
                             cookie�����ꡦ����

  http://www.din.or.jp/~hagi3/JavaScript/JSTips/CookieCounter.htm
  �Υ����������Ѥ��Ƥ��ޤ���
 **************************************************************************/

//----- Cookie����ؿ� -----
function setCookie(name, value, expires){
	document.cookie = name + '=' + escape(value) + 
	                  ((expires==null) ? '' : '; expires=' + expires.toGMTString());

}


//----- Cookie �����ؿ� -----
function getCookie(name){

	// cookieʸ����0�λ���null���֤�
	if (document.cookie.length == 0) return '';

	// cookie�Υ����򸡺�����ʥ������ʤ�����null���֤���
	var search = name + '=';
	offset = document.cookie.indexOf(search);
	if (offset == -1) return '';

	// cookie�����Ƥ��ڤ�Ф�
	offset += search.length;
	end = document.cookie.indexOf(';', offset);
	if(end == -1) end = document.cookie.length;

	return unescape(document.cookie.substring(offset, end));
}



//----- Cookie ͭ�����·׻� -----
function compute_expires(day){
	var today = new Date();
	var expires = today;
	expires.setTime(today.getTime() + (1000 * 60 * 60 * 24 * day) );
	return expires;
}


/**************************************************************************
                           ���ϥե���������å�

  http://www.scollabo.com/banban/magazine/review_063.html
  http://www.tagindex.com/javascript/form/check3.html
  �Υ����������Ѥ��Ƥ��ޤ���
 **************************************************************************/

//----- �ɤ߹��ߥե����������� -----
function check_read_form(form, last){ 

	// ȯ���ֹ�˿��������äƤ��뤫��
	if (!form.st.value.match(/^\d+$/) ||
	    !form.en.value.match(/^\d+$/)    )  {
		alert("ȯ���ֹ�ˤϿ��ͤ����Ϥ��Ƥ���������");
		form.st.focus();
		return false;
	}

	// ȯ���ֹ椬�ͤ���Ƥ���
//	if (form.st.value > form.en.value){   // ���ޤ���Ӥ��Ǥ��Ƥ��ޤ���
//		alert("�ɤ߽�����ȯ���ֹ���ɤ߻Ϥ��ȯ���ֹ����礭�����Ƥ���������");
//		form.st.focus();
//		return false;
//	}

	// �����ʹְ㤤
	if (form.en.value > last){
		alert("�ɤ߽�����ȯ���ֹ椬����åɤκǽ�ȯ���ֹ����礭���Ǥ���");
		form.en.focus();
		return false;
	}

	// �����ȥ뤬ȯ���Τɤ��餫��ɽ�������뤳��
	if (form.sub.checked == false && form.mes.checked == false){
		alert("��̾ɽ����ȯ��ɽ���Τɤ��餫�˥����å�������Ƥ���������");
		form.sub.focus();
		return false;
	}

	// �Ǹ�ޤǥ��ꥢ
	return true;

}



//----- �񤭹��ߥե����������� -----
function check_write_form(form){

	// �ѥ�������¤˰��ä����äƤ����饨�顼
	if (!check_password(form.pass.value)){
		form.pass.focus();
		return false;
	}

	// �ȥ�å����¤˰��ä����äƤ����饨�顼
	if (form.trip != null){
		var trip = form.trip.value;
		len = trip.length;	// ʸ���������å�
		if (len > trip_max){
			alert("�ȥ�åפ�ʸ������" + trip_max + "ʸ����������Ϥ��ޤ���");
			form.trip.focus();
			return false;
		}
		if (trip.match(/[^0-9A-Za-z]/)){	// ����ʸ�������å�
			alert("�ȥ�åפ����Ϥ������Ǥ���");
			form.trip.focus();
			return false;
		}
	}

	// email���Ϥ��������ä��饨�顼[�ʰץ����å�]
	if (form.email.value != ""  && !form.email.value.match(/.+@.+\..+/)){ 
		alert("email�����Ϥ������Ǥ���");
		form.email.focus();
		return false;
	}


	// webpage���Ϥ��������ä��饨�顼
	if (form.web.value != "" && !form.web.value.match(/^[-_.!~*'()a-zA-Z0-9;\/?:@&=+$,%#]+$/)){
		alert("webpage�����Ϥ������Ǥ���");
		form.web.focus();
		return false;
	}


	// ����å�̾�����Ϥ���Ƥ��ʤ��ä��饨�顼
	if (form.mode.value == "create"){
		if (form.thread.value == ""){
			alert("����å�̾�����Ϥ���Ƥ��ޤ���");
			form.thread.focus();
			return false;
		}
	}

	// �����ȥ롢��ʸ�Τ����ɤ��餫�����Ϥ���Ƥ��ʤ��ä��饨�顼
	if (form.title.value == "" && form.body.value == ""){
		alert("��̾����ʸ�Τɤ��餫���������Ϥ��Ƥ���������");
		form.title.focus();
		return false;
	}

	// �Ǹ�ޤǥ��ꥢ
	return true;

}

//----- �ѥ�����������ϥ����å� -----
function check_password(password){

	var len = password.length;  // ʸ���������å�
	if (len < password_min || len > password_max){
		alert("�ѥ���ɤ�ʸ������" + password_min + "ʸ���ʾ� " + password_max + "ʸ����������Ϥ��ޤ���");
		return false;
	}
	if (password.match(/[^0-9A-Za-z]/)){  // ����ʸ�������å�
		alert("�ѥ���ɤ����Ϥ������Ǥ���");
		return false;
	}
	return true;
}


//----- �ե�����Υꥻ�å����˥����å����� -----
function reset_form(){
	return window.confirm("���ϥե�������������ޤ���������Ǥ�����");
}

