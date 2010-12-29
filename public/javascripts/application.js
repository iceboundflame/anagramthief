function log(x) {
	if (typeof console == "object")
		console.log(x);
}

function initGame() {
	window.WEB_SOCKET_SWF_LOCATION = "http://iceboundflame.com:8080/WebSocketMain.swf";
	var jug = new Juggernaut;
	jug.subscribe(gd.jchan, function(data){
		log(data);
		switch (data.type) {
			case 'chat':
				addMessage(data.from, data.body, false);
				break;
			case 'action':
				addMessage(data.from, data.body, true, data.msgclass);
				break;
			case 'pool_update':
				$('#pool-info').html(data.body);
				break;
        /*case 'refresh_state':*/
        /*$.post(gd.urls.refreshState);*/
        /*break;*/
			case 'players_update':
        if (data.restarted) {
          gd.voteRestart = false;
          updateRestartButton();
        }

				$('#player-info-area').empty();
				for (var i in data.order) {
					var id = data.order[i];
					$('#player-info-area').append(data.body[id]);
				}
				if (data.added) {
					for (var i in data.added) {
						var id = data.added[i];
						$('#player-info-'+id).effect('highlight', {}, 3000);
					}
				}
				if (data.removed) {
					// TODO
				}

        if (data.new_word_id) {
          $('#word-'+data.new_word_id.join('-')).effect(
              'highlight', {}, 5000);
        }

				break;

			case 'definitions':
        newdef = $('<div class="active-defn" />').html(data.body);
        $('#definition').children().removeClass('active-defn');
        $('#definition').append(newdef);

				break;
		}
	});

  function switchDefn(whichWay) { // whichWay = 'prev' or 'next'
    cur = $('.active-defn');
    next = cur[whichWay]();
    if (next.size()) {
      cur.removeClass('active-defn');
      next.addClass('active-defn');
    }
  }
  $('#prev-defn').click(function () { switchDefn('prev'); });
  $('#next-defn').click(function () { switchDefn('next'); });

	var talkFiller = 'Say something...';
	$('#talk').focus(function() {
		if ($('#talk').val() == talkFiller)
			$('#talk').val('');
	});
	$('#talk').blur(function() {
		if ($('#talk').val() == '')
			$('#talk').val(talkFiller);
	});

	$('#talk').keyup(function(e) {
		if (e.keyCode != 13) return;
		var msg = $('#talk').val();

		if (!msg) return;

		$.post(gd.urls.chat,
			{message: msg});

		$('#talk').val('');
		return false;
	});

	$('#claimword').keyup(function(e) {
		if (e.keyCode != 13) return;

		var word = $('#claimword').val();
		if (!word) {
      flipChar();
      return;
    }

		$.post(gd.urls.claim,
			{word: word},
			function(data) {
				if (data.message) {
					addMessage(null, data.message, true);
				}
			},
			'json');

		$('#claimword').val('');
	});

  $('#vote-restart').click(function() {
    if (!gd.voteRestart && !confirm("Are you sure you want to vote to restart?"))
      return;
    gd.voteRestart = !gd.voteRestart;
    $.post(gd.urls.voteRestart,
      {vote: gd.voteRestart});
    updateRestartButton();
  });

  /*setInterval("heartbeat()", 5000);*/
}

function heartbeat() {
  $.post(gd.urls.heartbeat);
  log("Heartbeat");
}

function updateRestartButton() {
  $('#vote-restart').val(gd.voteRestart ? 'Cancel restart' : 'Vote to restart');
}

function flipChar() {
	$.post(gd.urls.flipChar,
		function(data) {
			if (data.message) {
				addMessage(null, data.message, true);
			}
		});
	$('#claimword').focus();
}

function addMessage(from, message, isAction, msgclass) {
  var msgId = 'message-' + Math.floor(Math.random()*2147483647);
	var li = $('<li id="'+msgId+'" />');
	if (from)
		li.append($('<strong />').text(from.name)).append(' ');
  if (msgclass) li.addClass(msgclass);
	li.append(message);
	$('#messages').append(li);
	messageArea = $('#message-area');
	/*log(messageArea[0].scrollHeight);*/
	messageArea.scrollTop(messageArea[0].scrollHeight);
  $('#'+msgId).effect('highlight', {}, 3000);
}
