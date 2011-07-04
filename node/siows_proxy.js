var io = require('socket.io').listen(8023);

var WebSocket = require('websocket-client').WebSocket;

io.sockets.on('connection', function (iosock) {
    var prequeue = [];
    var established = false;

    console.log("New connection!");

    var ws = new WebSocket('ws://localhost:8123');

    ws.onopen = function (event) {
      console.log("Tunnel established");

      established = true;
      prequeue.forEach(function (msg) {
        console.log("P>> "+ msg);
        ws.send(msg);
      });
      prequeue = null;
    };
    ws.onmessage = function (event) {
      console.log("<< " + event.data);
      iosock.send(event.data);
    };
    ws.onclose = function (event) {
      iosock.disconnect();
    };
    ws.onerror = function (event) {
      iosock.disconnect();
    };

    iosock.on('message', function (data) {
      if (established) {
        console.log(">> " + data);
        ws.send(data);
      } else {
        prequeue.push(data);
      }
    });
    iosock.on('disconnect', function () {
      ws.close();
    });
    iosock.on('error', function () {
      ws.close();
    });
  });
