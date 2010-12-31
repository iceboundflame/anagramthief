var Anathief = function() {
  var gd;
  var jug;

  function log(x) {
    if (typeof console == "object")
      console.log(x);
  }

  function init(_gd) {
    gd = _gd;

    initConn();

    initDefinitions();

    initChat();

    initGameInterface();

    initInviteInterface();
  }

  /** Connectivity **/

  function initConn() {
    /*window.WEB_SOCKET_SWF_LOCATION = "http://iceboundflame.com:8080/WebSocketMain.swf";*/

    disableGameUi();
    addMessage(null, 'Connecting...');

    jug = new Juggernaut();
    jug.on('connect', onConnect);
    jug.on('disconnect', onDisconnect);
    jug.on('reconnect', onReconnect);
    jug.subscribe(gd.jchan, onDataReceived);

    if (gd.heartRate > 0)
      setInterval('Anathief.heartbeat()', gd.heartRate);
  }

  function disableGameUi() {
    $('.game-ui').attr('disabled', 'disabled');
  }
  function enableGameUi() {
    $('.game-ui').removeAttr('disabled');
  }

  function onConnect() {
    refreshState();
    addMessage(null, 'Connected!');
    enableGameUi();
    log('Connected');
  }
  function onDisconnect() {
    addMessage(null, 'Disconnected.');
    disableGameUi();
    log('Disconnected');
  }
  function onReconnect() {
    addMessage(null, 'Reconnecting...');
    log('Reconnecting');
  }

  function onDataReceived(data) {
    log(data);
    switch (data.type) {
      case 'chat':
        addMessage(data.from, data.body, false);
        break;

      case 'action':
        addMessage(data.from, data.body, true, data.msgclass);
        break;

      case 'pool_update':
        updatePool(data.body);
        break;

      case 'players_update':
        if (data.restarted) {
          gd.voteRestart = false;
          updateRestartButton();
        }

        updatePlayersInfo(data.order, data.body, data.added, data.removed, data.new_word_id);
        break;

      case 'definitions':
        newdef = $('<div class="active-defn" />').html(data.body);
        $('#definition').children().removeClass('active-defn');
        $('#definition').append(newdef);

        break;
    }
  }

  function heartbeat() {
    $.post(gd.urls.heartbeat);
    log("Heartbeat");
  }

  /** Definitions **/

  function initDefinitions() {
    $('#prev-defn').click(function () { switchDefn('prev'); return false; });
    $('#next-defn').click(function () { switchDefn('next'); return false; });
  }
  function switchDefn(whichWay) { // whichWay = 'prev' or 'next'
    cur = $('.active-defn');
    next = cur[whichWay]();
    if (next.size()) {
      cur.removeClass('active-defn');
      next.addClass('active-defn');
    }
  }

  /** Chat **/

  function initChat() {
    $('#chat').focus(function() {
      if ($('#chat').val() == gd.chatFiller)
        $('#chat').val('');
    });
    $('#chat').blur(function() {
      if ($('#chat').val() == '')
        $('#chat').val(gd.chatFiller);
    });

    $('#chat').keyup(function(e) {
      if (e.keyCode != 13) return;
      var msg = $('#chat').val();

      if (!msg) return;

      $.post(gd.urls.chat,
        {message: msg});

      $('#chat').val('');
      return false;
    });
  }

  /** Game Interface: Flip, Claim, Vote Restart **/

  var votedRestart = false;

  function initGameInterface() {
    $('#flip-btn').click(function() {
      flipChar();
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

    $('#vote-restart-btn').click(function() {
      confMsg = "Are you sure you want to vote to restart the game?";
      if (!votedRestart && !confirm(confMsg))
        return;
      votedRestart = !votedRestart;
      $.post(gd.urls.voteRestart,
        {vote: votedRestart});
      updateRestartButton();
    });

    $('#refresh-btn').click(function() { refreshState(); return false; });
  }

  function refreshState() {
    $.post(gd.urls.refresh, {},
      function(data) {
        if (data.players_info) {
          updatePlayersInfo(data.players_info.order, data.players_info.body);
        }
        if (data.pool_info) {
          updatePool(data.pool_info.body);
        }
      },
      'json');
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

  function updateRestartButton() {
    $('#vote-restart-btn').val(
        votedRestart ? 'Cancel restart' : 'Vote to restart');
  }

  function updatePool(body) {
    $('#pool-info').html(body);
  }

  function updatePlayersInfo(order, body, added, removed, new_word_id) {
    $('#player-info-area').empty();
    for (var i in order) {
      var id = order[i];
      $('#player-info-area').append(body[id]);
    }
    if (added) {
      for (var i in added) {
        var id = added[i];
        $('#player-info-'+id).effect('highlight', {}, 3000);
      }
    }
    if (removed) {
      // TODO
    }

    if (new_word_id) {
      wordItem = $('#word-'+new_word_id.join('-'));

      wordItem.addClass('highlighted');
      wordItem.effect('highlight', {}, 5000);
    }
  }

  // Messages area
  function addMessage(from, message, isAction, msgclass) {
    var msgId = 'message-' + Math.floor(Math.random()*2147483647);
    var li = $('<li id="'+msgId+'" />');
    if (from)
      li.append($('<strong />').text(from.name)).append(' ');
    if (msgclass) li.addClass(msgclass);
    li.append(message);
    $('#messages').append(li);
    messageArea = $('#message-area');
    messageArea.scrollTop(messageArea[0].scrollHeight);
    $('#'+msgId).effect('highlight', {}, 3000);
  }

  function initInviteInterface() {
    $('#show-invites-link').click(function() {
      showInvites();
      return false;
    });
    $('#hide-invites-link').click(function() {
      hideInvites();
      return false;
    });
    $('#invite-url').focus(function() { this.select(); });
    $('#invite-url').select(function() { this.select(); });
    $('#invite-url').mouseover(function() { this.focus(); this.select(); });
  }

  function hideInvites() {
    $('#hide-invites-link').hide();
    $('#show-invites-link').show();
    $('#invites-section').slideUp(); //null, FB.Canvas.setSize);
  }
  function showInvites() {
    $('#show-invites-link').hide();
    $('#hide-invites-link').show();
    $('#invites-section').slideDown(); //null, FB.Canvas.setSize);
  }

  return {
    init: init,
    heartbeat: heartbeat,
    hideInvites: hideInvites,
    showInvites: showInvites
  };
}();
