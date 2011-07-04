var io = require('socket.io').listen(8023);

var WebSocket = require('websocket-client').WebSocket;

io.sockets.on('connection', function (iosock) {
    var prequeue = [];
    var established = false;

    console.log("New connection!");
    /*iosock.send('wait');*/

    /*for (var i = 0; i < 10000000; ++i) {*/
    /*var j = Math.sqrt(i);*/
    /*}*/
    console.log("Stall complete");
    var ws = new WebSocket('ws://localhost:8123');

    ws.onopen = function (event) {
      console.log("Tunnel established");
      /*iosock.send('connected');*/

      // TODO: test this
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
});
