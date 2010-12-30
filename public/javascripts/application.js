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
  }

  /** Connectivity **/

  function initConn() {
    /*window.WEB_SOCKET_SWF_LOCATION = "http://iceboundflame.com:8080/WebSocketMain.swf";*/

    jug = new Juggernaut();
    jug.on('connect', onConnect);
    jug.on('disconnect', onDisconnect);
    jug.on('reconnect', onReconnect);
    jug.subscribe(gd.jchan, onDataReceived);

    if (gd.heartRate > 0)
      setInterval("heartbeat()", gd.heartRate);
  }

  function onConnect() {
    log("Connected");
  }
  function onDisconnect() {
    log("Disconnected");
  }
  function onReconnect() {
    log("Reconnecting");
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
        $('#pool-info').html(data.body);
        break;

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
          wordItem = $('#word-'+data.new_word_id.join('-'));

          wordItem.addClass('highlighted');
          wordItem.effect('highlight', {}, 5000);
        }

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

  return {
    init: init
  }
}();
