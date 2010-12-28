function log(x) {
	if (typeof console == "object")
		console.log(x);
}

var voteRestart = false;

function initGame() {
	window.WEB_SOCKET_SWF_LOCATION = "http://iceboundflame.com:8080/WebSocketMain.swf";
	var jug = new Juggernaut;
	jug.subscribe(jchan, function(data){
		log(data);
		switch (data.type) {
			case 'chat':
				addMessage(data.from, data.body, false);
				break;
			case 'action':
				addMessage(data.from, data.body, true);
				break;
			case 'pool_update':
				$('#pool-info').html(data.body);
				break;
        /*case 'refresh_state':*/
        /*$.post(playRefreshStateUrl);*/
        /*break;*/
			case 'players_update':
        if (data.restarted) {
          voteRestart = false;
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

        if (data.new_word) {

        }

				break;
		}
	});

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

		$.post(playChatUrl,
			{message: msg});

		$('#talk').val('');
		return false;
	});

	$('#claimword').keyup(function(e) {
		if (e.keyCode != 13) return;

		var word = $('#claimword').val();
		if (!word) return;
		$.post(playClaimUrl,
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
    voteRestart = !voteRestart;
    $.post(playVoteRestartUrl,
      {vote: voteRestart});
    updateRestartButton();
  });
}

function updateRestartButton() {
  $('#vote-restart').val(voteRestart ? 'Cancel restart' : 'Vote to restart');
}

function flipChar() {
	$.post(playFlipCharUrl,
		function(data) {
			if (data.message) {
				addMessage(null, data.message, true);
			}
		});
	$('#claimword').focus();
}

function addMessage(from, message, isAction) {
  var msgId = 'message-' + Math.floor(Math.random()*2147483647);
	var li = $('<li id="'+msgId+'" />');
	if (from)
		li.append($('<strong />').text(from.name)).append(' ');
	li.append(message);
	$('#messages').append(li);
	messageArea = $('#message-area');
	/*console.log(messageArea[0].scrollHeight);*/
	messageArea.scrollTop(messageArea[0].scrollHeight);
  $('#'+msgId).effect('highlight', {}, 3000);
}
