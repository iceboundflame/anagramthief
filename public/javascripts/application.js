var Anathief = function() {
  var gd;
  var jug;
  var gameOver = false, votedDone = false;
  var connected = false;

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

    initInstructionsInterface();
    initInviteInterface();

    initPromptLogin();
  }

  /** Connectivity **/

  function initConn() {
    /*window.WEB_SOCKET_SWF_LOCATION = "http://iceboundflame.com:8080/WebSocketMain.swf";*/

    disableConnUi();
    addMessage(null, 'Connecting...');

    jug = new Juggernaut();
    jug.on('connect', onConnect);
    jug.on('disconnect', onDisconnect);
    jug.on('reconnect', onReconnect);
    jug.subscribe(gd.jchan, onDataReceived);

    if (gd.heartRate > 0)
      setInterval('Anathief.heartbeat()', gd.heartRate);
  }

  function disableConnUi() {
    $('.conn-ui').attr('disabled', 'disabled');
  }
  function enableConnUi() {
    $('.conn-ui').removeAttr('disabled');
  }
  function disablePlayUi() {
    $('.play-ui').attr('disabled', 'disabled');
    /*$(document.body).addClass('game-over').removeClass('game-on');*/
    $(document.body).addClass('game-over');
  }
  function enablePlayUi() {
    $('.play-ui').removeAttr('disabled');
    /*$(document.body).addClass('game-on').removeClass('game-over');*/
    $(document.body).removeClass('game-over');
  }

  function onConnect() {
    refreshState();
    addMessage(null, 'Connected!');
    enableConnUi();
    log('Connected');
    connected = true;
  }
  function onDisconnect() {
    addMessage(null, 'Disconnected.');
    disableConnUi();
    log('Disconnected');
    connected = false;
  }
  function onReconnect() {
    addMessage(null, 'Reconnecting...');
    log('Reconnecting');
  }

  function onDataReceived(data) {
    log(data);
    switch (data.type) {
      case 'chat':
        addMessage(data.from, data.body, false, 'chat', true);
        break;

      case 'action':
        addMessage(data.from, data.body, true, data.msgclass, !!data.msgclass);
        break;

      case 'update':
        processUpdate(data);
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
    $('#chat').keyup(function(e) {
      if (e.keyCode != 13) return;
      var msg = $('#chat').val();

      if (!msg) return;

      $.post(gd.urls.chat,
        {message: msg});

      $('#chat').val('');
      return false;
    });

    $('#message-area').click(function() {
      $('#chat').focus();
    });
  }

  /** Game Interface: Flip, Claim, Vote Restart **/

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

    function voteBtn(vote) {
      votedDone = vote;
      $.post(gd.urls.voteDone, {vote: votedDone});
      updateDoneButton();
    }
    $('#vote-done-btn').click(function() { voteBtn(true); });
    $('#cancel-vote-btn').click(function() { voteBtn(false); });
    $('#restart-btn').click(function() {
      $.post(gd.urls.restart);
    });

    $('#refresh-btn').click(function() { refreshState(); return false; });
  }

  function refreshState() {
    $.post(gd.urls.refresh, {},
      function(data) {
        log(data);
        processUpdate(data);
      },
      'json');
  }

  function flipChar() {
    $('#flip-btn').attr('disabled', 'disabled');
    /*$('#flip-wait').show();*/
    setTimeout(function () {
        /*$('#flip-wait').hide();*/
      if (connected && !gameOver)
        $('#flip-btn').removeAttr('disabled');
    }, 1000); // make sure this is in sync with the server side delay
    $.post(gd.urls.flipChar,
      function(data) {
        if (data.message) {
          addMessage(null, data.message, true);
        }
      });
    $('#claimword').focus();
  }

  function updateDoneButton() {
    if (gameOver) {
      $('#vote-done-btn').hide();
      $('#cancel-vote-btn').hide();
    } else if (votedDone) {
      $('#vote-done-btn').hide();
      $('#cancel-vote-btn').show();
    } else {
      $('#vote-done-btn').show();
      $('#cancel-vote-btn').hide();
    }
  }


  function processUpdate(data) {
    if (data.pool_info)
      updatePool(data.pool_info);

    if (data.players_info)
      updatePlayersInfo(data.players_info);

    if (data.game_over_info)
      updateGameOverInfo(data.game_over_info);

    FB.Canvas.setSize();
  }

  function updateGameOverInfo(data) {
    gameOver = data.game_over;
    if (gameOver) {
      disablePlayUi();
    } else {
      enablePlayUi();
    }
    if (data.body) {
      $('#game-over-info').html(data.body);
    }

    votedDone = ($.inArray(gd.me_id, data.users_voted_done) != -1);

    if (data.publish_fb) {
      publishGame(data.publish_fb);
    }

    updateDoneButton();
  }

  function updatePool(data) {
    $('#pool-info').html(data.body);
  }

  function updatePlayersInfo(data) {
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
      $('#word-'+data.new_word_id.join('-'))
        .addClass('highlighted')
        .effect('highlight', {}, 5000);
    }
  }

  function publishGame(data) {
    if (gd.isGuest) {
      $('#prompt-login').show();
    } else {
      FB.ui({
          method: 'feed',
          /*display: 'popup',*/
          name: data.title_line,
          link: gd.urls.canvas,
          picture: gd.urls.fbPostImg,
          description: 'Anagram Thief is an exciting multi-player game where you try to make words by stealing letters from your opponents.',
          properties: data.properties,
          message: ''
        },
        function(response) {
        });
    }
  }

  // Messages area
  function addMessage(from, message, isAction, msgclass, suppressHighlight) {
    var msgId = 'message-' + Math.floor(Math.random()*2147483647);
    var li = $('<li id="'+msgId+'" />');
    if (from)
      li.append($('<strong />').text(from.name)).append(' ');
    if (msgclass) li.addClass(msgclass);
    li.append(message);
    $('#messages').append(li);
    messageArea = $('#message-area');
    messageArea.scrollTop(messageArea[0].scrollHeight);
    if (!suppressHighlight)
      $('#'+msgId).effect('highlight', {}, 3000);
  }

  function initInstructionsInterface() {
    $('#show-instructions-link').click(function() {
      showInstructions();
      return false;
    });
    $('#hide-instructions-link').click(function() {
      hideInstructions();
      return false;
    });
  }
  function hideInstructions() {
    $('#hide-instructions-link').hide();
    $('#show-instructions-link').show();
    $('#instructions-section').slideUp(null, setSize);
  }
  function showInstructions() {
    $('#show-instructions-link').hide();
    $('#hide-instructions-link').show();
    $('#instructions-section').slideDown(null, setSize);
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
    $('#invites-section').slideUp(null, function(){
      $('#invites-section').hide(); // make document.body.scrollHeight good again
      setSize();
    });
  }
  function showInvites() {
    $('#show-invites-link').hide();
    $('#hide-invites-link').show();
    $('#invites-section').slideDown(null, setSize);
  }

  function initPromptLogin() {
    $('#hide-prompt-login').click(function() {
      $('#prompt-login').hide();
      return false;
    });
  }

  function setSize() {
    // FB by default doesn't make room for scrollbars
    // N.B. document.body doesn't shrink less than the current viewport height
    // in Chrome, but document.documentElement does.
    FB.Canvas.setSize({height: document.documentElement.scrollHeight + 30});
    /*FB.Canvas.setSize({height: $('#wrap')[0].scrollHeight + 30});*/
  }

  return {
    init: init,
    heartbeat: heartbeat,
    hideInvites: hideInvites,
    showInvites: showInvites,
    setSize: setSize
  };
}();

$(document).ready(function() {
  $('[placeholder]').placeholder();
});
