function escapeHtml(text) {
  return text.replace(/[&<>"'`]/g, function (chr) {
      return '&#' + chr.charCodeAt(0) + ';';
    });
}

var Anathief = function() {
  var gd;
  var sock;
  var isGameOver = false, votedDone = false;
  var connected = false;
  var players = {};

  var next_serial = 1;
  var msgResponseCallbacks = {};

  function log(x) {
    if (typeof console == "object")
      console.log(x);
  }

  function ssend(type, data, onresponse) {
    var serial = next_serial++;

    if (onresponse) {
      msgResponseCallbacks[serial] = onresponse;
    }

    var out = JSON.stringify(_.extend({_t: type, _s: serial}, data));
    log(">> " + out);
    sock.send(out);
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

    initBotControl();
  }

  /** Connectivity **/

  function initConn() {
    /*window.WEB_SOCKET_SWF_LOCATION = "http://iceboundflame.com:8080/WebSocketMain.swf";*/

    disableConnUi();
    addMessage(null, 'Connecting...');

    sock = new io.connect(gd.sio);
    sock.on('connect', onConnect);
    sock.on('disconnect', onDisconnect);
    sock.on('reconnect', onReconnect);
    sock.on('message', onMessage);
  }

  function disableConnUi() {
    $('.conn-ui').attr('disabled', 'disabled');
  }
  function enableConnUi() {
    $('.conn-ui').removeAttr('disabled');
  }
  function disablePlayUi() {
    $('.play-ui').attr('disabled', 'disabled');
    $(document.body).addClass('game-over');
  }
  function enablePlayUi() {
    $('.play-ui').removeAttr('disabled');
    $(document.body).removeClass('game-over');
  }

  function onConnect() {
    addMessage(null, 'Logging in...');
    ssend('identify', {id_token: gd.idToken},
      function (data) {
        if (data.ok) {
          addMessage(null, 'Connected.');
          enableConnUi();
          log('Connected');
          connected = true;
        } else {
          addMessage(null, 'Error logging in: '+data.message+'.');
        }
      });
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

  function onMessage(data_) {
    log("<< " + data_);
    data = JSON.parse(data_);
    switch (data._t) {
      case 'response':
        if (data._s in msgResponseCallbacks) {
          msgResponseCallbacks[data._s](data);
          delete msgResponseCallbacks[data._s];
        }
        break;

      case 'chatted':
        addMessage(data.from,
            _.template('says: <%= escapeHtml(message) %>', data),
            'chatted', true);
        break;

      case 'flipped':
        addMessage(data.from,
            _.template('flipped <%= escapeHtml(letter) %>.', data),
            'flipped');
        break;

      case 'claimed':
        data.desc = describeMove(data);
        addMessage(data.from,
            _.template('claimed <%= escapeHtml(word) %><%= desc %>.', data),
            'claimed', true);
        break;

      case 'claim_failed':
        data.desc = describeMove(data);
        data.failReason = failReason(data);
        addMessage(data.from,
            _.template('tried to claim <%= escapeHtml(word) %><%= desc %>, but <%= failReason %>.', data),
            'claim_failed');
        break;

      case 'voted_done':
        addMessage(data.from,
            _.template('<%= vote ? "voted to end the game." : "canceled vote to end game." %>'
              + '<br /><%= num_voted %> votes / <%= num_needed %> needed'
              + '<% if (game_ending) { %><br /><strong>Game Over!</strong><% } %>', data),
            'voted_done');

        if (data.game_ending) {
          var props = {};
          _.each(data.ranks, function(r) {
              var ordinal = r.ordinal;
              if (!(ordinal in props))
                props[ordinal] = [];
              props[ordinal].push(r.name + ", with " + r.score + " letters");
            });

          for (var ord in props) {
            props[ord] = props[ord].join('; ');
          }

          publishGame({
            title_line: "I just played a game of Anagram Thief!",
            properties: props
          });
        }
        break;

      case 'restarted':
        addMessage(data.from, 'restarted the game.', 'restarted');
        break;

      case 'joined':
        addMessage(data.from, 'joined the game.', 'player-joined');
        break;

      case 'left':
        addMessage(data.from, 'left the game.', 'player-left');
        break;

      case 'update':
        processUpdate(data);
        break;

      case 'definitions':
        newdef = $('<div class="active-defn" />').html(JST.definitions(data));
        $('#definition').children().removeClass('active-defn');
        $('#definition').append(newdef);

        break;
    }
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
    $('#chat').keydown(function(e) {
      if (e.keyCode == 13) { // enter
        var msg = $('#chat').val();

        if (msg) {
          ssend('chat', {message: msg});
        } else {
          $('#claimword').focus();
        }

        $('#chat').val('');
        return false;

      } else if (e.keyCode == 27) { // escape
        $('#chat').val('');
        $('#claimword').focus();
        return false;

      }
    });

    $('#message-area').click(function() {
      $('#chat').focus();
    });
  }

  /** Game Interface: Flip, Claim, Vote Restart **/

  function initGameInterface() {
    function flipChar() {
      $('#flip-btn').attr('disabled', 'disabled');

      setTimeout(function () {
        if (connected && !isGameOver)
          $('#flip-btn').removeAttr('disabled');
      }, 1000); // make sure this is in sync with the server side delay

      ssend('flip', {}, function (data) {
          if (data.message) {
            addMessage(null, data.message);
          }
        });

      $('#claimword').focus();
    }

    function submitClaim() {
      var word = $('#claimword').val();
      if (!word) {
        flipChar();
        return;
      }

      ssend('claim', {word: word});

      $('#claimword').val('');
    }

    $('#flip-btn').click(function() { flipChar(); return false; });

    $('#claimword').keydown(function(e) {
        if (e.keyCode == 32) { // spacebar
          $('#chat').focus();
          return false;
        } else if (e.keyCode == 27) { // escape
          $('#claimword').val('');
          return false;
        } else if (e.keyCode == 13) { // enter
          submitClaim();
          return false;
        }
      });
    $('#claim-btn').click(function() { submitClaim(); return false; });

    function voteBtn(vote) {
      votedDone = vote;
      ssend('vote_done', {vote: vote});
      updateDoneButton();
    }
    $('#vote-done-btn').click(function() { voteBtn(true); });
    $('#cancel-vote-btn').click(function() { voteBtn(false); });
    $('#restart-btn').click(function() { ssend('restart'); });
    $('#refresh-btn').click(function() { refreshState(); });
  }

  function refreshState() {
    ssend('refresh', {}, function (data) {
        if (data.ok) {
          processUpdate(data.update_data);
        }
      });
  }

  function updateDoneButton() {
    if (isGameOver) {
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
    players = data.players;

    updatePool(data);
    updatePlayers(data);
    updateGameOver(data);

    FB.Canvas.setSize();
  }

  function updatePool(data) {
    $('#pool-area').html(
        JST.tiles({tiles: data.pool, num_unseen: data.pool_remaining})
      );
  }

  function updatePlayers(data) {
    players = data.players;

    $('#player-area').empty();

    _.each(data.players_order, function (pid) {
      $('#player-area').append(
          JST.player(_.extend({tiles_template: JST.tiles}, players[pid]))
        );
    });
/*    if (data.added) {
      for (var i in data.added) {
        var id = data.added[i];
        $('#player-info-'+id).effect('highlight', {}, 3000);
      }
    }
    if (data.removed) {
      // TODO
    }*/

    /*if (data.new_word_id) {
      $('#word-'+data.new_word_id.join('-'))
        .addClass('highlighted')
        .effect('highlight', {}, 5000);
    }*/
  }

  function updateGameOver(data) {
    isGameOver = data.is_game_over;
    if (isGameOver) {
      disablePlayUi();
      $('#game-over-area').html(JST.game_over(data));
    } else {
      enablePlayUi();
      $('#game-over-area').empty();
    }

    votedDone = ($.inArray(gd.userId, data.players_voted_done) != -1);

    /*if (data.publish_fb) {*/
    /*publishGame(data.publish_fb);*/
    /*}*/

    updateDoneButton();
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
  function addMessage(from, message, msgclass, suppressHighlight) {
    var msgId = 'message-' + Math.floor(Math.random()*2147483647);
    var li = $('<li id="'+msgId+'" />');
    if (from && players[from]) {
      var fromName = players[from].name;
      li.append($('<strong />').text(fromName)).append(' ');
    }
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

  function initBotControl() {
    $('#bot-btn').click(function() {
      //
      $.post(gd.urls.addBot, {game_id: gd.gameId, level: $('#robot-level').val()});
      return false;
    });
    $('#nobot-btn').click(function() {
      //
      $.post(gd.urls.removeBot, {game_id: gd.gameId});
      return false;
    });
  }
  function removeBot(id) {
    $.post(gd.urls.removeBot, {game_id: gd.gameId, bot_id: id});
    return false;
  }

  function setSize() {
    // FB by default doesn't make room for scrollbars
    // N.B. document.body doesn't shrink less than the current viewport height
    // in Chrome, but document.documentElement does.
    FB.Canvas.setSize({height: document.documentElement.scrollHeight + 30});
    /*FB.Canvas.setSize({height: $('#wrap')[0].scrollHeight + 30});*/
  }

  function describeMove(data) {
    var desc = '';
    if (data.words_stolen && data.words_stolen.length) {
      desc += 'stealing ' + data.words_stolen.join(', ');
    }

    if (data.pool_used && data.pool_used.length) {
      desc += (data.words_stolen.length ? ' +' : 'taking');
      desc += ' '+data.pool_used.join(', ');
    }

    if (desc.length) return ' by ' + desc;
    return '';
  }

  function failReason(data) {
    switch (data.cause) {
      case 'word_steal_shares_root':
        return 'they share the common root ' + data.shared_roots.join(', ');

      case 'word_steal_not_extended':
        return "that would be stealing without extending";

      case 'word_too_short':
        return "it's too short";

      case 'word_not_in_dict':
        return "it's not in the dictionary";

      case 'word_not_available':
        return "it's not on the board";

      default:
        return data.cause;
    }
  }

  return {
    init: init,
    hideInvites: hideInvites,
    showInvites: showInvites,
    setSize: setSize,
    removeBot: removeBot,
  };
}();

$(document).ready(function() {
  $('[placeholder]').placeholder();
});

if (top.location.href == window.location.href)
  $(document.body).addClass('standalone');
